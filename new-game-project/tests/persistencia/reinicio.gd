extends TestCase
## Cierre y reinicio reales: la prueba se ejecuta dos veces, en procesos distintos.
##   godot --headless --path . res://tests/persistencia/reinicio.tscn -- --fase=guardar
##   godot --headless --path . res://tests/persistencia/reinicio.tscn -- --fase=comprobar
## La primera fase juega un poco y guarda en una ranura manual. La segunda arranca sin nada
## en memoria, carga esa ranura desde el menú principal y comprueba que todo se recupera.
## `tools/verificar.ps1` ejecuta las dos fases seguidas.

const STORAGE := "user://pruebas_guardado/reinicio"
const SLOT := "manual_3"
const EXPECTED_FILE := "esperado.json"
const MAIN_MENU := "res://scenes/main/main_menu.tscn"


func _ready() -> void:
	SaveSystem.autosave_enabled = false
	SaveSystem.use_storage(STORAGE)
	var phase := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fase="):
			phase = argument.trim_prefix("--fase=")
	match phase:
		"guardar":
			await _save_phase()
		"comprobar":
			await _check_phase()
		_:
			failures.append("fase desconocida «%s»: usa --fase=guardar o --fase=comprobar" % phase)
	for failure in failures:
		print("FALLO reinicio (%s): %s" % [phase, failure])
	if failures.is_empty():
		print("REINICIO %s: correcto" % phase)
	get_tree().quit(1 if not failures.is_empty() else 0)


func _save_phase() -> void:
	TestCase.clear_save_storage()
	var game := await make_game()
	GameState.set_flag("llamada_atendida")
	await game.go_to("mansion", "desde_plaza")
	Investigation.discover_clue("lista_invitados")
	Investigation.discover_clue("reloj_despacho")
	Investigation.record_testimony("t_elena_jaqueca")
	GameState.asked_topics["elena/coartada"] = true
	# Registro de los interrogatorios: una pregunta repetida, con su día y su hora, y otra con una
	# variante concreta, además de lo ya visto en un menú.
	ConversationLog.record("ortega", "caso", ConversationLog.BASE_VARIANT)
	ConversationLog.record("ortega", "caso", ConversationLog.BASE_VARIANT)
	ConversationLog.record("ortega", "informe", "pendiente")
	ConversationLog.mark_seen("lucia", ConversationLog.menu("lucia"))
	GameState.hypotheses["marcos"] = {"status": "sospechoso", "note": "Miente sobre la hora"}
	GameState.accusation_attempts = 1
	# Borrador a medias de la acusación: sin motivo todavía.
	Investigation.set_accusation_choice("suspect", "irene")
	Investigation.set_accusation_choice("opportunity", "lista_invitados")
	Investigation.set_accusation_choice("means", "reloj_despacho")
	GameClock.advance(95)
	GameState.play_seconds = 1234.5
	game.player.teleport(game.player.global_position + Vector3(1.2, 0.0, -1.5), 2.0)
	await wait_physics_frames(3)
	var expected := {
		"location_id": GameState.location_id,
		"position": [game.player.global_position.x, game.player.global_position.y, game.player.global_position.z],
		"yaw": game.player.model.rotation.y,
		"day": GameClock.day,
		"minutes": GameClock.minutes,
		"clues": GameState.clues.duplicate(),
		"testimonies": GameState.testimonies.duplicate(),
		"flags": GameState.flags.keys(),
		"conversations": {
			"ortega/caso": GameState.conversations["ortega/caso"],
			"ortega/informe": GameState.conversations["ortega/informe"],
		},
		"seen_topics": GameState.seen_topics.keys(),
	}
	check(await save_and_wait(SLOT), "la partida se guarda en %s" % SLOT)
	var file := FileAccess.open(STORAGE.path_join(EXPECTED_FILE), FileAccess.WRITE)
	file.store_string(JSON.stringify(expected))
	file.close()
	game.queue_free()
	await get_tree().process_frame


