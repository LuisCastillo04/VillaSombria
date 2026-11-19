extends TestCase
## Ranura activa: única fuente de verdad sobre a qué ranura pertenece la partida en curso.


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	GameState.location_id = "plaza"
	SaveSystem.begin_session(self)


func after_each() -> void:
	SaveSystem.end_session(self)
	SaveSystem.take_pending_load()
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


## Simula cerrar y abrir el juego: el gestor vuelve a leer su carpeta.
func _reopen_storage() -> void:
	SaveSystem.use_storage(SaveSystem.get_storage_dir())


func test_new_game_has_no_active_slot() -> void:
	check(not SaveSystem.has_active_slot(), "una partida nueva no pertenece a ninguna ranura")


func test_manual_save_makes_the_slot_active() -> void:
	await save_and_wait("manual_2")
	check_equal(SaveSystem.get_active_slot(), "manual_2", "la ranura guardada pasa a ser la activa")
	await save_and_wait("manual_4")
	check_equal(SaveSystem.get_active_slot(), "manual_4", "el último guardado manual manda")


func test_active_slot_survives_a_restart() -> void:
	await save_and_wait("manual_3")
	SaveSystem.end_session(self)
	_reopen_storage()
	check_equal(SaveSystem.get_active_slot(), "manual_3", "se recuerda entre sesiones")
	check_equal(SaveSystem.get_continue_slot(), "manual_3", "«Continuar» la retoma")


func test_loading_makes_the_slot_active() -> void:
	await save_and_wait("manual_1")
	await save_and_wait("manual_5")
	check(SaveSystem.request_load("manual_1")["ok"], "se prepara la carga")
	var document := SaveSystem.take_pending_load()
	SaveSystem.begin_session(self, document)
	check_equal(SaveSystem.get_active_slot(), "manual_1", "la ranura cargada pasa a ser la activa")


func test_loading_slot_three_sends_autosaves_there() -> void:
	GameClock.minutes = 600
	for slot_id: String in ["manual_1", "manual_3", "manual_5"]:
		await save_and_wait(slot_id)
	SaveSystem.request_load("manual_3")
	SaveSystem.begin_session(self, SaveSystem.take_pending_load())
	GameClock.minutes = 900
	check(await autosave_and_wait("pista"), "el autoguardado escribe")
	for slot_id: String in ["manual_1", "manual_3", "manual_5"]:
		var minutes := int(SaveSystem.read_slot(slot_id)["document"]["sections"]["clock"]["minutes"])
		check_equal(minutes, 900 if slot_id == "manual_3" else 600, "%s tras el autoguardado" % slot_id)


func test_saves_from_before_the_fingerprint_keep_autosaving() -> void:
	await save_and_wait("manual_2")
	var old: Dictionary = SaveSystem.read_slot("manual_2")["document"]
	(old["meta"] as Dictionary).erase("save_id")
	write_slot_file("manual_2", SaveFormat.to_text(old))
	SaveSystem.request_load("manual_2")
	SaveSystem.begin_session(self, SaveSystem.take_pending_load())
	check(await autosave_and_wait("lugar"), "una partida sin huella también admite autoguardado")
	check_equal(SaveSystem.get_active_slot(), "manual_2", "y sigue siendo la activa")


func test_continue_prefers_the_active_slot_over_the_newest() -> void:
	await save_and_wait("manual_1")
	await save_and_wait("manual_2")
	SaveSystem.request_load("manual_1")
	SaveSystem.begin_session(self, SaveSystem.take_pending_load())
	check_equal(SaveSystem.get_continue_slot(), "manual_1", "se continúa la partida que se estaba jugando")


func test_deleting_the_active_slot_clears_it() -> void:
	await save_and_wait("manual_2")
	SaveSystem.delete_slot("manual_2")
	check(not SaveSystem.has_active_slot(), "sin ranura activa")
	_reopen_storage()
	check(not SaveSystem.has_active_slot(), "tampoco en la sesión siguiente")


func test_starting_a_new_game_releases_the_previous_slot() -> void:
	await save_and_wait("manual_2")
	SaveSystem.begin_session(self)
	check(not SaveSystem.has_active_slot(), "la partida nueva no hereda la ranura anterior")


func test_selecting_or_reading_slots_does_not_change_the_active_one() -> void:
	await save_and_wait("manual_2")
	await save_and_wait("manual_3")
	SaveSystem.read_slot("manual_2")
	SaveSystem.get_slot_info("manual_5")
	SaveSystem.list_slots()
	check_equal(SaveSystem.get_active_slot(), "manual_3", "leer ranuras no cambia la activa")
