extends TestCase
## Las conversaciones rediseñadas, con la escena de juego real y entradas como las del jugador: la
## placa con el nombre real y la silueta iluminada de quien habla; la escritura progresiva, que se
## completa y avanza de una en una; la paginación de los textos largos sin perder ni repetir nada;
## las respuestas con el teclado, las teclas numéricas y el ratón, con la consecuencia real de
## `DialogueManager`; el rótulo de las respuestas; el cierre, que devuelve el control y el HUD; las
## teclas que no se escapan a otras pantallas; los avisos durante una conversación; el guardado; y
## la composición en pantallas de varias proporciones.

const OPEN_SECONDS := DialogueStyle.OPEN_SECONDS + 0.1
const CLOSE_SECONDS := DialogueStyle.CLOSE_SECONDS + 0.15
const GUARD_SECONDS := DialogueStyle.CONFIRM_GUARD_SECONDS + 0.1
const TINT_SECONDS := DialogueStyle.TINT_SECONDS + 0.1
const HUD_SECONDS := HudStyle.FADE_IN + 0.2

var game: Game
var ui: DialogueUi
var lines_shown := 0


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()
	lines_shown = 0
	DialogueManager.line_shown.connect(_count_line)
	game = await make_game()
	ui = game.get_node("DialogueUi")


func after_each() -> void:
	DialogueManager.line_shown.disconnect(_count_line)
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
	ui = null
	await get_tree().process_frame


func _count_line(_speaker: String, _text: String) -> void:
	lines_shown += 1


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


func _press_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)
	await wait_physics_frames(2)


func _move_mouse_to(control: Control) -> void:
	var spot := control.get_global_rect().get_center()
	for offset: Vector2 in [Vector2(-3.0, 0.0), Vector2.ZERO]:
		var motion := InputEventMouseMotion.new()
		motion.position = spot + offset
		motion.global_position = spot + offset
		motion.relative = Vector2(3.0, 0.0)
		get_viewport().push_input(motion, true)
	await wait_physics_frames(2)


func _click(control: Control) -> void:
	await _move_mouse_to(control)
	var spot := control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		get_viewport().push_input(click, true)
	await wait_physics_frames(2)


## Abre la conversación con el jefe de estación, en la estación, como al llegar al pueblo.
func _talk_to_eusebio() -> void:
	DialogueManager.start("eusebio")
	await _wait(OPEN_SECONDS)


## Pulsa la tecla de interactuar hasta que aparezcan las respuestas.
func _read_until_choices() -> void:
	for attempt in 40:
		if ui.is_choosing() or not DialogueManager.active:
			return
		await _press("interact")
	failures.append("no aparecieron las respuestas")


## Lee la intervención actual entera y espera la pulsación para continuar.
func _finish_typing() -> void:
	if ui.is_typing():
		await _press("interact")


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


# --- Lectura ---

func test_opening_shows_the_real_name_and_lights_the_speaker() -> void:
	await _talk_to_eusebio()
	await _wait(TINT_SECONDS)
	check(ui.is_open(), "la conversación aparece")
	check_equal(ui.get_speaker_plate().get_text(), GameData.get_character_name("eusebio"), "la placa lleva el nombre de characters.json")
	check_equal(ui.get_speaker(), "eusebio", "la luz es para quien habla")
	var cast := ui.get_cast()
	check(_near(cast.get_portrait().modulate, DialogueCast.ACTIVE_TINT), "su silueta se destaca")
	check(_near(cast.get_detective().modulate, DialogueCast.IDLE_TINT), "la del detective se atenúa")
	check_equal(cast.get_portrait().texture.resource_path, GameData.characters["eusebio"]["portrait"], "con la silueta de sus datos")
	var intro: String = GameData.get_dialogue("eusebio")["intro"][0]["lines"][0]["t"]
	check_equal(ui.get_dialogue_text().get_full_text(), intro, "el texto es el de los datos, sin cambios")
	check(ui.is_typing(), "y se escribe poco a poco")
	check(ui.get_continue_button().is_visible_in_tree(), "con «Continuar» en la esquina")
	var keys := InputLabels.keys_of("interact")
	check_equal(ui.get_continue_button().get_key_text(), keys[0] if not keys.is_empty() else "", "con la tecla real de interactuar")


