extends TestCase
## El tablero de deducción rediseñado, con la escena de juego real: se abre y se cierra con las teclas
## del InputMap; sus fichas de sospechosos y de pruebas salen de los datos y del estado de la partida
## (y nada que el jugador no haya descubierto); las hipótesis se anotan, se conservan como borrador si
## no se guardan y se ven en el expediente; la comparación usa `Investigation.try_link` y cuenta cada
## resultado; los hilos sólo unen deducciones registradas; se maneja con teclado y ratón; cabe en
## pantallas de distintas proporciones; y sobrevive a guardar y cargar.

const OPEN_SECONDS := BoardStyle.OPEN_SECONDS + 0.1
const CLOSE_SECONDS := BoardStyle.CLOSE_SECONDS + 0.1

var game: Game
var board: BoardUi


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()
	game = await make_game()
	board = game.get_node("BoardUi")


func after_each() -> void:
	await _free_game()
	SaveSystem.take_pending_load()
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()


func _free_game() -> void:
	if game == null:
		return
	if DialogueManager.active:
		DialogueManager.close()
	game.queue_free()
	game = null
	board = null
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Una pulsación tal como llega del teclado o del mando.
func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_physics_frames(2)


func _click(control: Control) -> void:
	var spot := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		get_viewport().push_input(click, true)
	await wait_physics_frames(2)


func _open() -> void:
	board.open()
	await _wait(OPEN_SECONDS)


func _card(item_id: String) -> BoardEvidenceCard:
	return board.get_investigation_canvas().get_card(item_id)


func _suspect(suspect_id: String) -> BoardSuspectCard:
	return board.get_suspect_row().get_card(suspect_id)


# --- Sospechosos ---

func test_suspect_cards_come_from_the_case_and_its_hypotheses() -> void:
	Investigation.set_hypothesis("irene", "principal", "")
	Investigation.set_hypothesis("anselmo", "descartado", "")
	Investigation.set_hypothesis("marcos", "sospechoso", "")
	await _open()
	var row := board.get_suspect_row()
	check_equal(Array(row.get_suspect_ids()), Array(GameData.get_suspects()), "una ficha por sospechoso del caso, en su orden")
	check_equal(_suspect("lucia").get_name_text(), GameData.characters["lucia"]["short"], "con el nombre corto")
	check_equal(_suspect("lucia").get_status_text(), "Sin valorar", "sin anotar, sin valorar")
	check_equal(_suspect("irene").get_status_text(), "Principal sospechoso", "la valoración guardada")
	check_equal(_suspect("irene").get_status_color(), BoardStyle.BURGUNDY, "el principal sospechoso, en burdeos")
	check_equal(_suspect("anselmo").get_status_text(), "Descartado", "el descartado se sigue leyendo")
	check_equal(_suspect("marcos").get_status_text(), "Sospechoso", "y el sospechoso")


func test_the_row_admits_more_suspects() -> void:
	var added: Array[String] = []
	for character_id: String in GameData.characters:
		if not bool(GameData.characters[character_id].get("suspect", false)) and character_id != "detective":
			GameData.characters[character_id]["suspect"] = true
			added.append(character_id)
	await _open()
	var row := board.get_suspect_row()
	await wait_physics_frames(3)
	check_equal(row.get_cards().size(), GameData.get_suspects().size(), "cada sospechoso nuevo tiene su ficha")
	for card in row.get_cards():
		check(card.size.x >= BoardStyle.SUSPECT_CARD_MIN_WIDTH - 0.5, "las fichas no se aplastan")
	check(row.get_h_scroll_bar().visible, "si no caben, la fila se desplaza")
	for character_id in added:
		GameData.characters[character_id].erase("suspect")
	board.close()


