extends TestCase
## Cierre controlado: X de la ventana, Alt + F4 y botones de salida. La salida real se
## sustituye para no cerrar el ejecutor de pruebas.

var _targets: Array = []
var _writes: Array[String] = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	GameState.location_id = "plaza"
	SaveSystem.begin_session(self)
	_targets.clear()
	_writes.clear()
	ExitManager.finish_override = func(target: int) -> void: _targets.append(target)
	SaveSystem.save_started.connect(_on_save_started)


func after_each() -> void:
	SaveSystem.save_started.disconnect(_on_save_started)
	if ExitManager.is_dialog_open():
		(ExitManager.get_node("Root/Center/Dialog/Box/Buttons/Cancel") as Button).pressed.emit()
	ExitManager.finish_override = Callable()
	get_tree().paused = false
	DialogueManager.close()
	SaveSystem.end_session(self)
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _on_save_started(slot_id: String) -> void:
	_writes.append(slot_id)


func _close_window() -> void:
	ExitManager.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)


func _wait_until(condition: Callable, frames: int = 180) -> bool:
	for frame in frames:
		if condition.call():
			return true
		await get_tree().process_frame
	return condition.call()


func _reason_in(slot_id: String) -> String:
	var result := SaveSystem.read_slot(slot_id)
	if result["status"] != SaveFormat.Status.OK:
		return ""
	return result["document"]["meta"].get("reason", "")


func _press(path: String) -> void:
	(ExitManager.get_node(path) as Button).pressed.emit()


func test_godot_does_not_close_on_its_own() -> void:
	check(not get_tree().auto_accept_quit, "la ventana no se cierra sin pasar por el guardado")


func test_closing_the_window_saves_into_the_active_slot() -> void:
	await save_and_wait("manual_2")
	GameState.set_flag("antes_de_cerrar")
	_writes.clear()
	_close_window()
	check(await _wait_until(func() -> bool: return not _targets.is_empty()), "termina la salida")
	check_equal(_targets, [ExitManager.Target.QUIT], "y cierra el juego")
	check_equal(_writes, ["manual_2"] as Array[String], "una sola escritura, en la ranura activa")
	check_equal(_reason_in("manual_2"), "salida", "marcada como guardado al salir")
	var flags: Array = SaveSystem.read_slot("manual_2")["document"]["sections"]["state"]["flags"]
	check(flags.has("antes_de_cerrar"), "con el estado de ese momento")
	for slot_id: String in ["manual_1", "manual_3", "manual_4", "manual_5"]:
		check_equal(SaveSystem.get_slot_info(slot_id)["status"], SaveFormat.Status.EMPTY, "sin tocar %s" % slot_id)


func test_repeated_close_requests_write_once() -> void:
	await save_and_wait("manual_1")
	GameState.set_flag("progreso")
	_writes.clear()
	for attempt in 3:
		_close_window()
	await _wait_until(func() -> bool: return not _targets.is_empty())
	await get_tree().process_frame
	check_equal(_writes.size(), 1, "tres peticiones, una escritura")
	check_equal(_targets.size(), 1, "y una sola salida")


func test_a_running_save_finishes_before_the_exit_save() -> void:
	await save_and_wait("manual_3")
	GameState.set_flag("progreso")
	_writes.clear()
	check(SaveSystem.save_to_slot("manual_3")["ok"], "empieza un guardado")
	ExitManager.request_exit(ExitManager.Target.QUIT)
	check_equal(_writes.size(), 1, "la salida espera a que termine")
	await _wait_until(func() -> bool: return not _targets.is_empty())
	check_equal(_writes.size(), 2, "y después guarda una vez")


func test_without_active_slot_the_player_is_asked() -> void:
	GameState.set_flag("progreso_sin_ranura")
	_close_window()
	await _wait_until(func() -> bool: return ExitManager.is_dialog_open())
	check(ExitManager.is_dialog_open(), "pregunta en lugar de cerrar")
	check(_targets.is_empty(), "el juego sigue abierto")
	check(_writes.is_empty(), "y no ha escrito en ninguna ranura")
	check(get_tree().paused, "con el juego en pausa")
	_press("Root/Center/Dialog/Box/Buttons/Cancel")
	check(not ExitManager.is_dialog_open() and not ExitManager.is_exiting(), "cancelar vuelve al juego")
	check(not get_tree().paused, "y lo reanuda")