func _check_phase() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORAGE.path_join(EXPECTED_FILE)))
	if not expected is Dictionary:
		failures.append("falta el resultado de la fase de guardado")
		return
	check(GameState.clues.is_empty() and GameState.flags.is_empty(), "el proceso nuevo empieza sin estado")
	var menu: Node = (load(MAIN_MENU) as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var continue_button: Button = menu.get_node("%Continue")
	check(not continue_button.disabled, "el menú principal ofrece continuar")
	var slots: SaveSlotsMenu = menu.get_node("%SaveSlotsMenu")
	# El cambio de escena real sustituiría a esta prueba: se crea la partida a mano.
	slots.load_ready.disconnect(menu._on_load_ready)
	(menu.get_node("%Load") as Button).pressed.emit()
	slots.select_slot(SLOT)
	slots.get_action_button().pressed.emit()
	check(SaveSystem.has_pending_load(), "la ranura se carga desde el menú")
	menu.queue_free()
	await get_tree().process_frame
	var game := await make_game()
	var position: Array = expected["position"]
	var saved_position := Vector3(position[0], position[1], position[2])
	check_equal(game.current_location.location_id, expected["location_id"], "lugar")
	check(game.player.global_position.distance_to(saved_position) < 0.2, "posición del detective")
	check(is_equal_approx(game.player.model.rotation.y, float(expected["yaw"])), "orientación")
	check_equal(GameClock.day, int(expected["day"]), "día")
	check_equal(GameClock.minutes, int(expected["minutes"]), "hora")
	for clue_id: String in expected["clues"]:
		check(GameState.clues.has(clue_id), "pista %s" % clue_id)
	for testimony_id: String in expected["testimonies"]:
		check(GameState.testimonies.has(testimony_id), "testimonio %s" % testimony_id)
	for flag: String in expected["flags"]:
		check(GameState.has_flag(flag), "marca %s" % flag)
	check(GameState.asked_topics.has("elena/coartada"), "preguntas ya hechas")
	for topic_key: String in expected["conversations"]:
		var saved_variants: Dictionary = expected["conversations"][topic_key]["variants"]
		var loaded: Dictionary = GameState.conversations.get(topic_key, {}).get("variants", {})
		check_equal(loaded.keys(), saved_variants.keys(), "variantes de %s" % topic_key)
		for variant_id: String in saved_variants:
			for field: String in ["count", "order", "day", "minutes"]:
				check_equal(int(loaded.get(variant_id, {}).get(field, -99)), int(saved_variants[variant_id][field]), "%s#%s: %s" % [topic_key, variant_id, field])
	check(ConversationLog.is_variant_done("elena", "coartada", ConversationLog.BASE_VARIANT), "la pregunta de una partida sin registro se recupera con su testimonio")
	for seen_key: String in expected["seen_topics"]:
		check(GameState.seen_topics.has(seen_key), "lo ya visto en un menú: %s" % seen_key)
	check_equal(GameState.hypotheses.get("marcos", {}).get("note", ""), "Miente sobre la hora", "hipótesis")
	check_equal(GameState.accusation_attempts, 1, "intentos de acusación")
	check(GameState.play_seconds >= 1234.5, "tiempo jugado")
	check(not SaveSystem.has_unsaved_progress(), "recién cargada no hay progreso sin guardar")
	var draft := Investigation.get_accusation_draft()
	check_equal(draft, {"suspect": "irene", "motive": "", "opportunity": "lista_invitados", "means": "reloj_despacho"}, "borrador de la acusación")
	var accusation: AccusationUi = game.get_node("AccusationUi")
	accusation.open()
	check_equal(accusation.get_field_text("suspect"), "Irene Vidal", "la hoja recupera al sospechoso")
	check_equal(accusation.get_field_text("opportunity"), "Lista de invitados", "y las pruebas elegidas")
	check(not accusation.get_field("motive").is_filled(), "el motivo sigue pendiente")
	accusation.close()
	game.queue_free()
	await get_tree().process_frame
	TestCase.clear_save_storage()
