extends TestCase
## Inspección de evidencias con la escena de juego real: cada prueba se abre en su plantilla con
## los textos de `clues.json`; «Evidencia obtenida» aparece sólo la primera vez, dura lo configurado y
## se va sola sin cerrar la hoja; la hoja se cierra con E (sin que la pulsación que la abrió la
## cierre), con Esc y con el ratón; el jugador queda bloqueado y vuelve a moverse; nada se repite al
## releer ni al cargar; y todo cabe en pantallas de distintas proporciones y tamaños de letra.

const OPEN_SECONDS := EvidenceStyle.OPEN_SECONDS + 0.1
const CLOSE_SECONDS := EvidenceStyle.CLOSE_SECONDS + 0.1
## Las tres pruebas con presentación propia y la plantilla, la placa y el icono que les tocan.
const SHOWCASE := {
	"carta_amor": ["carta", "Carta personal", "carta"],
	"periodico_aniversario": ["periodico", "Periódico / Crónica", "periodico"],
	"reloj_despacho": ["ficha", "Evidencia / Objeto", "engranaje"],
}
## Ubicación del quiosco del periódico en la plaza, como en `test_investigation`.
const KIOSK_SPOT := Vector3(-4.2, 0.1, 10.0)

var game: Game
var inspector: ClueInspector


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()
	game = await make_game()
	inspector = game.get_node("ClueInspector")


func after_each() -> void:
	for action: String in ["interact", "move_forward"]:
		Input.action_release(action)
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
	inspector = null
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _process_frames(count: int) -> void:
	for frame in count:
		await get_tree().process_frame


## Una pulsación completa (pulsar y soltar), como en el resto de pruebas de interfaz.
func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_physics_frames(2)


