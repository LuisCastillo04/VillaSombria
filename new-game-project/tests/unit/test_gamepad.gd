extends TestCase
## Mando: cada acción del juego tiene su botón sin pisar a otra, la cruceta y el stick mueven el foco
## de los menús una vez por empujón (y se repiten al mantenerlos), A confirma y B vuelve, el detective
## camina con el stick respetando la zona muerta, las pantallas se abren y se cierran con sus botones,
## el juego pasa solo de los rótulos del teclado a los del mando y desconectar el mando pausa la
## partida sin dejar nada pulsado. Los eventos se envían con `Input.parse_input_event`, el mismo camino
## que los de un mando real; las pruebas con mando físico están en docs/CONTROLES.md.
##
## Godot reparte esos eventos una vez por ciclo del bucle principal, y en un ciclo pesado caben varios
## pasos de física: por eso, tras cada evento, se esperan ciclos completos (`_settle`).

## Acciones que funcionan a la vez mientras se explora: ninguna puede compartir botón.
const EXPLORATION_ACTIONS: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "sprint", "interact", "open_journal", "open_board", "open_map", "wait_time", "pause"]

var game: Game
var _notices: Array[String] = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	TestCase.reset_test_settings()
	Controls.set_using_gamepad(false)
	EventBus.notification_requested.connect(_on_notification)
	_notices.clear()


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_notification)
	_release_everything()
	if ConfirmDialog.is_open():
		ConfirmDialog.cancel()
	get_tree().paused = false
	if game != null:
		game.queue_free()
		game = null
	await get_tree().process_frame
	await get_tree().process_frame
	Controls.set_using_gamepad(false)
	Controls.style_override = ""
	GameState.reset()
	GameClock.reset()
	TestCase.reset_test_settings()
	TestCase.clear_save_storage()


func _on_notification(title: String, _text: String, _kind: String) -> void:
	_notices.append(title)


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


## Deja que Godot reparta los eventos enviados y que el juego reaccione.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await wait_physics_frames(2)


## Un botón del mando pulsado y soltado, como llega de un mando real.
func _button(index: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = index
		event.pressed = pressed
		Input.parse_input_event(event)
	await _settle()


## El stick izquierdo en una posición; un empujón real llega como varios valores seguidos.
func _stick(value: Vector2) -> void:
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis
		event.axis_value = value.x if axis == JOY_AXIS_LEFT_X else value.y
		Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _push_stick_down() -> void:
	for value: float in [0.2, 0.45, 0.6, 0.75, 0.9, 1.0, 0.95]:
		await _stick(Vector2(0.0, value))
	await get_tree().process_frame


func _release_everything() -> void:
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_TRIGGER_RIGHT]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
		event.axis = axis
		event.axis_value = 0.0
		Input.parse_input_event(event)
	for direction in GamepadNavigation.DPAD:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = direction
		event.pressed = false
		Input.parse_input_event(event)
	for action in Controls.HELD_ACTIONS:
		Input.action_release(action)


static func _pad_inputs(action: String) -> Array[String]:
	var found: Array[String] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			found.append("boton %d" % (event as InputEventJoypadButton).button_index)
		elif event is InputEventJoypadMotion:
			var motion := event as InputEventJoypadMotion
			found.append("eje %d %s" % [motion.axis, "+" if motion.axis_value > 0.0 else "-"])
	return found


# --- Esquema ---

func test_every_game_action_has_its_own_gamepad_input() -> void:
	var owners := {}
	for action in EXPLORATION_ACTIONS:
		var inputs := _pad_inputs(action)
		check(not inputs.is_empty(), "%s tiene botón en el mando" % action)
		for input in inputs:
			check(not owners.has(input), "%s y %s no comparten %s" % [action, owners.get(input, ""), input])
			owners[input] = action
	check(_pad_inputs("ui_accept").has("boton %d" % JOY_BUTTON_A), "A confirma en los menús")
	check(_pad_inputs("ui_cancel").has("boton %d" % JOY_BUTTON_B), "B vuelve atrás")
	for action: String in GamepadNavigation.ACTIONS.values():
		check(_pad_inputs(action).is_empty(), "%s no lee el mando directamente: lo traduce la navegación" % action)