func test_the_window_holds_only_text_and_its_controls() -> void:
	await _talk_to_eusebio()
	var window := ui.get_dialogue_window()
	var pictures := window.find_children("*", "TextureRect", true, false)
	for picture in pictures:
		# Los indicadores de desplazamiento internos de la lista no son imágenes del juego.
		var internal := not picture.get_parent().get_children(false).has(picture)
		check(internal or ui.get_choice_hint().is_ancestor_of(picture), "la única imagen de la ventana es el icono de la ayuda")
	check(ui.get_dialogue_text().get_theme_font_size("normal_font_size") >= 40, "el texto es grande")
	var cast_index := ui.get_cast().get_index()
	check(cast_index < window.get_index(), "las siluetas quedan por detrás de la ventana")


func test_typing_completes_then_each_press_advances_once() -> void:
	DialogueManager.start("ortega")
	await _wait(OPEN_SECONDS)
	var before := lines_shown
	check(ui.is_typing(), "la presentación de Ortega se escribe")
	await _press("interact")
	check(ui.is_waiting_for_input(), "la primera pulsación completa el texto")
	check(ui.get_dialogue_text().is_complete(), "que se ve entero")
	check_equal(lines_shown, before, "sin pasar a la siguiente intervención")
	await _press("interact")
	check_equal(lines_shown, before + 1, "la segunda pulsación pasa sólo a la siguiente")
	check(ui.is_typing(), "que empieza a escribirse")
	check(ui.get_continue_button().is_visible_in_tree(), "«Continuar» sigue a la vista")


func test_continue_pulses_only_when_the_text_is_complete() -> void:
	await _talk_to_eusebio()
	var button := ui.get_continue_button()
	check(not button.is_waiting(), "mientras se escribe, la pestaña reposa")
	await _press("interact")
	check(button.is_waiting(), "con el texto entero, late")


func test_clicking_anywhere_advances_like_the_key() -> void:
	await _talk_to_eusebio()
	await _click(ui.get_continue_button())
	check(ui.is_waiting_for_input(), "un clic completa el texto")
	await _click(ui.get_continue_button())
	check(ui.is_choosing(), "y otro clic pasa a las preguntas")


func test_speakers_change_the_plate_and_the_light() -> void:
	DialogueManager.play_scene("llamada")
	await _wait(OPEN_SECONDS)
	var lines: Array = GameData.scenes["llamada"]["lines"]
	for index in lines.size():
		await _wait(TINT_SECONDS)
		var speaker: String = lines[index].get("s", "narrador")
		var plate := ui.get_speaker_plate()
		if speaker == "narrador":
			check(not plate.is_showing(), "línea %d: la narración no lleva placa" % index)
			check(ui.get_cast().get_lit_figure() == null, "línea %d: y apaga las dos siluetas" % index)
			check(ui.get_dialogue_text().is_narration(), "línea %d: con la letra de la narración" % index)
		else:
			check_equal(plate.get_text(), GameData.get_character_name(speaker), "línea %d: la placa sigue a la voz" % index)
			var lit := ui.get_cast().get_lit_figure()
			var expected := ui.get_cast().get_detective() if speaker == "detective" else ui.get_cast().get_portrait()
			check(lit == expected, "línea %d: se ilumina quien habla" % index)
			if speaker != "detective":
				check_equal(lit.texture.resource_path, GameData.characters[speaker]["portrait"], "línea %d: con su silueta" % index)
		if index < lines.size() - 1:
			await _finish_typing()
			await _press("interact")


