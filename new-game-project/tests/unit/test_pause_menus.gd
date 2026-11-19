extends TestCase
## Pausa, configuración y controles: el escenario sigue detrás, la ranura activa real, los ajustes
## reales de Settings, las teclas del InputMap, lo previsto visible pero inerte y la navegación
## con teclado y mando entre pantallas.

const PAUSE_OPTIONS: Array[String] = ["Continuar", "Guardar partida", "Cargar partida", "Configuración", "Controles", "Guardar y volver al menú"]

var game: Game
var pause: PauseMenu
var settings: SettingsMenu
var controls: ControlsMenu
var _volumes: Dictionary
var _vsync := false


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	_volumes = Settings.volumes.duplicate()
	_vsync = Settings.vsync
	game = await make_game()
	pause = game.get_node("PauseMenu")
	settings = pause.get_node("Root/SettingsMenu")
	controls = pause.get_node("Root/ControlsMenu")


func after_each() -> void:
	if pause.is_open:
		pause.close()
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	# Las pruebas no deben cambiar los ajustes del jugador.
	for bus: String in _volumes:
		Settings.set_volume(bus, _volumes[bus])
	Settings.set_vsync(_vsync)
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _button(button_name: String) -> MenuOptionButton:
	return pause.get_node("Root/Center/Panel/Box/" + button_name)


func _panel() -> Control:
	return pause.get_node("Root/Center/Panel")


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


## Una pulsación tal como llega del teclado o del mando.
func _navigate(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)


func _wait_fade() -> void:
	await get_tree().create_timer(MenuScreen.FADE_SECONDS + 0.1).timeout


## Teclas de una fila como listas normales, para compararlas con facilidad.
func _keys(label_text: String) -> Array:
	var row := controls.find_row(label_text)
	if row == null:
		failures.append("no existe la fila «%s»" % label_text)
		return []
	var groups: Array = []
	for group in row.get_key_groups():
		groups.append(Array(group))
	return groups


func _planned_rows(page: Control) -> Array[Control]:
	var rows: Array[Control] = []
	for child in page.get_children():
		if child.has_meta("planned"):
			rows.append(child)
	return rows


func _has_focusable(root: Node) -> bool:
	for child in root.get_children():
		if child is Control and (child as Control).focus_mode != Control.FOCUS_NONE:
			return true
		if _has_focusable(child):
			return true
	return false


func test_pause_freezes_the_world_behind_the_menu() -> void:
	pause.open()
	check(get_tree().paused, "la pausa detiene el juego")
	check(GameState.is_player_locked(), "y bloquea al detective")
	check(game.current_location != null and game.current_location.is_visible_in_tree(), "el escenario sigue detrás")
	check((pause.get_node("Root/Dim") as ColorRect).color.a < 1.0, "bajo un velo translúcido")
	check(_focus_owner() == _button("Resume"), "el foco empieza en «Continuar»")
	await _wait_fade()
	check(is_equal_approx((pause.get_node("Root") as Control).modulate.a, 1.0), "el fundido termina aunque el árbol esté en pausa")
	_navigate("ui_cancel")
	check(not pause.is_open and not get_tree().paused, "Escape cierra la pausa")
	check(not GameState.is_player_locked(), "y devuelve el control")


func test_pause_options_keep_their_order_and_icons() -> void:
	var texts: Array[String] = []
	for child in pause.get_node("Root/Center/Panel/Box").get_children():
		var button := child as MenuOptionButton
		if button != null:
			texts.append(button.text)
			check(button.icon != null, "«%s» lleva icono" % button.text)
	check_equal(texts, PAUSE_OPTIONS, "las opciones y su orden")


func test_slot_info_shows_the_real_active_slot() -> void:
	pause.open()
	check(pause.get_slot_info_text().begins_with("Autoguardado en espera"), "sin ranura activa no se inventa ninguna")
	pause.close()
	await save_and_wait("manual_3")
	pause.open()
	check_equal(pause.get_slot_info_text(), "Ranura activa: 03 · Los autoguardados van a ella", "con ranura, su número real")


func test_settings_open_over_the_pause_and_escape_returns() -> void:
	pause.open()
	_button("Settings").pressed.emit()
	check(settings.is_open(), "Configuración se abre")
	check(not _panel().visible, "en lugar de las opciones de la pausa")
	check_equal(settings.get_category_titles(), PackedStringArray(["Audio", "Gráficos", "Jugabilidad"]), "con sus tres categorías")
	check(settings.is_ancestor_of(_focus_owner()), "y con el foco dentro")
	_navigate("ui_cancel")
	check(not settings.is_open(), "Escape la cierra")
	check(pause.is_open and get_tree().paused, "sin salir de la pausa")
	check(_panel().visible, "vuelven las opciones")
	check(_focus_owner() == _button("Settings"), "con el foco en «Configuración»")
	_navigate("ui_cancel")
	check(not pause.is_open, "otro Escape cierra la pausa")