func test_the_stick_has_a_dead_zone_for_walking() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right"]:
		check(InputMap.action_get_deadzone(action) >= 0.2, "%s ignora las desviaciones pequeñas" % action)
	await _stick(Vector2(0.12, -0.15))
	check(Input.get_vector("move_left", "move_right", "move_forward", "move_back") == Vector2.ZERO, "un stick casi en reposo no mueve")
	await _stick(Vector2(0.0, -1.0))
	check(Input.get_vector("move_left", "move_right", "move_forward", "move_back").y < -0.9, "empujarlo sí")
	await _stick(Vector2.ZERO)


# --- Navegación de los menús ---

func test_navigation_presses_once_per_push_and_repeats_when_held() -> void:
	var navigation := GamepadNavigation.new()
	var presses := 0
	for value: float in [0.2, 0.45, 0.55, 0.8, 1.0, 0.9]:
		for event in navigation.update(Vector2(0.0, value), Vector2i.ZERO, 0.016):
			if event.pressed:
				presses += 1
				check_equal(event.action, "ui_down", "hacia abajo")
	check_equal(presses, 1, "un empujón es una sola pulsación")
	check(navigation.update(Vector2(0.0, 0.4), Vector2i.ZERO, 0.016).is_empty(), "un temblor bajo el umbral de empuje no suelta")
	var repeated := navigation.update(Vector2(0.0, 1.0), Vector2i.ZERO, GamepadNavigation.REPEAT_DELAY)
	check(repeated.size() == 1 and repeated[0].pressed, "mantenido, se repite tras la espera")
	var released := navigation.update(Vector2(0.0, 0.1), Vector2i.ZERO, 0.016)
	check(released.size() == 1 and not released[0].pressed, "al soltarlo se suelta")
	var dpad := navigation.update(Vector2(0.0, 1.0), Vector2i(1, 0), 0.016)
	check(dpad.size() == 1 and dpad[0].action == "ui_right", "la cruceta manda sobre el stick")
	navigation.release()
	var tap := navigation.update(Vector2.ZERO, Vector2i.ZERO, 0.016, [Vector2i.UP] as Array[Vector2i])
	check(tap.size() == 2 and tap[0].action == "ui_up" and tap[0].pressed and not tap[1].pressed, "un toque más corto que un fotograma no se pierde")


func test_the_stick_moves_the_pause_menu_one_step_at_a_time() -> void:
	game = await make_game()
	var pause: PauseMenu = game.get_node("PauseMenu")
	await _button(JOY_BUTTON_START)
	check(pause.is_open, "Menú (Start) abre la pausa")
	check(Controls.is_using_gamepad(), "y el juego pasa a los rótulos del mando")
	var resume: Control = pause.get_node("Root/Center/Panel/Box/Resume")
	var map_button: Control = pause.get_node("Root/Center/Panel/Box/Map")
	var save_button: Control = pause.get_node("Root/Center/Panel/Box/Save")
	check(_focus_owner() == resume, "el foco empieza en «Continuar»")
	await _push_stick_down()
	check(_focus_owner() == map_button, "un empujón baja una sola opción")
	await get_tree().create_timer(GamepadNavigation.REPEAT_DELAY + 0.05).timeout
	var focused_now := _focus_owner()
	check(focused_now != null and focused_now.get_parent() == map_button.get_parent() and focused_now.get_index() >= save_button.get_index(), "mantenido, sigue bajando")
	await _stick(Vector2.ZERO)
	var focused := _focus_owner()
	await get_tree().create_timer(GamepadNavigation.REPEAT_DELAY).timeout
	check(_focus_owner() == focused, "suelto, se queda quieto")
	await _button(JOY_BUTTON_B)
	check(not pause.is_open, "B cierra la pausa")


func test_a_confirms_and_b_goes_back_in_the_menus() -> void:
	game = await make_game()
	var pause: PauseMenu = game.get_node("PauseMenu")
	var settings: SettingsMenu = pause.get_node("Root/SettingsMenu")
	pause.open()
	(pause.get_node("Root/Center/Panel/Box/Settings") as Control).grab_focus()
	await _button(JOY_BUTTON_A)
	check(settings.is_open(), "A pulsa la opción señalada")
	await _button(JOY_BUTTON_DPAD_DOWN)
	check_equal(settings.get_selected_category(), 1, "la cruceta recorre las pestañas")
	await _button(JOY_BUTTON_B)
	await get_tree().create_timer(MenuScreen.FADE_SECONDS + 0.05).timeout
	check(not settings.is_open() and pause.is_open, "B vuelve a la pausa")
	check(_focus_owner() == pause.get_node("Root/Center/Panel/Box/Settings"), "con el foco en la opción que la abrió")


