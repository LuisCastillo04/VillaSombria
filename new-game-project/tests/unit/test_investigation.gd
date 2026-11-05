extends TestCase
## Registro de pistas, deducciones, acusación y flujo de la vertical slice.

var game: Game


func before_each() -> void:
	GameState.reset()
	GameClock.reset()


func after_each() -> void:
	DialogueManager.close()
	if game != null:
		game.queue_free()
		game = null
		await get_tree().process_frame
	GameState.reset()
	GameClock.reset()


func test_clue_is_registered_only_once() -> void:
	check(Investigation.discover_clue("reloj_despacho"), "la primera vez es nueva")
	check(not Investigation.discover_clue("reloj_despacho"), "la segunda vez no")
	check_equal(GameState.clues.count("reloj_despacho"), 1, "sin duplicados")


func test_discovery_notifies_interface() -> void:
	var seen: Array[String] = []
	var listener := func(title: String, body: String, _kind: String) -> void:
		seen.append(title + "|" + body)
	EventBus.notification_requested.connect(listener)
	Investigation.discover_clue("foto_clara")
	Investigation.discover_clue("foto_clara")
	EventBus.notification_requested.disconnect(listener)
	check_equal(seen.size(), 1, "una sola notificación")
	check(seen[0].contains("Fotografía de Clara"), "la notificación nombra la pista")


func test_unknown_clue_is_rejected() -> void:
	check(not GameState.clues.has("inventada"), "estado inicial")
	# El error se registra en la consola, lo importante es que no entra en el expediente.
	check(not GameData.clues.has("inventada"), "la pista no existe en los datos")


func test_link_requires_owned_items() -> void:
	var result := Investigation.try_link("reloj_despacho", "copia_telegrama")
	check_equal(result["result"], Investigation.LinkResult.MISSING_ITEM, "sin las pruebas no hay relación")
	check(GameState.deductions.is_empty(), "no se registra nada")


func test_real_link_creates_deduction_and_flag() -> void:
	Investigation.discover_clue("reloj_despacho")
	Investigation.discover_clue("copia_telegrama")
	var result := Investigation.try_link("copia_telegrama", "reloj_despacho")
	check_equal(result["result"], Investigation.LinkResult.NEW, "el orden de los elementos no importa")
	check_equal(result["deduction"], "d_hora_falsa", "deducción correcta")
	check(GameState.has_flag("hora_real_conocida"), "la deducción aplica sus efectos")
	var again := Investigation.try_link("reloj_despacho", "copia_telegrama")
	check_equal(again["result"], Investigation.LinkResult.ALREADY_KNOWN, "no se duplica")
	check_equal(GameState.deductions.size(), 1, "una sola deducción")


func test_unrelated_items_do_not_link() -> void:
	Investigation.discover_clue("foto_clara")
	Investigation.discover_clue("carta_amor")
	var result := Investigation.try_link("foto_clara", "carta_amor")
	check_equal(result["result"], Investigation.LinkResult.NONE, "dos pistas sin relación no deducen nada")


func test_deduction_can_chain_into_another() -> void:
	Investigation.discover_clue("reloj_despacho")
	Investigation.discover_clue("copia_telegrama")
	Investigation.record_testimony("t_anselmo_brindis")
	var blocked := Investigation.try_link("d_hora_falsa", "t_anselmo_brindis")
	check_equal(blocked["result"], Investigation.LinkResult.MISSING_ITEM, "primero hay que deducir la hora falsa")
	Investigation.try_link("reloj_despacho", "copia_telegrama")
	var chained := Investigation.try_link("d_hora_falsa", "t_anselmo_brindis")
	check_equal(chained["deduction"], "d_coartada_cae", "una deducción sirve como prueba de la siguiente")


func test_accusation_of_innocent_explains_why_not() -> void:
	var verdict := Investigation.evaluate_accusation("marcos", "transferencia", "d_bodega", "d_brandy")
	check(not verdict["ok"], "Marcos es inocente")
	check((verdict["reason"] as String).contains("pagaré"), "la refutación cita su coartada")