func test_pressing_a_suspect_opens_its_hypothesis_without_changing_it() -> void:
	Investigation.set_hypothesis("lucia", "sospechoso", "Mintió sobre la escalera.")
	await _open()
	await _click(_suspect("lucia"))
	var editor := board.get_editor()
	check(board.is_editing(), "pulsar un sospechoso abre su hipótesis")
	check_equal(editor.get_title(), "Hipótesis sobre Lucía Ferrer", "con su nombre completo")
	check_equal(editor.get_status_option().get_item_text(editor.get_status_option().selected), "Sospechoso", "su valoración")
	check_equal(editor.get_text_edit().text, "Mintió sobre la escalera.", "y su nota")
	check(_suspect("lucia").selected, "su ficha se ilumina")
	check(not _suspect("elena").selected, "y sólo la suya")
	check_equal(Investigation.get_hypothesis("lucia")["status"], "sospechoso", "elegirla no cambia la valoración")
	check(board.get_board().get_canvas_rect().encloses(Rect2(editor.position, editor.size)), "el panel se abre sobre el corcho")
	await _click(editor.get_close_button())
	check(not board.is_editing(), "la cruz cierra el panel")
	check(board.is_open, "sin cerrar el tablero")
	check(not _suspect("lucia").selected, "y la ficha se apaga")


func test_saving_a_hypothesis_updates_the_card_and_the_case_file() -> void:
	await _open()
	board.open_hypothesis("marcos")
	var editor := board.get_editor()
	editor.get_status_option().select(Investigation.HYPOTHESIS_STATUSES.find("principal"))
	editor.get_text_edit().text = "Debe dinero en el café."
	await _click(editor.get_save_button())
	check_equal(Investigation.get_hypothesis("marcos"), {"status": "principal", "note": "Debe dinero en el café."}, "se anota en la partida")
	check(not board.is_editing(), "guardar cierra el panel")
	check_equal(_suspect("marcos").get_status_text(), "Principal sospechoso", "la ficha muestra la valoración nueva")
	check(_suspect("marcos").flash > 0.0, "con un destello")
	var toast := board.get_toast()
	check(toast != null and toast.get_title() == "Hipótesis guardada", "y un aviso breve")
	board.close()
	await _wait(CLOSE_SECONDS)
	var journal: JournalUi = game.get_node("JournalUi")
	journal.open(JournalUi.Tab.SUSPECTS)
	var section := journal.get_section(JournalUi.Tab.SUSPECTS) as JournalSuspectsSection
	section.list.select("marcos")
	await wait_physics_frames(2)
	var texts := PackedStringArray()
	for label in section.detail.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	var joined := " ".join(texts)
	check(joined.contains("Principal sospechoso") and joined.contains("Debe dinero en el café."), "el expediente enseña lo anotado")
	journal.close()


func test_unsaved_changes_are_kept_as_a_draft() -> void:
	Investigation.set_hypothesis("elena", "", "Nota guardada.")
	await _open()
	board.open_hypothesis("elena")
	var editor := board.get_editor()
	editor.get_text_edit().text = "Nota a medias"
	editor.get_status_option().select(Investigation.HYPOTHESIS_STATUSES.find("sospechoso"))
	await _press("open_board")
	check(board.is_open, "con el panel abierto, la B no cierra el tablero")
	await _press("pause")
	check(not board.is_editing(), "Esc cierra el panel")
	check(board.is_open, "pero no el tablero")
	check(board.has_draft("elena"), "lo escrito queda como borrador")
	check(_suspect("elena").has_draft, "y la ficha lo recuerda")
	check_equal(Investigation.get_hypothesis("elena")["note"], "Nota guardada.", "la partida no cambia sin guardar")
	board.open_hypothesis("elena")
	check_equal(editor.get_text_edit().text, "Nota a medias", "al volver, el borrador sigue ahí")
	check(editor.is_draft_shown(), "y se avisa de que no está guardado")
	await _click(editor.get_discard_button())
	check_equal(editor.get_text_edit().text, "Nota guardada.", "descartar vuelve a lo guardado")
	check(not board.has_draft("elena"), "y olvida el borrador")
	editor.get_text_edit().text = "Otra idea"
	board.open_hypothesis("lucia")
	check(board.has_draft("elena"), "cambiar de sospechoso también conserva el borrador")
	board.close()
	await _wait(CLOSE_SECONDS)
	await _open()
	board.open_hypothesis("elena")
	check_equal(editor.get_text_edit().text, "Otra idea", "y cerrar el tablero")


