extends TestCase
## Ranuras, restauración completa de la partida y protección frente a operaciones inválidas.


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	SaveSystem.begin_session(self)


func after_each() -> void:
	SaveSystem.end_session(self)
	SaveSystem.take_pending_load()
	SaveSystem.autosave_enabled = false
	DialogueManager.close()
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _prepare_state(minutes: int, clue_id: String = "") -> void:
	GameState.location_id = "plaza"
	GameClock.minutes = minutes
	if not clue_id.is_empty():
		Investigation.discover_clue(clue_id)


func _minutes_in(slot_id: String) -> int:
	var result := SaveSystem.read_slot(slot_id)
	if result["status"] != SaveFormat.Status.OK:
		return -1
	return int(result["document"]["sections"]["clock"]["minutes"])


func _free_game(game: Game) -> void:
	game.queue_free()
	await get_tree().process_frame


func test_player_resumes_at_the_exact_position() -> void:
	SaveSystem.end_session(self)
	var game := await make_game()
	await game.go_to("plaza", "desde_cafe")
	game.player.teleport(game.player.global_position + Vector3(2.0, 0.0, 3.0), 1.25)
	await wait_physics_frames(2)
	var saved_at := game.player.global_position
	check(await save_and_wait("manual_1"), "se guarda desde la partida")
	await _free_game(game)
	GameState.reset()
	GameClock.reset()
	check(SaveSystem.request_load("manual_1")["ok"], "se prepara la carga")
	var resumed := await make_game()
	check_equal(resumed.current_location.location_id, "plaza", "mismo lugar")
	check(resumed.player.global_position.distance_to(saved_at) < 0.2, "misma posición")
	check(is_equal_approx(resumed.player.model.rotation.y, 1.25), "misma orientación")
	await _free_game(resumed)


func test_play_time_survives_a_reload() -> void:
	_prepare_state(600)
	GameState.play_seconds = 3725.0
	await save_and_wait("manual_1")
	check(is_equal_approx(SaveSystem.get_slot_info("manual_1")["summary"]["play_seconds"], 3725.0), "el menú lo muestra")
	GameState.reset()
	SaveSystem.apply_sections(SaveSystem.read_slot("manual_1")["document"]["sections"])
	check(is_equal_approx(GameState.play_seconds, 3725.0), "conserva el tiempo jugado")


func test_unloadable_state_is_never_written() -> void:
	var result := SaveSystem.save_to_slot("manual_1")
	check(not result["ok"], "sin lugar no hay partida que reconstruir")
	check(not (result["error"] as String).is_empty(), "explica el motivo")
	check(not SaveFile.exists(SaveSystem.get_slot_path("manual_1")), "no deja ningún archivo")


func test_slots_are_independent() -> void:
	_prepare_state(600, "reloj_despacho")
	await save_and_wait("manual_1")
	GameState.reset()
	_prepare_state(900, "foto_clara")
	await save_and_wait("manual_2")
	var first: Dictionary = SaveSystem.read_slot("manual_1")["document"]["sections"]["state"]
	var second: Dictionary = SaveSystem.read_slot("manual_2")["document"]["sections"]["state"]
	check(first["clues"].has("reloj_despacho") and not first["clues"].has("foto_clara"), "la ranura 1 sólo tiene lo suyo")
	check(second["clues"].has("foto_clara") and not second["clues"].has("reloj_despacho"), "la ranura 2 sólo tiene lo suyo")


func test_overwriting_replaces_the_content() -> void:
	_prepare_state(600)
	await save_and_wait("manual_1")
	_prepare_state(1200)
	check(await save_and_wait("manual_1"), "se sobrescribe")
	check_equal(_minutes_in("manual_1"), 1200, "queda la versión nueva")
	var path := SaveSystem.get_slot_path("manual_1")
	check(not FileAccess.file_exists(path + SaveFile.TEMP_SUFFIX), "sin temporales")
	check(not FileAccess.file_exists(path + SaveFile.BACKUP_SUFFIX), "sin copias sobrantes")


func test_deleting_a_slot_keeps_the_others() -> void:
	_prepare_state(600)
	await save_and_wait("manual_1")
	await save_and_wait("manual_2")
	var deleted: Array[String] = []
	var on_deleted := func(slot_id: String) -> void: deleted.append(slot_id)
	SaveSystem.slot_deleted.connect(on_deleted)
	check(SaveSystem.delete_slot("manual_1")["ok"], "se elimina")
	SaveSystem.slot_deleted.disconnect(on_deleted)
	check_equal(deleted, ["manual_1"] as Array[String], "avisa del borrado")
	check_equal(SaveSystem.get_slot_info("manual_1")["status"], SaveFormat.Status.EMPTY, "la ranura queda vacía")
	check_equal(SaveSystem.get_slot_info("manual_2")["status"], SaveFormat.Status.OK, "la otra sigue intacta")