func test_long_text_is_split_into_pages_without_losing_words() -> void:
	DialogueManager.start("ortega")
	await _wait(OPEN_SECONDS)
	var parts := PackedStringArray()
	for topic: Dictionary in GameData.get_dialogue("ortega")["topics"]:
		for line: Dictionary in topic.get("lines", []):
			parts.append(line["t"])
	var long_text := " ".join(parts)
	# La interfaz recibe un texto largo como si lo mostrase la conversación.
	DialogueManager.line_shown.emit("ortega", long_text)
	var text := ui.get_dialogue_text()
	var pages := text.get_pages()
	check(pages.size() > 1, "un texto que no cabe se reparte en páginas")
	check_equal(" ".join(pages).split(" ", false), long_text.split(" ", false), "se leen todas las palabras, en orden y sin repetir")
	var before := lines_shown
	for page in pages.size():
		check_equal(text.get_page_index(), page, "página %d a la vista" % page)
		check(text.get_line_count() <= text.max_lines, "página %d: cabe en la ventana" % page)
		await _press("interact")
		check(text.is_complete(), "página %d: la pulsación la completa" % page)
		if page < pages.size() - 1:
			await _press("interact")
			check_equal(lines_shown, before, "pasar de página no salta a otra intervención")
	await _press("interact")
	check(lines_shown > before or ui.is_choosing(), "leída la última página, la conversación sigue")


func test_a_narrower_window_spreads_the_text_again() -> void:
	DialogueManager.start("ortega")
	await _wait(OPEN_SECONDS)
	var text := ui.get_dialogue_text()
	var long_text: String = " ".join([GameData.get_dialogue("ortega")["intro"][0]["lines"][0]["t"], GameData.get_dialogue("ortega")["intro"][0]["lines"][1]["t"], GameData.get_dialogue("ortega")["intro"][0]["lines"][0]["t"]])
	DialogueManager.line_shown.emit("ortega", long_text)
	var wide_pages := text.get_pages().size()
	var root: Control = ui.get_node("Root")
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	root.size = Vector2(1100, 1080)
	await wait_physics_frames(2)
	check(text.get_pages().size() >= wide_pages, "con menos ancho hacen falta las mismas páginas o más")
	check_equal(" ".join(text.get_pages()).split(" ", false), long_text.split(" ", false), "y sigue sin perderse nada")
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# --- Respuestas ---

func test_choices_are_the_manager_options_with_their_consequences() -> void:
	GameClock.day = 2
	var offered: Array = []
	var listener := func(options: Array) -> void: offered.assign(options)
	DialogueManager.options_shown.connect(listener)
	await _talk_to_eusebio()
	await _read_until_choices()
	DialogueManager.options_shown.disconnect(listener)
	var ids: Array[String] = []
	for option: Dictionary in offered:
		ids.append(option["id"])
	check_equal(ui.get_option_ids(), ids, "las respuestas son las de DialogueManager, en su orden")
	var items := ui.get_choices().get_items()
	for index in items.size():
		check(items[index].text.begins_with("%d. " % (index + 1)), "cada una lleva el número de su tecla")
		check(items[index].text.ends_with(offered[index]["label"]), "y su texto sin cambios")
	var telegram := ids.find("telegrama")
	check(telegram >= 0, "el segundo día Eusebio tiene algo a nombre del inspector")
	await _press_key((KEY_1 + telegram) as Key)
	await _read_until_choices()
	check(GameState.clues.has("copia_telegrama"), "la respuesta entrega su pista")
	check(GameState.testimonies.has("t_eusebio_telegrama"), "y registra su testimonio")
	check(GameState.asked_topics.has("eusebio/telegrama"), "y queda como preguntada")
	check(not ui.get_option_ids().has("telegrama"), "la condición de los datos la retira del menú")


func test_the_plate_never_attributes_the_choices_to_the_interlocutor() -> void:
	await _talk_to_eusebio()
	await _read_until_choices()
	var plate := ui.get_speaker_plate().get_text()
	check_equal(plate, DialogueChoices.TOPICS_HEADING, "en un interrogatorio, «Tus preguntas»")
	check(plate != GameData.get_character_name("eusebio"), "nunca el nombre del interlocutor")
	check_equal(ui.get_speaker(), "eusebio", "mientras se elige, la luz sigue en quien escucha")
	DialogueManager.close()
	await _wait(CLOSE_SECONDS)
	DialogueManager.play_scene("confrontacion")
	await _wait(OPEN_SECONDS)
	await _read_until_choices()
	check_equal(ui.get_speaker_plate().get_text(), DialogueChoices.REPLIES_HEADING, "en una escena, «Tus respuestas»")
	check_equal(ui.get_speaker(), "detective", "y en una escena la luz es del detective, como antes")