func test_notes_are_limited_to_what_a_save_file_accepts() -> void:
	await _open()
	board.open_hypothesis("irene")
	var text := board.get_editor().get_text_edit()
	text.text = "x".repeat(SaveFormat.MAX_NOTE_LENGTH + 120)
	text.text_changed.emit()
	check_equal(text.text.length(), SaveFormat.MAX_NOTE_LENGTH, "la nota no pasa del máximo")
	check(board.get_editor().get_counter_text().begins_with("%d /" % SaveFormat.MAX_NOTE_LENGTH), "y el contador lo dice")


func test_ctrl_enter_saves_the_hypothesis() -> void:
	await _open()
	board.open_hypothesis("anselmo")
	board.get_editor().get_text_edit().text = "Coartada demasiado limpia."
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.ctrl_pressed = true
	key.pressed = true
	get_viewport().push_input(key)
	await wait_physics_frames(2)
	check_equal(Investigation.get_hypothesis("anselmo")["note"], "Coartada demasiado limpia.", "Ctrl + Intro guarda")
	check(not board.is_editing(), "y cierra el panel")


# --- Pruebas en el corcho ---

func test_the_cork_shows_only_what_the_player_found_in_groups() -> void:
	for item_id: String in ["reloj_despacho", "lista_invitados"]:
		Investigation.discover_clue(item_id)
	Investigation.record_testimony("t_anselmo_brindis")
	await _open()
	var canvas := board.get_investigation_canvas()
	check_equal(canvas.get_item_ids(), PackedStringArray(["reloj_despacho", "lista_invitados", "t_anselmo_brindis"]), "sólo lo descubierto, en orden de hallazgo")
	check_equal(canvas.get_group_titles(), PackedStringArray(["PRUEBAS · 2", "DECLARACIONES · 1"]), "agrupado y sin grupos vacíos")
	check_equal(_card("reloj_despacho").get_tag(), "PRUEBA", "cada ficha dice su tipo")
	check_equal(_card("reloj_despacho").get_title(), GameData.clues["reloj_despacho"]["name"], "y su título")
	check_equal(_card("t_anselmo_brindis").get_tag(), "DECLARACIÓN", "las declaraciones también")
	check_equal(_card("t_anselmo_brindis").get_subtitle(), GameData.get_character_name("anselmo"), "con quién declara")
	check(canvas.get_placeholders().is_empty(), "con tres fichas no hacen falta huecos")
	check(not canvas.is_empty_shown(), "ni el aviso de tablero vacío")
	for card in canvas.get_cards():
		check(card.is_title_complete() or not card.tooltip_text.is_empty(), "un título recortado se lee entero al señalarlo")


func test_free_slots_are_only_an_indicator() -> void:
	await _open()
	var canvas := board.get_investigation_canvas()
	check_equal(canvas.get_placeholders().size(), BoardCanvas.PLACEHOLDER_MIN_CELLS, "sin pruebas, sólo huecos libres")
	check(canvas.is_empty_shown(), "y un aviso con lo que hay que hacer")
	board.close()
	await _wait(CLOSE_SECONDS)
	Investigation.discover_clue("carta_valdes")
	await _open()
	check_equal(canvas.get_placeholders().size(), BoardCanvas.PLACEHOLDER_MIN_CELLS - 1, "cada prueba ocupa un hueco")
	check(not canvas.is_empty_shown(), "y el aviso se retira")
	check_equal(canvas.get_connections().get_decorative_count(), 1, "el bramante decorativo sólo une huecos libres")
	check(canvas.get_connections().get_relations().is_empty(), "y no hay ninguna relación")
	for rect in canvas.get_placeholders():
		check(not _card("carta_valdes").get_rect().intersects(rect), "los huecos no tapan las fichas")


