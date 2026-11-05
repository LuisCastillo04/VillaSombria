extends TestCase
## Conversaciones: flujo, condiciones, efectos, tiempo y bloqueo del jugador.

var last_options: Array = []
var lines: Array[String] = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	last_options = []
	lines = []
	DialogueManager.options_shown.connect(_on_options)
	DialogueManager.line_shown.connect(_on_line)


func after_each() -> void:
	DialogueManager.close()
	DialogueManager.options_shown.disconnect(_on_options)
	DialogueManager.line_shown.disconnect(_on_line)


func _on_options(options: Array) -> void:
	last_options = options


func _on_line(_speaker: String, text: String) -> void:
	lines.append(text)


## Avanza hasta que aparezca un menú o la conversación termine.
func _read_until_menu() -> void:
	last_options = []
	var guard := 0
	while DialogueManager.active and last_options.is_empty() and guard < 200:
		DialogueManager.advance()
		guard += 1


func _option_ids() -> Array:
	return last_options.map(func(option: Dictionary) -> String: return option["id"])


func test_conversation_locks_and_releases_player() -> void:
	DialogueManager.start("ortega")
	check(GameState.is_player_locked(), "hablar debe bloquear el movimiento")
	_read_until_menu()
	DialogueManager.choose(DialogueManager.EXIT_OPTION)
	check(not DialogueManager.active, "salir debe cerrar la conversación")
	check(not GameState.is_player_locked(), "cerrar debe devolver el control")


func test_intro_changes_after_first_meeting() -> void:
	DialogueManager.start("ortega")
	_read_until_menu()
	DialogueManager.close()
	check(GameState.has_flag("ortega_conocido"), "la presentación debe marcarse")
	var first_count := lines.size()
	check(first_count >= 2, "la primera vez hay presentación completa")
	lines.clear()
	DialogueManager.start("ortega")
	_read_until_menu()
	check_equal(lines.size(), 1, "la segunda vez el saludo es breve")


func test_topic_effects_are_applied_once() -> void:
	DialogueManager.start("elena")
	_read_until_menu()
	DialogueManager.choose("coartada")
	_read_until_menu()
	check(GameState.testimonies.has("t_elena_jaqueca"), "la pregunta debe registrar el testimonio")
	check(GameState.has_flag("hablo_elena"), "la pregunta debe marcar el progreso")
	var time_after_first := GameClock.minutes
	check(time_after_first > GameClock.DAY_START, "preguntar por primera vez consume tiempo")
	DialogueManager.choose("coartada")
	_read_until_menu()
	check_equal(GameClock.minutes, time_after_first, "repetir una pregunta no consume tiempo")
	check_equal(GameState.testimonies.count("t_elena_jaqueca"), 1, "el testimonio no se duplica")


func test_clue_unlocks_question() -> void:
	DialogueManager.start("lucia")
	_read_until_menu()
	check(not _option_ids().has("carta"), "sin la carta no debe aparecer la pregunta")
	DialogueManager.close()
	Investigation.discover_clue("carta_amor")
	DialogueManager.start("lucia")
	_read_until_menu()
	check(_option_ids().has("carta"), "la pista debe desbloquear la pregunta")


func test_conditional_answer_depends_on_state() -> void:
	GameClock.day = 2
	DialogueManager.start("ortega")
	_read_until_menu()
	DialogueManager.choose("informe")
	_read_until_menu()
	check(not GameState.clues.has("informe_forense"), "antes de mediodía no hay informe")
	GameState.set_flag("informe_llegado")
	DialogueManager.choose("informe")
	_read_until_menu()
	check(GameState.clues.has("informe_forense"), "con el correo recibido entrega el informe")


func test_any_condition_accepts_either_branch() -> void:
	var condition := {"any": [{"flags": ["a"]}, {"flags": ["b"]}]}
	check(not Conditions.check(condition), "sin ninguna rama no se cumple")
	GameState.set_flag("b")
	check(Conditions.check(condition), "basta con una rama")


func test_new_topics_are_reported() -> void:
	check(DialogueManager.has_new_topics("elena"), "un NPC sin interrogar tiene preguntas nuevas")
	for topic in DialogueManager.get_available_topics("elena"):
		GameState.asked_topics["elena/%s" % topic["id"]] = true
	check(not DialogueManager.has_new_topics("elena"), "preguntado todo, no hay novedades")


func test_scene_closes_by_itself() -> void:
	DialogueManager.play_scene("llamada")
	_read_until_menu()
	check(not DialogueManager.active, "una escena termina sola")
	check(GameState.has_flag("llamada_atendida"), "la escena aplica sus efectos")
	check(not GameState.is_player_locked(), "al terminar devuelve el control")
