extends TestCase
## Pantalla «Reasignar teclas» con pulsaciones como las del jugador: la pulsación que elige un hueco
## no se toma como tecla, las repeticiones no cuentan, Esc y un clic cancelan, Mayús y Ctrl se toman
## al soltarlas, Alt + F4 nunca se asigna, las teclas reservadas se explican, los conflictos preguntan
## si se intercambian y la alternativa se puede quitar. El cambio llega a la partida.

var layer: CanvasLayer
var menu: RebindMenu


func before_each() -> void:
	Controls.restore_defaults()
	layer = CanvasLayer.new()
	add_child(layer)
	menu = (load("res://scenes/ui/rebind_menu.tscn") as PackedScene).instantiate()
	layer.add_child(menu)
	await get_tree().process_frame
	menu.open()
	await get_tree().process_frame


func after_each() -> void:
	if ConfirmDialog.is_open():
		ConfirmDialog.cancel()
	layer.queue_free()
	await get_tree().process_frame
	Controls.restore_defaults()


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


func _slot(action: String, index: int) -> KeySlotButton:
	return menu.get_row(action).get_slot(index)


## Una tecla tal como llega del teclado: con su código físico y el lógico.
func _key(code: Key, pressed: bool = true, echo: bool = false, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	event.alt_pressed = alt
	get_viewport().push_input(event)


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)


## Elige un hueco como el jugador: abre su categoría, lo señala y pulsa Intro (se activa al soltarla).
func _choose(slot: KeySlotButton) -> void:
	menu.select_category(InputBindings.CATEGORIES.find(InputBindings.definition_of(slot.action)["category"]))
	await get_tree().process_frame
	slot.grab_focus()
	await get_tree().process_frame
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	await get_tree().process_frame


func test_every_rebindable_action_has_a_row_in_its_category() -> void:
	check_equal(menu.get_category_titles(), PackedStringArray(InputBindings.CATEGORIES), "las categorías de la lista de controles")
	for action in InputBindings.action_ids():
		var row := menu.get_row(action)
		check(row != null, "hay fila para %s" % action)
		if row == null:
			continue
		var page := menu.get_page(InputBindings.CATEGORIES.find(InputBindings.definition_of(action)["category"]))
		check(page.is_ancestor_of(row), "%s está en su categoría" % action)
		check_equal(row.get_slot(0).get_key(), Controls.get_key(action, 0), "%s muestra su tecla principal" % action)
	check_equal(_slot("move_forward", 1).get_key_text(), "↑", "y la alternativa con su nombre")
	check_equal(_slot("interact", 1).text, KeySlotButton.EMPTY_TEXT, "un hueco vacío muestra una raya")
	for page_index in InputBindings.CATEGORIES.size():
		for child in menu.get_page(page_index).get_children():
			if child.has_meta("fixed"):
				check((child as Control).focus_mode == Control.FOCUS_NONE, "las teclas fijas se ven pero no se eligen")


func test_the_key_that_chooses_the_slot_is_not_captured() -> void:
	await _choose(_slot("interact", 0))
	check(menu.is_capturing(), "elegir el hueco empieza la espera")
	check(menu.get_status_text().begins_with("Presiona una tecla para asignarla a «Interactuar"), "y lo pide en pantalla")
	check(_slot("interact", 0).is_waiting(), "el hueco dice que espera")
	_key(KEY_ENTER, true, true)
	check(menu.is_capturing(), "la repetición de Intro mantenida no cuenta")
	check_equal(Controls.get_keys("interact"), [KEY_E] as Array[Key], "Intro no se ha asignado")
	_tap(KEY_F)
	check(not menu.is_capturing(), "la tecla siguiente termina la espera")
	check_equal(Controls.get_keys("interact"), [KEY_F] as Array[Key], "y se asigna")
	check_equal(_slot("interact", 0).get_key_text(), "F", "el hueco la muestra")
	check(menu.get_row("interact").is_marked_custom(), "la fila se marca como personalizada")
	check(_focus_owner() == _slot("interact", 0), "el foco sigue en el hueco")