func test_choosing_returns_to_reading_with_the_answer() -> void:
	await _talk_to_eusebio()
	await _read_until_choices()
	var before := lines_shown
	await _press_key(KEY_1)
	check(not ui.is_choosing(), "tras elegir se vuelve a la lectura")
	check_equal(lines_shown, before + 1, "con la respuesta")
	check_equal(ui.get_speaker_plate().get_text(), GameData.get_character_name("eusebio"), "y la placa vuelve a quien habla")
	await _wait(DialogueStyle.MODE_SECONDS + 0.1)
	check(is_equal_approx(ui.get_dialogue_window().size.y, ui.get_target_height()), "la ventana recupera su alto de lectura")


func test_many_choices_scroll_and_keep_the_selection_visible() -> void:
	GameClock.day = 2
	for clue_id: String in GameData.clues:
		Investigation.discover_clue(clue_id)
	for testimony_id: String in GameData.testimonies:
		Investigation.record_testimony(testimony_id)
	DialogueManager.start("elena")
	await _wait(OPEN_SECONDS)
	await _read_until_choices()
	var choices := ui.get_choices()
	check(choices.get_count() >= DialogueStyle.COMPACT_CHOICES_FROM, "Elena tiene muchas preguntas con todo descubierto")
	check(choices.is_compact(), "las tarjetas se compactan")
	await _wait(DialogueStyle.MODE_SECONDS + 0.1)
	var view: Vector2 = ui.get_node("Root").size
	check(ui.get_dialogue_window().size.y <= view.y * DialogueStyle.MAX_WINDOW_RATIO + 1.0, "la ventana no tapa las caras de las siluetas")
	await _press("ui_up")
	await wait_physics_frames(3)
	var last := choices.get_items()[-1]
	check_equal(choices.get_selected_index(), choices.get_count() - 1, "arriba desde la primera señala la última")
	check(choices.get_global_rect().grow(1.0).encloses(last.get_global_rect()), "la lista se desplaza hasta la señalada")


func test_long_choice_labels_wrap_inside_their_card() -> void:
	var choices := ui.get_choices()
	var long_label := "Le repito la pregunta, porque las fechas no cuadran: si salió del salón antes del brindis y nadie la vio subir, ¿quién recogió la copa del despacho antes de que llegara la policía?"
	choices.show_options([{"id": "a", "label": long_label, "asked": false}, {"id": "b", "label": "Nada más.", "asked": true}])
	var card := choices.get_items()[0]
	var width := 900.0
	check(card.get_height_for_width(width) > DialogueChoiceItem.MIN_HEIGHT, "un texto largo pide más alto")
	check(card.get_height_for_width(width) > card.get_height_for_width(1460.0), "y más cuanto más estrecha es la tarjeta")
	check(card.autowrap_mode != TextServer.AUTOWRAP_OFF, "el texto se parte en líneas")
	choices.clear_options()


# --- Integración ---

func test_closing_returns_control_and_the_hud() -> void:
	var hud: Hud = game.get_node("Hud")
	await _wait(HUD_SECONDS)
	await _talk_to_eusebio()
	check(not hud.is_exploration_shown(), "durante la conversación el HUD se retira")
	await _read_until_choices()
	await _press_key(KEY_2)
	check(not DialogueManager.active, "«Terminar la conversación.» la cierra")
	check(not GameState.is_player_locked(), "el detective recupera el control en el acto")
	check(get_viewport().gui_get_focus_owner() == null or not ui.is_ancestor_of(get_viewport().gui_get_focus_owner()), "la conversación suelta el foco")
	await _wait(CLOSE_SECONDS)
	check(not ui.is_open(), "la ventana se desvanece")
	await _wait(HUD_SECONDS)
	check(hud.is_exploration_shown(), "y el HUD vuelve")


