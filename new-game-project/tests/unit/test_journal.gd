extends TestCase
## El expediente con los sistemas reales. Se abre y se cierra con las teclas del InputMap sin dejar
## bloqueos; sus cinco secciones enseñan lo que dicen `StoryDirector`, `GameState` y `GameData` (y nada
## que el jugador no haya descubierto); se recorre con teclado y ratón; recuerda dónde estaba; se pone
## al día solo; cabe en pantallas de distintas proporciones; y sobrevive a guardar y cargar.

const OPEN_SECONDS := JournalStyle.OPEN_SECONDS + 0.1
const CLOSE_SECONDS := JournalStyle.CLOSE_SECONDS + 0.1

var game: Game
var journal: JournalUi


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()
	game = await make_game()
	journal = game.get_node("JournalUi")


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
	journal = null
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	# Los temporizadores se atienden antes que las animaciones del mismo fotograma: si uno largo hace
	# vencer a la vez el temporizador y un fundido, se espera a que el fundido termine de verdad.
	await get_tree().process_frame


## Una pulsación tal como llega del teclado o del mando.
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


func _open(tab: int) -> JournalSection:
	journal.open(tab)
	await wait_physics_frames(3)
	return journal.get_section(tab)


func _field_text(section: JournalSection) -> String:
	return "\n".join(section.detail.get_field_texts())


