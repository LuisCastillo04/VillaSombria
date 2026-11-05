extends TestCase
## Recorridos con la escena de juego real: interacciones físicas y entradas de teclado.

var game: Game


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	game = await make_game()


func after_each() -> void:
	DialogueManager.close()
	game.queue_free()
	await get_tree().process_frame
	GameState.reset()
	GameClock.reset()


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await wait_physics_frames(2)


func _find_exit(target: String) -> LocationExit:
	for child in game.current_location.get_children():
		if child is LocationExit and (child as LocationExit).target_location == target:
			return child
	return null


## Coloca al detective junto a la salida y la usa pulsando E, como haría un jugador.
func _use_exit(target: String) -> void:
	var exit_node := _find_exit(target)
	check(exit_node != null, "debe existir la salida hacia " + target)
	game.player.teleport(exit_node.global_position + Vector3(0.3, 0.1, 0.3))
	await wait_physics_frames(6)
	_press("interact")
	await wait_physics_frames(3)


func _wait_until_arrived(target: String) -> void:
	for frame in 150:
		await get_tree().physics_frame
		if game.current_location.location_id == target and not game._changing:
			return
	failures.append("no se llegó a " + target)


func test_route_from_station_to_the_crime_scene() -> void:
	check_equal(game.current_location.location_id, "estacion", "se empieza en la estación")
	await _use_exit("plaza")
	await _wait_until_arrived("plaza")

	# La verja sigue cerrada hasta atender la llamada.
	await _use_exit("mansion")
	await wait_physics_frames(30)
	check_equal(game.current_location.location_id, "plaza", "la verja cerrada no deja pasar")

	var before := GameClock.minutes
	await _use_exit("cafe")
	await _wait_until_arrived("cafe")
	check(GameClock.minutes > before, "cambiar de lugar consume tiempo")
	check(DialogueManager.active, "al entrar en el café suena el teléfono")
	DialogueManager.close()
	GameState.set_flag("llamada_atendida")

	await _use_exit("plaza")
	await _wait_until_arrived("plaza")
	await _use_exit("mansion")
	await _wait_until_arrived("mansion")
	check(game.current_location.get_npc("ortega") != null, "Ortega espera en la mansión")


func test_archive_is_closed_on_sunday_and_open_on_monday() -> void:
	await game.go_to("plaza", "inicio")
	await _use_exit("archivo")
	await wait_physics_frames(30)
	check_equal(game.current_location.location_id, "plaza", "el domingo está cerrado")
	GameClock.start_next_day()
	await _use_exit("archivo")
	await _wait_until_arrived("archivo")
	check(game.current_location.get_npc("hilario") != null, "el lunes Hilario atiende el archivo")


func test_bed_refuses_early_and_accepts_when_ready() -> void:
	await game.go_to("cafe", "cama")
	DialogueManager.close()
	await wait_physics_frames(6)
	check(game.player.detector.get_focused() is RestPoint, "la cama queda al alcance")
	var notes: Array[String] = []
	var listener := func(title: String, _body: String, _kind: String) -> void:
		notes.append(title)
	EventBus.notification_requested.connect(listener)
	_press("interact")
	await wait_physics_frames(3)
	EventBus.notification_requested.disconnect(listener)
	check(notes.has("Todavía no"), "antes de tiempo la cama lo explica")
	check_equal(GameClock.day, 1, "no pasa el día")

	for flag: String in ["llamada_atendida", "ortega_briefing", "hablo_elena", "hablo_marcos", "hablo_lucia", "hablo_anselmo", "hablo_irene"]:
		GameState.set_flag(flag)
	Investigation.discover_clue("reloj_despacho")
	_press("interact")
	for frame in 150:
		await get_tree().physics_frame
		if GameClock.day == 2 and not game._changing:
			break
	check_equal(GameClock.day, 2, "acostarse lleva al lunes")
	check(DialogueManager.active, "el nuevo día empieza con su escena")


func test_conversation_through_the_interface() -> void:
	await game.go_to("plaza", "inicio")
	var ui: DialogueUi = game.get_node("DialogueUi")
	var hilario := game.current_location.get_npc("hilario")
	game.player.teleport(hilario.global_position + Vector3(0.0, 0.1, 1.0))
	await wait_physics_frames(6)
	_press("interact")
	await wait_physics_frames(3)
	check(DialogueManager.active, "E abre la conversación")
	check(ui._root.visible, "aparece el interrogatorio")
	check(ui._portrait.visible and ui._portrait.texture != null, "con la silueta del personaje")
	check(ui._typing, "el texto aparece gradualmente")

	_press("interact")
	await wait_physics_frames(2)
	check(not ui._typing, "E completa el texto de golpe")
	check_equal(ui._text.visible_characters, -1, "se ve la línea completa")
	_press("interact")
	await wait_physics_frames(2)
	check(ui._options_scroll.visible, "tras la línea aparecen las preguntas")
	check(ui._option_ids.size() >= 2, "hay preguntas y la opción de salir")

	await _press_key(KEY_1)
	check(ui._typing or ui._waiting_input, "una tecla numérica hace la pregunta")
	check(GameState.asked_topics.size() > 0, "la pregunta queda registrada")
	var guard := 0
	while not ui._options_scroll.visible and guard < 30:
		_press("interact")
		await wait_physics_frames(2)
		guard += 1
	check(ui._options_scroll.visible, "al terminar la respuesta vuelve el menú")
	await _press_key((KEY_1 + ui._option_ids.size() - 1) as Key)
	check(not DialogueManager.active, "la última opción cierra la conversación")
	check(not GameState.is_player_locked(), "y devuelve el control")


func test_keys_open_and_close_panels() -> void:
	await game.go_to("plaza", "inicio")
	var journal: JournalUi = game.get_node("JournalUi")
	var board: BoardUi = game.get_node("BoardUi")
	_press("open_journal")
	await wait_physics_frames(3)
	check(journal.is_open, "J abre el expediente")
	_press("open_board")
	await wait_physics_frames(3)
	check(not board.is_open, "no se abren dos paneles a la vez")
	_press("open_journal")
	await wait_physics_frames(3)
	check(not journal.is_open, "J lo cierra")
	_press("open_board")
	await wait_physics_frames(3)
	check(board.is_open, "B abre el tablero")
	_press("open_board")
	await wait_physics_frames(3)
	check(not board.is_open, "B lo cierra")
	check(not GameState.is_player_locked(), "sin bloqueos residuales")


func test_wait_key_advances_time_and_moves_npcs() -> void:
	await game.go_to("cafe", "desde_plaza")
	DialogueManager.close()
	check(game.current_location.get_npc("irene") == null, "por la mañana Irene sigue en la mansión")
	GameClock.minutes = 15 * 60 + 30
	_press("wait_time")
	await wait_physics_frames(4)
	check_equal(GameClock.minutes, 16 * 60 + 30, "T deja pasar una hora")
	check(game.current_location.get_npc("irene") != null, "la rutina la trae al café a su hora")