func test_autosave_writes_only_the_active_slot() -> void:
	_prepare_state(500)
	await save_and_wait("manual_1")
	_prepare_state(600)
	await save_and_wait("manual_2")
	_prepare_state(700)
	check(await autosave_and_wait("lugar"), "el autoguardado escribe")
	check_equal(_minutes_in("manual_2"), 700, "en la ranura activa")
	check_equal(_minutes_in("manual_1"), 500, "sin tocar las demás")
	await save_and_wait("manual_4")
	_prepare_state(800)
	await autosave_and_wait("pista")
	check_equal(_minutes_in("manual_4"), 800, "tras guardar en otra ranura, los autoguardados la siguen")
	check_equal(_minutes_in("manual_2"), 700, "y la anterior ya no cambia")
	for slot_id: String in ["manual_3", "manual_5"]:
		check_equal(SaveSystem.get_slot_info(slot_id)["status"], SaveFormat.Status.EMPTY, "no se crean ranuras nuevas")


func test_autosave_refuses_a_slot_changed_outside_the_game() -> void:
	_prepare_state(600)
	await save_and_wait("manual_2")
	var foreign: Dictionary = SaveSystem.read_slot("manual_2")["document"]
	foreign["meta"]["save_id"] = "otra_partida"
	write_slot_file("manual_2", SaveFormat.to_text(foreign))
	SaveSystem.autosave_enabled = true
	var result := SaveSystem.autosave("lugar")
	check(not result["ok"], "no se sobrescribe una versión que el juego no conoce")
	check(not SaveSystem.has_active_slot(), "y la ranura deja de ser la activa")
	check_equal(SaveSystem.read_slot("manual_2")["document"]["meta"]["save_id"], "otra_partida", "el archivo ajeno sigue intacto")


func test_continue_picks_the_most_recent_valid_save() -> void:
	_prepare_state(600)
	await save_and_wait("manual_2")
	await save_and_wait("manual_1")
	check_equal(SaveSystem.find_latest_slot(), "manual_1", "el guardado posterior gana")
	await save_and_wait("manual_4")
	check_equal(SaveSystem.find_latest_slot(), "manual_4", "y otro posterior también")
	write_slot_file("manual_5", "{roto")
	check_equal(SaveSystem.find_latest_slot(), "manual_4", "los archivos dañados se ignoran")


func test_simultaneous_operations_are_rejected() -> void:
	_prepare_state(600)
	check(SaveSystem.save_to_slot("manual_1")["ok"], "empieza el primer guardado")
	check(SaveSystem.is_busy(), "el gestor está ocupado")
	check(not SaveSystem.save_to_slot("manual_2")["ok"], "un segundo guardado se rechaza")
	check(not SaveSystem.delete_slot("manual_1")["ok"], "no se borra una ranura mientras se escribe")
	var outcome: Array = await SaveSystem.save_finished
	check(outcome[1], "el primero termina bien")
	check(not SaveSystem.is_busy(), "queda libre")
	check_equal(SaveSystem.get_slot_info("manual_2")["status"], SaveFormat.Status.EMPTY, "el rechazado no escribió nada")


func test_saving_is_blocked_in_unsafe_moments() -> void:
	_prepare_state(600)
	check(SaveSystem.get_save_blocker().is_empty(), "explorando se puede guardar")
	GameState.lock_player("pausa")
	check(SaveSystem.get_save_blocker().is_empty(), "desde la pausa también")
	GameState.lock_player("transicion")
	check(SaveSystem.get_save_blocker().contains("cambio de lugar"), "no durante una transición")
	GameState.clear_player_locks()
	GameState.lock_player("tablero")
	check(not SaveSystem.get_save_blocker().is_empty(), "no con un panel abierto")
	GameState.clear_player_locks()
	DialogueManager.play_scene("intro")
	check(SaveSystem.get_save_blocker().contains("conversación"), "no durante una escena")
	check(not SaveSystem.save_to_slot("manual_1")["ok"], "el guardado se rechaza")
	DialogueManager.close()
	GameState.clear_player_locks()
	GameState.set_flag(SaveSystem.CASE_CLOSED_FLAG)
	check(not SaveSystem.get_save_blocker().is_empty(), "no con el caso cerrado")
	SaveSystem.end_session(self)
	GameState.flags.clear()
	check(not SaveSystem.get_save_blocker().is_empty(), "no sin partida en curso")


func test_unknown_slot_ids_are_rejected() -> void:
	_prepare_state(600)
	for slot_id: String in ["../ajustes", "manual_0", "manual_6", "auto_1", ""]:
		check(not SaveSystem.is_valid_slot(slot_id), "«%s» no es una ranura" % slot_id)
		check(not SaveSystem.save_to_slot(slot_id)["ok"], "no se guarda en «%s»" % slot_id)
		check(not SaveSystem.request_load(slot_id)["ok"], "no se carga «%s»" % slot_id)
		check(not SaveSystem.delete_slot(slot_id)["ok"], "no se borra «%s»" % slot_id)
	check_equal(SaveSystem.get_slots().size(), SaveSystem.SLOT_COUNT, "cinco ranuras")