func test_threads_join_only_registered_deductions() -> void:
	for item_id: String in ["reloj_despacho", "copia_telegrama", "llave_reloj"]:
		Investigation.discover_clue(item_id)
	await _open()
	var connections := board.get_investigation_canvas().get_connections()
	check(connections.get_relations().is_empty(), "sin deducir nada, no hay hilos aunque las pruebas encajen")
	board.select_item("reloj_despacho")
	board.select_item("copia_telegrama")
	check_equal(connections.get_pending(), ["reloj_despacho", "copia_telegrama"] as Array[String], "lo que se compara se une a trazos")
	board.link_selected()
	await wait_physics_frames(2)
	var ids := connections.get_relations().map(func(relation: Dictionary) -> String: return relation["id"])
	check_equal(ids, ["d_hora_falsa"], "la deducción registrada se une con hilo rojo")
	check(connections.get_pending().is_empty(), "y la comparación terminada ya no tiene hilo")
	board.select_item("reloj_despacho")
	check(connections.is_highlighted("d_hora_falsa"), "al elegir una de sus fichas, su hilo se aviva")
	check(_card("copia_telegrama").related, "y la otra ficha lo señala")
	check(not _card("llave_reloj").related, "las que no están relacionadas, no")
	board.close()
	await _wait(CLOSE_SECONDS)
	GameState.deductions.append("d_reloj_llave")
	GameState.clues.erase("llave_reloj")
	await _open()
	ids = connections.get_relations().map(func(relation: Dictionary) -> String: return relation["id"])
	check(not ids.has("d_reloj_llave"), "una deducción sin sus dos fichas a la vista no se dibuja")


# --- Comparación ---

func test_mouse_selection_fills_the_comparison() -> void:
	for item_id: String in ["foto_clara", "carta_amor", "reloj_despacho"]:
		Investigation.discover_clue(item_id)
	await _open()
	var comparison := board.get_comparison()
	check(comparison.get_link_button().disabled, "sin elegir nada, «Relacionar» está desactivado")
	check_equal(comparison.get_slot(1).get_title(), "Elemento 1: sin seleccionar", "y los huecos lo dicen")
	await _click(_card("foto_clara"))
	check_equal(board.get_selection(), ["foto_clara"] as Array[String], "pulsar una ficha la elige")
	check_equal(_card("foto_clara").slot, 1, "como elemento 1")
	check_equal(comparison.get_slot(1).get_title(), GameData.clues["foto_clara"]["name"], "el hueco 1 muestra su título")
	check_equal(comparison.get_slot(1).get_text(), GameData.clues["foto_clara"]["description"], "y su texto completo")
	check(comparison.get_slot(1).get_facts_text().contains(GameData.clues["foto_clara"]["where"]), "y dónde se halló")
	check_equal(comparison.get_feedback(), BoardComparisonPanel.Feedback.NEED_SECOND, "falta un elemento y se dice")
	check(comparison.get_link_button().disabled, "con uno solo no se puede relacionar")
	await _click(_card("carta_amor"))
	check_equal(_card("carta_amor").slot, 2, "la segunda es el elemento 2")
	check(not comparison.get_link_button().disabled, "con dos, sí")
	await _click(_card("reloj_despacho"))
	check_equal(board.get_selection(), ["carta_amor", "reloj_despacho"] as Array[String], "una tercera sustituye a la más antigua")
	check_equal(_card("foto_clara").slot, 0, "que se suelta")
	await _click(_card("carta_amor"))
	check_equal(board.get_selection(), ["reloj_despacho"] as Array[String], "pulsar una elegida la suelta")
	await _click(comparison.get_slot(1).get_remove_button())
	check(board.get_selection().is_empty(), "la cruz del hueco también")
	check(comparison.get_link_button().disabled, "y «Relacionar» vuelve a desactivarse")