func test_other_screens_stay_closed_during_a_conversation() -> void:
	await _talk_to_eusebio()
	for action: String in ["open_journal", "open_board", "open_map", "pause", "wait_time"]:
		await _press(action)
	var journal: JournalUi = game.get_node("JournalUi")
	var board: BoardUi = game.get_node("BoardUi")
	var pause: PauseMenu = game.get_node("PauseMenu")
	check(not journal.is_open and not board.is_open and not pause.is_open, "ninguna tecla abre otra pantalla")
	check(DialogueManager.active and ui.is_open(), "y la conversación sigue")
	check_equal(GameClock.minutes, GameClock.DAY_START, "ni pasa el tiempo")


func test_notices_rise_above_the_conversation() -> void:
	var hud: Hud = game.get_node("Hud")
	check_equal(hud.get_notices_layer(), hud.layer, "explorando, los avisos van en la capa del HUD")
	await _talk_to_eusebio()
	EventBus.notification_requested.emit("Pista registrada", "Una prueba", "pista")
	await wait_physics_frames(3)
	check(hud.get_notices_layer() > ui.layer, "en una conversación, por encima de ella")
	var toasts := hud.get_toasts_container().get_global_rect()
	var view: Vector2 = hud.get_node("Root").size
	check(absf(toasts.get_center().x - view.x * 0.5) < 1.0, "centrados arriba, entre las siluetas")
	check(toasts.end.y < ui.get_dialogue_window().get_global_rect().position.y, "sin tapar la ventana")
	DialogueManager.close()
	await wait_physics_frames(3)
	check_equal(hud.get_notices_layer(), hud.layer, "al terminar vuelven a su capa")


func test_a_scene_that_follows_another_does_not_blink() -> void:
	DialogueManager.play_scene("intro")
	await _wait(OPEN_SECONDS)
	# Como la confrontación, que al terminar da paso al epílogo en el mismo instante.
	DialogueManager.close()
	DialogueManager.play_scene("dia_2")
	await wait_physics_frames(2)
	var dim: ColorRect = ui.get_node("Root/Dim")
	check(dim.color.a > DialogueStyle.DIM.a * 0.8, "el velo no se apaga entre una escena y otra")
	check(ui.get_dialogue_window().modulate.a > 0.9, "ni la ventana")
	check(ui.is_open() and DialogueManager.active, "y la nueva escena está en marcha")


func test_saving_waits_for_the_conversation_and_keeps_what_was_said() -> void:
	GameClock.day = 2
	SaveSystem.begin_session(self)
	await _talk_to_eusebio()
	check_equal(SaveSystem.get_save_blocker(), "Termina la conversación antes de guardar.", "no se guarda a mitad de una conversación")
	await _read_until_choices()
	await _press_key((KEY_1 + ui.get_option_ids().find("telegrama")) as Key)
	await _read_until_choices()
	await _press_key((KEY_1 + ui.get_option_ids().find(DialogueManager.EXIT_OPTION)) as Key)
	await _wait(CLOSE_SECONDS)
	check_equal(SaveSystem.get_save_blocker(), "", "al terminar ya se puede guardar")
	check(await save_and_wait("manual_1"), "la partida se guarda")
	SaveSystem.end_session(self)
	await _free_game()
	GameState.reset()
	GameClock.reset()
	check(SaveSystem.request_load("manual_1")["ok"], "la carga se prepara")
	game = await make_game()
	ui = game.get_node("DialogueUi")
	check(GameState.clues.has("copia_telegrama"), "la pista conseguida hablando se conserva")
	check(GameState.testimonies.has("t_eusebio_telegrama"), "y el testimonio")
	check(GameState.asked_topics.has("eusebio/telegrama"), "y lo que ya se preguntó")
	check(GameState.has_flag("eusebio_conocido"), "y la presentación hecha")
	check(not ui.is_open() and not DialogueManager.active, "la partida cargada empieza sin conversación abierta")


# --- Controles ---

