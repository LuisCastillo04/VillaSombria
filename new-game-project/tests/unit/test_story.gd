extends TestCase
## Recorre el caso completo como lo haría un jugador, para garantizar que la historia
## se puede terminar y que cada paso depende de lo que debe depender.

var actions: Array[String] = []
var menu_open := false


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	actions = []
	EventBus.story_action.connect(_on_action)
	DialogueManager.options_shown.connect(_on_options)


func after_each() -> void:
	DialogueManager.close()
	EventBus.story_action.disconnect(_on_action)
	DialogueManager.options_shown.disconnect(_on_options)
	GameState.reset()
	GameClock.reset()


func _on_action(action: String) -> void:
	actions.append(action)


func _on_options(_options: Array) -> void:
	menu_open = true


func _read() -> void:
	menu_open = false
	var guard := 0
	while DialogueManager.active and not menu_open and guard < 300:
		DialogueManager.advance()
		guard += 1


func _play(scene_id: String) -> void:
	DialogueManager.play_scene(scene_id)
	_read()


func _is_available(npc_id: String, topic_id: String) -> bool:
	for topic in DialogueManager.get_available_topics(npc_id):
		if topic["id"] == topic_id:
			return true
	return false


## Hace una pregunta exigiendo que esté disponible en ese momento de la historia.
func _ask(npc_id: String, topic_id: String) -> void:
	check(_is_available(npc_id, topic_id), "%s/%s debería estar disponible" % [npc_id, topic_id])
	DialogueManager.start(npc_id)
	_read()
	DialogueManager.choose(topic_id)
	_read()
	DialogueManager.close()


func _link(first_id: String, second_id: String, expected: String) -> void:
	var outcome := Investigation.try_link(first_id, second_id)
	check_equal(outcome["deduction"], expected, "relación %s + %s" % [first_id, second_id])


func _examine(clue_ids: Array[String]) -> void:
	for clue_id in clue_ids:
		Investigation.discover_clue(clue_id)


func _complete_day_one() -> void:
	_play("intro")
	StoryDirector.on_location_entered("cafe")
	_read()
	_ask("ortega", "caso")
	_ask("ortega", "puerta")
	_examine(["lista_invitados", "reloj_despacho", "copa_lavada", "huellas_betun", "billete_tren", "carta_amor", "foto_clara", "libro_bodega", "llave_reloj"])
	for topic: String in ["coartada", "marido", "invitada", "billete", "hija_anselmo"]:
		_ask("elena", topic)
	for topic: String in ["coartada", "discusion", "lucia", "relojes"]:
		_ask("marcos", topic)
	for topic: String in ["hallazgo", "coartada", "carta"]:
		_ask("lucia", topic)
	for topic: String in ["coartada", "despues", "brandy", "relojes", "clara"]:
		_ask("anselmo", topic)
	for topic: String in ["quien", "despacho", "regreso"]:
		_ask("irene", topic)
	for topic: String in ["pension", "marcos", "irene"]:
		_ask("rosa", topic)


func _complete_day_two() -> void:
	check(StoryDirector.rest(), "el primer día debe poder cerrarse")
	_play("dia_2")
	check_equal(GameClock.day, 2, "lunes")
	check(not GameState.has_flag("informe_llegado"), "el correo aún no ha llegado")
	GameClock.advance(4 * 60)
	check(GameState.has_flag("informe_llegado"), "a mediodía llega el informe")
	_ask("ortega", "informe")
	_ask("eusebio", "telegrama")
	_ask("eusebio", "elena")
	_ask("hilario", "valdes")
	_ask("hilario", "cormoran")
	_link("reloj_despacho", "copia_telegrama", "d_hora_falsa")
	_link("d_hora_falsa", "t_anselmo_brindis", "d_coartada_cae")
	_link("t_marcos_habitacion", "pagare_marcos", "d_marcos_mentira")
	_link("t_elena_jaqueca", "registro_billetes", "d_elena_mentira")
	_link("t_irene_amiga", "t_elena_irene", "d_irene_mentira")
	_link("huellas_betun", "t_ortega_escena", "d_servicio")
	_link("reloj_despacho", "llave_reloj", "d_reloj_llave")
	_link("t_anselmo_sin_brandy", "informe_forense", "d_brandy")
	_link("t_anselmo_bodega", "t_lucia_escalera", "d_bodega")
	_link("transferencia", "foto_clara", "d_dinero")