func test_each_link_outcome_is_explained() -> void:
	for item_id: String in ["foto_clara", "carta_amor", "reloj_despacho", "copia_telegrama"]:
		Investigation.discover_clue(item_id)
	await _open()
	var comparison := board.get_comparison()
	board.select_item("foto_clara")
	board.select_item("carta_amor")
	var before := GameClock.minutes
	await _click(comparison.get_link_button())
	check_equal(comparison.get_feedback(), BoardComparisonPanel.Feedback.NONE, "sin relación")
	check(comparison.get_result_text().contains("ninguna relación"), "se dice sin desvelar cuál sería la buena")
	check(GameState.deductions.is_empty(), "y no se registra nada")
	check_equal(GameClock.minutes, before, "ni pasa el tiempo")
	board.select_item("reloj_despacho")
	board.select_item("copia_telegrama")
	await _click(comparison.get_link_button())
	check_equal(comparison.get_feedback(), BoardComparisonPanel.Feedback.NEW, "una deducción nueva")
	check(comparison.get_result_text().contains(GameData.deductions["d_hora_falsa"]["title"]), "con su conclusión")
	check(GameState.deductions.has("d_hora_falsa"), "registrada por la investigación")
	check_equal(GameClock.minutes, before + BoardUi.LINK_MINUTES, "lleva su tiempo")
	check(_card("d_hora_falsa") != null, "y se prende en el corcho")
	check_equal(get_viewport().gui_get_focus_owner(), _card("d_hora_falsa"), "con el foco, para seguir con el teclado")
	board.select_item("reloj_despacho")
	board.select_item("copia_telegrama")
	await _click(comparison.get_link_button())
	check_equal(comparison.get_feedback(), BoardComparisonPanel.Feedback.KNOWN, "repetirla dice que ya se estableció")
	check_equal(GameState.deductions.count("d_hora_falsa"), 1, "sin duplicarla")
	check_equal(GameClock.minutes, before + BoardUi.LINK_MINUTES, "ni gastar más tiempo")
	board.close()
	await _wait(CLOSE_SECONDS)
	var journal: JournalUi = game.get_node("JournalUi")
	journal.open(JournalUi.Tab.DEDUCTIONS)
	var section := journal.get_section(JournalUi.Tab.DEDUCTIONS) as JournalDeductionsSection
	check(section.list.get_entry_ids().has("d_hora_falsa"), "la deducción aparece en el expediente")
	journal.close()


# --- Teclado, apertura y cierre ---

func test_real_keys_open_and_close_the_board() -> void:
	await _press("open_board")
	check(board.is_open, "B abre el tablero")
	check(GameState.get_player_lock_reasons().has("tablero"), "y bloquea al detective")
	var key := InputLabels.keys_of("open_board")[0]
	check_equal(board.get_board().header.get_close_text(), "[%s] Cerrar" % key, "el encabezado dice la tecla real")
	await _wait(OPEN_SECONDS)
	await _press("open_board")
	check(not board.is_open, "B lo cierra")
	check(not GameState.is_player_locked(), "sin bloqueos residuales")
	await _wait(CLOSE_SECONDS)
	check(not (board.get_node("Root") as Control).visible, "y se oculta tras el fundido")
	await _press("open_board")
	await _wait(OPEN_SECONDS)
	await _press("pause")
	check(not board.is_open, "Esc también lo cierra")
	check(not (game.get_node("PauseMenu") as PauseMenu).is_open, "sin abrir la pausa")
	await _wait(CLOSE_SECONDS)
	await _press("open_board")
	await _wait(OPEN_SECONDS)
	await _click(board.get_board().header.get_close_button())
	check(not board.is_open, "y «[B] Cerrar» con el ratón")


func test_opening_and_closing_quickly_is_safe() -> void:
	Investigation.discover_clue("carta_valdes")
	for attempt in 4:
		board.open()
		board.close()
	board.open()
	await wait_physics_frames(2)
	check(board.is_open, "tras abrir y cerrar seguido, queda abierto")
	await _wait(OPEN_SECONDS)
	check(is_equal_approx((board.get_node("Root") as Control).modulate.a, 1.0), "del todo visible")
	check(is_equal_approx(board.get_board().scale.x, 1.0), "y a su tamaño")
	board.close()
	board.open()
	board.close()
	await _wait(CLOSE_SECONDS)
	check(not (board.get_node("Root") as Control).visible, "y cerrado al final, oculto")
	check(not GameState.is_player_locked(), "sin bloqueos")
	check(get_viewport().gui_get_focus_owner() == null, "ni foco retenido")


