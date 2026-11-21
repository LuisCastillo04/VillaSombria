extends TestCase
## Configuración con todas sus opciones reales, manejada como lo haría el jugador desde la pausa:
## ya no queda nada «Próximamente», cada control muestra y cambia su preferencia, la pantalla pide
## confirmación y los controles nunca se contradicen, y todo se recorre con teclado, mando y ratón.

var game: Game
var pause: PauseMenu
var settings: SettingsMenu


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.reset_test_settings()
	game = await make_game()
	pause = game.get_node("PauseMenu")
	settings = pause.get_node("Root/SettingsMenu")
	pause.open()
	pause.get_node("Root/Center/Panel/Box/Settings").pressed.emit()
	await get_tree().process_frame


func after_each() -> void:
	if ConfirmDialog.is_open():
		ConfirmDialog.cancel()
	await get_tree().process_frame
	if pause.is_open:
		pause.close()
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	TestCase.reset_test_settings()
	GameState.reset()
	GameClock.reset()


func _navigate(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _texts(node: Node) -> PackedStringArray:
	var found := PackedStringArray()
	if node is Label:
		found.append((node as Label).text)
	elif node is Button:
		found.append((node as Button).text)
	for child in node.get_children():
		found.append_array(_texts(child))
	return found


func _click(control: Control) -> void:
	var spot := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		get_viewport().push_input(click, true)
	await get_tree().process_frame


func test_nothing_is_left_as_coming_soon() -> void:
	check_equal(settings.get_category_titles(), PackedStringArray(["Audio", "Gráficos", "Jugabilidad", "Filtros", "Accesibilidad"]), "cinco categorías")
	for index in settings.get_category_titles().size():
		var page := settings.get_page(index)
		check(not _texts(page).has("PRÓXIMAMENTE"), "en «%s» no queda nada «Próximamente»" % settings.get_category_titles()[index])
		for child in page.get_children():
			check(not child.has_meta("planned"), "ni filas previstas")


func test_every_option_is_a_real_control() -> void:
	for key: String in ["graficos/modo_ventana", "graficos/resolucion", "graficos/calidad_iluminacion", "graficos/calidad_efectos", "jugabilidad/velocidad_texto", "accesibilidad/tamano_letra"]:
		var selector := settings.get_selector(key)
		check(selector != null, "%s tiene selector" % key)
		if selector != null:
			check(selector.focus_mode == Control.FOCUS_ALL, "%s se puede seleccionar" % key)
	for key: String in ["graficos/vsync", "jugabilidad/avance_automatico", "jugabilidad/confirmaciones", "accesibilidad/contraste_alto", "accesibilidad/subtitulos", "accesibilidad/movimiento_reducido"]:
		check(settings.get_switch(key) != null, "%s tiene interruptor" % key)
	check(settings.get_fullscreen_switch() != null, "y pantalla completa también")


func test_selectors_show_and_change_the_real_settings() -> void:
	var lighting := settings.get_selector("graficos/calidad_iluminacion")
	check_equal(lighting.get_value_text(), "Alto", "la calidad muestra la vigente")
	check_equal(lighting.get_options(), ["bajo", "medio", "alto"] as Array[String], "con sus tres niveles")
	lighting.step(-1)
	check_equal(Settings.get_value("graficos/calidad_iluminacion"), "medio", "cambiarla cambia la preferencia")
	var speed := settings.get_selector("jugabilidad/velocidad_texto")
	speed.step(1)
	check_equal(Settings.get_value("jugabilidad/velocidad_texto"), "rapido", "la velocidad del texto")
	var size := settings.get_selector("accesibilidad/tamano_letra")
	size.step(1)
	check(is_equal_approx(get_tree().root.content_scale_factor, UiAccessibility.TEXT_SCALES["grande"]), "y el tamaño de letra se aplica al momento")
	size.step(-1)
	# Si otra pantalla cambia una preferencia, el control se pone al día.
	Settings.set_value("graficos/calidad_efectos", "bajo")
	check_equal(settings.get_selector("graficos/calidad_efectos").get_value_text(), "Bajo", "un cambio desde fuera se ve")


func test_switches_write_their_settings() -> void:
	for key: String in ["jugabilidad/avance_automatico", "accesibilidad/contraste_alto", "accesibilidad/movimiento_reducido"]:
		var button := settings.get_switch(key)
		check_equal(button.button_pressed, bool(Settings.get_value(key)), "%s muestra su valor" % key)
		button.button_pressed = not button.button_pressed
		check_equal(bool(Settings.get_value(key)), button.button_pressed, "%s lo cambia" % key)
		button.button_pressed = not button.button_pressed
	var confirmations := settings.get_switch("jugabilidad/confirmaciones")
	check(confirmations.button_pressed, "las confirmaciones empiezan activadas")
	confirmations.button_pressed = false
	check(not ConfirmDialog.confirmations_enabled(), "y se pueden desactivar")


func test_window_mode_asks_and_the_switch_follows() -> void:
	var mode := settings.get_selector("graficos/modo_ventana")
	check_equal(mode.get_value_text(), "Ventana", "empieza en ventana")
	check(not settings.get_fullscreen_switch().button_pressed, "con pantalla completa apagada")
	mode.step(1)
	await get_tree().process_frame
	check(ConfirmDialog.is_open(), "un modo nuevo pide confirmación")
	ConfirmDialog.confirm()
	await get_tree().process_frame
	await get_tree().process_frame
	check_equal(Settings.get_value("graficos/modo_ventana"), "sin_bordes", "confirmado, se guarda")
	check_equal(mode.get_value_text(), "Sin bordes", "el selector lo muestra")
	check(not settings.get_fullscreen_switch().button_pressed, "y pantalla completa sigue apagada: no se contradicen")
	settings.get_fullscreen_switch().button_pressed = true
	await get_tree().process_frame
	check(ConfirmDialog.is_open(), "el interruptor también pide confirmación")
	check_equal(mode.get_value_text(), "Pantalla completa", "y el selector muestra el modo que se prueba")
	ConfirmDialog.cancel()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not settings.get_fullscreen_switch().button_pressed, "al restaurar, el interruptor vuelve")
	check_equal(mode.get_value_text(), "Sin bordes", "y el selector también")