func test_confirmation_dialogs_work_with_the_gamepad() -> void:
	game = await make_game()
	GameClock.minutes = 10 * 60
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	check(ConfirmDialog.is_open(), "RB pide dejar pasar una hora")
	check(_focus_owner() == ConfirmDialog.get_confirm_button(), "con el foco en «Confirmar»")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	check(_focus_owner() == ConfirmDialog.get_cancel_button(), "la cruceta pasa a «Cancelar»")
	await _button(JOY_BUTTON_DPAD_LEFT)
	await _button(JOY_BUTTON_A)
	check(not ConfirmDialog.is_open(), "A contesta")
	check_equal(GameClock.minutes, 11 * 60, "y pasa la hora")


# --- Partida ---

func test_the_detective_walks_with_the_stick() -> void:
	game = await make_game()
	var start := game.player.global_position
	await _stick(Vector2(0.0, -1.0))
	await wait_physics_frames(20)
	check(game.player.global_position.distance_to(start) > 0.3, "el detective camina con el stick")
	await _stick(Vector2.ZERO)
	await wait_physics_frames(20)
	var stopped := game.player.global_position
	await wait_physics_frames(10)
	check(game.player.global_position.distance_to(stopped) < 0.05, "y se para al soltarlo")


func test_the_screens_open_and_close_with_their_buttons() -> void:
	game = await make_game()
	var journal: JournalUi = game.get_node("JournalUi")
	var board: BoardUi = game.get_node("BoardUi")
	var pause: PauseMenu = game.get_node("PauseMenu")
	await _button(JOY_BUTTON_Y)
	check(journal.is_open, "Y abre el expediente")
	await _button(JOY_BUTTON_B)
	check(not journal.is_open, "B lo cierra")
	await _button(JOY_BUTTON_X)
	check(board.is_open, "X abre el tablero")
	await _button(JOY_BUTTON_B)
	check(not board.is_open, "B lo cierra")
	await _button(JOY_BUTTON_BACK)
	var map: MapScreen = pause.get_node("Root/MapScreen")
	check(map.is_open(), "Vista abre el mapa")
	await _button(JOY_BUTTON_BACK)
	await get_tree().create_timer(MenuScreen.FADE_SECONDS + 0.05).timeout
	check(not map.is_open() and not pause.is_open, "y lo cierra, de vuelta al juego")
	check(not GameState.is_player_locked(), "con el control devuelto")
	check(_focus_owner() == null, "y sin ningún botón de la interfaz con el foco")


func test_a_advances_a_conversation_and_the_dpad_picks_an_answer() -> void:
	game = await make_game()
	var ui: DialogueUi = game.get_node("DialogueUi")
	Controls.set_using_gamepad(true)
	DialogueManager.start("eusebio")
	await get_tree().create_timer(0.5).timeout
	check_equal(ui.get_continue_button().get_key_text(), "A", "«Continuar» anuncia el botón A")
	check(not ui.is_choosing(), "empieza leyendo")
	var presses := 0
	for attempt in 40:
		if ui.is_choosing() or not DialogueManager.active:
			break
		await _button(JOY_BUTTON_A)
		presses += 1
	check(presses > 0 and ui.is_choosing(), "A avanza la conversación hasta las preguntas")
	check(ui.get_choice_hint().get_text().contains("cruceta"), "que explican cómo elegir con el mando")
	var first := ui.get_choices().get_selected_index()
	await _button(JOY_BUTTON_DPAD_DOWN)
	check_equal(ui.get_choices().get_selected_index(), first + 1, "la cruceta señala la siguiente, una sola vez")
	if DialogueManager.active:
		DialogueManager.close()


# --- Teclado o mando ---