func test_keyboard_moves_between_cards_and_selects() -> void:
	for item_id: String in ["carta_valdes", "lista_invitados", "reloj_despacho"]:
		Investigation.discover_clue(item_id)
	await _open()
	check_equal(get_viewport().gui_get_focus_owner(), _card("carta_valdes"), "al abrir, el foco está en la primera ficha")
	await _press("ui_right")
	check_equal(get_viewport().gui_get_focus_owner(), _card("lista_invitados"), "las flechas recorren el corcho")
	await _press("ui_accept")
	check_equal(board.get_selection(), ["lista_invitados"] as Array[String], "Intro elige la ficha")
	await _press("ui_up")
	var focused := get_viewport().gui_get_focus_owner()
	check(focused is BoardSuspectCard, "hacia arriba se llega a los sospechosos")
	await _press("ui_accept")
	check(board.is_editing(), "e Intro abre su hipótesis")
	var suspect := (focused as BoardSuspectCard).suspect_id
	check_equal(get_viewport().gui_get_focus_owner(), board.get_editor().get_status_option(), "con el foco en la valoración")
	await _press("pause")
	check_equal(get_viewport().gui_get_focus_owner(), _suspect(suspect), "al cerrarla, el foco vuelve a su ficha")


# --- Tamaño de pantalla ---

func test_layout_fits_every_screen_shape() -> void:
	for clue_id: String in GameData.clues:
		Investigation.discover_clue(clue_id)
	Investigation.set_hypothesis("irene", "principal", "")
	var root: Control = board.get_node("Root")
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# 16:9 (lo mismo a 1280 × 720, 1366 × 768, 1600 × 900 o 1920 × 1080), 4:3, 5:4, 16:10 y 21:9.
	for view: Vector2 in [Vector2(1920, 1080), Vector2(1440, 1080), Vector2(1350, 1080), Vector2(1920, 1200), Vector2(2560, 1080)]:
		root.size = view
		board.open()
		await _wait(OPEN_SECONDS)
		board.select_item("reloj_despacho")
		board.select_item("copia_telegrama")
		board.open_hypothesis("irene")
		await wait_physics_frames(4)
		var label := "%dx%d" % [int(view.x), int(view.y)]
		var frame := board.get_board()
		var frame_rect := frame.get_global_rect()
		check(Rect2(Vector2.ZERO, view).encloses(frame_rect), label + ": el tablero cabe en la pantalla")
		check(frame_rect.size.x <= BoardStyle.FRAME_MAX_WIDTH + 0.5, label + ": sin pasar del ancho máximo")
		check(frame.header.get_title_font_size() >= BoardStyle.TITLE_MIN_SIZE, label + ": el rótulo se lee")
		var close := frame.header.get_close_button().get_global_rect()
		check(frame_rect.encloses(close) and not close.intersects(frame.seal.get_global_rect()), label + ": «Cerrar» se ve y no lo tapa el sello")
		var row := board.get_suspect_row()
		var canvas := board.get_investigation_canvas()
		var side := board.get_comparison()
		for part: Control in [row, canvas, side]:
			check(frame_rect.encloses(part.get_global_rect()), label + ": %s queda dentro del tablero" % part.name)
		check(not row.get_global_rect().intersects(canvas.get_global_rect()), label + ": la fila de sospechosos no pisa el corcho")
		check(not canvas.get_global_rect().intersects(side.get_global_rect()), label + ": ni el corcho la comparación")
		check(canvas.size.x >= BoardStyle.CARD_SIZE.x * 2.0, label + ": en el corcho caben al menos dos columnas")
		check(not row.get_h_scroll_bar().visible, label + ": los cinco sospechosos caben sin desplazar")
		for card in row.get_cards():
			check(card.is_status_complete(), label + ": la valoración de %s se lee entera" % card.suspect_id)
		for card in canvas.get_cards():
			check(card.position.x >= 0.0 and card.position.x + card.size.x <= canvas.get_scroll().size.x, label + ": la ficha %s cabe a lo ancho" % card.item_id)
		var link := side.get_link_button().get_global_rect()
		check(side.get_global_rect().encloses(link) and link.size.y > 0.0, label + ": «Relacionar» se ve")
		check(side.get_combined_minimum_size().y <= side.size.y + 0.5, label + ": la comparación no pide más alto del que hay")
		var editor := board.get_editor()
		check(canvas.get_global_rect().encloses(editor.get_global_rect()), label + ": el panel de hipótesis queda sobre el corcho")
		check(editor.get_global_rect().encloses(editor.get_save_button().get_global_rect()), label + ": con «Guardar hipótesis» a la vista")
		board.close()
		await _wait(CLOSE_SECONDS)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --- Guardar y cargar ---

