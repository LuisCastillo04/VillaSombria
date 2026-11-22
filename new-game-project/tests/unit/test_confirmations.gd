extends TestCase
## Confirmaciones configurables con la escena de juego real: dejar pasar una hora pregunta antes si
## el jugador lo tiene activado (y no pregunta si no), con la tecla que tenga asignada la acción, sin
## que el detective se mueva ni se abra otra pantalla; y las confirmaciones críticas (eliminar o
## sobrescribir una partida, mantener un cambio de pantalla) se hacen siempre.

var game: Game
var _notices: Array[String] = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	TestCase.reset_test_settings()
	game = await make_game()
	EventBus.notification_requested.connect(_on_notification)
	_notices.clear()


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_notification)
	if ConfirmDialog.is_open():
		ConfirmDialog.cancel()
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	TestCase.reset_test_settings()
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()


func _on_notification(title: String, _text: String, _kind: String) -> void:
	_notices.append(title)


## Una pulsación de una acción, tal como llega del teclado o del mando.
func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_physics_frames(2)


func _press_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_physics_frames(2)


func test_waiting_asks_first_when_confirmations_are_on() -> void:
	check(ConfirmDialog.confirmations_enabled(), "por defecto se pregunta")
	GameClock.minutes = 10 * 60
	await _press("wait_time")
	check(ConfirmDialog.is_open(), "la tecla de esperar abre la pregunta")
	check(ConfirmDialog.get_message_text().begins_with("¿Quieres dejar pasar una hora?"), "con la pregunta pedida")
	check(ConfirmDialog.get_message_text().contains("10:00") and ConfirmDialog.get_message_text().contains("11:00"), "y la hora de ahora y la de después")
	check_equal(ConfirmDialog.get_confirm_button().text, "Confirmar", "con «Confirmar»")
	check_equal(ConfirmDialog.get_cancel_button().text, "Cancelar", "y «Cancelar»")
	check_equal(GameClock.minutes, 10 * 60, "el tiempo no pasa todavía")
	check(GameState.is_player_locked(), "el detective espera la respuesta")
	check(get_viewport().gui_get_focus_owner() == ConfirmDialog.get_confirm_button(), "el foco está en «Confirmar»")
	await _press("ui_accept")
	check(not ConfirmDialog.is_open(), "aceptar (Intro o el botón del mando) contesta")
	check_equal(GameClock.minutes, 11 * 60, "y pasa una hora")
	check(_notices.has("Pasa el tiempo"), "con su aviso de siempre")
	check(not GameState.is_player_locked(), "el detective recupera el control")


func test_cancelling_keeps_the_time_and_opens_nothing() -> void:
	var pause: PauseMenu = game.get_node("PauseMenu")
	GameClock.minutes = 12 * 60
	await _press("wait_time")
	ConfirmDialog.get_cancel_button().pressed.emit()
	await wait_physics_frames(2)
	check_equal(GameClock.minutes, 12 * 60, "«Cancelar» no deja pasar el tiempo")
	check(not GameState.is_player_locked(), "y devuelve el control")
	await _press("wait_time")
	await _press("ui_cancel")
	check(not ConfirmDialog.is_open(), "Escape (o cancelar en el mando) también cancela")
	check(not pause.is_open, "sin abrir la pausa")
	check_equal(GameClock.minutes, 12 * 60, "y sin que pase el tiempo")
	check(_notices.is_empty(), "no hay aviso de tiempo")


func test_only_one_question_at_a_time() -> void:
	GameClock.minutes = 9 * 60
	await _press("wait_time")
	await _press("wait_time")
	await _press("open_journal")
	check(ConfirmDialog.is_open(), "sigue la misma pregunta")
	check(not (game.get_node("JournalUi") as JournalUi).is_open, "mientras tanto no se abre el expediente")
	ConfirmDialog.confirm()
	await wait_physics_frames(2)
	check_equal(GameClock.minutes, 10 * 60, "y al confirmar pasa una sola hora")


func test_waiting_is_direct_when_confirmations_are_off() -> void:
	Settings.set_value("jugabilidad/confirmaciones", false)
	GameClock.minutes = 14 * 60
	await _press("wait_time")
	check(not ConfirmDialog.is_open(), "no se pregunta nada")
	check_equal(GameClock.minutes, 15 * 60, "la hora pasa en el acto, como antes")
	check(_notices.has("Pasa el tiempo"), "con su aviso")


func test_the_reassigned_key_is_respected() -> void:
	var original := InputMap.action_get_events("wait_time")
	InputMap.action_erase_events("wait_time")
	var other := InputEventKey.new()
	other.physical_keycode = KEY_H
	InputMap.action_add_event("wait_time", other)
	await _press_key(KEY_T)
	check(not ConfirmDialog.is_open(), "la tecla de antes ya no hace nada")
	await _press_key(KEY_H)
	check(ConfirmDialog.is_open(), "la tecla asignada ahora abre la pregunta")
	ConfirmDialog.cancel()
	InputMap.action_erase_events("wait_time")
	for event in original:
		InputMap.action_add_event("wait_time", event)


func test_at_the_end_of_the_day_there_is_nothing_to_confirm() -> void:
	GameClock.minutes = GameClock.DAY_LIMIT
	await _press("wait_time")
	check(not ConfirmDialog.is_open(), "no se pregunta")
	check(_notices.has("Es muy tarde"), "se avisa de que hay que descansar, como antes")


func test_critical_confirmations_do_not_depend_on_the_setting() -> void:
	Settings.set_value("jugabilidad/confirmaciones", false)
	check(await ConfirmDialog.ask_optional("PRUEBA", "¿Opcional?"), "una pregunta opcional se contesta sola")
	check(not ConfirmDialog.is_open(), "sin mostrarse")
	var pause: PauseMenu = game.get_node("PauseMenu")
	var slots: SaveSlotsMenu = pause.get_node("Root/SaveSlotsMenu")
	pause.open()
	(pause.get_node("Root/Center/Panel/Box/Save") as Button).pressed.emit()
	slots.select_slot("manual_1")
	slots.get_action_button().pressed.emit()
	await SaveSystem.save_finished
	slots.select_slot("manual_1")
	slots.get_action_button().pressed.emit()
	check(slots.is_confirming(), "sobrescribir una partida sigue preguntando")
	slots.get_confirm_cancel().pressed.emit()
	slots.get_delete_button().pressed.emit()
	check(slots.is_confirming(), "y eliminarla también")
	slots.get_confirm_cancel().pressed.emit()
	check_equal(SaveSystem.get_slot_info("manual_1")["status"], SaveFormat.Status.OK, "la partida sigue ahí")
	slots.cancel()
	pause.close()
	Settings.request_display_change("sin_bordes", Vector2i(1280, 720))
	await get_tree().process_frame
	check(ConfirmDialog.is_open(), "mantener un cambio de pantalla también pregunta")
	ConfirmDialog.cancel()
	await get_tree().process_frame
