extends TestCase
## Controles desde la pausa, como el jugador: las tres herramientas de «Otros» ya no dicen
## «Próximamente» y funcionan; las dos que siguen allí desde antes (dejar pasar una hora y cerrar el
## juego guardando) no cambian; reasignar y el esquema del mando se abren encima y vuelven con el foco
## en su fila y las teclas al día; restaurar pregunta antes y sólo toca los controles.

var game: Game
var pause: PauseMenu
var controls: ControlsMenu


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	TestCase.reset_test_settings()
	Controls.restore_defaults()
	game = await make_game()
	pause = game.get_node("PauseMenu")
	controls = pause.get_node("Root/ControlsMenu")


func after_each() -> void:
	if ConfirmDialog.is_open():
		ConfirmDialog.cancel()
	if pause.is_open:
		pause.close()
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	Controls.restore_defaults()
	TestCase.reset_test_settings()
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame


func _wait_fade() -> void:
	await get_tree().create_timer(MenuScreen.FADE_SECONDS + 0.1).timeout


## Abre Controles desde la pausa, en «Otros».
func _open_others() -> void:
	pause.open()
	(pause.get_node("Root/Center/Panel/Box/Controls") as Button).pressed.emit()
	controls.select_category(ControlsMenu.CATEGORIES.size() - 1)
	await get_tree().process_frame


static func _texts(node: Node) -> PackedStringArray:
	var found := PackedStringArray()
	for child in node.get_children():
		if child is Label:
			found.append((child as Label).text)
		found.append_array(_texts(child))
	return found


func test_the_three_tools_are_real_options_without_the_soon_badge() -> void:
	await _open_others()
	var page := controls.get_page(ControlsMenu.CATEGORIES.size() - 1)
	check(not _texts(page).has("PRÓXIMAMENTE"), "en «Otros» ya no queda nada «Próximamente»")
	var titles := PackedStringArray()
	for child in page.get_children():
		if child is MenuActionRow:
			titles.append((child as MenuActionRow).get_title())
	check_equal(titles, PackedStringArray(["Reasignar teclas", "Jugar con mando", "Restaurar las teclas predeterminadas"]), "las tres herramientas, en su orden")
	check(controls.find_row("Dejar pasar una hora") != null, "dejar pasar una hora sigue en la lista")
	var keys: Array = []
	for group in controls.find_row("Cerrar el juego guardando").get_key_groups():
		keys.append(Array(group))
	check_equal(keys, [["Alt", "F4"]], "y cerrar el juego guardando sigue con Alt + F4")
	check(controls.get_tool("reasignar").get_detail().begins_with("Elegir otra tecla para cada acción"), "con su explicación de siempre")
	check(controls.get_tool("restaurar").get_detail().ends_with("ya la usas"), "restaurar dice que ya se usa la configuración original")


func test_the_tools_are_reached_with_the_keyboard() -> void:
	await _open_others()
	controls.get_tab(ControlsMenu.CATEGORIES.size() - 1).grab_focus()
	await _press("ui_right")
	check(_focus_owner() == controls.find_row("Dejar pasar una hora"), "a la derecha se entra en la lista")
	for step in 3:
		await _press("ui_down")
	check(_focus_owner() == controls.get_tool("mando"), "bajando se llega a las herramientas")
	await _press("ui_left")
	check(_focus_owner() == controls.get_tab(ControlsMenu.CATEGORIES.size() - 1), "y a la izquierda se vuelve a la pestaña")