func test_saved_and_loaded_game_keeps_the_board() -> void:
	for item_id: String in ["reloj_despacho", "copia_telegrama"]:
		Investigation.discover_clue(item_id)
	await _open()
	board.select_item("reloj_despacho")
	board.select_item("copia_telegrama")
	board.link_selected()
	board.open_hypothesis("anselmo")
	board.get_editor().get_status_option().select(Investigation.HYPOTHESIS_STATUSES.find("descartado"))
	board.get_editor().get_text_edit().text = "Coartada demasiado limpia."
	board.save_hypothesis()
	board.close()
	await _wait(CLOSE_SECONDS)
	SaveSystem.begin_session(self)
	check(await save_and_wait("manual_1"), "la partida se guarda")
	SaveSystem.end_session(self)
	await _free_game()
	GameState.reset()
	GameClock.reset()
	check(SaveSystem.request_load("manual_1")["ok"], "la carga se prepara")
	game = await make_game()
	board = game.get_node("BoardUi")
	await _open()
	check_equal(_suspect("anselmo").get_status_text(), "Descartado", "la valoración vuelve")
	board.open_hypothesis("anselmo")
	check_equal(board.get_editor().get_text_edit().text, "Coartada demasiado limpia.", "y la hipótesis")
	check(_card("d_hora_falsa") != null, "la deducción sigue en el corcho")
	var ids := board.get_investigation_canvas().get_connections().get_relations().map(func(relation: Dictionary) -> String: return relation["id"])
	check_equal(ids, ["d_hora_falsa"], "con su hilo")
	check(not board.has_draft("anselmo"), "y sin borradores de otra partida")


# --- Integración ---

func test_decoration_never_takes_the_mouse() -> void:
	Investigation.discover_clue("carta_valdes")
	await _open()
	var frame := board.get_board()
	var canvas := board.get_investigation_canvas()
	for decoration: Control in [frame, frame.header, frame.header.get_photo(), frame.header.get_help(), frame.seal, canvas.get_connections(), canvas.get_node("Decor"), canvas.get_node("Rim")]:
		check_equal(decoration.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s no recibe el ratón" % decoration.name)
	for photo in canvas.find_children("*", "JournalPhoto", true, false):
		check_equal((photo as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "la foto decorativa tampoco")
	var focusable := 0
	for control in canvas.find_children("*", "Control", true, false):
		if (control as Control).focus_mode != Control.FOCUS_NONE and not control is BoardEvidenceCard and not control is ScrollBar:
			focusable += 1
	check_equal(focusable, 0, "en el corcho sólo se eligen fichas: los huecos libres no son botones")
	await _click(frame.seal)
	check(board.is_open, "pulsar el sello no hace nada")


func test_closed_board_leaves_the_other_keys_alone() -> void:
	await _open()
	board.close()
	await _wait(CLOSE_SECONDS)
	check(not (board.get_node("Root") as Control).is_visible_in_tree(), "cerrado, el tablero no se ve")
	await _press("open_journal")
	var journal: JournalUi = game.get_node("JournalUi")
	check(journal.is_open, "la J vuelve a abrir el expediente")
	await _press("open_board")
	check(not board.is_open, "y con el expediente abierto, la B no abre el tablero encima")
	journal.close()


func test_mouse_wheel_scrolls_a_full_cork() -> void:
	for clue_id: String in GameData.clues:
		Investigation.discover_clue(clue_id)
	for testimony_id: String in GameData.testimonies:
		Investigation.record_testimony(testimony_id)
	await _open()
	var scroll := board.get_investigation_canvas().get_scroll()
	check(scroll.get_v_scroll_bar().visible, "con todo descubierto, el corcho se desplaza")
	var spot := _card(GameState.clues[0]).get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = pressed
		wheel.position = spot
		wheel.global_position = spot
		get_viewport().push_input(wheel, true)
	await wait_physics_frames(3)
	check(scroll.scroll_vertical > 0, "la rueda lo desplaza aunque el ratón esté sobre una ficha")