func test_escape_and_clicks_cancel_without_closing() -> void:
	await _choose(_slot("open_map", 0))
	_tap(KEY_ESCAPE)
	check(not menu.is_capturing(), "Esc cancela la espera")
	check(menu.is_open(), "sin cerrar la pantalla")
	check_equal(Controls.get_keys("open_map"), [KEY_M] as Array[Key], "y sin cambiar nada")
	check(menu.get_status_text().begins_with("Cambio cancelado"), "lo dice")
	await _choose(_slot("open_map", 0))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(4.0, 4.0)
	get_viewport().push_input(click)
	check(not menu.is_capturing(), "un clic también cancela")
	check_equal(Controls.get_keys("open_map"), [KEY_M] as Array[Key], "sin cambiar nada")
	_tap(KEY_ESCAPE)
	check(not menu.is_open(), "sin espera, Esc vuelve atrás")


func test_modifiers_are_taken_on_release_and_alt_f4_is_never_taken() -> void:
	await _choose(_slot("wait_time", 0))
	_key(KEY_CTRL, true)
	check(menu.is_capturing(), "Ctrl pulsada todavía no se asigna")
	_key(KEY_CTRL, false)
	check_equal(Controls.get_keys("wait_time"), [KEY_CTRL] as Array[Key], "al soltarla sola, sí")
	await _choose(_slot("wait_time", 0))
	_key(KEY_ALT, true)
	_key(KEY_F4, true, false, true)
	_key(KEY_F4, false, false, true)
	_key(KEY_ALT, false)
	check_equal(Controls.get_keys("wait_time"), [KEY_CTRL] as Array[Key], "Alt + F4 no se toma ni entera ni a trozos")
	check(menu.is_capturing(), "la espera sigue")
	check(menu.get_status_text().contains("sistema"), "y explica por qué")
	_tap(KEY_ESCAPE)


func test_reserved_keys_are_explained_and_the_wait_goes_on() -> void:
	await _choose(_slot("interact", 0))
	_tap(KEY_1)
	check(menu.is_capturing(), "una tecla reservada no termina la espera")
	check(menu.get_status_text().contains("reservada para elegir respuestas"), "dice para qué está reservada")
	_tap(KEY_UP)
	check(menu.get_status_text().contains("moverse por los menús"), "y por qué interactuar no puede usar ↑")
	_tap(KEY_G)
	check_equal(Controls.get_keys("interact"), [KEY_G] as Array[Key], "otra tecla sí se asigna")


func test_a_conflict_asks_to_swap_and_swaps() -> void:
	await _choose(_slot("open_map", 0))
	_tap(KEY_E)
	check(ConfirmDialog.is_open(), "una tecla en uso pregunta")
	check(ConfirmDialog.get_message_text().contains("La tecla E ya está asignada a «Interactuar y avanzar el diálogo»."), "dice quién la usa")
	check(ConfirmDialog.get_message_text().contains("¿Quieres intercambiar las asignaciones?"), "y ofrece intercambiarlas")
	check(ConfirmDialog.get_message_text().contains("pasará a usar M"), "con lo que recibirá la otra acción")
	check_equal(ConfirmDialog.get_confirm_button().text, "Intercambiar", "botón para intercambiar")
	check(_focus_owner() == ConfirmDialog.get_cancel_button(), "el foco empieza en cancelar, lo seguro")
	ConfirmDialog.confirm()
	check_equal(Controls.get_keys("open_map"), [KEY_E] as Array[Key], "el mapa pasa a E")
	check_equal(Controls.get_keys("interact"), [KEY_M] as Array[Key], "interactuar a M")
	check_equal(_slot("interact", 0).get_key_text(), "M", "las dos filas se ponen al día")
	check(menu.get_status_text().begins_with("Intercambiadas"), "y se confirma en pantalla")


func test_cancelling_a_conflict_changes_nothing() -> void:
	await _choose(_slot("open_board", 0))
	_tap(KEY_J)
	check(ConfirmDialog.is_open(), "J es del expediente: pregunta")
	ConfirmDialog.cancel()
	check_equal(Controls.get_keys("open_board"), [KEY_B] as Array[Key], "el tablero sigue con B")
	check_equal(Controls.get_keys("open_journal"), [KEY_J, KEY_TAB] as Array[Key], "y el expediente con J y Tab")
	check(menu.get_status_text().begins_with("Sin cambios"), "lo dice")
	check(menu.is_open() and not menu.is_capturing(), "la pantalla sigue abierta, sin esperar")


