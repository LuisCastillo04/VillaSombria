extends TestCase
## Las modalidades de diálogo con la escena de juego real y entradas como las del jugador: la sección
## plegable «Preguntas realizadas», el estado de cada tarjeta, el foco cuando una pregunta cambia de
## sección, las preguntas bloqueadas del diálogo único, el aviso sin preguntas pendientes, el cambio
## de modalidad desde Configuración, salir de un lugar y volver, los indicadores de los personajes y
## el historial del expediente.

const OPEN_SECONDS := DialogueStyle.OPEN_SECONDS + 0.1
const CLOSE_SECONDS := DialogueStyle.CLOSE_SECONDS + 0.15
const GUARD_SECONDS := DialogueStyle.CONFIRM_GUARD_SECONDS + 0.1

var game: Game
var ui: DialogueUi


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()
	game = await make_game()
	ui = game.get_node("DialogueUi")


func after_each() -> void:
	if DialogueManager.active:
		DialogueManager.close()
	Settings.set_value(ConversationLog.MODE_KEY, SettingsSchema.default_value(ConversationLog.MODE_KEY))
	if game != null:
		game.queue_free()
		game = null
		ui = null
		await get_tree().process_frame
	SaveSystem.take_pending_load()
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	TestCase.clear_save_storage()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


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
	var motion := InputEventMouseMotion.new()
	motion.position = spot
	motion.global_position = spot
	motion.relative = Vector2(3.0, 0.0)
	get_viewport().push_input(motion, true)
	await wait_physics_frames(2)
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = spot
		click.global_position = spot
		get_viewport().push_input(click, true)
	await wait_physics_frames(2)


## Pulsa la tecla de interactuar hasta que aparezcan las respuestas.
func _read_until_choices() -> void:
	for attempt in 60:
		if ui.is_choosing() or not DialogueManager.active:
			await _wait(GUARD_SECONDS)
			return
		await _press("interact")
	failures.append("no aparecieron las respuestas")


func _talk_to(npc_id: String) -> void:
	DialogueManager.start(npc_id)
	await _wait(OPEN_SECONDS)
	await _read_until_choices()


## Elige con su tecla numérica (la que muestra la tarjeta) y oye la respuesta entera.
func _ask_with_number(topic_id: String) -> void:
	var item := ui.get_choices().get_item(topic_id)
	if item == null or item.number <= 0:
		failures.append("«%s» no tiene número" % topic_id)
		return
	await _press_key((KEY_1 + item.number - 1) as Key)
	await _read_until_choices()


func _close_conversation() -> void:
	DialogueManager.close()
	await _wait(CLOSE_SECONDS)


func _set_mode(mode: String) -> void:
	Settings.set_value(ConversationLog.MODE_KEY, mode)


## El estado de la partida sin el tiempo jugado, que corre solo.
func _progress() -> Dictionary:
	var state := GameState.to_dict()
	state.erase("play_seconds")
	return state


func _focused_item() -> Control:
	return get_viewport().gui_get_focus_owner()


# --- Diálogo inteligente ---

func test_smart_mode_groups_asked_questions_behind_a_folded_section() -> void:
	await _talk_to("eusebio")
	var choices := ui.get_choices()
	check(not choices.has_section(), "sin preguntas hechas no hay sección")
	await _ask_with_number("camino")
	check(choices.has_section(), "hecha una, aparece «Preguntas realizadas»")
	check(not choices.is_section_expanded(), "plegada por defecto")
	check_equal(choices.get_section().get_count(), 1, "con la pregunta hecha")
	check(not choices.get_item("camino").visible, "la pregunta hecha no se ve")
	check(choices.get_item("camino").number == 0, "ni lleva número")
	check_equal(choices.get_item(DialogueManager.EXIT_OPTION).number, 1, "la de salir es ahora la primera")
	check_equal(choices.get_notice_text(), DialogueChoices.EMPTY_NOTICE, "sin preguntas pendientes, el aviso discreto")
	var item := choices.get_item("camino")
	check_equal(item.state, ConversationLog.DONE, "la tarjeta se marca como realizada")
	check(item.is_repeatable, "y repetible")


func test_smart_mode_lets_the_player_repeat_from_the_section() -> void:
	await _talk_to("eusebio")
	await _ask_with_number("camino")
	var choices := ui.get_choices()
	check(choices.is_section_focused(), "sin pendientes, el foco empieza en la sección")
	await _press("ui_right")
	check(choices.is_section_expanded(), "→ la despliega")
	check(choices.get_item("camino").visible, "la pregunta hecha se ve")
	check_equal(choices.get_item("camino").number, 1, "y se puede elegir con su número")
	await _press("ui_down")
	check_equal(choices.get_selected_id(), "camino", "↓ pasa de la cabecera a la pregunta hecha")
	await _press("interact")
	check_equal(DialogueManager.get_current_topic(), "camino", "y repetirla reproduce su respuesta")
	await _read_until_choices()
	check_equal(ConversationLog.times_asked("eusebio", "camino"), 2, "la repetición se cuenta")
	check(choices.is_section_expanded(), "la sección sigue como la dejó el jugador")
	check_equal(choices.get_selected_id(), "camino", "y el foco vuelve a la pregunta repetida")
	await _press("ui_left")
	check(not choices.is_section_expanded(), "← la pliega")
	check(choices.is_section_focused(), "y el foco, que estaba dentro, vuelve a la cabecera")