func test_controls_open_over_the_pause_and_back_returns() -> void:
	pause.open()
	_button("Controls").pressed.emit()
	check(controls.is_open() and not _panel().visible, "Controles se abre en lugar de las opciones")
	check_equal(controls.get_category_titles(), PackedStringArray(["Movimiento", "Interacción", "Menús", "Otros"]), "con sus cuatro categorías")
	controls.get_back_button().pressed.emit()
	check(not controls.is_open() and _panel().visible, "«Volver» regresa a la pausa")
	check(_focus_owner() == _button("Controls"), "con el foco en «Controles»")


func test_audio_shows_and_applies_the_real_volumes() -> void:
	Settings.set_volume("Musica", 0.7)
	pause.open()
	_button("Settings").pressed.emit()
	var slider := settings.get_volume_slider("Musica")
	check(is_equal_approx(slider.value, 0.7), "la barra muestra el volumen guardado")
	check_equal(settings.get_volume_text("Musica"), "70%", "con su porcentaje")
	slider.value = 0.35
	check(is_equal_approx(Settings.volumes["Musica"], 0.35), "moverla cambia el ajuste")
	check_equal(settings.get_volume_text("Musica"), "35%", "y el porcentaje")
	var bus := AudioServer.get_bus_index("Musica")
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.35)), "el cambio llega al canal de audio")
	var stored := ConfigFile.new()
	stored.load(Settings.SETTINGS_PATH)
	check(is_equal_approx(float(stored.get_value("volumen", "Musica", -1.0)), 0.35), "y se guarda")


func test_graphics_switches_use_the_real_settings() -> void:
	pause.open()
	_button("Settings").pressed.emit()
	settings.select_category(1)
	check_equal(settings.get_fullscreen_switch().button_pressed, Settings.fullscreen, "pantalla completa refleja el ajuste")
	check_equal(settings.get_vsync_switch().button_pressed, Settings.vsync, "y la sincronización vertical también")
	var before := Settings.vsync
	settings.get_vsync_switch().button_pressed = not before
	check_equal(Settings.vsync, not before, "el interruptor cambia la sincronización vertical")


func test_planned_options_are_visible_but_inert() -> void:
	var graphics := _planned_rows(settings.get_page(1))
	var gameplay := _planned_rows(settings.get_page(2))
	var controls_planned := _planned_rows(controls.get_page(3))
	check(graphics.size() >= 1, "Gráficos muestra opciones previstas")
	check(gameplay.size() >= 4, "Jugabilidad existe aunque aún no tenga opciones")
	check(controls_planned.size() >= 3, "Controles anuncia reasignación y mando")
	for row in graphics + gameplay + controls_planned:
		check(row.focus_mode == Control.FOCUS_NONE and not _has_focusable(row), "una opción prevista no se puede seleccionar")
	check(not _has_focusable(settings.get_page(2)), "en Jugabilidad no hay nada que se pueda activar")


func test_controls_show_the_input_map() -> void:
	pause.open()
	_button("Controls").pressed.emit()
	check_equal(_keys("Moverse"), [["W", "A", "S", "D"], ["↑", "←", "↓", "→"]], "moverse: WASD o flechas")
	check_equal(_keys("Correr (mantener)"), [["Mayús"]], "correr con Mayús")
	check_equal(_keys("Interactuar"), [["E"]], "interactuar con E")
	check_equal(_keys("Abrir o cerrar el expediente"), [["J"], ["Tab"]], "expediente con J o Tab")
	check_equal(_keys("Abrir o cerrar el tablero"), [["B"]], "tablero con B")
	check_equal(_keys("Dejar pasar una hora"), [["T"]], "esperar con T")
	check_equal(_keys("Pausar el juego"), [["Esc"]], "pausa con Esc")
	# Una tecla nueva en el InputMap aparece al volver a abrir, sin tocar el menú.
	var extra := InputEventKey.new()
	extra.physical_keycode = KEY_H
	InputMap.action_add_event("wait_time", extra)
	controls.get_back_button().pressed.emit()
	_button("Controls").pressed.emit()
	check_equal(_keys("Dejar pasar una hora"), [["T"], ["H"]], "las teclas se leen del InputMap")
	InputMap.action_erase_event("wait_time", extra)


func test_category_tabs_and_pages_are_linked_for_the_keyboard() -> void:
	pause.open()
	_button("Settings").pressed.emit()
	await get_tree().process_frame
	check(_focus_owner() == settings.get_tab(0), "el foco empieza en la categoría elegida")
	_navigate("ui_down")
	check_equal(settings.get_selected_category(), 1, "bajar por las pestañas cambia de categoría")
	check(settings.get_page(1).is_visible_in_tree() and not settings.get_page(0).is_visible_in_tree(), "y muestra su página")
	_navigate("ui_right")
	check(_focus_owner() == settings.get_fullscreen_switch(), "a la derecha se entra en su primera opción")
	_navigate("ui_left")
	check(_focus_owner() == settings.get_tab(1), "y a la izquierda se vuelve a su pestaña")
	check_equal(settings.get_selected_category(), 1, "sin cambiar de categoría")
