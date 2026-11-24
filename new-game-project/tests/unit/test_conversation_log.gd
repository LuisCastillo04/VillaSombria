extends TestCase
## Registro de los interrogatorios y modalidades de diálogo, sin interfaz: cuándo cuenta una pregunta
## como hecha, las variantes como conversaciones independientes, el orden y el estado de cada
## pregunta en las tres modalidades, el bloqueo de la modalidad única, los desbloqueos y que repetir
## nunca duplique pistas, testimonios, avisos ni tiempo.

var last_options: Array = []
var lines: Array[String] = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()
	last_options = []
	lines = []
	DialogueManager.options_shown.connect(_on_options)
	DialogueManager.line_shown.connect(_on_line)


func after_each() -> void:
	DialogueManager.close()
	DialogueManager.options_shown.disconnect(_on_options)
	DialogueManager.line_shown.disconnect(_on_line)
	Settings.set_value(ConversationLog.MODE_KEY, SettingsSchema.default_value(ConversationLog.MODE_KEY))
	GameState.reset()
	GameClock.reset()
	TownMap.reset()


func _on_options(options: Array) -> void:
	last_options = options


func _on_line(_speaker: String, text: String) -> void:
	lines.append(text)


func _read_until_menu() -> void:
	last_options = []
	var guard := 0
	while DialogueManager.active and last_options.is_empty() and guard < 200:
		DialogueManager.advance()
		guard += 1


func _ask(npc_id: String, topic_id: String) -> void:
	DialogueManager.start(npc_id)
	_read_until_menu()
	DialogueManager.choose(topic_id)
	_read_until_menu()
	DialogueManager.close()


func _set_mode(mode: String) -> void:
	Settings.set_value(ConversationLog.MODE_KEY, mode)


func _ids(entries: Array) -> Array:
	return entries.map(func(entry: Dictionary) -> String: return entry["id"])


