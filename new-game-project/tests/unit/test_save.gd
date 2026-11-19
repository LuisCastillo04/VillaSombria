extends TestCase
## Guardado, carga y pantallas de la partida.


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	SaveSystem.begin_session(self)


func after_each() -> void:
	SaveSystem.end_session(self)
	SaveSystem.take_pending_load()
	TestCase.clear_save_storage()
	GameState.reset()
	GameClock.reset()


func _load(slot_id: String) -> bool:
	var result := SaveSystem.read_slot(slot_id)
	if result["status"] != SaveFormat.Status.OK:
		return false
	SaveSystem.apply_sections(result["document"]["sections"])
	return true


func test_round_trip_preserves_the_whole_case() -> void:
	GameState.set_flag("ortega_briefing")
	Investigation.discover_clue("reloj_despacho")
	Investigation.record_testimony("t_elena_jaqueca")
	GameState.deductions.append("d_servicio")
	GameState.asked_topics["elena/coartada"] = true
	GameState.hypotheses["marcos"] = {"status": "sospechoso", "note": "Miente"}
	GameState.location_id = "mansion"
	GameState.spawn_id = "desde_plaza"
	GameState.accusation_attempts = 2
	GameClock.day = 2
	GameClock.minutes = 14 * 60 + 30
	check(await save_and_wait("manual_1"), "debe poder guardarse")

	GameState.reset()
	GameClock.reset()
	check(_load("manual_1"), "debe poder cargarse")
	check(GameState.has_flag("ortega_briefing"), "marcas")
	check(GameState.clues.has("reloj_despacho"), "pistas")
	check(GameState.testimonies.has("t_elena_jaqueca"), "testimonios")
	check(GameState.deductions.has("d_servicio"), "deducciones")
	check(GameState.asked_topics.has("elena/coartada"), "preguntas hechas")
	check_equal(GameState.hypotheses["marcos"]["note"], "Miente", "hipótesis")
	check_equal(GameState.location_id, "mansion", "lugar")
	check_equal(GameState.accusation_attempts, 2, "intentos")
	check_equal(GameClock.day, 2, "día")
	check_equal(GameClock.minutes, 14 * 60 + 30, "hora")


func test_loaded_clues_are_not_duplicated_or_renotified() -> void:
	GameState.location_id = "plaza"
	Investigation.discover_clue("foto_clara")
	check(await save_and_wait("manual_1"), "se guarda")
	check(_load("manual_1"), "se carga")
	check(not Investigation.discover_clue("foto_clara"), "tras cargar la pista sigue registrada")
	check_equal(GameState.clues.count("foto_clara"), 1, "sin duplicados")


func test_missing_file_is_handled() -> void:
	check_equal(SaveSystem.read_slot("manual_1")["status"], SaveFormat.Status.EMPTY, "la ranura está vacía")
	check(not SaveSystem.request_load("manual_1")["ok"], "cargar una ranura vacía falla limpiamente")
	check(not SaveSystem.has_pending_load(), "no queda ninguna carga pendiente")
	check(SaveSystem.find_latest_slot().is_empty(), "no hay partida que continuar")


func test_corrupted_file_leaves_state_untouched() -> void:
	GameState.set_flag("intacta")
	write_slot_file("manual_1", "esto no es json {{{")
	check(not SaveSystem.request_load("manual_1")["ok"], "un archivo corrupto se rechaza")
	check_equal(SaveSystem.get_slot_info("manual_1")["status"], SaveFormat.Status.CORRUPT, "se marca como dañado")
	check(GameState.has_flag("intacta"), "el estado actual no se altera")


func test_incompatible_version_is_rejected() -> void:
	write_slot_file("manual_1", JSON.stringify({"version": 999, "state": {}, "clock": {}}))
	check(not SaveSystem.request_load("manual_1")["ok"], "una versión desconocida se rechaza")
	check_equal(SaveSystem.get_slot_info("manual_1")["status"], SaveFormat.Status.INCOMPATIBLE, "se marca como incompatible")


func test_summary_for_menu() -> void:
	GameState.location_id = "plaza"
	GameClock.day = 3
	GameClock.minutes = 9 * 60 + 5
	await save_and_wait("manual_2")
	var summary: Dictionary = SaveSystem.get_slot_info("manual_2")["summary"]
	check_equal(summary["day"], 3, "día")
	check_equal(summary["minutes"], 9 * 60 + 5, "hora")
	check_equal(summary["location_name"], "Plaza Mayor", "lugar")