func test_focus_moves_on_when_a_question_changes_section() -> void:
	GameState.set_flag("llamada_atendida")
	await game.go_to("mansion", "desde_plaza")
	Investigation.discover_clue("llave_reloj")
	await _talk_to("anselmo")
	var choices := ui.get_choices()
	check_equal(choices.get_selected_id(), "coartada", "se empieza en la primera pregunta")
	await _ask_with_number("coartada")
	check(not choices.get_item("coartada").visible, "la hecha pasa a la sección plegada")
	check_equal(choices.get_selected_id(), choices.get_visible_option_ids()[0], "el foco no se pierde: va a la primera pendiente")
	check(choices.get_item(choices.get_selected_id()).state == ConversationLog.PENDING, "que es una pregunta pendiente")
	var visible_numbers: Array[int] = []
	for item in choices.get_items():
		if item.visible:
			visible_numbers.append(item.number)
	check_equal(visible_numbers, range(1, visible_numbers.size() + 1), "los números siguen seguidos, sin huecos")
	await _press("ui_up")
	check(_focused_item() is DialogueChoiceItem and (_focused_item() as DialogueChoiceItem).option_id == DialogueManager.EXIT_OPTION, "↑ desde la primera da la vuelta hasta la de salir")
	await _press("ui_up")
	check(choices.is_section_focused(), "la cabecera también se recorre con las flechas")


func test_a_new_question_is_tagged_and_shown_first() -> void:
	GameState.set_flag("llamada_atendida")
	await game.go_to("mansion", "desde_plaza")
	await _talk_to("elena")
	await _ask_with_number("coartada")
	await _close_conversation()
	Investigation.discover_clue("billete_tren")
	await _talk_to("elena")
	var choices := ui.get_choices()
	var billete := choices.get_item("billete")
	check(billete != null and billete.is_fresh, "la pregunta desbloqueada por el billete lleva «Nuevo»")
	check(not choices.get_item("marido").is_fresh, "la que ya estaba, no")
	check(choices.get_visible_option_ids().find("billete") < choices.get_visible_option_ids().find(DialogueManager.EXIT_OPTION), "y aparece entre las pendientes, antes de la de salir")


# --- Diálogo único ---

func test_single_mode_shows_asked_questions_locked() -> void:
	_set_mode(ConversationLog.MODE_SINGLE)
	await _talk_to("eusebio")
	await _ask_with_number("camino")
	var choices := ui.get_choices()
	choices.set_section_expanded(true)
	await wait_physics_frames(2)
	var item := choices.get_item("camino")
	check(item.visible, "desplegada, la pregunta hecha se ve")
	check(item.is_locked(), "bloqueada")
	check_equal(item.number, 0, "sin número")
	check_equal(item.focus_mode, Control.FOCUS_NONE, "sin foco")
	check(ui.get_choice_hint().get_text().contains("expediente"), "el pie recuerda que lo respondido se relee en el expediente")
	await _press("ui_down")
	check(not item.has_focus(), "las flechas se la saltan")
	await _click(item)
	check(DialogueManager.get_current_topic().is_empty(), "un clic no la elige")
	await _press_key(KEY_2)
	check(DialogueManager.get_current_topic().is_empty(), "ni un número")
	check_equal(ConversationLog.times_asked("eusebio", "camino"), 1, "sigue contada una vez")


# --- Modalidad libre y cambios de modalidad ---

func test_free_mode_keeps_everything_in_place() -> void:
	_set_mode(ConversationLog.MODE_FREE)
	await _talk_to("eusebio")
	await _ask_with_number("camino")
	var choices := ui.get_choices()
	check(not choices.has_section(), "no hay sección de realizadas")
	check(choices.get_item("camino").visible, "la pregunta hecha sigue en su sitio")
	check_equal(choices.get_item("camino").number, 1, "con su número")
	check_equal(choices.get_item("camino").state, ConversationLog.DONE, "pero se ve como realizada")
	check_equal(choices.get_selected_id(), "camino", "y el foco vuelve a ella")


