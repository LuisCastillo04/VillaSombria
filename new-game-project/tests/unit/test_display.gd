extends TestCase
## Modo de ventana y resolución: qué se ofrece según el monitor, cómo se ajusta lo pedido, la
## confirmación con cuenta atrás que restaura lo anterior y la ventana de confirmación común.
## Sin ventana (`--headless`) no se mueve nada real: eso lo comprueba `tests/visual/pantalla.tscn`.

var _result: Variant = null


func before_each() -> void:
	_result = null
	TestCase.reset_test_settings()


func after_each() -> void:
	if ConfirmDialog.is_open():
		ConfirmDialog.cancel()
	get_tree().paused = false
	await get_tree().process_frame
	TestCase.reset_test_settings()


## Lanza la petición sin esperarla, para poder contestar a la pregunta mientras tanto.
func _request(mode: String, size: Vector2i, timeout: float = Settings.DISPLAY_CONFIRM_SECONDS) -> void:
	_result = await Settings.request_display_change(mode, size, timeout)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_window_sizes_fit_the_monitor() -> void:
	var small := DisplaySettings.sizes_fitting(Vector2i(1366, 768))
	check_equal(small, [Vector2i(1024, 576), Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1366, 768)] as Array[Vector2i], "en un monitor de 1366 × 768 sólo caben las menores")
	check_equal(DisplaySettings.sizes_fitting(Vector2i(800, 600)), [DisplaySettings.MIN_WINDOW] as Array[Vector2i], "si no cabe ninguna, queda la mínima")
	for size in DisplaySettings.sizes_fitting(Vector2i(4000, 3000)):
		check(size.x >= DisplaySettings.MIN_WINDOW.x and size.y >= DisplaySettings.MIN_WINDOW.y, "ninguna baja del mínimo")
	var windowed := DisplaySettings.resolutions_for("ventana")
	var limit := DisplaySettings.size_limit("ventana")
	for size in windowed:
		check(size.x <= limit.x and size.y <= limit.y, "%s cabe con la barra de título" % size)
	check(DisplaySettings.resolutions_for("sin_bordes").has(DisplaySettings.screen_size()), "sin bordes admite el tamaño del monitor")
	check_equal(DisplaySettings.resolutions_for("pantalla_completa"), [DisplaySettings.screen_size()] as Array[Vector2i], "en pantalla completa manda el monitor")


func test_requested_size_is_adjusted_to_what_fits() -> void:
	var options := DisplaySettings.resolutions_for("ventana")
	check_equal(DisplaySettings.fit(Vector2i(1280, 720), "ventana"), Vector2i(1280, 720), "lo que cabe se respeta")
	var huge := DisplaySettings.fit(Vector2i(7680, 4320), "ventana")
	check_equal(huge, options[options.size() - 1], "lo que no cabe baja a la mayor disponible")
	check_equal(DisplaySettings.fit(Vector2i(1100, 700), "ventana"), Vector2i(1024, 576), "y lo intermedio, a la mayor que no lo supera")
	check_equal(DisplaySettings.fit(Vector2i(1280, 720), "exclusiva"), DisplaySettings.screen_size(), "en pantalla completa, la del monitor")


func test_fullscreen_switch_and_window_mode_are_the_same_setting() -> void:
	for mode: String in ["pantalla_completa", "exclusiva"]:
		Settings.set_value("graficos/modo_ventana", mode)
		check(Settings.fullscreen, "«%s» cuenta como pantalla completa" % mode)
	for mode: String in ["ventana", "sin_bordes"]:
		Settings.set_value("graficos/modo_ventana", mode)
		check(not Settings.fullscreen, "«%s» no" % mode)
	Settings.set_fullscreen(true)
	check_equal(Settings.get_value("graficos/modo_ventana"), "pantalla_completa", "activar pantalla completa elige ese modo")
	Settings.set_fullscreen(false)
	check_equal(Settings.get_value("graficos/modo_ventana"), "ventana", "y desactivarla vuelve a la ventana")


func test_confirmed_display_change_is_saved() -> void:
	_request("sin_bordes", Vector2i(1366, 768))
	await get_tree().process_frame
	check(ConfirmDialog.is_open(), "se pregunta si se mantiene")
	check_equal(ConfirmDialog.get_title_text(), "¿MANTENER ESTA PANTALLA?", "con su título")
	check(ConfirmDialog.get_message_text().contains("Ventana sin bordes"), "nombrando el modo nuevo")
	check(ConfirmDialog.get_countdown_text().contains("15 s"), "y la cuenta atrás")
	check_equal(Settings.get_value("graficos/modo_ventana"), "ventana", "mientras tanto no se guarda nada")
	check(Settings.is_display_change_pending(), "y el cambio queda pendiente")
	check(get_viewport().gui_get_focus_owner() == ConfirmDialog.get_cancel_button(), "el foco empieza en «Restaurar»")
	ConfirmDialog.get_confirm_button().pressed.emit()
	await get_tree().process_frame
	check_equal(_result, true, "«Mantener» confirma")
	check_equal(Settings.get_value("graficos/modo_ventana"), "sin_bordes", "el modo se guarda")
	check_equal(Settings.get_value("graficos/resolucion"), Vector2i(1366, 768), "y la resolución")
	var stored := ConfigFile.new()
	stored.load(Settings.settings_path)
	check_equal(stored.get_value("graficos", "modo_ventana", ""), "sin_bordes", "en el archivo")


