extends TestCase
## Indicador animado de guardado: aparece, confirma sólo lo real y desaparece.


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	GameState.location_id = "plaza"
	SaveSystem.begin_session(self)
	SaveIndicator.min_saving_seconds = 0.1
	SaveIndicator.saved_seconds = 0.2
	SaveIndicator.failed_seconds = 0.2
	SaveIndicator.fade_seconds = 0.1
	# Un guardado de las pruebas anteriores puede seguir en pantalla.
	for frame in 300:
		if not SaveIndicator.is_showing():
			break
		await get_tree().process_frame


func after_each() -> void:
	await _wait(0.6)
	SaveIndicator.min_saving_seconds = 0.6
	SaveIndicator.saved_seconds = 1.6
	SaveIndicator.failed_seconds = 4.0
	SaveIndicator.fade_seconds = 0.6
	SaveSystem.end_session(self)
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func test_indicator_follows_a_successful_save() -> void:
	check(not SaveIndicator.is_showing(), "oculto antes de guardar")
	check(SaveSystem.save_to_slot("manual_1")["ok"], "empieza el guardado")
	check(SaveIndicator.is_showing(), "aparece al empezar")
	check_equal(SaveIndicator.state, SaveIndicator.State.SAVING, "en estado de guardado")
	check_equal(SaveIndicator.get_title(), "Guardando…", "con su texto")
	await SaveSystem.save_finished
	await _wait(0.2)
	check_equal(SaveIndicator.state, SaveIndicator.State.SAVED, "confirma al terminar")
	check_equal(SaveIndicator.get_title(), "Partida guardada", "con la confirmación")
	await _wait(0.5)
	check(not SaveIndicator.is_showing(), "y desaparece")
	check_equal(SaveIndicator.state, SaveIndicator.State.HIDDEN, "sin quedarse a medias")


func test_failed_write_is_never_confirmed() -> void:
	# Una carpeta con el nombre del temporal impide escribir de verdad.
	var blocker := SaveSystem.get_slot_path("manual_2") + SaveFile.TEMP_SUFFIX
	DirAccess.make_dir_recursive_absolute(blocker)
	var seen_states: Array = []
	check(SaveSystem.save_to_slot("manual_2")["ok"], "el guardado empieza")
	var outcome: Array = await SaveSystem.save_finished
	for step in 6:
		seen_states.append(SaveIndicator.state)
		await _wait(0.05)
	DirAccess.remove_absolute(blocker)
	check(not outcome[1], "la escritura falla")
	check(not (outcome[2] as String).is_empty(), "con un mensaje")
	check(seen_states.has(SaveIndicator.State.FAILED), "el indicador muestra el fallo")
	check(not seen_states.has(SaveIndicator.State.SAVED), "y nunca una confirmación falsa")
	check_equal(SaveSystem.get_slot_info("manual_2")["status"], SaveFormat.Status.EMPTY, "no queda ningún archivo")


func test_a_new_save_restarts_the_indicator() -> void:
	SaveSystem.save_to_slot("manual_1")
	await SaveSystem.save_finished
	await _wait(0.15)
	check_equal(SaveIndicator.state, SaveIndicator.State.SAVED, "primer guardado confirmado")
	SaveSystem.save_to_slot("manual_2")
	check_equal(SaveIndicator.state, SaveIndicator.State.SAVING, "el segundo vuelve a «Guardando…»")
	await SaveSystem.save_finished


func test_there_is_a_single_indicator() -> void:
	SaveSystem.end_session(self)
	var game := await make_game()
	var found := get_tree().root.find_children("SaveIndicator", "CanvasLayer", true, false)
	check_equal(found.size(), 1, "una sola instancia, la global")
	game.queue_free()
	await get_tree().process_frame