## Pulsa o suelta una acción a través de `Input`, que además recuerda si sigue pulsada.
func _hold(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	await _process_frames(3)


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


func _toast_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for toast in (game.get_node("Hud") as Hud).get_toasts():
		titles.append(toast.get_title())
	return titles


func _labels_named(document: EvidenceDocument, node_name: String) -> String:
	var label := document.find_child(node_name, true, false) as Label
	return label.text if label != null else ""


# --- Plantillas y datos ---

func test_each_showcase_clue_opens_in_its_own_template() -> void:
	for clue_id: String in SHOWCASE:
		inspector.open(clue_id)
		await wait_physics_frames(2)
		var expected: Array = SHOWCASE[clue_id]
		var document := inspector.get_document()
		check_equal(document.get_template_id(), expected[0], "%s: su plantilla" % clue_id)
		check_equal(inspector.get_header().get_text(), expected[1], "%s: el rótulo de la placa" % clue_id)
		check(inspector.get_header().get_icon() == EvidenceStyle.icon(expected[2]), "%s: el icono de la placa" % clue_id)
		check_equal(inspector.get_close_button().get_label_text(), "%s Cerrar" % InputLabels.keys_of("interact")[0], "%s: el único control es «[E] Cerrar»" % clue_id)
		inspector.close()
		await _wait(CLOSE_SECONDS)


func test_letter_shows_the_message_apart_from_the_investigator_note() -> void:
	inspector.open("carta_amor")
	await wait_physics_frames(2)
	var letter := inspector.get_document() as EvidenceLetter
	var presentation: Dictionary = GameData.clues["carta_amor"]["presentation"]
	check(letter != null, "la carta usa su plantilla")
	check_equal(letter.get_body_text(), presentation["body"], "el cuerpo es el texto manuscrito de los datos")
	check_equal(_labels_named(letter, "Salutation"), "Lucía:", "el encabezado")
	check_equal(_labels_named(letter, "Signature"), "M.", "la firma de Marcos")
	check_equal(_labels_named(letter, "Place"), "Cuarto de Lucía", "dónde se halló, arriba a la derecha")
	var note := letter.find_child("Note", true, false) as EvidenceTag
	check(note != null and note.get_text() == "Está doblada dentro de un misal.", "el misal va en la nota del investigador")
	check(not letter.get_body_text().contains("misal"), "y no dentro del mensaje manuscrito")
	check(letter.find_child("Ornament", true, false) != null, "con las violetas prensadas")
	for text in letter.get_texts():
		check(not text.contains("1948") and not text.contains("octubre"), "la carta no lleva una fecha inventada: «%s»" % text)


func test_newspaper_keeps_the_existing_story() -> void:
	inspector.open("periodico_aniversario")
	await wait_physics_frames(2)
	var paper := inspector.get_document() as EvidenceNewspaper
	check(paper != null, "el periódico usa su plantilla")
	var texts := " | ".join(paper.get_texts())
	for expected: String in ["El Eco de Villa Sombría", "TREINTA AÑOS DEL BANCO VALDÉS", "Esta noche, cena privada en la mansión.", "Sábado, 16 de octubre de 1948", "archivo municipal"]:
		check(texts.contains(expected), "el periódico dice «%s»" % expected)
	check(not texts.contains("17 de octubre") and not texts.contains("anoche"), "la crónica es del sábado de la cena, no del día siguiente")
	var where := paper.find_child("Where", true, false) as EvidenceTag
	check(where != null and where.get_text() == "Hallada en: Quiosco de la plaza", "dónde se halló")
	check(paper.find_child("Photo", true, false) != null, "con la fotografía de la mansión")


func test_clock_record_card_keeps_its_description_and_illustration() -> void:
	inspector.open("reloj_despacho")
	await wait_physics_frames(2)
	var card := inspector.get_document() as EvidenceRecordCard
	var clue: Dictionary = GameData.clues["reloj_despacho"]
	check(card != null, "el reloj usa la ficha de investigación")
	check_equal(_labels_named(card, "Description"), clue["description"], "la descripción de siempre, completa")
	var texts := card.get_texts()
	check(texts.has("RELOJ") and texts.has("Reloj de sobremesa parado"), "el tipo y el título")
	var where := card.find_child("Where", true, false) as EvidenceTag
	check(where != null and where.get_text() == "Hallada en: Despacho de Julián Valdés", "la ubicación resaltada")
	var art := card.find_child("Illustration", true, false) as TextureRect
	check(art != null and art.texture.resource_path == clue["image"], "la ilustración del reloj, la misma imagen que el expediente")
	check(art != null and not art.get_rect().intersects(card.find_child("Description", true, false).get_rect()), "sin tapar la descripción")


func test_every_clue_can_be_examined() -> void:
	for clue_id: String in GameData.clues:
		inspector.open(clue_id)
		await _process_frames(1)
		var entry := EvidenceInfo.describe(clue_id)
		var document := inspector.get_document()
		check(document != null and document.get_template_id() == entry["template"], "%s: se abre en su plantilla" % clue_id)
		check(inspector.get_header().get_text().length() > 0, "%s: con su placa" % clue_id)
		if document is EvidenceRecordCard:
			check_equal(_labels_named(document, "Description"), GameData.clues[clue_id]["description"], "%s: con su descripción" % clue_id)
			var has_picture := document.find_child("Illustration", true, false) != null or document.find_child("Emblem", true, false) != null
			check(has_picture, "%s: con su ilustración o el emblema de su categoría" % clue_id)
		check(GameState.clues.has(clue_id), "%s: queda registrada" % clue_id)
		inspector.close()
	await _wait(CLOSE_SECONDS)
	check(not GameState.is_player_locked(), "tras examinarlas todas no queda ningún bloqueo")


func test_presentations_agree_with_the_clue_descriptions() -> void:
	for clue_id: String in GameData.clues:
		var clue: Dictionary = GameData.clues[clue_id]
		if not clue.has("presentation"):
			continue
		var presentation: Dictionary = clue["presentation"]
		var description := str(clue["description"]).to_lower()
		check(EvidenceInfo.TEMPLATES.has(presentation.get("template", "")), "%s: plantilla conocida" % clue_id)
		for key: String in ["body", "salutation", "masthead", "headline"]:
			if presentation.has(key):
				var text := str(presentation[key]).to_lower().trim_suffix(":")
				check(description.contains(text), "%s: «%s» coincide con la descripción del expediente" % [clue_id, key])
		for key: String in ["image", "ornament", "vignette"]:
			if presentation.has(key):
				check(ResourceLoader.exists(presentation[key]), "%s: existe %s" % [clue_id, presentation[key]])
	for clue_id: String in GameData.clues:
		var image := str(GameData.clues[clue_id].get("image", ""))
		check(image.is_empty() or ResourceLoader.exists(image), "%s: su imagen existe" % clue_id)


# --- «Evidencia obtenida» ---

func test_first_discovery_shows_the_notice_once_and_without_a_duplicate_toast() -> void:
	var discovered: Array[String] = []
	var on_discovered := func(clue_id: String) -> void: discovered.append(clue_id)
	EventBus.clue_discovered.connect(on_discovered)
	inspector.open("carta_amor")
	var notice := inspector.get_notice()
	check(notice.is_playing(), "al registrar una prueba nueva arranca el aviso")
	check_equal(notice.get_text(), "Evidencia obtenida", "con su rótulo")
	await _wait(EvidenceStyle.NOTICE_DELAY + EvidenceStyle.NOTICE_IN + 0.15)
	check(notice.is_showing(), "y se ve")
	check(not _toast_titles().has("Pista registrada"), "el HUD no repite el hallazgo con otro aviso")
	check_equal(discovered, ["carta_amor"] as Array[String], "la prueba se registra una vez")
	inspector.close()
	await _wait(CLOSE_SECONDS)
	inspector.open("carta_amor")
	await _process_frames(2)
	check(not notice.is_playing() and not notice.is_showing(), "al releerla no aparece")
	check_equal(discovered.size(), 1, "ni se vuelve a registrar")
	var notices := inspector.get_root().find_children("*", "EvidenceNotice", true, false)
	check_equal(notices.size(), 1, "hay un único aviso, que se reutiliza")
	EventBus.clue_discovered.disconnect(on_discovered)


func test_notice_lasts_the_configured_time_and_the_sheet_stays_open() -> void:
	check_equal(inspector.notice_seconds, 2.5, "por defecto el aviso se queda 2,5 segundos")
	inspector.open("periodico_aniversario")
	var notice := inspector.get_notice()
	check_equal(notice.get_last_hold(), inspector.notice_seconds, "con la duración configurada")
	await _wait(EvidenceStyle.NOTICE_DELAY + EvidenceStyle.NOTICE_IN + 0.1)
	var while_showing := inspector.get_document_rect()
	await _wait(2.0)
	check(notice.is_showing(), "a los dos segundos y medio de abrir sigue a la vista")
	await _wait(EvidenceNotice.total_seconds(inspector.notice_seconds) - EvidenceStyle.NOTICE_DELAY - EvidenceStyle.NOTICE_IN - 2.0 + 0.3)
	check(not notice.is_showing() and not notice.is_playing(), "después se desvanece solo")
	check(inspector.is_open, "y la hoja sigue abierta")
	check_equal(inspector.get_document_rect(), while_showing, "el aviso no movió ni cambió de tamaño el documento")


func test_notice_duration_can_be_changed() -> void:
	inspector.notice_seconds = 0.4
	inspector.open("reloj_despacho")
	await _wait(EvidenceNotice.total_seconds(0.4) + 0.25)
	check(not inspector.get_notice().is_showing(), "con 0,4 segundos el aviso ya se fue")
	check(inspector.is_open, "y la hoja sigue abierta")


func test_closing_before_the_notice_ends() -> void:
	inspector.open("carta_amor")
	await _wait(OPEN_SECONDS)
	check(inspector.get_notice().is_playing(), "el aviso está en marcha")
	await _press("interact")
	check(not inspector.is_open, "E cierra sin esperar al aviso")
	check(not inspector.get_notice().is_playing(), "y el aviso se detiene")
	check(not GameState.is_player_locked(), "el jugador recupera el control al momento")
	await _wait(CLOSE_SECONDS)
	check(not inspector.get_notice().visible, "al terminar el fundido no queda nada del aviso")
	inspector.open("reloj_despacho")
	check(inspector.get_notice().is_playing(), "la siguiente prueba nueva tiene su propio aviso")


func test_loaded_game_does_not_announce_known_clues() -> void:
	inspector.open("reloj_despacho")
	inspector.close()
	SaveSystem.begin_session(self)
	check(await save_and_wait("manual_1"), "la partida se guarda")
	SaveSystem.end_session(self)
	await _free_game()
	GameState.reset()
	GameClock.reset()
	check(SaveSystem.request_load("manual_1")["ok"], "la carga se prepara")
	game = await make_game()
	inspector = game.get_node("ClueInspector")
	check(GameState.clues.has("reloj_despacho"), "la prueba sigue registrada tras cargar")
	check(not inspector.is_open and not inspector.get_notice().is_playing(), "cargar no abre ni anuncia nada")
	var minutes := GameClock.minutes
	inspector.open("reloj_despacho")
	await _process_frames(2)
	check(not inspector.get_notice().is_playing(), "releerla tras cargar no la anuncia")
	check_equal(GameClock.minutes, minutes, "ni vuelve a contar el tiempo de examinarla")
	check_equal(GameState.clues.count("reloj_despacho"), 1, "ni la duplica")


func test_clues_from_conversations_keep_the_hud_notice() -> void:
	Investigation.discover_clue("informe_forense")
	await _process_frames(2)
	check(_toast_titles().has("Pista registrada"), "una pista recibida hablando se sigue anunciando en el HUD")
	check(not inspector.is_open, "sin abrir la hoja de inspección")


# --- Entrada y bloqueo ---

func test_the_press_that_examines_does_not_close_the_sheet() -> void:
	await game.go_to("plaza", "inicio")
	game.player.teleport(KIOSK_SPOT)
	await wait_physics_frames(6)
	check(game.player.detector.get_focused() is ClueObject, "el periódico del quiosco queda al alcance")
	await _hold("interact", true)
	check(inspector.is_open, "E examina el periódico")
	check(not inspector.is_close_armed(), "mientras E sigue pulsada, no cierra")
	await _hold("interact", true)
	check(inspector.is_open, "ni aunque llegue otra pulsación de la misma tecla")
	await _hold("interact", false)
	check(inspector.is_close_armed(), "al soltarla, ya puede cerrar")
	check(inspector.is_open, "y la hoja sigue abierta")
	await _hold("interact", true)
	await _hold("interact", false)
	check(not inspector.is_open, "la siguiente pulsación de E la cierra")


func test_escape_closes_without_opening_the_pause() -> void:
	inspector.open("carta_amor")
	await _wait(OPEN_SECONDS)
	await _press("pause")
	check(not inspector.is_open, "Esc cierra la hoja")
	check(not (game.get_node("PauseMenu") as PauseMenu).is_open, "sin abrir la pausa")


func test_mouse_closes_with_the_button() -> void:
	inspector.open("periodico_aniversario")
	await _wait(OPEN_SECONDS)
	await _click(inspector.get_close_button())
	check(not inspector.is_open, "un clic en «Cerrar» cierra la hoja")


func test_player_is_locked_while_reading_and_restored_after() -> void:
	await _wait(Hud.FIRST_REVEAL_DELAY + HudStyle.FADE_IN + 0.2)
	var hud: Hud = game.get_node("Hud")
	check(hud.is_exploration_shown(), "explorando, el HUD está a la vista")
	inspector.open("carta_amor")
	await _process_frames(2)
	check(GameState.get_player_lock_reasons().has(ClueInspector.LOCK), "examinar bloquea al jugador")
	check(not hud.is_exploration_shown(), "y retira el HUD")
	var start: Vector3 = game.player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(10)
	check(game.player.global_position.distance_to(start) < 0.05, "el detective no camina mientras lee")
	await _press("open_journal")
	check(not (game.get_node("JournalUi") as JournalUi).is_open, "ni se abre el expediente encima")
	Input.action_release("move_forward")
	inspector.close()
	await _process_frames(2)
	check(not GameState.is_player_locked(), "al cerrar, el control vuelve")
	check(hud.is_exploration_shown(), "y el HUD también")
	await _press("open_journal")
	var journal: JournalUi = game.get_node("JournalUi")
	check(journal.is_open, "el expediente vuelve a abrirse")
	var clues := journal.get_section(JournalUi.Tab.CLUES) as JournalCluesSection
	journal.select_tab(JournalUi.Tab.CLUES)
	await _process_frames(2)
	check_equal(clues.list.get_entry_ids(), PackedStringArray(["carta_amor"]), "y lista la carta examinada")
	journal.close()


func test_close_key_follows_the_input_map() -> void:
	var saved := InputMap.action_get_events("interact")
	InputMap.action_erase_events("interact")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event("interact", key)
	inspector.open("reloj_despacho")
	check_equal(inspector.get_close_button().get_key_text(), "F", "el botón muestra la tecla asignada de verdad")
	inspector.close()
	InputMap.action_erase_events("interact")
	for event in saved:
		InputMap.action_add_event("interact", event)


func test_freeing_the_game_with_the_sheet_open_leaves_no_lock() -> void:
	inspector.open("carta_amor")
	await _free_game()
	check(not GameState.get_player_lock_reasons().has(ClueInspector.LOCK), "no queda el bloqueo de inspección")


# --- Pantalla ---

func test_layout_fits_every_screen_shape_and_text_size() -> void:
	var root := inspector.get_root()
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# 16:9, 4:3, 5:4, 21:9 y 16:9 con la letra «Muy grande» de Accesibilidad (lienzo 1920/1,3).
	for view: Vector2 in [Vector2(1920, 1080), Vector2(1920, 1440), Vector2(1920, 1536), Vector2(2520, 1080), Vector2(1477, 831)]:
		root.size = view
		for clue_id: String in SHOWCASE:
			inspector.open(clue_id)
			await _wait(OPEN_SECONDS)
			var label := "%dx%d, %s" % [int(view.x), int(view.y), clue_id]
			var screen := Rect2(Vector2.ZERO, view)
			var frame := inspector.get_frame_rect()
			var document := inspector.get_document_rect()
			var header := inspector.get_header_rect()
			var close := inspector.get_close_rect()
			var plate := inspector.get_notice_plate_rect()
			check(screen.encloses(frame), label + ": el marco cabe")
			check(frame.encloses(document), label + ": el documento queda dentro del marco")
			check(screen.encloses(header) and screen.encloses(close), label + ": la placa y el botón caben")
			check(document.size.x >= view.x * 0.6 or document.size.y >= view.y * 0.7, label + ": el documento ocupa la mayor parte de la pantalla")
			check(screen.encloses(plate), label + ": el aviso cabe")
			check(plate.end.y <= frame.position.y and not plate.intersects(document), label + ": el aviso no tapa el documento")
			check(not inspector.get_notice_rect().intersects(header), label + ": ni la placa del encabezado")
			check(not close.intersects(document.grow(-2.0)), label + ": el botón no tapa el papel")
			inspector.close()
			await _wait(CLOSE_SECONDS)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func test_larger_text_keeps_the_document_as_big_as_with_normal_text() -> void:
	inspector.open("periodico_aniversario")
	await _wait(OPEN_SECONDS)
	var root := get_tree().root
	var normal := inspector.get_document_rect().size.y * root.content_scale_factor
	var normal_header := inspector.get_header_rect().size * root.content_scale_factor
	for size_id: String in ["grande", "muy_grande"]:
		UiAccessibility.apply_text_scale(get_tree(), size_id)
		await _process_frames(4)
		var factor := root.content_scale_factor
		check(is_equal_approx(factor, UiAccessibility.text_scale(size_id)), "%s: la interfaz crece" % size_id)
		var on_screen := inspector.get_document_rect().size.y * factor
		check(absf(on_screen - normal) <= normal * 0.02, "%s: el documento se ve del mismo tamaño que con la letra normal" % size_id)
		check((inspector.get_header_rect().size * factor).distance_to(normal_header) < 1.0, "%s: y la placa del encabezado también" % size_id)
		check(Rect2(Vector2.ZERO, inspector.get_root().size).encloses(inspector.get_frame_rect()), "%s: el marco cabe" % size_id)
	UiAccessibility.apply_text_scale(get_tree(), "normal")
	await _process_frames(2)
