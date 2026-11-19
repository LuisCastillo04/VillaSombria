extends TestCase
## Cierre real de la ventana, en dos procesos. Lo lanza `tools/probar_cierre.ps1`:
##   --fase=jugar      abre una partida, guarda en dos ranuras, avanza y espera a que el
##                     sistema operativo cierre la ventana (X o Alt + F4).
##   --fase=comprobar  sin ventana: la ranura activa tiene el estado del momento del cierre y
##                     la otra ranura no ha cambiado.

const STORAGE := "user://pruebas_guardado/cierre"
const ACTIVE := "manual_2"
const OTHER := "manual_4"
const EXPECTED_FILE := "esperado.json"
const FLAG := "cerrado_con_la_ventana"


func _ready() -> void:
	SaveSystem.autosave_enabled = false
	SaveSystem.use_storage(STORAGE)
	var phase := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fase="):
			phase = argument.trim_prefix("--fase=")
	match phase:
		"jugar":
			await _play_phase()
			return
		"comprobar":
			_check_phase()
		_:
			failures.append("fase desconocida «%s»" % phase)
	for failure in failures:
		print("FALLO cierre: ", failure)
	if failures.is_empty():
		print("CIERRE correcto")
	get_tree().quit(1 if not failures.is_empty() else 0)


func _play_phase() -> void:
	TestCase.clear_save_storage()
	var game := await make_game()
	await save_and_wait(OTHER)
	await save_and_wait(ACTIVE)
	GameState.set_flag(FLAG)
	Investigation.discover_clue("carta_valdes")
	game.player.teleport(game.player.global_position + Vector3(1.5, 0.0, 0.5), 0.8)
	await wait_physics_frames(3)
	var where := game.player.global_position
	var expected := {
		"position": [where.x, where.y, where.z],
		"other_save_id": SaveSystem.read_slot(OTHER)["document"]["meta"]["save_id"],
	}
	var file := FileAccess.open(STORAGE.path_join(EXPECTED_FILE), FileAccess.WRITE)
	file.store_string(JSON.stringify(expected))
	file.close()
	if not failures.is_empty():
		for failure in failures:
			print("FALLO cierre: ", failure)
		get_tree().quit(1)
		return
	# A partir de aquí sólo el cierre de la ventana termina el proceso.
	print("LISTO para cerrar")


func _check_phase() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORAGE.path_join(EXPECTED_FILE)))
	if not expected is Dictionary:
		failures.append("falta el resultado de la fase de juego")
		return
	var active := SaveSystem.read_slot(ACTIVE)
	check_equal(active["status"], SaveFormat.Status.OK, "la ranura activa se puede leer")
	if active["status"] != SaveFormat.Status.OK:
		return
	var document: Dictionary = active["document"]
	check_equal(document["meta"]["reason"], "salida", "se guardó al cerrar la ventana")
	var state: Dictionary = document["sections"]["state"]
	check((state["flags"] as Array).has(FLAG), "con el progreso posterior al último guardado")
	check((state["clues"] as Array).has("carta_valdes"), "incluida la pista nueva")
	var position: Array = document["sections"]["player"]["position"]
	var saved := Vector3(position[0], position[1], position[2])
	var target: Array = expected["position"]
	check(saved.distance_to(Vector3(target[0], target[1], target[2])) < 0.2, "y la posición del detective")
	var other := SaveSystem.read_slot(OTHER)
	check_equal(other["document"]["meta"].get("save_id", ""), expected["other_save_id"], "la otra ranura no cambió")
	check_equal(SaveSystem.get_active_slot(), ACTIVE, "la ranura activa se recuerda")
	TestCase.clear_save_storage()