func test_a_swap_that_would_leave_an_action_without_keys_is_not_offered() -> void:
	await _choose(_slot("open_board", 1))
	_tap(KEY_E)
	check(not ConfirmDialog.is_open(), "no se pregunta")
	check(menu.is_capturing(), "se sigue esperando otra tecla")
	check(menu.get_status_text().contains("única tecla de «Interactuar"), "y se explica por qué")
	_tap(KEY_ESCAPE)


func test_the_alternative_can_be_removed_but_not_the_primary() -> void:
	_slot("move_forward", 1).grab_focus()
	_tap(KEY_DELETE)
	check_equal(Controls.get_keys("move_forward"), [KEY_W] as Array[Key], "Supr quita ↑ de avanzar")
	check_equal(_slot("move_forward", 1).text, KeySlotButton.EMPTY_TEXT, "el hueco queda vacío")
	_slot("move_forward", 0).grab_focus()
	_tap(KEY_DELETE)
	check_equal(Controls.get_keys("move_forward"), [KEY_W] as Array[Key], "la principal no se quita")
	check(menu.get_status_text().contains("no se puede quitar"), "y se explica")


func test_keyboard_navigation_between_tabs_and_slots() -> void:
	check(_focus_owner() == menu.get_tab(0), "el foco empieza en la primera categoría")
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	get_viewport().push_input(right)
	check(_focus_owner() == _slot("move_forward", 0), "a la derecha se entra en la primera tecla")
	get_viewport().push_input(right)
	check(_focus_owner() == _slot("move_forward", 1), "otra vez, a su alternativa")
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	get_viewport().push_input(down)
	check(_focus_owner() == _slot("move_back", 1), "abajo sigue en la misma columna")
	var left := InputEventAction.new()
	left.action = "ui_left"
	left.pressed = true
	get_viewport().push_input(left)
	get_viewport().push_input(left)
	check(_focus_owner() == menu.get_tab(0), "a la izquierda se vuelve a la pestaña")


func test_a_rebound_key_works_in_the_game() -> void:
	Settings.set_value("jugabilidad/confirmaciones", false)
	await _choose(_slot("wait_time", 0))
	_tap(KEY_Y)
	menu.close()
	GameState.reset()
	GameClock.reset()
	var game := await make_game()
	var before := GameClock.minutes
	_tap(KEY_T)
	await wait_physics_frames(2)
	check_equal(GameClock.minutes, before, "T ya no deja pasar el tiempo")
	_tap(KEY_Y)
	await wait_physics_frames(2)
	check_equal(GameClock.minutes, before + Game.WAIT_MINUTES, "Y sí")
	game.queue_free()
	await get_tree().process_frame
	GameState.reset()
	GameClock.reset()
	Settings.set_value("jugabilidad/confirmaciones", true)


func test_closing_the_window_during_a_wait_leaves_the_keyboard_to_the_exit_question() -> void:
	# Como dentro de la pausa, la pantalla sigue recibiendo pulsaciones con el juego congelado.
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var targets: Array = []
	ExitManager.finish_override = func(target: int) -> void: targets.append(target)
	GameState.location_id = "plaza"
	SaveSystem.begin_session(self)
	GameState.set_flag("progreso_sin_ranura")
	await _choose(_slot("interact", 0))
	# Alt + F4 llega a Godot como sus teclas y, aparte, como la petición de cierre de la ventana.
	_key(KEY_ALT, true)
	_key(KEY_F4, true, false, true)
	ExitManager.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	for frame in 180:
		if ExitManager.is_dialog_open():
			break
		await get_tree().process_frame
	check(ExitManager.is_dialog_open(), "sin ranura activa, el cierre pregunta como siempre")
	_key(KEY_F4, false, false, true)
	_key(KEY_ALT, false)
	_tap(KEY_ESCAPE)
	check(not ExitManager.is_dialog_open(), "Esc contesta a la pregunta de salida")
	check(not menu.is_capturing(), "y la espera de la tecla termina")
	check(targets.is_empty(), "cancelar deja el juego abierto")
	check_equal(Controls.get_keys("interact"), [KEY_E] as Array[Key], "sin haber asignado Alt, F4 ni Esc")
	ExitManager.finish_override = Callable()
	SaveSystem.end_session(self)
	GameState.reset()
	get_tree().paused = false