func test_continue_follows_the_input_map() -> void:
	var saved := InputMap.action_get_events("interact")
	InputMap.action_erase_events("interact")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event("interact", key)
	await _talk_to_eusebio()
	check_equal(ui.get_continue_button().get_key_text(), "F", "la pestaña muestra la tecla asignada de verdad")
	InputMap.action_erase_events("interact")
	for event in saved:
		InputMap.action_add_event("interact", event)


# --- Navegación por las respuestas ---

func test_arrow_keys_move_the_selection_around_the_list() -> void:
	await _talk_to_eusebio()
	await _read_until_choices()
	var choices := ui.get_choices()
	check_equal(choices.get_count(), 2, "Eusebio ofrece una pregunta y la de salir")
	check_equal(choices.get_selected_index(), 0, "se empieza señalando la primera")
	await _press("ui_down")
	check_equal(choices.get_selected_index(), 1, "abajo señala la segunda")
	await _press("ui_down")
	check_equal(choices.get_selected_index(), 0, "desde la última se vuelve a la primera")
	await _press("ui_up")
	check_equal(choices.get_selected_index(), 1, "arriba desde la primera va a la última")
	await _wait(DialogueStyle.SELECT_SECONDS + 0.05)
	check(choices.get_items()[1].is_highlighted(), "la señalada se resalta")
	check(not choices.get_items()[0].is_highlighted(), "y sólo ella")
	check(DialogueManager.active and ui.is_choosing(), "moverse no elige nada")


func test_confirming_right_after_the_choices_appear_is_ignored() -> void:
	await _talk_to_eusebio()
	await _press("interact")
	await _press("interact")
	check(ui.is_choosing(), "tras la presentación aparecen las preguntas")
	await _press("interact")
	check(ui.is_choosing(), "una pulsación de más al terminar de leer no elige la primera")
	check(not GameState.asked_topics.has("eusebio/camino"), "y no se registra ninguna pregunta")
	await _wait(GUARD_SECONDS)
	await _press("interact")
	check(GameState.asked_topics.has("eusebio/camino"), "pasado el instante, E confirma la señalada")
	check(ui.is_typing() or ui.is_waiting_for_input(), "y se muestra la respuesta")


func test_number_keys_choose_even_from_the_keypad() -> void:
	await _talk_to_eusebio()
	await _read_until_choices()
	await _press_key(KEY_KP_1)
	check(GameState.asked_topics.has("eusebio/camino"), "el 1 del teclado numérico hace la primera pregunta")
	await _read_until_choices()
	await _press_key(KEY_9)
	check(ui.is_choosing() and DialogueManager.active, "un número sin respuesta no hace nada")
	await _press_key(KEY_2)
	check(not DialogueManager.active, "el 2 termina la conversación")


func test_hovering_highlights_and_only_a_click_chooses() -> void:
	await _talk_to_eusebio()
	await _read_until_choices()
	await _wait(GUARD_SECONDS)
	var items := ui.get_choices().get_items()
	await _move_mouse_to(items[1])
	check_equal(ui.get_choices().get_selected_index(), 1, "el ratón señala la tarjeta sobre la que pasa")
	check(DialogueManager.active and ui.is_choosing(), "pasar por encima no elige")
	await _click(items[0])
	check(GameState.asked_topics.has("eusebio/camino"), "el clic elige la pregunta")


func test_focus_returns_to_the_last_choice() -> void:
	await _talk_to_eusebio()
	await _read_until_choices()
	await _press_key(KEY_1)
	await _read_until_choices()
	check_equal(ui.get_choices().get_selected_id(), "camino", "al volver al menú, el foco está en la pregunta hecha")
	check(not ui.get_choices().get_items()[0].is_new, "y ya no se marca como nueva")