func test_rebinding_opens_on_top_and_returns_with_the_new_keys() -> void:
	await _open_others()
	var tool := controls.get_tool("reasignar")
	tool.grab_focus()
	await _press("ui_accept")
	var rebind := controls.get_rebind_menu()
	check(rebind.is_open(), "«Reasignar teclas» abre su pantalla")
	check(not (controls.get_node("Center") as Control).visible, "en lugar del panel de Controles")
	check(rebind.is_ancestor_of(_focus_owner()), "con el foco dentro")
	Controls.assign("interact", 0, KEY_F)
	await _press("ui_cancel")
	await _wait_fade()
	check(not rebind.is_open() and controls.is_open(), "Esc vuelve a Controles")
	check(pause.is_open, "sin salir de la pausa")
	check(_focus_owner() == tool, "con el foco en «Reasignar teclas»")
	var keys: Array = []
	for group in controls.find_row("Interactuar").get_key_groups():
		keys.append(Array(group))
	check_equal(keys, [["F"]], "la lista ya muestra la tecla nueva")
	check(controls.get_tool("restaurar").get_detail().ends_with("1 acción personalizada"), "y restaurar sabe que hay una personalizada")


func test_the_gamepad_scheme_opens_on_top_and_returns() -> void:
	await _open_others()
	controls.get_tool("mando").pressed.emit()
	var scheme := controls.get_gamepad_menu()
	check(scheme.is_open(), "«Jugar con mando» abre el esquema")
	check(controls.get_tool("mando").get_detail().contains("mando"), "su fila dice si hay mando conectado")
	scheme.get_back_button().pressed.emit()
	await _wait_fade()
	check(not scheme.is_open() and controls.is_open(), "«Volver» regresa a Controles")
	check(_focus_owner() == controls.get_tool("mando"), "con el foco en su fila")


func test_restoring_asks_first_and_only_touches_the_controls() -> void:
	Settings.set_value("audio/Musica", 0.3)
	Settings.set_value("accesibilidad/contraste_alto", true)
	Controls.assign("interact", 0, KEY_F)
	Controls.swap("open_map", 0, KEY_B)
	await _open_others()
	var tool := controls.get_tool("restaurar")
	tool.grab_focus()
	await _press("ui_accept")
	check(ConfirmDialog.is_open(), "restaurar pregunta antes")
	check_equal(ConfirmDialog.get_title_text(), "¿RESTAURAR CONTROLES PREDETERMINADOS?", "con el título pedido")
	check_equal(ConfirmDialog.get_message_text(), "Se eliminarán las asignaciones personalizadas de teclado y se recuperará la configuración original.", "y el texto pedido")
	check_equal(ConfirmDialog.get_confirm_button().text, "Restaurar controles", "botón «Restaurar controles»")
	check_equal(ConfirmDialog.get_cancel_button().text, "Cancelar", "y «Cancelar»")
	check(_focus_owner() == ConfirmDialog.get_cancel_button(), "con el foco en cancelar")
	ConfirmDialog.cancel()
	check_equal(Controls.customized_actions().size(), 3, "cancelar no cambia nada")
	await _press("ui_accept")
	ConfirmDialog.confirm()
	check(Controls.customized_actions().is_empty(), "confirmar vuelve a las teclas de fábrica")
	var keys: Array = []
	for group in controls.find_row("Interactuar").get_key_groups():
		keys.append(Array(group))
	check_equal(keys, [["E"]], "la lista se pone al día en el acto")
	check(tool.get_detail().begins_with("Restauradas"), "y lo confirma")
	check(_focus_owner() == tool, "el foco vuelve a la fila")
	var stored := ConfigFile.new()
	stored.load(Settings.settings_path)
	check(not stored.has_section("controles"), "no queda nada personalizado en el archivo")
	check(is_equal_approx(float(Settings.get_value("audio/Musica")), 0.3), "el volumen no se toca")
	check(bool(Settings.get_value("accesibilidad/contraste_alto")), "ni la accesibilidad")


func test_opening_controls_again_starts_on_its_own_panel() -> void:
	await _open_others()
	controls.get_tool("reasignar").pressed.emit()
	check(controls.get_rebind_menu().is_open(), "la reasignación está abierta")
	pause.close()
	await _wait_fade()
	pause.open()
	(pause.get_node("Root/Center/Panel/Box/Controls") as Button).pressed.emit()
	check(controls.is_open() and (controls.get_node("Center") as Control).visible, "al volver a entrar se ve el panel de Controles")
	check(not controls.get_rebind_menu().visible, "y no la reasignación de antes")