func test_choosing_a_slot_saves_and_then_exits() -> void:
	GameState.set_flag("progreso_sin_ranura")
	_close_window()
	await _wait_until(func() -> bool: return ExitManager.is_dialog_open())
	_press("Root/Center/Dialog/Box/Buttons/Primary")
	var slots: SaveSlotsMenu = ExitManager.get_node("Root/SaveSlotsMenu")
	check(slots.visible and slots.mode == SaveSlotsMenu.Mode.SAVE, "se abre la lista para guardar")
	slots.select_slot("manual_4")
	slots.get_action_button().pressed.emit()
	await _wait_until(func() -> bool: return not _targets.is_empty())
	check_equal(_targets, [ExitManager.Target.QUIT], "sale tras guardar")
	check_equal(_reason_in("manual_4"), "salida", "en la ranura elegida")
	check_equal(SaveSystem.get_active_slot(), "manual_4", "que pasa a ser la activa")


func test_leaving_without_saving_is_an_explicit_choice() -> void:
	GameState.set_flag("progreso_sin_ranura")
	_close_window()
	await _wait_until(func() -> bool: return ExitManager.is_dialog_open())
	_press("Root/Center/Dialog/Box/Buttons/Leave")
	check_equal(_targets, [ExitManager.Target.QUIT], "sale")
	check(_writes.is_empty(), "sin escribir nada")


func test_a_failed_write_never_exits_silently() -> void:
	await save_and_wait("manual_2")
	GameState.set_flag("progreso")
	var blocker := SaveSystem.get_slot_path("manual_2") + SaveFile.TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(blocker)
	_close_window()
	await _wait_until(func() -> bool: return ExitManager.is_dialog_open())
	check(ExitManager.is_dialog_open(), "avisa del fallo")
	check(_targets.is_empty(), "y no cierra")
	DirAccess.remove_absolute(blocker)
	_press("Root/Center/Dialog/Box/Buttons/Primary")
	await _wait_until(func() -> bool: return not _targets.is_empty())
	check_equal(_targets, [ExitManager.Target.QUIT], "reintentar guarda y sale")
	check_equal(_reason_in("manual_2"), "salida", "con la partida al día")


func test_closing_mid_conversation_saves_the_state_before_it() -> void:
	await save_and_wait("manual_1")
	GameState.set_flag("antes_de_la_escena")
	DialogueManager.play_scene("intro")
	GameState.set_flag("a_medias")
	_close_window()
	await _wait_until(func() -> bool: return not _targets.is_empty())
	var flags: Array = SaveSystem.read_slot("manual_1")["document"]["sections"]["state"]["flags"]
	check(flags.has("antes_de_la_escena"), "guarda lo anterior a la conversación")
	check(not flags.has("a_medias"), "y no un estado a medio aplicar")


func test_closed_case_exits_without_saving() -> void:
	await save_and_wait("manual_1")
	GameState.set_flag(SaveSystem.CASE_CLOSED_FLAG)
	_writes.clear()
	_close_window()
	await _wait_until(func() -> bool: return not _targets.is_empty())
	check(_writes.is_empty(), "con el caso cerrado no se guarda")
	check_equal(_targets, [ExitManager.Target.QUIT], "y se sale")


func test_main_menu_quit_without_a_game_exits_directly() -> void:
	SaveSystem.end_session(self)
	var menu: Node = (load("res://scenes/main/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	(menu.get_node("%Quit") as Button).pressed.emit()
	await _wait_until(func() -> bool: return not _targets.is_empty())
	check_equal(_targets, [ExitManager.Target.QUIT], "«Salir» usa la misma ruta y sale")
	check(_writes.is_empty(), "sin partida no hay nada que guardar")
	menu.queue_free()
	await get_tree().process_frame
