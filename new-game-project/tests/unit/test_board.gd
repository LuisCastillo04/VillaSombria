extends TestCase
## Tablero de deducción y acusación manejados a través de su interfaz real.

var game: Game
var board: BoardUi
var accusation: AccusationUi


func before_each() -> void:
	game = await make_game()
	board = game.get_node("BoardUi")
	accusation = game.get_node("AccusationUi")


func after_each() -> void:
	DialogueManager.close()
	game.queue_free()
	await get_tree().process_frame
	GameState.reset()
	GameClock.reset()


func _press_card(item_id: String) -> void:
	(board._cards[item_id] as Button).button_pressed = true


func test_cards_show_only_what_the_player_knows() -> void:
	Investigation.discover_clue("reloj_despacho")
	board.open()
	await wait_physics_frames(2)
	check(board._cards.has("reloj_despacho"), "las pistas halladas aparecen")
	check(not board._cards.has("copia_telegrama"), "las no halladas no aparecen")
	check(GameState.is_player_locked(), "el tablero bloquea el movimiento")
	board.close()
	check(not GameState.is_player_locked(), "cerrarlo devuelve el control")


func test_linking_real_contradiction_through_the_ui() -> void:
	Investigation.discover_clue("reloj_despacho")
	Investigation.discover_clue("copia_telegrama")
	board.open()
	await wait_physics_frames(2)
	check(board._link_button.disabled, "sin selección no se puede relacionar")
	_press_card("reloj_despacho")
	_press_card("copia_telegrama")
	check(not board._link_button.disabled, "con dos elementos se puede relacionar")
	var before := GameClock.minutes
	board._link_button.pressed.emit()
	await wait_physics_frames(2)
	check(GameState.deductions.has("d_hora_falsa"), "la relación real se registra")
	check(board._cards.has("d_hora_falsa"), "la deducción se convierte en tarjeta utilizable")
	check(board._result.text.contains("El reloj miente"), "se muestra la conclusión")
	check(GameClock.minutes > before, "deducir consume tiempo")


func test_wrong_link_gives_no_deduction() -> void:
	Investigation.discover_clue("foto_clara")
	Investigation.discover_clue("carta_amor")
	board.open()
	await wait_physics_frames(2)
	_press_card("foto_clara")
	_press_card("carta_amor")
	board._link_button.pressed.emit()
	check(GameState.deductions.is_empty(), "sin relación no se registra nada")
	check(board._result.text.contains("ninguna relación"), "el tablero lo comunica")


func test_third_selection_replaces_the_oldest() -> void:
	for clue_id: String in ["foto_clara", "carta_amor", "reloj_despacho"]:
		Investigation.discover_clue(clue_id)
	board.open()
	await wait_physics_frames(2)
	_press_card("foto_clara")
	_press_card("carta_amor")
	_press_card("reloj_despacho")
	check_equal(board._selection.size(), 2, "sólo se comparan dos elementos")
	check(not board._selection.has("foto_clara"), "se descarta el más antiguo")
	check(not (board._cards["foto_clara"] as Button).button_pressed, "su tarjeta se desmarca")


func test_hypothesis_is_saved() -> void:
	board.open()
	await wait_physics_frames(2)
	board._open_hypothesis("marcos")
	board._note_status.select(2)
	board._note_text.text = "Debe dinero y mintió."
	board._save_hypothesis()
	var saved: Dictionary = GameState.hypotheses["marcos"]
	check_equal(saved["status"], "principal", "estado guardado")
	check_equal(saved["note"], "Debe dinero y mintió.", "nota guardada")
	check(GameState.to_dict()["hypotheses"].has("marcos"), "las hipótesis forman parte de la partida")


func test_failed_accusation_allows_retry() -> void:
	Investigation.discover_clue("reloj_despacho")
	accusation.open()
	accusation._suspect.select(accusation._suspect_ids.find("marcos"))
	accusation._accuse.pressed.emit()
	check(accusation.is_open, "un error no cierra la acusación ni termina la partida")
	check(accusation._verdict.text.contains("pagaré"), "Ortega explica la refutación")
	check_equal(GameState.accusation_attempts, 1, "se cuenta el intento")
	accusation.close()
	check(not GameState.is_player_locked(), "se puede volver a investigar")


func test_correct_accusation_starts_confrontation() -> void:
	for item: String in ["transferencia", "informe_forense", "libro_bodega"]:
		Investigation.discover_clue(item)
	accusation.open()
	var titles := accusation._items.map(func(item: Dictionary) -> String: return item["id"])
	accusation._suspect.select(accusation._suspect_ids.find("anselmo"))
	accusation._motive.select(titles.find("transferencia"))
	accusation._opportunity.select(titles.find("libro_bodega"))
	accusation._means.select(titles.find("informe_forense"))
	accusation._accuse.pressed.emit()
	check(not accusation.is_open, "acertar cierra la acusación")
	check(DialogueManager.active, "empieza la confrontación")
