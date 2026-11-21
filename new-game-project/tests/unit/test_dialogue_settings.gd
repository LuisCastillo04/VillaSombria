extends TestCase
## Velocidad del texto y avance automático de las conversaciones, con la escena de juego real y
## entradas como las del jugador: la velocidad elegida llega a la escritura, el texto instantáneo no
## deja saltarse una intervención con dos pulsaciones, el avance automático espera a que se lea la
## página, pasa solo, nunca elige una respuesta y responde a los cambios en mitad de la conversación.

const OPEN_SECONDS := DialogueStyle.OPEN_SECONDS + 0.1

var game: Game
var ui: DialogueUi
var lines_shown := 0


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.reset_test_settings()
	lines_shown = 0
	DialogueManager.line_shown.connect(_count_line)
	game = await make_game()
	ui = game.get_node("DialogueUi")


func after_each() -> void:
	DialogueManager.line_shown.disconnect(_count_line)
	if DialogueManager.active:
		DialogueManager.close()
	game.queue_free()
	await get_tree().process_frame
	TestCase.reset_test_settings()
	GameState.reset()
	GameClock.reset()


func _count_line(_speaker: String, _text: String) -> void:
	lines_shown += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_physics_frames(2)


func test_text_speed_follows_the_setting() -> void:
	var text := ui.get_dialogue_text()
	check(is_equal_approx(text.characters_per_second, DialogueStyle.CHARACTERS_PER_SECOND), "por defecto, la velocidad normal de siempre")
	for speed: String in SettingsSchema.options("jugabilidad/velocidad_texto"):
		Settings.set_value("jugabilidad/velocidad_texto", speed)
		check(is_equal_approx(text.characters_per_second, DialogueStyle.text_speed(speed)), "«%s» llega a la escritura" % speed)
	check(DialogueStyle.text_speed("lento") < DialogueStyle.text_speed("normal"), "lento escribe menos letras por segundo")
	check(DialogueStyle.text_speed("rapido") > DialogueStyle.text_speed("normal"), "rápido, más")
	check_equal(DialogueStyle.text_speed("instantaneo"), 0.0, "instantáneo no escribe: muestra la página")


func test_slow_text_really_takes_longer() -> void:
	var text := ui.get_dialogue_text()
	Settings.set_value("jugabilidad/velocidad_texto", "lento")
	DialogueManager.play_scene("llamada")
	await _wait(OPEN_SECONDS + 0.5)
	var slow := text.visible_characters
	DialogueManager.close()
	await _wait(0.4)
	Settings.set_value("jugabilidad/velocidad_texto", "rapido")
	DialogueManager.play_scene("llamada")
	await _wait(OPEN_SECONDS + 0.5)
	var fast := text.visible_characters if text.visible_characters >= 0 else text.get_page_length()
	check(slow > 0 and slow < fast, "en el mismo tiempo, lento muestra menos letras (%d) que rápido (%d)" % [slow, fast])


func test_instant_text_shows_the_page_and_ignores_a_double_press() -> void:
	Settings.set_value("jugabilidad/velocidad_texto", "instantaneo")
	DialogueManager.play_scene("llamada")
	await get_tree().process_frame
	check(ui.is_waiting_for_input(), "la primera intervención aparece entera")
	await _wait(OPEN_SECONDS)
	var before := lines_shown
	await _press("interact")
	await _press("interact")
	check_equal(lines_shown, before + 1, "dos pulsaciones seguidas pasan una sola intervención")
	check(ui.is_waiting_for_input(), "y la nueva ya se lee entera")
	await _wait(DialogueStyle.INSTANT_ADVANCE_GUARD + 0.05)
	await _press("interact")
	check_equal(lines_shown, before + 2, "pasado el instante, la siguiente pulsación avanza")


func test_changing_the_speed_mid_line_applies_at_once() -> void:
	Settings.set_value("jugabilidad/velocidad_texto", "lento")
	DialogueManager.play_scene("llamada")
	await _wait(OPEN_SECONDS)
	check(ui.is_typing(), "la intervención se está escribiendo")
	Settings.set_value("jugabilidad/velocidad_texto", "instantaneo")
	check(ui.is_waiting_for_input(), "al pasar a instantáneo, aparece entera en el acto")
	Settings.set_value("jugabilidad/velocidad_texto", "normal")
	await _press("interact")
	check(ui.is_typing(), "y la siguiente se escribe ya a la velocidad nueva")