func test_restoring_keeps_the_previous_display() -> void:
	_request("exclusiva", Vector2i(1280, 720))
	await get_tree().process_frame
	ConfirmDialog.get_cancel_button().pressed.emit()
	await get_tree().process_frame
	check_equal(_result, false, "«Restaurar» descarta el cambio")
	check_equal(Settings.get_value("graficos/modo_ventana"), "ventana", "y el modo sigue siendo el anterior")
	check(not Settings.is_display_change_pending(), "sin nada pendiente")


func test_unanswered_change_is_restored_after_the_countdown() -> void:
	_request("pantalla_completa", Vector2i(1280, 720), 0.4)
	await get_tree().process_frame
	check(ConfirmDialog.is_open(), "se pregunta")
	await _wait(0.7)
	check(not ConfirmDialog.is_open(), "al agotarse el tiempo la pregunta se cierra sola")
	check_equal(_result, false, "como si se hubiera restaurado")
	check_equal(Settings.get_value("graficos/modo_ventana"), "ventana", "y la pantalla vuelve a la anterior")


func test_countdown_runs_with_the_game_paused() -> void:
	get_tree().paused = true
	_request("sin_bordes", Vector2i(1280, 720), 0.4)
	await get_tree().process_frame
	await _wait(0.7)
	check(not ConfirmDialog.is_open(), "la cuenta atrás avanza con el juego en pausa")
	check_equal(Settings.get_value("graficos/modo_ventana"), "ventana", "y restaura")


func test_escape_restores_and_only_one_change_at_a_time() -> void:
	_request("sin_bordes", Vector2i(1280, 720))
	await get_tree().process_frame
	check_equal(await Settings.request_display_change("exclusiva", Vector2i(1280, 720)), false, "otro cambio a la vez se rechaza")
	_press("ui_cancel")
	await get_tree().process_frame
	check(not ConfirmDialog.is_open(), "Escape contesta la pregunta")
	check_equal(_result, false, "restaurando")
	check_equal(await Settings.request_display_change("ventana", Vector2i(1280, 720)), true, "pedir lo que ya está no pregunta")
	check(not ConfirmDialog.is_open(), "ni abre nada")


func test_confirmation_keeps_the_focus_inside_and_returns_it() -> void:
	var opener := Button.new()
	add_child(opener)
	opener.grab_focus()
	_request("sin_bordes", Vector2i(1280, 720))
	await get_tree().process_frame
	_press("ui_left")
	check(get_viewport().gui_get_focus_owner() == ConfirmDialog.get_confirm_button(), "izquierda va al otro botón")
	_press("ui_down")
	check(get_viewport().gui_get_focus_owner() == ConfirmDialog.get_confirm_button(), "abajo no saca el foco de la ventana")
	_press("ui_right")
	check(get_viewport().gui_get_focus_owner() == ConfirmDialog.get_cancel_button(), "derecha vuelve")
	ConfirmDialog.cancel()
	await get_tree().process_frame
	check(get_viewport().gui_get_focus_owner() == opener, "al cerrar, el foco vuelve a quien abrió la pregunta")
	opener.queue_free()


func test_escape_closes_the_question_not_the_settings_behind() -> void:
	GameState.reset()
	GameClock.reset()
	var game := await make_game()
	var pause: PauseMenu = game.get_node("PauseMenu")
	var settings: SettingsMenu = pause.get_node("Root/SettingsMenu")
	pause.open()
	pause.get_node("Root/Center/Panel/Box/Settings").pressed.emit()
	_request("sin_bordes", Vector2i(1280, 720))
	await get_tree().process_frame
	_press("ui_cancel")
	await get_tree().process_frame
	check(not ConfirmDialog.is_open(), "Escape cierra la pregunta")
	check(settings.is_open(), "y la configuración sigue abierta")
	check(pause.is_open, "dentro de la pausa")
	pause.close()
	game.queue_free()
	await get_tree().process_frame
	GameState.reset()
	GameClock.reset()


func test_test_scenes_keep_their_own_window() -> void:
	check(DisplaySettings.is_window_fixed(get_tree()), "las escenas de res://tests/ no reciben el modo guardado")