func _entry(entries: Array, topic_id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if entry["id"] == topic_id:
			return entry
	return {}


# --- Cuándo cuenta una pregunta como hecha ---

func test_a_question_counts_only_when_its_answer_ends() -> void:
	DialogueManager.start("anselmo")
	_read_until_menu()
	DialogueManager.choose("coartada")
	check_equal(DialogueManager.get_current_topic(), "coartada", "se está oyendo la respuesta")
	check(not ConversationLog.was_asked("anselmo", "coartada"), "a mitad de la respuesta no cuenta como hecha")
	_read_until_menu()
	check(ConversationLog.was_asked("anselmo", "coartada"), "oída entera, sí")
	check(DialogueManager.get_current_topic().is_empty(), "y ya no hay respuesta en curso")
	var record: Dictionary = GameState.conversations["anselmo/coartada"]["variants"][ConversationLog.BASE_VARIANT]
	check_equal(record["count"], 1, "una vez")
	check_equal(record["day"], 1, "con el día")
	check_equal(record["minutes"], GameClock.DAY_START, "y la hora en que se completó, antes de su coste")
	check_equal(record.get("gained", {}).get("testimonies", []), ["t_anselmo_brindis"], "y lo que entregó")


func test_an_interrupted_question_stays_pending() -> void:
	DialogueManager.start("elena")
	_read_until_menu()
	DialogueManager.choose("coartada")
	DialogueManager.close()
	check(not ConversationLog.was_asked("elena", "coartada"), "cortada a mitad, no se registra")
	check(not GameState.testimonies.has("t_elena_jaqueca"), "ni se aplican sus consecuencias")
	check(DialogueManager.has_new_topics("elena"), "sigue pendiente")
	_ask("elena", "coartada")
	check(GameState.testimonies.has("t_elena_jaqueca"), "y se puede completar después")


func test_variants_are_independent_conversations() -> void:
	GameClock.day = 2
	_ask("ortega", "informe")
	check(ConversationLog.is_variant_done("ortega", "informe", "pendiente"), "hecha la del informe que no ha llegado")
	check_equal(_entry(DialogueManager.get_topic_menu("ortega"), "informe").get("state"), ConversationLog.DONE, "esa variante ya no está pendiente")
	GameState.set_flag("informe_llegado")
	var entry := _entry(DialogueManager.get_topic_menu("ortega"), "informe")
	check_equal(entry["variant"], "llegado", "con el correo, la pregunta ofrece la variante nueva")
	check_equal(entry["state"], ConversationLog.PENDING, "como una conversación pendiente")
	var before := GameClock.minutes
	_ask("ortega", "informe")
	check(GameState.clues.has("informe_forense"), "la variante nueva entrega el informe")
	check_equal(GameClock.minutes, before + DialogueManager.TOPIC_MINUTES, "y cuesta lo que una pregunta nueva")


# --- Modalidades ---

func test_free_mode_keeps_the_data_order() -> void:
	_set_mode(ConversationLog.MODE_FREE)
	_ask("anselmo", "coartada")
	var menu := DialogueManager.get_topic_menu("anselmo")
	check_equal(_ids(menu), _ids(DialogueManager.get_available_topics("anselmo")), "las mismas preguntas, en el orden de los datos")
	check_equal(_entry(menu, "coartada")["state"], ConversationLog.DONE, "la hecha se marca como realizada")
	check_equal(_entry(menu, "coartada")["section"], ConversationLog.SECTION_MAIN, "pero sigue en su sitio")


func test_smart_mode_puts_new_questions_first() -> void:
	_set_mode(ConversationLog.MODE_SMART)
	_ask("anselmo", "coartada")
	var menu := DialogueManager.get_topic_menu("anselmo")
	check_equal(menu[0]["state"], ConversationLog.PENDING, "primero las pendientes")
	check_equal(menu[-1]["id"], "coartada", "la hecha, al final")
	check_equal(menu[-1]["section"], ConversationLog.SECTION_ASKED, "en «Preguntas realizadas»")
	check(_ids(menu).has("despues"), "y la que desbloqueó, entre las pendientes")
	check_equal(_entry(menu, "despues")["section"], ConversationLog.SECTION_MAIN, "en la parte principal")


func test_smart_mode_lets_the_player_repeat() -> void:
	_set_mode(ConversationLog.MODE_SMART)
	_ask("anselmo", "coartada")
	lines.clear()
	_ask("anselmo", "coartada")
	check(lines.size() >= 2, "repetirla vuelve a reproducir la respuesta")
	check_equal(ConversationLog.times_asked("anselmo", "coartada"), 2, "y se cuenta")


func test_single_mode_locks_what_was_asked() -> void:
	_set_mode(ConversationLog.MODE_SINGLE)
	_ask("anselmo", "coartada")
	var entry := _entry(DialogueManager.get_topic_menu("anselmo"), "coartada")
	check_equal(entry["state"], ConversationLog.LOCKED, "la hecha queda bloqueada")
	check_equal(entry["section"], ConversationLog.SECTION_ASKED, "dentro de «Preguntas realizadas»")
	lines.clear()
	DialogueManager.start("anselmo")
	_read_until_menu()
	var before := lines.size()
	DialogueManager.choose("coartada")
	check_equal(lines.size(), before, "elegirla no reproduce nada")
	check(DialogueManager.get_current_topic().is_empty(), "ni empieza ninguna respuesta")
	check_equal(ConversationLog.times_asked("anselmo", "coartada"), 1, "ni se cuenta otra vez")
	DialogueManager.close()


func test_single_mode_reopens_a_new_variant() -> void:
	_set_mode(ConversationLog.MODE_SINGLE)
	GameClock.day = 2
	_ask("ortega", "informe")
	check_equal(_entry(DialogueManager.get_topic_menu("ortega"), "informe")["state"], ConversationLog.LOCKED, "«todavía no» queda bloqueada")
	GameState.set_flag("informe_llegado")
	var entry := _entry(DialogueManager.get_topic_menu("ortega"), "informe")
	check_equal(entry["state"], ConversationLog.PENDING, "la variante con el informe se puede hacer")
	check_equal(entry["section"], ConversationLog.SECTION_MAIN, "como una pregunta nueva")
	_ask("ortega", "informe")
	check(GameState.clues.has("informe_forense"), "y entrega el informe")


func test_repeatable_conversations_are_never_locked() -> void:
	GameClock.day = 3
	GameState.deductions.append("d_hora_falsa")
	var actions: Array[String] = []
	var listener := func(action: String) -> void: actions.append(action)
	EventBus.story_action.connect(listener)
	for mode in ConversationLog.MODES:
		_set_mode(mode)
		_ask("ortega", "acusar")
		var entry := _entry(DialogueManager.get_topic_menu("ortega"), "acusar")
		check(entry["state"] != ConversationLog.LOCKED, "%s: reunir a los sospechosos no se bloquea" % mode)
		check_equal(entry["section"], ConversationLog.SECTION_MAIN, "%s: y sigue en la parte principal" % mode)
	EventBus.story_action.disconnect(listener)
	check_equal(actions.count("open_accusation"), 3, "cada vez abre la acusación")


# --- Repetir sin duplicar ---

func test_repeating_never_reapplies_consequences() -> void:
	for mode in [ConversationLog.MODE_FREE, ConversationLog.MODE_SMART]:
		GameState.reset()
		GameClock.reset()
		_set_mode(mode)
		GameClock.day = 2
		Investigation.discover_clue("billete_tren")
		_ask("eusebio", "elena")
		var clues := GameState.clues.duplicate()
		var testimonies := GameState.testimonies.duplicate()
		var minutes := GameClock.minutes
		var events: Array[String] = []
		var on_clue := func(id: String) -> void: events.append("pista " + id)
		var on_testimony := func(id: String) -> void: events.append("testimonio " + id)
		var on_flag := func(id: String) -> void: events.append("marca " + id)
		var on_notice := func(title: String, _body: String, _kind: String) -> void: events.append("aviso " + title)
		EventBus.clue_discovered.connect(on_clue)
		EventBus.testimony_recorded.connect(on_testimony)
		EventBus.flag_set.connect(on_flag)
		EventBus.notification_requested.connect(on_notice)
		_ask("eusebio", "elena")
		_ask("eusebio", "elena")
		EventBus.clue_discovered.disconnect(on_clue)
		EventBus.testimony_recorded.disconnect(on_testimony)
		EventBus.flag_set.disconnect(on_flag)
		EventBus.notification_requested.disconnect(on_notice)
		check_equal(events, [] as Array[String], "%s: repetir no vuelve a entregar ni a avisar de nada" % mode)
		check_equal(GameState.clues, clues, "%s: las pistas no se duplican" % mode)
		check_equal(GameState.testimonies, testimonies, "%s: los testimonios tampoco" % mode)
		check_equal(GameClock.minutes, minutes, "%s: ni pasa el tiempo" % mode)
		check_equal(ConversationLog.times_asked("eusebio", "elena"), 3, "%s: pero se cuenta cada vez" % mode)
		var gained: Dictionary = GameState.conversations["eusebio/elena"]["variants"][ConversationLog.BASE_VARIANT]["gained"]
		check_equal(gained.get("clues", []), ["registro_billetes"], "%s: lo obtenido sigue siendo lo de la primera vez" % mode)


# --- Desbloqueos ---

func test_evidence_unlocks_a_follow_up_question() -> void:
	DialogueManager.start("elena")
	_read_until_menu()
	check(not _ids(last_options).has("billete"), "sin el billete no se le puede preguntar por él")
	DialogueManager.close()
	Investigation.discover_clue("billete_tren")
	check(DialogueManager.has_new_topics("elena"), "la pista le abre una conversación nueva")
	DialogueManager.start("elena")
	_read_until_menu()
	var entry := _entry(last_options, "billete")
	check_equal(entry.get("state"), ConversationLog.PENDING, "la pregunta del billete aparece pendiente")
	check(entry.get("fresh", false), "y marcada como nueva: ya se había hablado con Elena")
	check(not _entry(last_options, "coartada").get("fresh", true), "lo que ya estaba la primera vez no es nuevo")
	DialogueManager.choose("coartada")
	_read_until_menu()
	check(_entry(last_options, "billete").get("fresh", false), "sigue siendo nueva durante la conversación")
	DialogueManager.close()
	DialogueManager.start("elena")
	_read_until_menu()
	check(not _entry(last_options, "billete").get("fresh", true), "en la conversación siguiente ya no")
	check_equal(_entry(last_options, "billete").get("state"), ConversationLog.PENDING, "aunque siga pendiente")


func test_the_first_meeting_marks_nothing_as_new() -> void:
	DialogueManager.start("anselmo")
	_read_until_menu()
	check(last_options.all(func(option: Dictionary) -> bool: return not option.get("fresh", false)), "en la primera conversación nada es «Nuevo»")
	DialogueManager.choose("coartada")
	_read_until_menu()
	check(_entry(last_options, "despues").get("fresh", false), "lo que desbloquea una respuesta durante ella sí")


func test_conditions_on_conversations_and_places() -> void:
	check(not Conditions.check({"asked": ["irene/quien"]}), "sin hablar con Irene")
	check(Conditions.check({"not_asked": ["irene/quien"]}), "not_asked se cumple antes")
	_ask("irene", "quien")
	check(Conditions.check({"asked": ["irene/quien"]}), "asked se cumple al completar la conversación")
	check(not Conditions.check({"not_asked": ["irene/quien"]}), "y not_asked deja de cumplirse")
	check(not Conditions.check({"visited": ["archivo"]}), "sin pisar el archivo")
	TownMap._on_location_changed("archivo")
	check(Conditions.check({"visited": ["archivo"]}), "visited se cumple al visitarlo")
	check(Conditions.check({"any": [{"visited": ["mansion"]}, {"asked": ["irene/quien"]}]}), "y se combinan con any")


# --- Situación de cada personaje ---

func test_npc_status_follows_the_investigation() -> void:
	GameState.set_flag("llamada_atendida")
	check_equal(ConversationLog.npc_status("rosa"), ConversationLog.STATUS_PENDING, "sin hablar con ella, tiene preguntas pendientes")
	_ask("rosa", "pueblo")
	_ask("rosa", "pension")
	check_equal(ConversationLog.npc_status("rosa"), ConversationLog.STATUS_WAITING, "hecho lo disponible, la investigación aún puede abrir algo")
	GameState.set_flag("hablo_marcos")
	check_equal(ConversationLog.npc_status("rosa"), ConversationLog.STATUS_NEW, "hablar con Marcos le abre una pregunta nueva")
	DialogueManager.start("rosa")
	_read_until_menu()
	DialogueManager.close()
	check_equal(ConversationLog.npc_status("rosa"), ConversationLog.STATUS_PENDING, "vista en su menú, ya sólo está pendiente")
	_ask("rosa", "marcos")
	GameState.set_flag("hablo_irene")
	_ask("rosa", "irene")
	check_equal(ConversationLog.npc_status("rosa"), ConversationLog.STATUS_DONE, "con todo hecho, el interrogatorio está completo")
	for mode in ConversationLog.MODES:
		_set_mode(mode)
		check_equal(ConversationLog.npc_status("rosa"), ConversationLog.STATUS_DONE, "%s: la situación no depende de la modalidad" % mode)


func test_questions_closed_for_good_do_not_keep_a_character_waiting() -> void:
	GameClock.day = 2
	check(not ConversationLog.can_still_open("hilario", ConversationLog.find_topic("hilario", "domingo")), "la pregunta del domingo no vuelve el lunes")
	check(ConversationLog.can_still_open("hilario", ConversationLog.find_topic("hilario", "recortes")), "la de los recortes aún puede abrirse")
	_ask("eusebio", "telegrama")
	check(not ConversationLog.can_still_open("eusebio", ConversationLog.find_topic("eusebio", "telegrama")), "una pregunta que sus datos retiran al hacerla no vuelve")
	check(Conditions.is_closed({"day_max": 1}), "un día pasado no vuelve")
	check(not Conditions.is_closed({"clues": ["billete_tren"]}), "una pista que falta todavía puede llegar")
	check(Conditions.is_closed({"not_clues": ["copia_telegrama"]}), "una pista que ya se tiene no se pierde")
	check(not Conditions.is_closed({"any": [{"day_max": 1}, {"clues": ["billete_tren"]}]}), "any sólo se cierra si se cierran todas")


## Con una pregunta de prueba cuyas consecuencias no son idempotentes (un aviso y una acción), repetirla
## demostraría cualquier duplicado; una conversación repetible, en cambio, las repite a propósito.
func test_one_time_events_never_run_twice() -> void:
	GameData._dialogues["prueba_eventos"] = {
		"intro": [{"lines": [{"s": "narrador", "t": "Prueba."}]}],
		"topics": [
			{"id": "unica", "label": "Una vez.", "lines": [{"s": "narrador", "t": "Una."}],
				"effects": {"notify": {"title": "Aviso único", "body": ""}, "flags": ["prueba_unica"]}},
			{"id": "siempre", "label": "Cada vez.", "repeatable": true, "lines": [{"s": "narrador", "t": "Otra."}],
				"effects": {"notify": {"title": "Aviso repetible", "body": ""}}},
		],
	}
	var notices: Array[String] = []
	var listener := func(title: String, _body: String, _kind: String) -> void: notices.append(title)
	EventBus.notification_requested.connect(listener)
	for mode in [ConversationLog.MODE_FREE, ConversationLog.MODE_SMART]:
		_set_mode(mode)
		_ask("prueba_eventos", "unica")
		_ask("prueba_eventos", "siempre")
	EventBus.notification_requested.disconnect(listener)
	GameData._dialogues.erase("prueba_eventos")
	check_equal(notices.count("Aviso único"), 1, "el aviso de una conversación ya hecha no se repite")
	check_equal(notices.count("Aviso repetible"), 2, "el de una conversación repetible, sí")
	check_equal(ConversationLog.times_asked("prueba_eventos", "unica"), 2, "aunque la pregunta se repitió")