func test_full_case_can_be_solved() -> void:
	_complete_day_one()
	check(GameState.clues.has("carta_valdes"), "la introducción entrega la carta")
	check(GameState.has_flag("llamada_atendida"), "la llamada se ha atendido")
	_complete_day_two()
	check_equal(GameState.deductions.size(), GameData.deductions.size(), "todas las deducciones son alcanzables")

	check(StoryDirector.rest(), "el segundo día debe poder cerrarse")
	_play("dia_3")
	_ask("marcos", "pagare")
	_ask("elena", "huida")
	_ask("irene", "identidad")
	_ask("irene", "cormoran")
	_ask("hilario", "recortes")
	_ask("anselmo", "hora_real")
	_ask("anselmo", "dinero")
	check_equal(GameState.clues.size(), GameData.clues.size() - 1, "todas las pistas salvo la opcional del quiosco")
	check_equal(GameState.testimonies.size(), GameData.testimonies.size(), "todos los testimonios son alcanzables")

	_ask("ortega", "acusar")
	check(actions.has("open_accusation"), "Ortega abre la acusación")
	check(Investigation.evaluate_accusation("anselmo", "d_dinero", "d_bodega", "d_brandy")["ok"], "la acusación es válida")

	DialogueManager.play_scene("confrontacion")
	_read()
	check(menu_open, "la confrontación ofrece una elección")
	DialogueManager.choose("0")
	_read()
	check(GameState.has_flag("caso_resuelto"), "el caso queda resuelto")
	check(actions.has("start_epilogue"), "se encadena el epílogo")
	_play("epilogo")
	check(actions.has("case_closed"), "el epílogo cierra el caso")
	check(not GameState.is_player_locked(), "sin bloqueos al terminar")


func test_both_confrontation_choices_reach_the_end() -> void:
	for option: String in ["0", "1"]:
		actions.clear()
		GameState.reset()
		DialogueManager.play_scene("confrontacion")
		_read()
		DialogueManager.choose(option)
		_read()
		check(actions.has("start_epilogue"), "la opción %s debe llevar al epílogo" % option)


func test_accusation_is_not_offered_too_early() -> void:
	_complete_day_one()
	check(not _is_available("ortega", "acusar"), "el primer día no se puede acusar")
	StoryDirector.rest()
	GameClock.advance(4 * 60)
	check(not _is_available("ortega", "acusar"), "sin demostrar la hora falsa no se puede acusar")
	GameClock.day = 3
	check(not _is_available("ortega", "acusar"), "el tercer día sigue haciendo falta la deducción")


func test_telegram_is_not_available_on_sunday() -> void:
	check(not _is_available("eusebio", "telegrama"), "el telegrama vuelve el lunes")
	check(not _is_available("hilario", "valdes"), "el archivo abre el lunes")


func test_day_two_cannot_close_without_key_evidence() -> void:
	_complete_day_one()
	StoryDirector.rest()
	check(not StoryDirector.can_rest(), "sin las pruebas del lunes no se puede dormir")
	check(not StoryDirector.get_rest_blocked_message().is_empty(), "el juego explica qué falta")


func test_final_day_never_advances() -> void:
	GameClock.day = 3
	Investigation.discover_clue("reloj_despacho")
	check(not StoryDirector.rest(), "el último día no hay un cuarto día")
	check_equal(GameClock.day, 3, "el calendario se detiene en el tercer día")


func test_objectives_follow_progress() -> void:
	var first := StoryDirector.get_objectives()
	check_equal(first.size(), 1, "al empezar sólo se ve el primer objetivo")
	GameState.set_flag("llamada_atendida")
	var pending := StoryDirector.get_objectives().filter(func(item: Dictionary) -> bool: return not item["done"])
	check((pending[0]["text"] as String).contains("Ortega"), "tras la llamada toca ir a la mansión")


func test_clock_stops_at_limit_without_breaking() -> void:
	GameClock.advance(24 * 60)
	check(GameClock.is_at_limit(), "el reloj se detiene en la hora tope")
	var stopped := GameClock.minutes
	GameClock.advance(30)
	check_equal(GameClock.minutes, stopped, "no pasa de la hora tope")
	check(not NpcSchedule.get_slot("ortega", GameClock.day, GameClock.minutes).is_empty(), "las rutinas siguen válidas")
