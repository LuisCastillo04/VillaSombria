extends TestCase
## Política de autoguardado: agrupación, momentos seguros, separación mínima y puntos de control.

var _finished: Array = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	_finished.clear()
	SaveSystem.autosave_enabled = true
	SaveSystem.autosave_delay = 0.05
	SaveSystem.autosave_min_interval = 0.0
	GameState.location_id = "plaza"
	SaveSystem.begin_session(self)
	SaveSystem.save_finished.connect(_on_save_finished)


func after_each() -> void:
	SaveSystem.save_finished.disconnect(_on_save_finished)
	SaveSystem.end_session(self)
	SaveSystem.autosave_enabled = false
	SaveSystem.autosave_delay = 1.5
	SaveSystem.autosave_min_interval = 30.0
	DialogueManager.close()
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _on_save_finished(slot_id: String, ok: bool, _message: String) -> void:
	_finished.append({"slot": slot_id, "ok": ok})


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _last_reason() -> String:
	if _finished.is_empty():
		return ""
	return SaveSystem.get_slot_info(_finished[-1]["slot"])["summary"].get("reason", "")


func test_bursts_of_events_produce_a_single_save() -> void:
	for clue_id: String in ["reloj_despacho", "foto_clara", "lista_invitados"]:
		Investigation.discover_clue(clue_id)
	await _wait(0.4)
	check_equal(_finished.size(), 1, "una sola escritura para tres pistas seguidas")
	check(_finished[0]["ok"] and SaveSystem.is_auto_slot(_finished[0]["slot"]), "en una ranura automática")
	check_equal(_last_reason(), "pista", "con su motivo")


func test_nothing_is_written_without_progress() -> void:
	SaveSystem.request_autosave("lugar")
	await _wait(0.3)
	check(_finished.is_empty(), "sin cambios no se guarda")
	check(not SaveSystem.has_pending_autosave(), "la petición se descarta")


func test_waits_until_the_scene_ends() -> void:
	DialogueManager.play_scene("intro")
	Investigation.discover_clue("reloj_despacho")
	await _wait(0.3)
	check(_finished.is_empty(), "no se guarda durante una escena")
	check(SaveSystem.has_pending_autosave(), "la petición sigue pendiente")
	DialogueManager.close()
	await _wait(0.3)
	check_equal(_finished.size(), 1, "se guarda al terminar la escena")
	check_equal(_last_reason(), "escena", "con el motivo de la escena")


func test_waits_while_a_panel_is_open() -> void:
	GameState.lock_player("tablero")
	Investigation.discover_clue("reloj_despacho")
	await _wait(0.3)
	check(_finished.is_empty(), "no con el tablero abierto")
	GameState.unlock_player("tablero")
	await _wait(SaveSystem.AUTOSAVE_RETRY_SECONDS + 0.3)
	check_equal(_finished.size(), 1, "se guarda al cerrarlo")


func test_minimum_interval_defers_without_losing_the_request() -> void:
	SaveSystem.autosave_min_interval = 0.6
	Investigation.discover_clue("reloj_despacho")
	await _wait(0.3)
	check(_finished.is_empty(), "todavía no ha pasado la separación mínima")
	await _wait(0.6)
	check_equal(_finished.size(), 1, "pasado el intervalo se guarda")


func test_new_day_is_a_checkpoint() -> void:
	SaveSystem.autosave_min_interval = 60.0
	GameClock.start_next_day()
	await _wait(0.3)
	check_equal(_finished.size(), 1, "el nuevo día no espera la separación mínima")
	check_equal(_last_reason(), "nuevo_dia", "motivo de punto de control")


func test_ending_the_session_cancels_pending_requests() -> void:
	Investigation.discover_clue("reloj_despacho")
	SaveSystem.end_session(self)
	await _wait(0.3)
	check(_finished.is_empty(), "sin partida en curso no se guarda")
	check(not SaveSystem.has_pending_autosave(), "y la petición se olvida")


func test_changing_location_autosaves_after_the_transition() -> void:
	SaveSystem.end_session(self)
	var game := await make_game()
	await game.go_to("plaza", "desde_estacion")
	await _wait(SaveSystem.AUTOSAVE_RETRY_SECONDS + 0.4)
	check_equal(_finished.size(), 1, "un autoguardado al entrar en la plaza")
	check_equal(_last_reason(), "lugar", "por el cambio de lugar")
	var state: Dictionary = SaveSystem.read_slot(_finished[0]["slot"])["document"]["sections"]["state"]
	check_equal(state["location_id"], "plaza", "con el lugar nuevo")
	game.queue_free()
	await get_tree().process_frame
