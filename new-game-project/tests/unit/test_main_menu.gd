extends TestCase
## Menú principal: la plaza en marcha detrás de la interfaz, el orden de las opciones,
## «Continuar» según las partidas guardadas y la navegación con teclado, mando y ratón.

const OPTIONS: Array[String] = ["Nueva partida", "Continuar partida", "Cargar partida", "Configuración", "Créditos", "Salir"]

var menu: Node


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	menu = await _open_menu()


func after_each() -> void:
	menu.queue_free()
	await get_tree().process_frame
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _open_menu() -> Node:
	var instance: Node = (load("res://scenes/main/main_menu.tscn") as PackedScene).instantiate()
	add_child(instance)
	await get_tree().process_frame
	return instance


func _option(option_name: String) -> MenuOptionButton:
	return menu.get_node("%" + option_name)


func _focus_owner() -> Control:
	return menu.get_viewport().gui_get_focus_owner()


## Una pulsación de navegación tal como llega del teclado o del mando.
func _navigate(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	menu.get_viewport().push_input(event)


func _wait_highlight() -> void:
	await get_tree().create_timer(MenuOptionButton.HIGHLIGHT_SECONDS + 0.1).timeout


func test_the_live_plaza_stays_behind_the_interface() -> void:
	var plaza: LocationBase = null
	var rain: RainEffect = null
	for child in menu.get_node("Backdrop").get_children():
		if child is LocationBase:
			plaza = child
		elif child is RainEffect:
			rain = child
	check(plaza != null, "la plaza real se instancia como fondo")
	check(rain != null and rain.emitting, "con la lluvia en marcha")
	check((menu.get_node("Backdrop/Camera3D") as Camera3D).current, "vista por la cámara del menú")
	check(not get_tree().paused, "el mundo no se detiene")
	var ui: CanvasLayer = menu.get_node("Ui")
	check(ui.layer > (menu.get_node("PostFx") as CanvasLayer).layer, "la interfaz va en una capa por encima")
	check(MenuFrame.FILL.a < 1.0, "y su panel es translúcido")


func test_options_keep_their_order_and_icons() -> void:
	var texts: Array[String] = []
	for child in menu.get_node("%Menu").get_children():
		var button := child as MenuOptionButton
		check(button != null, "%s es una opción del menú" % child.name)
		if button != null:
			texts.append(button.text)
			check(button.icon != null, "«%s» lleva icono" % button.text)
	check_equal(texts, OPTIONS, "las opciones y su orden")


func test_without_saves_continue_is_dimmed_and_skipped() -> void:
	var continue_button := _option("Continue")
	check(continue_button.disabled, "sin partidas, «Continuar» está desactivado")
	check_equal(continue_button.focus_mode, Control.FOCUS_NONE, "y no puede recibir el foco")
	check_equal(continue_button.detail_text, "", "sin día ni hora")
	check(_focus_owner() == _option("NewGame"), "el foco empieza en «Nueva partida»")
	_navigate("ui_down")
	check(_focus_owner() == _option("Load"), "bajar salta a «Cargar partida»")
	continue_button.mouse_entered.emit()
	check(_focus_owner() == _option("Load"), "señalarla con el ratón no la selecciona")


func test_with_a_save_continue_shows_day_and_time() -> void:
	GameState.location_id = "plaza"
	GameClock.day = 3
	GameClock.minutes = 9 * 60 + 15
	SaveSystem.begin_session(self)
	await save_and_wait("manual_1")
	SaveSystem.end_session(self)
	menu.queue_free()
	await get_tree().process_frame
	menu = await _open_menu()
	var continue_button := _option("Continue")
	check(not continue_button.disabled, "con partida, «Continuar» está activo")
	check_equal(continue_button.focus_mode, Control.FOCUS_ALL, "y se puede seleccionar")
	check_equal(continue_button.text, "Continuar partida", "el texto principal no cambia")
	check_equal(continue_button.detail_text, "(Día 3 · 09:15)", "el día y la hora salen de la partida guardada")
	_navigate("ui_down")
	check(_focus_owner() == continue_button, "bajar desde «Nueva partida» llega a «Continuar»")


func test_keyboard_and_gamepad_navigation_wraps_around() -> void:
	_navigate("ui_up")
	check(_focus_owner() == _option("Quit"), "subir desde la primera opción lleva a «Salir»")
	_navigate("ui_down")
	check(_focus_owner() == _option("NewGame"), "y bajar desde «Salir» vuelve a la primera")


func test_hovering_highlights_a_single_option() -> void:
	await _wait_highlight()
	check(_option("NewGame").is_highlighted(), "la opción inicial aparece resaltada")
	var load_button := _option("Load")
	var motion := InputEventMouseMotion.new()
	motion.position = load_button.get_global_rect().get_center()
	motion.global_position = motion.position
	menu.get_viewport().push_input(motion, true)
	check(_focus_owner() == load_button, "pasar el ratón por encima selecciona la opción")
	await _wait_highlight()
	check(load_button.is_highlighted(), "y la resalta")
	check(not _option("NewGame").is_highlighted(), "sin dejar otra resaltada a la vez")


func test_panels_take_the_focus_and_give_it_back() -> void:
	var options: Control = menu.get_node("%Menu")
	var settings: SettingsPanel = menu.get_node("%SettingsPanel")
	_option("Settings").grab_focus()
	_option("Settings").pressed.emit()
	check(settings.visible and not options.visible, "Configuración ocupa el lugar de las opciones")
	check(_focus_owner() != null and settings.is_ancestor_of(_focus_owner()), "y recibe el foco")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	menu._input(cancel)
	check(options.visible and not settings.visible, "Escape vuelve a las opciones")
	check(_focus_owner() == _option("Settings"), "con el foco en «Configuración»")
	_option("Credits").pressed.emit()
	check((menu.get_node("%CreditsPanel") as Control).visible, "los créditos se abren")
	check(_focus_owner() == _option("CreditsClose"), "con «Volver» seleccionado")
	_option("CreditsClose").pressed.emit()
	check(options.visible, "«Volver» cierra los créditos")
	check(_focus_owner() == _option("Credits"), "y devuelve el foco a «Créditos»")


func test_load_screen_gives_the_focus_back_to_load() -> void:
	var slots: SaveSlotsMenu = menu.get_node("%SaveSlotsMenu")
	_option("Load").pressed.emit()
	check(slots.visible and not (menu.get_node("%Layout") as Control).visible, "el expediente sustituye al menú")
	slots.get_back_button().pressed.emit()
	check((menu.get_node("%Layout") as Control).visible, "«Volver» muestra el menú")
	check(_focus_owner() == _option("Load"), "con el foco en «Cargar partida»")