func test_auto_advance_waits_for_the_page_and_moves_on() -> void:
	Settings.set_value("jugabilidad/avance_automatico", true)
	DialogueManager.play_scene("llamada")
	await get_tree().process_frame
	check(not ui.is_auto_advancing(), "mientras se escribe no cuenta")
	await _wait(OPEN_SECONDS)
	await _press("interact")
	check(ui.is_waiting_for_input(), "con la página entera")
	check(ui.is_auto_advancing(), "empieza a contar")
	var hold := ui.get_auto_advance_remaining()
	var length := ui.get_dialogue_text().get_page_length()
	check(hold >= DialogueStyle.AUTO_MIN_HOLD and hold <= DialogueStyle.AUTO_MAX_HOLD, "una espera razonable (%.1f s)" % hold)
	var expected := DialogueStyle.auto_hold(length, DialogueStyle.CHARACTERS_PER_SECOND)
	check(hold <= expected and hold > expected - 0.2, "según lo que hay que leer (%.2f de %.2f s)" % [hold, expected])
	check(ui.get_continue_button().get_auto_progress() >= 0.0, "«Continuar» muestra la espera")
	var before := lines_shown
	await _wait(hold * 0.5)
	check_equal(lines_shown, before, "no pasa antes de tiempo")
	await _wait(hold * 0.5 + 0.2)
	check_equal(lines_shown, before + 1, "y pasa sola a la siguiente intervención")
	check(ui.get_continue_button().get_auto_progress() < 0.0 or ui.is_auto_advancing(), "la cuenta vuelve a empezar con la nueva")


func test_auto_advance_never_chooses_an_answer() -> void:
	Settings.set_value("jugabilidad/avance_automatico", true)
	Settings.set_value("jugabilidad/velocidad_texto", "instantaneo")
	DialogueManager.start("eusebio")
	await _wait(OPEN_SECONDS)
	await _wait(ui.get_auto_advance_remaining() + 0.3)
	check(ui.is_choosing(), "tras la presentación aparecen las preguntas")
	await _wait(DialogueStyle.AUTO_MAX_HOLD + 0.5)
	check(ui.is_choosing(), "y siguen ahí: el avance automático no elige")
	check(GameState.asked_topics.is_empty(), "no se ha hecho ninguna pregunta")
	check(not ui.is_auto_advancing(), "ni cuenta mientras hay una decisión pendiente")
	check(DialogueManager.active, "la conversación sigue abierta")


func test_auto_advance_can_change_mid_conversation() -> void:
	Settings.set_value("jugabilidad/velocidad_texto", "instantaneo")
	DialogueManager.play_scene("llamada")
	await _wait(OPEN_SECONDS)
	check(not ui.is_auto_advancing(), "desactivado, no cuenta")
	Settings.set_value("jugabilidad/avance_automatico", true)
	check(ui.is_auto_advancing(), "al activarlo empieza a contar con la página a la vista")
	Settings.set_value("jugabilidad/avance_automatico", false)
	check(not ui.is_auto_advancing(), "al desactivarlo deja de contar")
	var before := lines_shown
	await _wait(DialogueStyle.AUTO_MAX_HOLD * 0.5)
	check_equal(lines_shown, before, "y ya no pasa sola")
	await _press("interact")
	check_equal(lines_shown, before + 1, "la tecla sigue avanzando")


func test_manual_advance_still_works_with_auto_advance() -> void:
	Settings.set_value("jugabilidad/avance_automatico", true)
	Settings.set_value("jugabilidad/velocidad_texto", "instantaneo")
	DialogueManager.play_scene("llamada")
	await _wait(OPEN_SECONDS)
	var before := lines_shown
	await _press("ui_accept")
	check_equal(lines_shown, before + 1, "aceptar (Intro o el botón del mando) avanza sin esperar")
	check(ui.is_auto_advancing(), "y la cuenta empieza de nuevo para la siguiente")


func test_auto_advance_stops_when_the_conversation_closes() -> void:
	Settings.set_value("jugabilidad/avance_automatico", true)
	Settings.set_value("jugabilidad/velocidad_texto", "instantaneo")
	DialogueManager.play_scene("llamada")
	await _wait(OPEN_SECONDS)
	check(ui.is_auto_advancing(), "cuenta")
	DialogueManager.close()
	check(not ui.is_auto_advancing(), "al cerrar deja de contar")
	var before := lines_shown
	await _wait(DialogueStyle.AUTO_MAX_HOLD * 0.3)
	check_equal(lines_shown, before, "y no avanza nada")
	check(not GameState.is_player_locked(), "el detective recupera el control")