func test_resolution_follows_the_window_mode() -> void:
	var resolution := settings.get_selector("graficos/resolucion")
	check(not resolution.is_disabled(), "en ventana se puede elegir")
	var sizes := DisplaySettings.resolutions_for("ventana")
	check_equal(resolution.get_options().size(), sizes.size(), "entre las que caben en el monitor")
	check_equal(resolution.get_value_text(), "1280 × 720", "y muestra la vigente")
	resolution.step(-1)
	await get_tree().process_frame
	check(ConfirmDialog.is_open(), "cambiarla pide confirmación")
	ConfirmDialog.confirm()
	await get_tree().process_frame
	check_equal(Settings.get_value("graficos/resolucion"), Vector2i(1152, 648), "y se guarda al confirmar")
	Settings.set_value("graficos/modo_ventana", "exclusiva")
	check(resolution.is_disabled(), "en pantalla completa no se elige")
	check(resolution.get_detail_text().contains("monitor"), "y se explica que manda el monitor")
	var screen := DisplaySettings.screen_size()
	check_equal(resolution.get_value_text(), "%d × %d" % [screen.x, screen.y], "mostrando su resolución")
	resolution.step(1)
	check(not ConfirmDialog.is_open(), "desactivado no cambia nada")


func test_keyboard_and_gamepad_reach_and_change_every_option() -> void:
	settings.select_category(1)
	await get_tree().process_frame
	settings.get_tab(1).grab_focus()
	await _navigate("ui_right")
	check(_focus() == settings.get_fullscreen_switch(), "a la derecha se entra en la primera opción")
	var reached: Array[Control] = []
	for step in 8:
		await _navigate("ui_down")
		if not reached.has(_focus()):
			reached.append(_focus())
	var effects := settings.get_selector("graficos/calidad_efectos")
	check(reached.has(settings.get_vsync_switch()), "abajo llega a la sincronización vertical")
	check(reached.has(effects), "y hasta el último selector")
	effects.grab_focus()
	await _navigate("ui_left")
	check_equal(Settings.get_value("graficos/calidad_efectos"), "medio", "izquierda (cruceta o flecha) baja el nivel")
	check(_focus() == effects, "sin salir del selector")
	await _navigate("ui_accept")
	check_equal(Settings.get_value("graficos/calidad_efectos"), "alto", "aceptar (Intro o A) pasa al siguiente")
	await _navigate("ui_accept")
	check_equal(Settings.get_value("graficos/calidad_efectos"), "bajo", "y al final da la vuelta")
	await _navigate("ui_right")
	await _navigate("ui_right")
	await _navigate("ui_right")
	check_equal(Settings.get_value("graficos/calidad_efectos"), "alto", "derecha sube sin pasar del último")
	await _navigate("ui_cancel")
	check(not settings.is_open(), "Escape (o B) cierra la configuración")


func test_mouse_uses_the_arrows_and_the_value() -> void:
	settings.select_category(Array(settings.get_category_titles()).find("Accesibilidad"))
	await get_tree().process_frame
	var size := settings.get_selector("accesibilidad/tamano_letra")
	await _click(size.get_node("HBoxContainer/HBoxContainer/Siguiente") if size.has_node("HBoxContainer/HBoxContainer/Siguiente") else size.find_child("Siguiente", true, false))
	check_equal(Settings.get_value("accesibilidad/tamano_letra"), "grande", "la flecha derecha sube el tamaño")
	await get_tree().process_frame
	await _click(size.find_child("Anterior", true, false))
	check_equal(Settings.get_value("accesibilidad/tamano_letra"), "normal", "y la izquierda lo baja")


func test_the_main_menu_has_the_same_options() -> void:
	var menu: Node = (load("res://scenes/main/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var main_settings: SettingsMenu = menu.get_node("%SettingsMenu")
	check_equal(main_settings.get_category_titles().size(), 5, "las cinco categorías")
	check(main_settings.get_selector("graficos/calidad_iluminacion") != null, "con sus selectores")
	Settings.set_value("jugabilidad/velocidad_texto", "lento")
	check_equal(main_settings.get_selector("jugabilidad/velocidad_texto").get_value_text(), "Lento", "y los mismos valores")
	menu.queue_free()
	await get_tree().process_frame