func test_the_labels_follow_the_device_in_use() -> void:
	game = await make_game()
	var hud: Hud = game.get_node("Hud")
	var bar := hud.get_controls_bar()
	check_equal(bar.get_hint("interact").get_keys(), PackedStringArray(["E"]), "con el teclado, E")
	await _button(JOY_BUTTON_A)
	check(Controls.is_using_gamepad(), "un botón del mando pasa a «mando»")
	check_equal(bar.get_hint("interact").get_keys(), PackedStringArray(["A"]), "la barra muestra A")
	check_equal(bar.get_hint("move").get_keys(), PackedStringArray(["Stick izq."]), "y el stick para moverse")
	check_equal(bar.get_hint("journal").get_keys(), PackedStringArray(["Y"]), "e Y para el expediente")
	var small := InputEventMouseMotion.new()
	small.relative = Vector2(2.0, 1.0)
	Input.parse_input_event(small)
	await _settle()
	check(Controls.is_using_gamepad(), "un roce del ratón no cambia nada")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.keycode = KEY_K
	key.pressed = true
	Input.parse_input_event(key)
	await _settle()
	check(not Controls.is_using_gamepad(), "una tecla vuelve al teclado")
	check_equal(bar.get_hint("interact").get_keys(), PackedStringArray(["E"]), "y a sus rótulos")


func test_button_names_follow_the_gamepad_brand() -> void:
	check_equal(InputLabels.style_for("Xbox Series Controller"), "xbox", "Xbox")
	check_equal(InputLabels.style_for("PS5 Controller"), "playstation", "PlayStation 5")
	check_equal(InputLabels.style_for("DualShock 4"), "playstation", "PlayStation 4")
	check_equal(InputLabels.style_for("Nintendo Switch Pro Controller"), "nintendo", "Nintendo")
	check_equal(InputLabels.style_for("Generic USB Joystick"), "xbox", "un mando genérico usa los nombres de Xbox")
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	check_equal(InputLabels.button_name(a, false, "playstation"), "✕", "el botón de abajo es la cruz en PlayStation")
	check_equal(InputLabels.button_name(a, false, "nintendo"), "B", "y B en Nintendo")
	Controls.style_override = "playstation"
	check_equal(InputLabels.keys_of("open_journal", InputLabels.Device.GAMEPAD), PackedStringArray(["△"]), "el expediente es el triángulo")
	check_equal(InputLabels.keys_of("sprint", InputLabels.Device.GAMEPAD), PackedStringArray(["R2", "L3"]), "correr con R2 o L3")


func test_connecting_and_disconnecting_a_gamepad() -> void:
	game = await make_game()
	var pause: PauseMenu = game.get_node("PauseMenu")
	Controls.handle_connection_change(0, true)
	check(_notices.has("Mando conectado"), "conectar un mando se avisa")
	await _button(JOY_BUTTON_A)
	Input.action_press("move_forward")
	Controls.handle_connection_change(0, false)
	await get_tree().process_frame
	check(_notices.has("Mando desconectado"), "desconectarlo también")
	check(not Input.is_action_pressed("move_forward"), "el detective no sigue andando solo")
	check(not Controls.is_using_gamepad(), "el juego vuelve a los rótulos del teclado")
	check(pause.is_open, "y la partida se pausa")
	pause.close()
	Controls.set_using_gamepad(false)
	Controls.handle_connection_change(0, false)
	await get_tree().process_frame
	check(not pause.is_open, "si no se estaba usando, no se pausa nada")


func test_the_gamepad_screen_lists_the_real_buttons() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var menu: GamepadMenu = (load("res://scenes/ui/gamepad_menu.tscn") as PackedScene).instantiate()
	layer.add_child(menu)
	await get_tree().process_frame
	menu.open()
	check_equal(menu.get_category_titles(), PackedStringArray(["Explorar", "Conversaciones", "Menús"]), "por situaciones")
	for category: Dictionary in GamepadMenu.CATEGORIES:
		for definition: Dictionary in category["rows"]:
			var row := menu.find_row(definition["label"])
			check(row != null and not row.get_key_groups().is_empty(), "«%s» tiene botón" % definition["label"])
	check_equal(Array(menu.find_row("Interactuar").get_key_groups()), [PackedStringArray(["A"])], "interactuar con A")
	check_equal(Array(menu.find_row("Moverse").get_key_groups()), [PackedStringArray(["Stick izq."]), PackedStringArray(["Cruceta"])], "moverse con el stick o la cruceta")
	check_equal(Array(menu.find_row("Volver atrás o cerrar una pantalla").get_key_groups()), [PackedStringArray(["B"])], "volver con B")
	if Controls.get_connected_gamepads().is_empty():
		check(menu.get_status_text().begins_with("No hay ningún mando conectado"), "dice que no hay mando")
	layer.queue_free()
	await get_tree().process_frame
