extends TestCase
## La acusación formal manejada a través de su interfaz real: la hoja, la lista de sospechosos, el
## panel lateral de pruebas, el teclado, el ratón, el borrador y la composición en pantalla.

var game: Game
var accusation: AccusationUi


func before_each() -> void:
	game = await make_game()
	accusation = game.get_node("AccusationUi")


func after_each() -> void:
	if accusation.is_open:
		accusation.close()
	Settings.set_value("accesibilidad/tamano_letra", "normal")
	DialogueManager.close()
	game.queue_free()
	await get_tree().process_frame
	GameState.reset()
	GameClock.reset()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _discover_everything() -> void:
	for clue_id: String in GameData.clues:
		GameState.clues.append(clue_id)
	for testimony_id: String in GameData.testimonies:
		GameState.testimonies.append(testimony_id)
	for deduction_id: String in GameData.deductions:
		GameState.deductions.append(deduction_id)


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _type(character: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = OS.find_keycode_from_string(character.to_upper())
		event.physical_keycode = event.keycode
		event.unicode = character.unicode_at(0)
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame


func _click_at(spot: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		get_viewport().push_input(click, true)
	await get_tree().process_frame
	await get_tree().process_frame


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _screen() -> Rect2:
	return Rect2(Vector2.ZERO, get_tree().root.get_visible_rect().size).grow(0.5)


# --- Apertura, campos vacíos y bloqueo ---

func test_opens_empty_with_placeholders_and_locks_the_player() -> void:
	accusation.open()
	await _wait(0.35)
	check(GameState.get_player_lock_reasons().has("acusacion"), "el detective no se mueve con la hoja abierta")
	check_equal(accusation.get_header().get_title(), "ACUSACIÓN FORMAL", "rótulo")
	check_equal(accusation.get_field_text("suspect"), "Seleccionar sospechoso", "sospechoso sin elegir")
	for field: String in ["motive", "opportunity", "means"]:
		check_equal(accusation.get_field_text(field), "Seleccionar evidencia o testimonio", "%s sin elegir" % field)
		check(not accusation.get_field(field).is_filled(), "%s pendiente" % field)
	check(accusation.get_accuse_button().disabled, "no se puede presentar una acusación vacía")
	check(accusation.get_status_text().contains("sospechoso, motivo, oportunidad y medios"), "se dice qué falta: %s" % accusation.get_status_text())
	check_equal(accusation.get_verdict_text(), AccusationInfo.DEFAULT_VERDICT, "Ortega escucha")
	check_equal(_focused(), accusation.get_field("suspect").selector, "el foco empieza en el primer campo pendiente")
	accusation.get_continue_button().pressed.emit()
	check(not accusation.is_open, "«Seguir investigando» cierra")
	check(not GameState.is_player_locked(), "y devuelve el control")


func test_pause_key_closes_the_form_instead_of_pausing() -> void:
	accusation.open()
	await _wait(0.3)
	await _press("pause")
	check(not accusation.is_open, "Esc cierra la acusación")
	check(not (game.get_node("PauseMenu") as PauseMenu).is_open, "sin abrir la pausa a la vez")


# --- Sospechosos ---

func test_suspect_list_offers_every_suspect_with_portraits() -> void:
	accusation.open()
	accusation.open_field("suspect")
	await _wait(0.25)
	var list := accusation.get_suspect_list()
	check(accusation.is_suspect_list_open() and list.visible, "se despliega la lista propia")
	var names: Array[String] = []
	for row in list.get_rows():
		names.append(row.get_title())
		check(row.get_subtitle() != "", "%s lleva su papel en la casa" % row.get_title())
	var expected: Array[String] = []
	for suspect_id in GameData.get_suspects():
		expected.append(GameData.get_character_name(suspect_id))
	check_equal(names, expected, "los cinco sospechosos, en su orden")
	check(_focused() is AccusationListRow, "el foco entra en la lista")
	check(_screen().encloses(list.get_box_rect()), "la lista cabe en la pantalla (%s en %s)" % [list.get_box_rect(), _screen()])


func test_every_suspect_can_be_chosen() -> void:
	accusation.open()
	for suspect_id in GameData.get_suspects():
		accusation.open_field("suspect")
		await get_tree().process_frame
		accusation.get_suspect_list().get_row(suspect_id).pressed.emit()
		await get_tree().process_frame
		check_equal(accusation.get_field_text("suspect"), GameData.get_character_name(suspect_id), "se elige a " + suspect_id)
		check_equal(Investigation.get_accusation_draft()["suspect"], suspect_id, "y queda en el borrador")
		check(not accusation.is_suspect_list_open(), "la lista se cierra al elegir")
	accusation.open_field("suspect")
	var last: String = GameData.get_suspects()[-1]
	check(accusation.get_suspect_list().get_row(last).chosen, "el elegido se marca al volver a desplegar")


func test_keyboard_picks_a_suspect_and_escape_only_closes_the_list() -> void:
	accusation.open()
	await _wait(0.3)
	accusation.get_field("suspect").selector.grab_focus()
	await _press("ui_accept")
	check(accusation.is_suspect_list_open(), "Intro despliega la lista")
	await _press("ui_down")
	var row := _focused() as AccusationListRow
	check(row != null and row.item_id == GameData.get_suspects()[1], "la flecha baja al segundo sospechoso")
	await _press("ui_cancel")
	check(not accusation.is_suspect_list_open(), "Esc cierra la lista")
	check(accusation.is_open, "pero no la acusación")
	check_equal(accusation.get_field_text("suspect"), "Seleccionar sospechoso", "sin elegir nada")
	check_equal(_focused(), accusation.get_field("suspect").selector, "el foco vuelve al campo")
	await _press("ui_accept")
	await _press("ui_down")
	await _press("ui_accept")
	check_equal(Investigation.get_accusation_draft()["suspect"], GameData.get_suspects()[1], "Intro elige el señalado")


func test_click_outside_the_list_closes_it_without_choosing() -> void:
	accusation.open()
	accusation.open_field("suspect")
	await _wait(0.25)
	await _click_at(Vector2(6.0, 6.0))
	check(not accusation.is_suspect_list_open(), "un clic fuera la cierra")
	check(accusation.is_open, "la hoja sigue abierta")
	check_equal(Investigation.get_accusation_draft()["suspect"], "", "sin elegir")


# --- Panel lateral ---

func test_panel_shows_only_the_category_of_its_field() -> void:
	_discover_everything()
	accusation.open()
	for field: String in ["motive", "opportunity", "means"]:
		accusation.open_field(field)
		await get_tree().process_frame
		var panel := accusation.get_panel()
		check(accusation.is_panel_open(), "%s abre el panel lateral" % field)
		check_equal(panel.get_title(), AccusationInfo.PANEL_TITLES[field], "título del panel para %s" % field)
		check(accusation.get_field(field).selector.active, "el campo que se edita queda marcado")
		var expected := Investigation.get_accusation_options(field).map(func(item: Dictionary) -> String: return item["id"])
		var shown := panel.get_option_ids()
		check_equal(shown.size(), expected.size(), "%s enseña sus opciones" % field)
		for item_id in shown:
			check(expected.has(item_id), "%s no enseña %s" % [field, item_id])
			check_equal(shown.count(item_id), 1, "%s no repite %s" % [field, item_id])
		check_equal(panel.get_rows().size(), shown.size(), "una fila por opción")
		for row in panel.get_rows():
			check(not row.chosen, "nada viene elegido de antemano (%s)" % row.item_id)


func test_panel_never_shows_undiscovered_items() -> void:
	Investigation.discover_clue("pagare_marcos")
	Investigation.record_testimony("t_marcos_discusion")
	accusation.open()
	accusation.open_field("motive")
	await get_tree().process_frame
	check_equal(accusation.get_panel().get_option_ids(), ["pagare_marcos", "t_marcos_discusion"] as Array[String], "sólo lo descubierto")
	check_equal(accusation.get_panel().get_visible_groups(), PackedStringArray(["Pruebas (1)", "Testimonios (1)"]), "agrupado por clase")


func test_choosing_an_item_fills_only_its_field_and_closes_the_panel() -> void:
	_discover_everything()
	accusation.open()
	accusation.open_field("opportunity")
	await _wait(0.35)
	var panel := accusation.get_panel()
	panel.get_row("libro_bodega").pressed.emit()
	await _wait(0.35)
	check_equal(accusation.get_field_text("opportunity"), "Libro de bodega", "se rellena la oportunidad")
	check_equal(Investigation.get_accusation_draft()["opportunity"], "libro_bodega", "con su identificador en el borrador")
	for field: String in ["suspect", "motive", "means"]:
		check(not accusation.get_field(field).is_filled(), "%s sigue igual" % field)
	check(not accusation.is_panel_open(), "el panel se cierra al elegir")
	check(not panel.visible, "y desaparece")
	check_equal(_focused(), accusation.get_field("opportunity").selector, "el foco vuelve al campo")
	accusation.open_field("opportunity")
	await get_tree().process_frame
	check(panel.get_row("libro_bodega").chosen, "la elección se resalta al volver")
	check_equal(_focused(), panel.get_row("libro_bodega"), "y recibe el foco")


func test_testimonies_use_the_short_speaker_name() -> void:
	Investigation.record_testimony("t_ortega_escena")
	accusation.open()
	accusation.open_field("opportunity")
	await get_tree().process_frame
	var panel := accusation.get_panel()
	check_equal(panel.get_row("t_ortega_escena").get_title(), "Ortega: La escena del crimen", "título corto en la fila")
	panel.get_row("t_ortega_escena").highlighted.emit("t_ortega_escena")
	check(panel.get_preview_text().begins_with("La puerta principal"), "la vista previa recuerda lo que dijo")
	check_equal(panel.get_row("t_ortega_escena").get_icon_name(), "testigos", "icono de testimonio")


func test_item_types_get_distinct_icons() -> void:
	_discover_everything()
	accusation.open()
	accusation.open_field("motive")
	await get_tree().process_frame
	var panel := accusation.get_panel()
	check_equal(panel.get_row("carta_valdes").get_icon_name(), "carta", "carta")
	check_equal(panel.get_row("foto_clara").get_icon_name(), "fotografia", "fotografía")
	check_equal(panel.get_row("transferencia").get_icon_name(), "documento", "documento")
	check_equal(panel.get_row("sociedad_cormoran").get_icon_name(), "libro", "registro")
	check_equal(panel.get_row("billete_tren").get_icon_name(), "etiqueta", "objeto")
	check_equal(panel.get_row("d_dinero").get_icon_name(), "cerebro", "deducción")
	accusation.open_field("means")
	await get_tree().process_frame
	check_equal(panel.get_row("informe_forense").get_icon_name(), "carpeta", "informe")


func test_escape_closes_the_panel_before_the_form() -> void:
	_discover_everything()
	accusation.open()
	accusation.open_field("means")
	await _wait(0.35)
	await _press("ui_cancel")
	check(not accusation.is_panel_open(), "Esc cierra el panel")
	check(accusation.is_open, "sin cerrar la hoja")
	check_equal(_focused(), accusation.get_field("means").selector, "el foco vuelve al campo")
	await _press("ui_cancel")
	check(not accusation.is_open, "el segundo Esc cierra la hoja")


func test_close_button_and_clicking_the_background_close_the_panel() -> void:
	_discover_everything()
	accusation.open()
	accusation.open_field("motive")
	await _wait(0.35)
	accusation.get_panel().get_close_button().pressed.emit()
	check(not accusation.is_panel_open(), "el botón de cierre vuelve al formulario")
	accusation.open_field("motive")
	await _wait(0.35)
	await _click_at(Vector2(8.0, get_tree().root.get_visible_rect().size.y * 0.5))
	check(not accusation.is_panel_open(), "un clic en el fondo también")
	check(accusation.is_open, "la hoja sigue abierta")


func test_switching_fields_retargets_the_panel() -> void:
	_discover_everything()
	accusation.open()
	accusation.open_field("motive")
	await get_tree().process_frame
	accusation.open_field("means")
	await get_tree().process_frame
	check_equal(accusation.get_active_picker(), "means", "el panel pasa a los medios")
	check_equal(accusation.get_panel().get_title(), AccusationInfo.PANEL_TITLES["means"], "con su título")
	check(not accusation.get_field("motive").selector.active, "el motivo deja de estar marcado")
	accusation.open_field("means")
	check(not accusation.is_panel_open(), "pulsar otra vez el mismo campo lo cierra")


func test_keyboard_moves_through_rows_and_preview_follows() -> void:
	_discover_everything()
	accusation.open()
	await _wait(0.3)
	accusation.get_field("motive").selector.grab_focus()
	await _press("ui_accept")
	await _wait(0.3)
	var panel := accusation.get_panel()
	var rows := panel.get_visible_rows()
	check_equal(_focused(), rows[0], "el foco entra en la primera fila")
	await _press("ui_down")
	await _press("ui_down")
	check_equal(_focused(), rows[2], "la flecha recorre la lista")
	check_equal(panel.get_preview_id(), rows[2].item_id, "la vista previa sigue al foco")
	await _press("ui_accept")
	check_equal(Investigation.get_accusation_draft()["motive"], rows[2].item_id, "Intro elige la fila")


func test_search_filters_by_title_and_content_ignoring_accents() -> void:
	_discover_everything()
	accusation.open()
	accusation.open_field("opportunity")
	await get_tree().process_frame
	var panel := accusation.get_panel()
	var all := panel.get_visible_rows().size()
	panel.set_query("PENSION")
	var ids := panel.get_visible_rows().map(func(row: AccusationListRow) -> String: return row.item_id)
	check(ids.has("registro_pension"), "encuentra el título sin tildes ni mayúsculas")
	check(ids.has("t_irene_pension"), "y lo que dice el contenido")
	check(ids.size() < all, "y oculta el resto")
	panel.set_query("22:40 bodega")
	ids = panel.get_visible_rows().map(func(row: AccusationListRow) -> String: return row.item_id)
	check(ids.has("libro_bodega"), "el libro tiene la hora y la bodega")
	check(ids.has("d_bodega"), "la deducción también las nombra")
	check(not ids.has("t_anselmo_bodega"), "todas las palabras deben aparecer: la coartada no dice 22:40")
	panel.set_query("faro abandonado")
	check(panel.is_showing_empty(), "sin coincidencias se avisa")
	check(panel.get_empty_text().contains("faro abandonado"), "repitiendo la búsqueda")
	panel.set_query("")
	check_equal(panel.get_visible_rows().size(), all, "vaciar el buscador lo enseña todo")


func test_typing_while_browsing_goes_to_the_search() -> void:
	_discover_everything()
	accusation.open()
	accusation.open_field("means")
	await _wait(0.35)
	var panel := accusation.get_panel()
	await _type("l")
	await _type("l")
	check(panel.get_search().has_focus(), "una letra lleva al buscador")
	check_equal(panel.get_search().text, "ll", "y se escribe")
	check(panel.get_visible_rows().size() < panel.get_option_ids().size(), "la lista se filtra al escribir")
	await _press("pause")
	check(accusation.is_panel_open(), "escribiendo, una tecla de pausa que fuera una letra no cierra nada")
	await _press("ui_cancel")
	check(not accusation.is_panel_open(), "Esc cierra el panel también desde el buscador")
	check(accusation.is_open, "sin cerrar la hoja")


func test_empty_category_explains_how_to_continue() -> void:
	Investigation.discover_clue("libro_bodega")
	accusation.open()
	accusation.open_field("motive")
	await get_tree().process_frame
	var panel := accusation.get_panel()
	check(panel.is_showing_empty(), "sin pruebas del motivo se avisa")
	check(panel.get_empty_text().contains("Todavía no has reunido"), "con un texto que no adelanta nada")
	check(not panel.get_search().visible, "sin buscador inútil")
	check_equal(panel.get_hint_texts().size(), 1, "sólo queda la tecla de volver")
	check(panel.get_hint_texts()[0].ends_with("Volver al formulario"), "volver")


# --- Borrador y presentación ---

func test_continue_investigating_keeps_the_draft_and_new_evidence_appears() -> void:
	Investigation.discover_clue("transferencia")
	accusation.open()
	accusation.choose("suspect", "anselmo")
	accusation.choose("motive", "transferencia")
	accusation.get_continue_button().pressed.emit()
	check_equal(GameState.accusation_attempts, 0, "seguir investigando no es un intento")
	check(not DialogueManager.active, "ni empieza ninguna escena")
	Investigation.discover_clue("libro_bodega")
	await _wait(0.3)
	accusation.open()
	check_equal(accusation.get_field_text("suspect"), "Anselmo Roca", "el sospechoso sigue elegido")
	check_equal(accusation.get_field_text("motive"), "Transferencia de la Compañía Cormorán", "y el motivo")
	check(not accusation.get_field("opportunity").is_filled(), "lo demás sigue pendiente")
	accusation.open_field("opportunity")
	await get_tree().process_frame
	check(accusation.get_panel().get_option_ids().has("libro_bodega"), "lo descubierto después aparece en su campo")


func test_incomplete_accusation_cannot_be_presented() -> void:
	for item_id: String in ["transferencia", "libro_bodega"]:
		Investigation.discover_clue(item_id)
	accusation.open()
	accusation.choose("suspect", "anselmo")
	accusation.choose("motive", "transferencia")
	accusation.choose("opportunity", "libro_bodega")
	check(accusation.get_accuse_button().disabled, "falta un campo: no se puede presentar")
	check_equal(accusation.get_status_text(), "Falta elegir: medios.", "se dice cuál")
	check(accusation.present().is_empty(), "presentar no hace nada")
	check_equal(GameState.accusation_attempts, 0, "ni cuenta un intento")


func test_failed_accusation_keeps_the_draft_for_another_try() -> void:
	for item_id: String in ["billete_tren", "registro_billetes", "copa_lavada"]:
		Investigation.discover_clue(item_id)
	accusation.open()
	accusation.choose("suspect", "elena")
	accusation.choose("motive", "billete_tren")
	accusation.choose("opportunity", "registro_billetes")
	accusation.choose("means", "copa_lavada")
	check(not accusation.get_accuse_button().disabled, "completa se puede presentar")
	var verdict := accusation.present()
	check(not verdict["ok"], "no se sostiene")
	check(accusation.get_verdict_text().begins_with("Ortega: A las 23:05"), "Ortega explica por qué")
	check_equal(GameState.accusation_attempts, 1, "cuenta un intento")
	check(accusation.is_open, "se puede corregir sin empezar de cero")
	check_equal(Investigation.get_accusation_draft()["means"], "copa_lavada", "el borrador sigue")


func test_correct_accusation_starts_the_confrontation_and_closing_the_case_clears_the_draft() -> void:
	for item_id: String in ["transferencia", "libro_bodega", "informe_forense"]:
		Investigation.discover_clue(item_id)
	accusation.open()
	accusation.choose("suspect", "anselmo")
	accusation.choose("motive", "transferencia")
	accusation.choose("opportunity", "libro_bodega")
	accusation.choose("means", "informe_forense")
	check(accusation.present()["ok"], "la acusación se sostiene")
	check(not accusation.is_open, "la hoja se cierra")
	check(DialogueManager.active, "empieza la confrontación")
	check_equal(Investigation.get_accusation_draft()["suspect"], "anselmo", "el borrador dura hasta cerrar el caso")
	DialogueManager.close()
	GameState.set_flag("caso_resuelto")
	check_equal(GameState.accusation_draft, {}, "con el caso resuelto se descarta")


# --- Composición ---

func test_layout_centers_the_form_and_fits_both_panels() -> void:
	_discover_everything()
	accusation.open()
	await _wait(0.4)
	var screen := _screen()
	var sheet := accusation.get_sheet_rect()
	check(screen.encloses(sheet), "la hoja cabe (%s en %s)" % [sheet, screen.size])
	check(absf(sheet.get_center().x - screen.get_center().x) < 2.0, "sin panel, la hoja está centrada")
	accusation.open_field("motive")
	await _wait(AccusationStyle.SPLIT_SECONDS + 0.1)
	sheet = accusation.get_sheet_rect()
	var panel := accusation.get_panel_rect()
	check(screen.encloses(sheet), "con el panel, la hoja cabe")
	check(screen.encloses(panel), "y el panel también (%s)" % panel)
	check(panel.position.x > sheet.end.x, "el panel queda a la derecha, sin tapar el formulario")
	accusation.close_picker()
	await _wait(AccusationStyle.SPLIT_SECONDS + 0.1)
	check(absf(accusation.get_sheet_rect().get_center().x - screen.get_center().x) < 2.0, "al cerrarlo la hoja vuelve al centro")


func test_large_text_scales_everything_inside_the_screen() -> void:
	_discover_everything()
	Settings.set_value("accesibilidad/tamano_letra", "muy_grande")
	await get_tree().process_frame
	accusation.open()
	accusation.open_field("opportunity")
	await _wait(AccusationStyle.SPLIT_SECONDS + 0.2)
	var screen := _screen()
	check(accusation.get_layout_scale() < 1.0, "la hoja se reduce para caber")
	check(screen.encloses(accusation.get_sheet_rect()), "la hoja cabe con la letra muy grande")
	check(screen.encloses(accusation.get_panel_rect()), "y el panel también")
	accusation.close_picker()
	accusation.open_field("suspect")
	await _wait(0.25)
	check(screen.encloses(accusation.get_suspect_list().get_box_rect()), "y la lista de sospechosos")