static func _controls_in(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child in node.get_children(true):
		if child is Control:
			found.append(child as Control)
		found.append_array(_controls_in(child))
	return found


# --- Apertura y cierre ---

func test_real_keys_open_and_close_without_leftover_locks() -> void:
	await _press("open_journal")
	check(journal.is_open, "J abre el expediente")
	check(GameState.get_player_lock_reasons().has("expediente"), "y bloquea al detective")
	await _wait(OPEN_SECONDS)
	await _press("open_journal")
	check(not journal.is_open, "J lo cierra")
	check(not GameState.is_player_locked(), "sin bloqueos residuales")
	await _wait(CLOSE_SECONDS)
	check(not (journal.get_node("Root") as Control).visible, "tras el fundido desaparece")
	await _press("open_journal")
	await _press("pause")
	check(not journal.is_open, "Esc también lo cierra")
	check(not (game.get_node("PauseMenu") as PauseMenu).is_open, "sin abrir la pausa con la misma pulsación")
	await _press("open_journal")
	journal.get_folder().footer.get_close_button().pressed.emit()
	check(not journal.is_open, "«Cerrar el expediente» se puede pulsar con el ratón")
	check(not GameState.is_player_locked(), "y tampoco deja bloqueos")


func test_open_and_close_are_animated_and_ignore_clicks_while_fading() -> void:
	journal.open(0)
	var root: Control = journal.get_node("Root")
	check(root.modulate.a < 0.5, "la carpeta empieza transparente")
	check(journal.get_folder().scale.x < 1.0, "y algo más pequeña")
	await _wait(OPEN_SECONDS)
	check(is_equal_approx(root.modulate.a, 1.0) and journal.get_folder().scale.is_equal_approx(Vector2.ONE), "y termina a su tamaño")
	journal.close()
	check((journal.get_node("Root/Shield") as Control).visible, "mientras se desvanece, nada responde a los clics")
	check(get_viewport().gui_get_focus_owner() == null, "y ninguna pieza conserva el foco")
	await _wait(CLOSE_SECONDS)
	check(not root.visible and is_equal_approx(root.modulate.a, 1.0), "al final se oculta y queda listo para volver")


func test_five_sections_with_their_tabs_and_icons() -> void:
	await _open(0)
	var tabs := journal.get_folder().tabs
	check_equal(tabs.get_tab_count(), 6, "seis pestañas: las cinco de siempre y Preguntas")
	var titles := PackedStringArray()
	for index in tabs.get_tab_count():
		titles.append(tabs.get_tab(index).text)
		check(tabs.get_tab(index).icon != null, "cada pestaña lleva su icono")
	check_equal(titles, PackedStringArray(["Objetivos", "Pistas", "Testimonios", "Sospechosos", "Deducciones", "Preguntas"]), "en el orden del expediente")
	for icon_name in JournalUi.TAB_ICONS:
		check(ResourceLoader.exists(CaseFileStyle.ICONS % icon_name), "el icono existe: " + icon_name)
	check_equal(journal.get_folder().header.get_title(), "EXPEDIENTE 1948/17 · CASO VALDÉS", "el rótulo de la carpeta")
	check_equal(JournalUi.STATUS_LABELS, JournalInfo.STATUS_LABELS, "el tablero sigue leyendo las valoraciones del expediente")


# --- Objetivos ---

func test_objectives_follow_the_story_with_their_states() -> void:
	var section: JournalObjectivesSection = await _open(JournalUi.Tab.OBJECTIVES)
	var cards := section.get_cards()
	var expected := StoryDirector.get_objectives()
	check_equal(cards.size(), expected.size(), "una tarjeta por objetivo visible")
	check_equal(cards[0].get_text(), expected[0]["text"], "el primero es el del día")
	check_equal(cards[0].state, JournalInfo.ObjectiveState.ACTIVE, "y está en curso")
	check_equal(section.get_date_text(), StoryDirector.get_day_title(), "bajo la cinta, la fecha del día")
	# Se cumple un objetivo con el expediente abierto: la sección se pone al día sola.
	GameState.set_flag("llamada_atendida")
	await wait_physics_frames(2)
	cards = section.get_cards()
	var states := {}
	for card in cards:
		states[card.objective_id] = card.state
	check_equal(states.get("o_cafe"), JournalInfo.ObjectiveState.DONE, "el objetivo cumplido se marca")
	check_equal(states.get("o_mansion"), JournalInfo.ObjectiveState.ACTIVE, "y el siguiente pasa a estar en curso")
	check_equal(cards[cards.size() - 1].objective_id, "o_cafe", "los cumplidos van al final")
	check_equal(cards[cards.size() - 1].get_state_label(), "Cumplido", "con su etiqueta")


func test_case_summary_counts_real_progress_and_real_rules() -> void:
	for clue_id: String in ["carta_valdes", "reloj_despacho"]:
		Investigation.discover_clue(clue_id)
	Investigation.record_testimony("t_elena_jaqueca")
	var section: JournalObjectivesSection = await _open(JournalUi.Tab.OBJECTIVES)
	var texts := _field_text(section)
	check(texts.contains("2 / %d" % GameData.clues.size()), "pistas encontradas frente al total")
	check(texts.contains("0 / %d" % GameData.deductions.size()), "deducciones frente al total")
	var stats: Control = section.detail.get_fields().get_node("Stats")
	var testimonies: Label = stats.get_child(1).get_child(0).get_child(0).get_node("Value")
	check_equal(testimonies.text, "1", "testimonios registrados, sin adelantar el total")
	check(texts.contains("%d minutos" % DialogueManager.TOPIC_MINUTES), "las reglas citan el coste real de una pregunta")
	check(texts.contains("23:30"), "y la hora tope del reloj")
	check(texts.contains(GameData.locations[Game.REST_LOCATION]["name"]), "y dónde se descansa")
	check_equal(section.detail.get_title(), StoryDirector.get_day_title(), "el encabezado es la fecha narrativa")
	check(section.detail.get_subtitle().contains(GameClock.format_time()), "con la hora del reloj")
	# Sin ventana no se puede fotografiar la escena: queda el emblema del lugar, con su nombre.
	var photo := section.detail.get_photo()
	check(section.detail.is_photo_shown(), "la ficha lleva su fotografía")
	check_equal(photo.get_caption(), GameData.locations[GameState.location_id]["name"], "con el nombre del lugar")


# --- Pistas ---

func test_clues_list_details_and_empty_state() -> void:
	var section: JournalCluesSection = await _open(JournalUi.Tab.CLUES)
	check(section.list.is_empty(), "una partida nueva no tiene pistas")
	check(section.detail.is_empty_shown(), "la ficha muestra el estado vacío")
	var empty := section.detail.get_empty_state()
	check_equal(empty.get_title(), "Aún no hay pistas registradas.", "con su rótulo")
	check_equal(empty.get_key(), InputLabels.keys_of("interact")[0], "y la tecla real de examinar")
	check_equal(section.column.banner.text, "PISTAS (0)", "la cinta cuenta las pistas")
	journal.close()
	for clue_id: String in ["carta_valdes", "reloj_despacho", "huellas_betun"]:
		Investigation.discover_clue(clue_id)
	section = await _open(JournalUi.Tab.CLUES)
	check_equal(section.column.banner.text, "PISTAS (3)", "la cinta se pone al día")
	check_equal(section.list.get_entry_ids(), PackedStringArray(["carta_valdes", "reloj_despacho", "huellas_betun"]), "en el orden en que se hallaron")
	section.list.select("reloj_despacho")
	var clue: Dictionary = GameData.clues["reloj_despacho"]
	check_equal(section.detail.get_title(), clue["name"], "la ficha es la de la pista elegida")
	check_equal(section.detail.get_subtitle(), "Reloj", "con su categoría")
	var texts := _field_text(section)
	check(texts.contains(clue["where"]), "su procedencia")
	check(texts.contains(clue["description"]), "y la descripción completa")
	check_equal(section.detail.get_photo().get_mode(), JournalPhoto.Mode.PHOTO, "con imagen propia (la ilustración del reloj), su fotografía")
	check_equal(section.list.get_item("reloj_despacho").get_thumb().get_icon_name(), "reloj", "la fila lleva el icono de su categoría")
	section.list.select("huellas_betun")
	check_equal(section.detail.get_photo().get_mode(), JournalPhoto.Mode.EMBLEM, "sin imagen propia, el emblema de su categoría")


func test_a_clue_image_from_the_data_becomes_its_photo() -> void:
	var clue: Dictionary = GameData.clues["carta_valdes"]
	clue["image"] = "res://assets/ui/mansion_grabado.svg"
	Investigation.discover_clue("carta_valdes")
	var section: JournalCluesSection = await _open(JournalUi.Tab.CLUES)
	check_equal(section.detail.get_photo().get_mode(), JournalPhoto.Mode.PHOTO, "una imagen en los datos se muestra como fotografía")
	clue.erase("image")


# --- Testimonios ---

func test_testimonies_empty_state_and_statements() -> void:
	var section: JournalTestimoniesSection = await _open(JournalUi.Tab.TESTIMONIES)
	var empty := section.detail.get_empty_state()
	check(section.detail.is_empty_shown(), "sin declaraciones, estado vacío")
	check_equal(empty.get_title(), "Aún no hay declaraciones registradas.", "con el rótulo previsto")
	check_equal(empty.get_text(), "Las declaraciones de testigos y personajes aparecerán aquí conforme avances en la investigación.", "y su texto")
	check_equal(section.column.banner.text, "TESTIMONIOS (0)", "la cinta dice cero")
	check(section.column.art != null, "con el grabado del interrogatorio al pie")
	journal.close()
	Investigation.record_testimony("t_marcos_cafe")
	Investigation.record_testimony("t_elena_jaqueca")
	section = await _open(JournalUi.Tab.TESTIMONIES)
	check_equal(section.list.get_entry_ids(), PackedStringArray(["t_elena_jaqueca", "t_marcos_cafe"]), "agrupadas por personaje, en el orden del reparto")
	section.list.select("t_marcos_cafe")
	var testimony: Dictionary = GameData.testimonies["t_marcos_cafe"]
	check_equal(section.detail.get_title(), "Marcos Valdés", "quién declara")
	check_equal(section.detail.get_subtitle(), GameData.characters["marcos"]["role"], "y su papel")
	var texts := _field_text(section)
	check(texts.contains("«%s»" % testimony["text"]), "el texto completo de la declaración")
	check(texts.contains(testimony["topic"]), "y su tema")
	check(not texts.contains("Fecha:") and not texts.contains("Lugar:"), "sin fecha ni lugar inventados")
	check_equal(section.detail.get_photo().get_mode(), JournalPhoto.Mode.PORTRAIT, "con el retrato de quien declara")
	check(section.list.get_item("t_marcos_cafe").get_thumb().get_texture() != null, "también en miniatura")


# --- Sospechosos ---

func test_suspect_sheets_come_from_the_real_state() -> void:
	GameState.hypotheses["marcos"] = {"status": "principal", "note": "Debe dinero en el café."}
	var section: JournalSuspectsSection = await _open(JournalUi.Tab.SUSPECTS)
	check_equal(section.list.get_entry_ids(), PackedStringArray(GameData.get_suspects()), "los cinco sospechosos de los datos")
	check_equal(section.column.banner.text, "SOSPECHOSOS (5)", "la cinta los cuenta")
	section.list.select("marcos")
	check_equal(section.detail.get_title(), "Marcos Valdés", "el nombre")
	check_equal(section.detail.get_subtitle(), "Hijo de la víctima", "su relación con el caso")
	var texts := _field_text(section)
	check(texts.contains(GameData.characters["marcos"]["bio"]), "la biografía")
	check(texts.contains(StoryDirector.describe_whereabouts("marcos")), "el paradero de su rutina")
	check(texts.contains("Principal sospechoso"), "la valoración del tablero")
	check(texts.contains("Debe dinero en el café."), "y la hipótesis anotada")
	check_equal(section.detail.get_photo().get_mode(), JournalPhoto.Mode.PORTRAIT, "su retrato con clip")
	section.list.select("anselmo")
	texts = _field_text(section)
	check_equal(section.detail.get_title(), "Anselmo Roca", "cambiar de sospechoso cambia toda la ficha")
	check(texts.contains("Sin valorar") and not texts.contains("Debe dinero"), "sin arrastrar datos del anterior")


func test_whereabouts_follow_the_clock() -> void:
	var section: JournalSuspectsSection = await _open(JournalUi.Tab.SUSPECTS)
	section.list.select("marcos")
	var morning := StoryDirector.describe_whereabouts("marcos")
	check(_field_text(section).contains(morning), "por la mañana, donde dice su rutina")
	GameClock.day = 2
	GameClock.advance(5 * 60)
	await wait_physics_frames(2)
	var later := StoryDirector.describe_whereabouts("marcos")
	check(later != morning, "la rutina cambia con el día y la hora")
	check(_field_text(section).contains(later), "y la ficha abierta se pone al día")


# --- Deducciones ---

func test_deductions_empty_page_and_board_key() -> void:
	var section: JournalDeductionsSection = await _open(JournalUi.Tab.DEDUCTIONS)
	check(not section.column.visible, "sin deducciones, una sola página grande")
	var empty := section.detail.get_empty_state()
	check_equal(empty.get_title(), "Aún no hay deducciones.", "con su rótulo")
	var board_key := InputLabels.keys_of("open_board")[0]
	check_equal(empty.get_text(), "Relaciona pruebas y testimonios en el tablero [%s]." % board_key, "y la tecla real del tablero")
	check(empty.is_art_shown(), "el grabado del tablero en el centro")
	check(section.detail.art != null, "y libros y lupa en la esquina")
	check_equal(section.get_footer_left(), 0.0, "el pie aprovecha todo el ancho")


func test_deductions_show_only_known_evidence() -> void:
	for clue_id: String in ["reloj_despacho", "copia_telegrama"]:
		Investigation.discover_clue(clue_id)
	var outcome := Investigation.try_link("reloj_despacho", "copia_telegrama")
	check_equal(outcome["result"], Investigation.LinkResult.NEW, "la deducción se establece en el tablero")
	var section: JournalDeductionsSection = await _open(JournalUi.Tab.DEDUCTIONS)
	check(section.column.visible, "con deducciones vuelve la lista")
	check_equal(section.list.get_entry_ids(), PackedStringArray(["d_hora_falsa"]), "la deducción hallada")
	check_equal(section.column.banner.text, "DEDUCCIONES (1)", "contada en la cinta")
	check_equal(section.detail.get_title(), GameData.deductions["d_hora_falsa"]["title"], "su título")
	check_equal(section.detail.get_subtitle(), "Contradicción", "su tipo")
	var texts := _field_text(section)
	check(texts.contains(GameData.deductions["d_hora_falsa"]["text"]), "su conclusión")
	check(texts.contains(GameData.clues["reloj_despacho"]["name"]) and texts.contains(GameData.clues["copia_telegrama"]["name"]), "las pruebas que la sostienen")
	check(not texts.contains("Eusebio Pardo"), "y nunca una declaración que aún no se ha oído")
	check(section.get_footer_left() > 0.0, "el pie vuelve a ir bajo la ficha")


# --- Navegación ---

func test_keyboard_moves_between_sections_and_entries() -> void:
	await _open(JournalUi.Tab.OBJECTIVES)
	var tabs := journal.get_folder().tabs
	check(tabs.get_tab(0).has_focus(), "sin fichas, el foco está en la pestaña")
	await _press("ui_right")
	check_equal(journal.get_current_tab(), JournalUi.Tab.CLUES, "derecha pasa a la sección siguiente")
	await _press("ui_left")
	check_equal(journal.get_current_tab(), JournalUi.Tab.OBJECTIVES, "izquierda vuelve")
	await _press_key(KEY_4)
	check_equal(journal.get_current_tab(), JournalUi.Tab.SUSPECTS, "las cifras llevan directamente a una sección")
	check(tabs.get_tab(JournalUi.Tab.SUSPECTS).has_focus(), "y el foco sigue en las pestañas")
	var section := journal.get_section(JournalUi.Tab.SUSPECTS)
	var suspects := GameData.get_suspects()
	await _press("ui_down")
	check(section.list.get_item(suspects[0]).has_focus(), "abajo baja a la ficha elegida de la sección")
	await _press("ui_down")
	check_equal(section.list.get_selected_id(), suspects[1], "abajo elige la siguiente")
	check_equal(section.detail.get_title(), GameData.characters[suspects[1]]["name"], "y su ficha aparece")
	await _press("ui_up")
	await _press("ui_up")
	check(tabs.get_tab(JournalUi.Tab.SUSPECTS).has_focus(), "arriba desde la primera sube a su pestaña")
	await _press("ui_left")
	check_equal(journal.get_current_tab(), JournalUi.Tab.TESTIMONIES, "en las pestañas, izquierda y derecha también cambian de sección")
	check(tabs.get_tab(JournalUi.Tab.TESTIMONIES).has_focus(), "y el foco sigue en ellas")
	await _press("ui_right")
	await _press("ui_down")
	check(section.list.get_item(suspects[0]).has_focus(), "al volver, la sección recuerda su ficha")
	await _press_key(KEY_2)
	check_equal(journal.get_current_tab(), JournalUi.Tab.CLUES, "desde una ficha, las cifras también cambian de sección")
	check(journal.get_folder().tabs.get_tab(JournalUi.Tab.CLUES).has_focus(), "sin fichas, el foco pasa a la pestaña")


func test_mouse_selects_tabs_and_entries() -> void:
	await _open(JournalUi.Tab.OBJECTIVES)
	await _wait(OPEN_SECONDS)
	await _click(journal.get_folder().tabs.get_tab(JournalUi.Tab.SUSPECTS))
	check_equal(journal.get_current_tab(), JournalUi.Tab.SUSPECTS, "un clic en la pestaña cambia de sección")
	var section := journal.get_section(JournalUi.Tab.SUSPECTS)
	await _click(section.list.get_item("irene"))
	check_equal(section.list.get_selected_id(), "irene", "un clic en una ficha la elige")
	check_equal(section.detail.get_title(), "Irene Vidal", "y muestra sus datos")


func test_long_details_scroll_with_page_keys() -> void:
	for clue_id: String in GameData.clues:
		Investigation.discover_clue(clue_id)
	var root: Control = journal.get_node("Root")
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.size = Vector2(1920, 1080)
	var section := await _open(JournalUi.Tab.CLUES)
	var scroll := section.detail.get_scroll()
	# Una ficha muy larga, como la de una carta extensa.
	for index in 30:
		section.detail.add_paragraph("Línea de prueba número %d de una ficha larga que no cabe en la página." % index)
	await wait_physics_frames(3)
	await _press("ui_page_down")
	check(scroll.scroll_vertical > 0, "Av Pág baja por una ficha larga")
	await _press("ui_page_up")
	check_equal(scroll.scroll_vertical, 0, "Re Pág vuelve arriba")
	check(section.column.scroll.get_v_scroll_bar().visible, "una lista de diecinueve pistas se desplaza")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func test_reopening_restores_section_and_entry_without_rebuilding() -> void:
	var section: JournalSuspectsSection = await _open(JournalUi.Tab.SUSPECTS)
	section.list.select("lucia")
	var item := section.list.get_item("lucia")
	journal.select_tab(JournalUi.Tab.CLUES)
	journal.select_tab(JournalUi.Tab.SUSPECTS)
	check(section.list.get_item("lucia") == item, "cambiar de pestaña no rehace las fichas")
	journal.close()
	await _wait(CLOSE_SECONDS)
	journal.open()
	await wait_physics_frames(3)
	check_equal(journal.get_current_tab(), JournalUi.Tab.SUSPECTS, "al volver a abrir sigue en la misma sección")
	check_equal(section.list.get_selected_id(), "lucia", "con la misma ficha elegida")
	check(section.list.get_item("lucia") == item, "sin reconstruir la lista")


func test_new_findings_appear_while_open() -> void:
	var section: JournalCluesSection = await _open(JournalUi.Tab.CLUES)
	Investigation.discover_clue("lista_invitados")
	await wait_physics_frames(2)
	check_equal(section.list.get_entry_ids(), PackedStringArray(["lista_invitados"]), "una pista nueva aparece sin cerrar el expediente")
	check(not section.detail.is_empty_shown(), "y su ficha sustituye al estado vacío")


# --- Integración ---

func test_journal_hides_the_hud_and_keeps_other_panels_closed() -> void:
	await _wait(Hud.FIRST_REVEAL_DELAY + HudStyle.FADE_IN + 0.2)
	var hud: Hud = game.get_node("Hud")
	check(hud.is_exploration_shown(), "explorando, el HUD está a la vista")
	await _press("open_journal")
	await wait_physics_frames(2)
	check(not hud.is_exploration_shown(), "con el expediente abierto, el HUD se retira")
	await _press("open_board")
	check(not (game.get_node("BoardUi") as BoardUi).is_open, "no se abre el tablero encima")
	await _press("open_map")
	check(not (game.get_node("PauseMenu") as PauseMenu).is_open, "ni el mapa")
	await _press("open_journal")
	await wait_physics_frames(2)
	check(hud.is_exploration_shown(), "al cerrarlo, el HUD vuelve")


func test_nothing_in_the_journal_steals_input_when_closed() -> void:
	await _open(JournalUi.Tab.SUSPECTS)
	journal.close()
	await _wait(CLOSE_SECONDS)
	check(not (journal.get_node("Root") as Control).is_visible_in_tree(), "cerrado, el expediente no se ve")
	check(get_viewport().gui_get_focus_owner() == null, "ni retiene el foco")
	await _press("open_board")
	var board: BoardUi = game.get_node("BoardUi")
	check(board.is_open, "las demás teclas vuelven a funcionar")
	board.close()


func test_layout_fits_every_screen_shape() -> void:
	for clue_id: String in GameData.clues:
		Investigation.discover_clue(clue_id)
	var root: Control = journal.get_node("Root")
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# 16:9 (lo mismo a 1280 × 720, 1366 × 768, 1600 × 900 o 1920 × 1080), 4:3, 5:4, 16:10 y 21:9.
	for view: Vector2 in [Vector2(1920, 1080), Vector2(1440, 1080), Vector2(1350, 1080), Vector2(1920, 1200), Vector2(2560, 1080)]:
		root.size = view
		journal.open(0)
		# Se mide con la carpeta ya abierta: durante la apertura crece desde algo menos de su tamaño.
		await _wait(OPEN_SECONDS)
		for tab in JournalUi.TAB_TITLES.size():
			journal.select_tab(tab)
			await wait_physics_frames(4)
			var label := "%dx%d, pestaña %d" % [int(view.x), int(view.y), tab]
			var folder := journal.get_folder()
			var screen := Rect2(Vector2.ZERO, view)
			var folder_rect := folder.get_global_rect()
			check(screen.encloses(folder_rect), label + ": la carpeta cabe en la pantalla")
			check(folder_rect.size.x <= JournalStyle.FOLDER_MAX_WIDTH + 0.5, label + ": y no pasa del ancho máximo")
			var tabs := folder.tabs
			for index in tabs.get_tab_count():
				var rect := tabs.get_tab(index).get_global_rect()
				check(folder_rect.encloses(rect), label + ": la pestaña %d cabe en la carpeta" % index)
				if index > 0:
					check(rect.position.x >= tabs.get_tab(index - 1).get_global_rect().end.x, label + ": las pestañas no se pisan")
				check(tabs.get_tab(index).get_content_width() <= rect.size.x + 1.0, label + ": el texto de la pestaña cabe")
			var body := folder.body.get_global_rect()
			check(folder_rect.encloses(body), label + ": el cuerpo queda dentro de la carpeta")
			var section := journal.get_section(tab)
			check(body.encloses(section.get_global_rect().grow(-0.5)), label + ": la sección no se sale del cuerpo")
			check(section.get_combined_minimum_size().x <= body.size.x + 0.5, label + ": el contenido no pide más ancho del que hay")
			check(section.get_combined_minimum_size().y <= body.size.y + 0.5, label + ": ni más alto")
			check(folder.header.get_title_font_size() >= JournalHeader.TITLE_MIN_SIZE, label + ": el rótulo se lee")
			var close := folder.footer.get_close_button().get_global_rect()
			check(folder_rect.encloses(close) and close.size.x > 0.0, label + ": «Cerrar el expediente» se ve")
			check(not close.intersects(section.detail.get_global_rect()), label + ": el pie no tapa la ficha")
			if section.column.visible:
				check(not section.column.get_global_rect().intersects(section.detail.get_global_rect()), label + ": la lista y la ficha no se pisan")
			if section.detail.is_photo_shown():
				var photo := section.detail.get_photo().get_global_rect()
				check(section.detail.get_global_rect().grow(8.0).encloses(photo), label + ": la foto queda en su página")
			elif section.detail.has_photo():
				failures.append(label + ": la foto no cabe y se retira")
		journal.close()
		await _wait(CLOSE_SECONDS)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func test_loaded_game_shows_the_same_case_file() -> void:
	Investigation.discover_clue("reloj_despacho")
	Investigation.record_testimony("t_anselmo_brindis")
	GameState.hypotheses["anselmo"] = {"status": "sospechoso", "note": "Coartada demasiado limpia."}
	SaveSystem.begin_session(self)
	check(await save_and_wait("manual_1"), "la partida se guarda")
	SaveSystem.end_session(self)
	await _free_game()
	GameState.reset()
	GameClock.reset()
	check(SaveSystem.request_load("manual_1")["ok"], "la carga se prepara")
	game = await make_game()
	journal = game.get_node("JournalUi")
	var clues: JournalCluesSection = await _open(JournalUi.Tab.CLUES)
	check_equal(clues.list.get_entry_ids(), PackedStringArray(["reloj_despacho"]), "las pistas cargadas")
	var testimonies: JournalTestimoniesSection = await _open(JournalUi.Tab.TESTIMONIES)
	check_equal(testimonies.list.get_entry_ids(), PackedStringArray(["t_anselmo_brindis"]), "los testimonios cargados")
	var suspects: JournalSuspectsSection = await _open(JournalUi.Tab.SUSPECTS)
	suspects.list.select("anselmo")
	var texts := _field_text(suspects)
	check(texts.contains("Sospechoso") and texts.contains("Coartada demasiado limpia."), "la valoración y la hipótesis guardadas")
	journal.close()