func test_game_resumes_at_saved_location() -> void:
	GameState.location_id = "cafe"
	GameState.spawn_id = "desde_plaza"
	GameState.set_flag("llamada_atendida")
	Investigation.discover_clue("reloj_despacho")
	GameClock.day = 2
	await save_and_wait("manual_1")
	SaveSystem.end_session(self)
	GameState.reset()
	GameClock.reset()
	check(SaveSystem.request_load("manual_1")["ok"], "la carga se prepara")
	var game := await make_game()
	check_equal(game.current_location.location_id, "cafe", "reanuda en el lugar guardado")
	check_equal(GameClock.day, 2, "reanuda en el día guardado")
	check(GameState.clues.has("reloj_despacho"), "conserva las pistas")
	check(not SaveSystem.has_pending_load(), "la petición de carga se consume")
	game.queue_free()
	await get_tree().process_frame


func test_clue_object_stays_collected_after_changing_location() -> void:
	var game := await make_game()
	GameState.set_flag("llamada_atendida")
	await game.go_to("mansion", "desde_plaza")
	Investigation.discover_clue("lista_invitados")
	await game.go_to("plaza", "desde_mansion")
	await game.go_to("mansion", "desde_plaza")
	var found := false
	for child in game.current_location.get_children():
		if child is ClueObject and (child as ClueObject).clue_id == "lista_invitados":
			found = true
			check(not (child as ClueObject).wants_attention(), "una pista ya registrada no reclama atención")
	check(found, "el objeto sigue en la escena")
	check_equal(GameState.clues.count("lista_invitados"), 1, "la pista persiste entre escenarios")
	game.queue_free()
	await get_tree().process_frame


func test_new_game_starts_at_the_station() -> void:
	var game := await make_game()
	check_equal(game.current_location.location_id, "estacion", "la historia empieza en el andén")
	check_equal(GameClock.day, 1, "día uno")
	game.queue_free()
	await get_tree().process_frame


func test_pause_freezes_and_resumes() -> void:
	var game := await make_game()
	var pause: PauseMenu = game.get_node("PauseMenu")
	pause.open()
	check(get_tree().paused, "la pausa detiene el juego")
	check(GameState.is_player_locked(), "y bloquea al jugador")
	pause.close()
	check(not get_tree().paused, "continuar reanuda")
	check(not GameState.is_player_locked(), "y devuelve el control")
	game.queue_free()
	await get_tree().process_frame


func test_menu_offers_continue_only_with_a_save() -> void:
	var scene: PackedScene = load("res://scenes/main/main_menu.tscn")
	var empty_menu := scene.instantiate()
	add_child(empty_menu)
	await get_tree().process_frame
	check(empty_menu.get_node("%Continue").disabled, "sin partida, Continuar está desactivado")
	empty_menu.queue_free()
	await get_tree().process_frame
	GameState.location_id = "plaza"
	GameClock.day = 2
	await save_and_wait("manual_3")
	var menu := scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	var continue_button: MenuOptionButton = menu.get_node("%Continue")
	check(not continue_button.disabled, "con partida, Continuar está activo")
	check(continue_button.detail_text.contains("Día 2"), "muestra el progreso guardado")
	menu.queue_free()
	await get_tree().process_frame


func test_volume_setting_reaches_the_audio_bus() -> void:
	var original: float = Settings.volumes["Musica"]
	Settings.set_volume("Musica", 0.25)
	var index := AudioServer.get_bus_index("Musica")
	check(index >= 0, "el canal de música existe")
	check(is_equal_approx(AudioServer.get_bus_volume_db(index), linear_to_db(0.25)), "el volumen se aplica")
	Settings.set_volume("Musica", 0.0)
	check(AudioServer.is_bus_mute(index), "a cero se silencia")
	Settings.set_volume("Musica", original)


func test_case_summary_reports_real_progress() -> void:
	var game := await make_game()
	Investigation.discover_clue("reloj_despacho")
	GameState.accusation_attempts = 3
	var closed: CaseClosedUi = game.get_node("CaseClosedUi")
	var summary := closed.build_summary()
	check(summary.contains("Pistas halladas: 1 de %d" % GameData.clues.size()), "cuenta las pistas reales")
	check(summary.contains("Intentos de acusación: 3"), "cuenta los intentos")
	game.queue_free()
	await get_tree().process_frame