func test_switching_modes_from_the_settings_menu() -> void:
	await _talk_to("eusebio")
	await _ask_with_number("camino")
	await _close_conversation()
	# La misma Configuración de la pausa (y del menú principal), sin abrir la pausa.
	var settings: SettingsMenu = game.get_node("PauseMenu").get_node("Root/SettingsMenu")
	settings.refresh()
	var selector := settings.get_selector(ConversationLog.MODE_KEY)
	check(selector != null, "Configuración → Jugabilidad tiene el sistema de diálogos")
	check_equal(selector.get_value(), ConversationLog.MODE_SMART, "en diálogo inteligente por defecto")
	var details := {}
	for mode in ConversationLog.MODES:
		selector.set_value_no_signal(mode)
		selector.value_changed.emit(mode)
		await get_tree().process_frame
		check_equal(ConversationLog.mode(), mode, "el selector cambia la modalidad a %s" % mode)
		details[selector.get_detail_text()] = true
		await _talk_to("eusebio")
		var item := ui.get_choices().get_item("camino")
		match mode:
			ConversationLog.MODE_FREE:
				check(item.visible and item.state == ConversationLog.DONE, "libre: en su sitio")
			ConversationLog.MODE_SMART:
				check(not item.visible and item.state == ConversationLog.DONE, "inteligente: apartada y repetible")
			ConversationLog.MODE_SINGLE:
				check(not item.visible and item.is_locked(), "única: apartada y bloqueada")
		check(ConversationLog.was_asked("eusebio", "camino"), "%s: el progreso no se pierde" % mode)
		await _close_conversation()
	check_equal(details.size(), 3, "la explicación cambia con cada modalidad")


# --- Escenarios, personajes y expediente ---

func test_leaving_and_coming_back_keeps_the_progress() -> void:
	await _talk_to("eusebio")
	await _ask_with_number("camino")
	await _close_conversation()
	await game.go_to("plaza", "")
	await wait_physics_frames(3)
	await game.go_to("estacion", "")
	await wait_physics_frames(3)
	check(ConversationLog.was_asked("eusebio", "camino"), "volver a la estación no reinicia nada")
	await _talk_to("eusebio")
	check_equal(ui.get_choices().get_item("camino").state, ConversationLog.DONE, "la pregunta sigue hecha")
	check_equal(ui.get_choices().get_notice_text(), DialogueChoices.EMPTY_NOTICE, "y Eusebio sigue sin preguntas nuevas")


func test_characters_show_their_progress() -> void:
	var eusebio := game.current_location.get_npc("eusebio")
	var interaction := eusebio.interaction
	check(interaction.get_marker().is_shown(), "con preguntas pendientes su rombo se ve a distancia")
	check_equal(interaction.get_status_kind(), ConversationLog.STATUS_PENDING, "tiene preguntas pendientes")
	await _talk_to("eusebio")
	await _ask_with_number("camino")
	await _close_conversation()
	await wait_physics_frames(2)
	check(not interaction.get_marker().is_shown() or interaction.get_marker().has_emphasis() == false, "sin pendientes, el rombo no llama la atención")
	check_equal(interaction.get_status_text(), ConversationLog.STATUS_LABELS[ConversationLog.STATUS_WAITING], "«Sin novedades por ahora»: la investigación aún puede abrir algo")
	GameClock.start_next_day()
	await wait_physics_frames(2)
	check_equal(interaction.get_status_kind(), ConversationLog.STATUS_NEW, "al día siguiente tiene algo nuevo a nombre del inspector")
	check(interaction.get_marker().has_emphasis(), "y su rombo destaca")
	var player := game.player
	var front := eusebio.global_position + Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, eusebio.model.rotation.y)
	player.teleport(front, 0.0)
	var prompt := (game.get_node("Hud") as Hud).get_prompt()
	for frame in 30:
		await get_tree().physics_frame
		if not prompt.get_status_text().is_empty():
			break
	check_equal(prompt.get_status_text(), ConversationLog.STATUS_LABELS[ConversationLog.STATUS_NEW], "al acercarse, el aviso lo dice")


func test_the_journal_history_never_replays_anything() -> void:
	GameClock.day = 2
	await _talk_to("eusebio")
	await _ask_with_number("telegrama")
	await _close_conversation()
	var before := _progress()
	var events: Array[String] = []
	var listener := func(_a: Variant = null, _b: Variant = null) -> void: events.append("señal")
	for progress: Signal in [EventBus.clue_discovered, EventBus.testimony_recorded, EventBus.flag_set, EventBus.conversation_recorded]:
		progress.connect(listener)
	var journal: JournalUi = game.get_node("JournalUi")
	journal.open(JournalUi.Tab.INTERROGATIONS)
	await wait_physics_frames(3)
	var section := journal.get_section(JournalUi.Tab.INTERROGATIONS) as JournalInterrogationsSection
	check_equal(section.list.get_entry_ids(), PackedStringArray(["eusebio/telegrama#base"]), "el historial tiene la pregunta hecha")
	var texts := "\n".join(section.detail.get_field_texts())
	check(texts.contains(GameData.get_dialogue("eusebio")["topics"][1]["label"]), "con la pregunta")
	check(texts.contains("Conozco su voz desde hace treinta años"), "la respuesta tal como se oyó")
	check(texts.contains(GameData.testimonies["t_eusebio_telegrama"]["topic"]), "y lo que aportó")
	journal.close()
	await wait_physics_frames(3)
	for progress: Signal in [EventBus.clue_discovered, EventBus.testimony_recorded, EventBus.flag_set, EventBus.conversation_recorded]:
		progress.disconnect(listener)
	check_equal(events, [] as Array[String], "consultarlo no ejecuta nada")
	check_equal(_progress(), before, "ni cambia la partida")
	check(not DialogueManager.active, "ni abre la conversación")