func test_accusation_needs_all_three_proofs() -> void:
	check(not Investigation.evaluate_accusation("anselmo", "foto_clara", "d_bodega", "d_brandy")["ok"], "motivo débil")
	check(not Investigation.evaluate_accusation("anselmo", "d_dinero", "carta_amor", "d_brandy")["ok"], "oportunidad débil")
	check(not Investigation.evaluate_accusation("anselmo", "d_dinero", "d_bodega", "carta_amor")["ok"], "medios débiles")
	check(Investigation.evaluate_accusation("anselmo", "d_dinero", "d_bodega", "d_brandy")["ok"], "acusación completa")


func test_time_events_fire_even_after_a_jump() -> void:
	GameClock.day = 2
	GameClock.minutes = GameClock.DAY_START
	GameClock.advance(9 * 60)
	check(GameState.has_flag("informe_llegado"), "saltar por encima de las 12:00 no pierde el evento")
	check(GameState.has_flag("evento_ev_forense"), "queda marcado para no repetirse")


func test_rest_is_blocked_until_day_goals_done() -> void:
	check(not StoryDirector.rest(), "no se puede dormir sin investigar")
	check_equal(GameClock.day, 1, "el día no avanza")
	for flag: String in ["llamada_atendida", "ortega_briefing", "hablo_elena", "hablo_marcos", "hablo_lucia", "hablo_anselmo", "hablo_irene"]:
		GameState.set_flag(flag)
	Investigation.discover_clue("reloj_despacho")
	check(StoryDirector.rest(), "hecho lo imprescindible se puede dormir")
	check_equal(GameClock.day, 2, "empieza el día siguiente")
	check_equal(GameClock.minutes, GameClock.DAY_START, "a primera hora")


## Recorrido de la vertical slice con entradas reales en la plaza.
func test_vertical_slice_flow() -> void:
	game = await make_game()
	await game.go_to("plaza", "inicio")
	await wait_physics_frames(3)
	check_equal(game.current_location.location_id, "plaza", "el detective llega a la plaza")
	var hilario := game.current_location.get_npc("hilario")
	check(hilario != null, "hay un NPC interactivo en la plaza")
	check(not _available("hilario", "periodico"), "la pregunta empieza bloqueada")

	# Examina el periódico del quiosco y lo registra en el expediente.
	game.player.teleport(Vector3(-4.2, 0.1, 10.0))
	await wait_physics_frames(6)
	var focused := game.player.detector.get_focused()
	check(focused is ClueObject, "el quiosco debe quedar enfocado")
	game.player.detector.trigger(game.player)
	await wait_physics_frames(2)
	check(GameState.clues.has("periodico_aniversario"), "la pista entra en el expediente")
	check(GameState.is_player_locked(), "examinar bloquea el movimiento")
	var inspector: ClueInspector = game.get_node("ClueInspector")
	check(inspector.is_open, "se abre la hoja de la pista")
	inspector.close()
	check(not GameState.is_player_locked(), "cerrar devuelve el control")

	# La pista desbloquea la pregunta a Hilario.
	check(_available("hilario", "periodico"), "la pista debe desbloquear la pregunta")
	game.player.teleport(hilario.global_position + Vector3(0.0, 0.1, 1.0))
	await wait_physics_frames(6)
	check(game.player.detector.get_focused() is NpcInteraction, "el NPC debe quedar enfocado")
	game.player.detector.trigger(game.player)
	check(DialogueManager.active, "se abre el interrogatorio")
	check_equal(hilario.state, Npc.State.TALKING, "el NPC se detiene")


func _available(npc_id: String, topic_id: String) -> bool:
	for topic in DialogueManager.get_available_topics(npc_id):
		if topic["id"] == topic_id:
			return true
	return false