func test_closing_with_the_interact_key_does_not_reopen_the_conversation() -> void:
	check_equal(game.current_location.location_id, "estacion", "se empieza en la estación")
	var eusebio := game.current_location.get_npc("eusebio")
	check(eusebio != null, "Eusebio atiende la estación")
	if eusebio == null:
		return
	game.player.teleport(eusebio.global_position + Vector3(0.0, 0.1, 1.0))
	await wait_physics_frames(6)
	await _press("interact")
	check(DialogueManager.active, "E abre la conversación")
	await _wait(OPEN_SECONDS)
	await _read_until_choices()
	await _press("ui_down")
	await _wait(GUARD_SECONDS)
	await _press("interact")
	check(not DialogueManager.active, "E sobre «Terminar la conversación.» la cierra")
	await wait_physics_frames(4)
	check(not DialogueManager.active, "la misma pulsación no vuelve a abrirla")
	check(not GameState.is_player_locked(), "y el detective recupera el control")


# --- Diseño adaptable ---

func test_layout_fits_every_screen_shape() -> void:
	var root: Control = ui.get_node("Root")
	root.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# 16:9 (lo mismo a 1280 × 720, 1366 × 768, 1600 × 900 o 1920 × 1080), 4:3, 5:4, 16:10 y 21:9.
	for view: Vector2 in [Vector2(1920, 1080), Vector2(1440, 1080), Vector2(1350, 1080), Vector2(1920, 1200), Vector2(2560, 1080)]:
		root.size = view
		var label := "%dx%d" % [int(view.x), int(view.y)]
		DialogueManager.start("eusebio")
		await _wait(OPEN_SECONDS)
		var screen := Rect2(Vector2.ZERO, view)
		var window := ui.get_dialogue_window().get_global_rect()
		check(screen.encloses(window), label + ": la ventana cabe en la pantalla")
		check(window.size.x <= DialogueStyle.MAX_WIDTH + 0.5, label + ": sin pasar del ancho 16:9")
		check(absf(window.get_center().x - view.x * 0.5) < 1.0, label + ": centrada")
		var plate := ui.get_speaker_plate().get_global_rect()
		check(screen.encloses(plate), label + ": la placa se ve entera")
		check(plate.position.y < window.position.y and plate.end.y > window.position.y, label + ": montada sobre el borde superior")
		var paper := Rect2(window.position + ui.get_dialogue_window().get_paper_rect().position, ui.get_dialogue_window().get_paper_rect().size)
		var text := ui.get_dialogue_text().get_global_rect()
		check(paper.encloses(text), label + ": el texto queda dentro del pergamino")
		var tab := ui.get_continue_button().get_global_rect()
		check(window.encloses(tab), label + ": «Continuar» dentro de la ventana")
		check(text.end.y <= tab.position.y, label + ": el texto no pisa «Continuar»")
		check(ui.get_dialogue_text().get_line_count() <= DialogueStyle.TEXT_LINES, label + ": la intervención cabe")
		var detective := ui.get_cast().get_detective().get_global_rect()
		var portrait := ui.get_cast().get_portrait().get_global_rect()
		check(detective.position.y + detective.size.y * 0.4 < window.position.y, label + ": la cabeza del detective queda a la vista")
		check(portrait.position.y + portrait.size.y * 0.35 < window.position.y, label + ": y la de su interlocutor")
		check(detective.get_center().x < view.x * 0.5 and portrait.get_center().x > view.x * 0.5, label + ": cada uno a su lado")
		await _press("interact")
		await _press("interact")
		await _wait(DialogueStyle.MODE_SECONDS + 0.1)
		check(ui.is_choosing(), label + ": aparecen las preguntas")
		window = ui.get_dialogue_window().get_global_rect()
		check(screen.encloses(window), label + ": con las preguntas la ventana sigue dentro")
		var list := ui.get_choices().get_global_rect()
		check(window.encloses(list), label + ": la lista queda dentro de la ventana")
		for card in ui.get_choices().get_items():
			var card_rect := card.get_global_rect()
			check(list.grow(0.5).encloses(card_rect), label + ": cada tarjeta cabe en la lista")
		var hint := ui.get_choice_hint().get_global_rect()
		check(window.encloses(hint) and hint.position.y >= list.end.y, label + ": la ayuda va al pie, bajo las respuestas")
		DialogueManager.close()
		await _wait(CLOSE_SECONDS)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