func test_backup_is_used_when_the_main_file_is_damaged() -> void:
	_prepare_state(780)
	await save_and_wait("manual_1")
	var path := SaveSystem.get_slot_path("manual_1")
	DirAccess.copy_absolute(path, path + SaveFile.BACKUP_SUFFIX)
	write_slot_file("manual_1", "{roto")
	check_equal(_minutes_in("manual_1"), 780, "se recupera desde la copia")


func test_version_one_save_is_imported_once() -> void:
	var legacy := {
		"version": 1,
		"state": {"flags": ["llamada_atendida"], "clues": ["carta_valdes"], "testimonies": [], "deductions": [],
			"asked_topics": [], "hypotheses": {}, "location_id": "cafe", "spawn_id": "desde_plaza",
			"accusation_attempts": 0},
		"clock": {"day": 1, "minutes": 1410},
	}
	var legacy_path := SaveSystem.get_storage_dir().path_join("partida.json")
	var file := FileAccess.open(legacy_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	SaveSystem.use_storage(SaveSystem.get_storage_dir())
	var info := SaveSystem.get_slot_info("manual_1")
	check_equal(info["status"], SaveFormat.Status.OK, "la partida antigua aparece en la primera ranura")
	check_equal(info["summary"]["reason"], "importada", "marcada como importada")
	check_equal(info["summary"]["play_seconds"], -1.0, "sin tiempo jugado inventado")
	check(FileAccess.file_exists(legacy_path), "el archivo original no se toca")
	SaveSystem.delete_slot("manual_1")
	SaveSystem.use_storage(SaveSystem.get_storage_dir())
	check_equal(SaveSystem.get_slot_info("manual_1")["status"], SaveFormat.Status.EMPTY, "no se vuelve a importar")


func test_previous_autosaves_are_imported_once() -> void:
	_prepare_state(600)
	await save_and_wait("manual_1")
	var older: Dictionary = SaveSystem.read_slot("manual_1")["document"]
	older["meta"]["kind"] = "auto"
	older["meta"]["saved_at"] = 1000.0
	var newer: Dictionary = older.duplicate(true)
	newer["meta"]["saved_at"] = 2000.0
	newer["sections"]["clock"]["minutes"] = 1234
	var directory := SaveSystem.get_storage_dir()
	for entry: Array in [["auto_1.json", older], ["auto_2.json", newer]]:
		var file := FileAccess.open(directory.path_join(entry[0]), FileAccess.WRITE)
		file.store_string(SaveFormat.to_text(entry[1]))
		file.close()
	SaveSystem.use_storage(directory)
	check_equal(_minutes_in("manual_2"), 1234, "el autoguardado más reciente pasa a la primera ranura libre")
	check_equal(SaveSystem.get_slot_info("manual_2")["summary"]["reason"], "importada", "marcado como importado")
	check(FileAccess.file_exists(directory.path_join("auto_1.json")), "los archivos originales no se tocan")
	SaveSystem.delete_slot("manual_2")
	SaveSystem.use_storage(directory)
	check_equal(SaveSystem.get_slot_info("manual_2")["status"], SaveFormat.Status.EMPTY, "no se vuelve a importar")


func test_visited_places_survive_a_reload() -> void:
	_prepare_state(600)
	TownMap.reset()
	EventBus.location_changed.emit("plaza")
	EventBus.location_changed.emit("archivo")
	await save_and_wait("manual_1")
	var sections: Dictionary = SaveSystem.read_slot("manual_1")["document"]["sections"]
	check_equal(sections.get("map", {}).get("visited", []), ["archivo", "plaza"], "la partida guarda los lugares visitados")
	TownMap.reset()
	SaveSystem.apply_sections(sections)
	check_equal(TownMap.get_visited_ids(), PackedStringArray(["archivo", "plaza"]), "y se recuperan al cargar")
	sections.erase("map")
	SaveSystem.apply_sections(sections)
	check(TownMap.get_visited_ids().is_empty(), "una partida anterior al mapa carga sin lugares visitados")


func test_new_game_does_not_inherit_previous_state() -> void:
	_prepare_state(1300, "reloj_despacho")
	EventBus.location_changed.emit("archivo")
	GameState.set_flag("ortega_briefing")
	GameState.play_seconds = 999.0
	GameClock.day = 3
	await save_and_wait("manual_1")
	SaveSystem.end_session(self)
	var game := await make_game()
	check(GameState.clues.is_empty(), "sin pistas")
	check(not GameState.has_flag("ortega_briefing"), "sin marcas")
	check_equal(GameClock.day, 1, "día uno")
	check(GameState.play_seconds < 5.0, "el tiempo jugado empieza de cero")
	check_equal(game.current_location.location_id, "estacion", "empieza en la estación")
	check_equal(TownMap.get_visited_ids(), PackedStringArray(["estacion"]), "sin los lugares visitados de la otra partida")
	check_equal(_minutes_in("manual_1"), 1300, "la partida guardada sigue intacta")
	await _free_game(game)
