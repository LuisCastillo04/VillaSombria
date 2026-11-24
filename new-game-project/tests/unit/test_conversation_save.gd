extends TestCase
## Progreso de los interrogatorios en las partidas guardadas: viaja con cada ranura, lo incluyen el
## guardado manual y el automático, una partida nueva empieza sin él, las partidas anteriores al
## registro lo recuperan de lo que ya guardaban (sin inventar conversaciones) y un registro dañado
## nunca impide cargar.

var last_options: Array = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	SaveSystem.begin_session(self)
	last_options = []
	DialogueManager.options_shown.connect(_on_options)


func after_each() -> void:
	DialogueManager.options_shown.disconnect(_on_options)
	DialogueManager.close()
	SaveSystem.end_session(self)
	SaveSystem.take_pending_load()
	TestCase.clear_save_storage()
	Settings.set_value(ConversationLog.MODE_KEY, SettingsSchema.default_value(ConversationLog.MODE_KEY))
	GameState.reset()
	GameClock.reset()


func _on_options(options: Array) -> void:
	last_options = options


func _read_until_menu() -> void:
	last_options = []
	var guard := 0
	while DialogueManager.active and last_options.is_empty() and guard < 200:
		DialogueManager.advance()
		guard += 1


## Hace una pregunta entera, como el jugador: abre la conversación, elige y oye la respuesta.
func _ask(npc_id: String, topic_id: String) -> void:
	DialogueManager.start(npc_id)
	_read_until_menu()
	DialogueManager.choose(topic_id)
	_read_until_menu()
	DialogueManager.close()


func _state_in(slot_id: String) -> Dictionary:
	var result := SaveSystem.read_slot(slot_id)
	if result["status"] != SaveFormat.Status.OK:
		return {"error": result["error"]}
	return result["document"]["sections"]["state"]


func _load(slot_id: String) -> bool:
	var result := SaveSystem.read_slot(slot_id)
	if result["status"] != SaveFormat.Status.OK:
		return false
	SaveSystem.apply_sections(result["document"]["sections"])
	return true


## Partida como las que escribía el juego antes del registro: sólo `asked_topics`.
func _legacy_document(asked: Array, clues: Array, testimonies: Array, extra: Dictionary = {}) -> Dictionary:
	var state := {
		"flags": [], "clues": clues, "testimonies": testimonies, "deductions": [],
		"asked_topics": asked, "hypotheses": {}, "location_id": "mansion", "spawn_id": "",
		"accusation_attempts": 0,
	}
	state.merge(extra, true)
	return SaveFormat.build({"kind": "manual", "saved_at": 1763500000, "reason": "manual"}, {"state": state, "clock": {"day": 2, "minutes": 700}})


func test_progress_round_trips_through_a_save() -> void:
	GameState.location_id = "mansion"
	_ask("anselmo", "coartada")
	_ask("anselmo", "coartada")
	_ask("lucia", "hallazgo")
	var before := GameState.conversations.duplicate(true)
	check(await save_and_wait("manual_1"), "se guarda")
	var saved := _state_in("manual_1")
	check(saved.get("conversations", {}).has("anselmo/coartada"), "el registro viaja en la sección state")
	GameState.reset()
	check(GameState.conversations.is_empty(), "una partida nueva no tiene registro")
	check(_load("manual_1"), "se carga")
	check_equal(GameState.conversations, before, "vuelve exactamente igual: variantes, veces, orden, día y hora")
	check_equal(ConversationLog.times_asked("anselmo", "coartada"), 2, "también cuántas veces se hizo")
	check(GameState.asked_topics.has("lucia/hallazgo"), "y el resumen de preguntas hechas")


func test_each_slot_keeps_its_own_history() -> void:
	GameState.location_id = "mansion"
	_ask("elena", "coartada")
	check(await save_and_wait("manual_1"), "primera ranura")
	_ask("marcos", "coartada")
	check(await save_and_wait("manual_2"), "segunda ranura")
	check(_load("manual_1"), "carga la primera")
	check(ConversationLog.was_asked("elena", "coartada"), "en la primera se habló con Elena")
	check(not ConversationLog.was_asked("marcos", "coartada"), "pero no con Marcos")
	check(_load("manual_2"), "carga la segunda")
	check(ConversationLog.was_asked("marcos", "coartada"), "en la segunda, con los dos")
	GameState.reset()
	check(not ConversationLog.was_asked("elena", "coartada"), "una partida nueva empieza sin preguntas hechas")


func test_autosave_includes_the_history_of_the_active_slot() -> void:
	GameState.location_id = "mansion"
	check(await save_and_wait("manual_3"), "ranura activa")
	_ask("irene", "quien")
	check(await autosave_and_wait("interrogatorio"), "autoguardado")
	check(_state_in("manual_3").get("conversations", {}).has("irene/quien"), "el autoguardado lleva el registro")
	check(not FileAccess.file_exists(SaveSystem.get_slot_path("manual_1")), "y no crea otras ranuras")


func test_repeating_a_question_is_not_progress_to_save() -> void:
	GameState.location_id = "mansion"
	_ask("rosa", "pueblo")
	check(await save_and_wait("manual_1"), "guardado")
	check(not SaveSystem.has_unsaved_progress(), "nada pendiente tras guardar")
	_ask("rosa", "pueblo")
	check_equal(ConversationLog.times_asked("rosa", "pueblo"), 2, "la repetición se cuenta")
	check(not SaveSystem.has_unsaved_progress(), "pero repetir no es avanzar: no pide otro guardado")
	_ask("rosa", "pension")
	check(SaveSystem.has_unsaved_progress(), "una pregunta nueva sí")


func test_changing_the_mode_keeps_the_progress() -> void:
	_ask("anselmo", "coartada")
	var before := GameState.conversations.duplicate(true)
	for mode in ConversationLog.MODES:
		Settings.set_value(ConversationLog.MODE_KEY, mode)
		check_equal(GameState.conversations, before, "con la modalidad «%s» el registro sigue igual" % mode)
		check(ConversationLog.was_asked("anselmo", "coartada"), "%s: la pregunta sigue hecha" % mode)
	check(not FileAccess.get_file_as_string(Settings.settings_path).contains("conversations"), "la modalidad va en las preferencias; el progreso, sólo en la partida")


func test_exiting_halfway_through_an_answer_keeps_the_question_pending() -> void:
	GameState.location_id = "mansion"
	check(await save_and_wait("manual_1"), "ranura activa")
	DialogueManager.start("elena")
	_read_until_menu()
	DialogueManager.choose("coartada")
	check_equal(DialogueManager.get_current_topic(), "coartada", "a mitad de la respuesta")
	var outcome: Dictionary = await SaveSystem.save_for_exit()
	check_equal(outcome["status"], "saved", "el juego guarda al salir")
	var saved := _state_in("manual_1")
	check(not saved.get("conversations", {}).has("elena/coartada"), "lo guardado es el estado de antes de la conversación")
	check(not (saved.get("asked_topics", []) as Array).has("elena/coartada"), "así que la pregunta sigue pendiente al volver")
	DialogueManager.close()


# --- Partidas anteriores al registro ---

func test_legacy_saves_recover_what_they_can_prove() -> void:
	var document := _legacy_document(
		["rosa/pueblo", "anselmo/coartada", "ortega/informe"],
		["informe_forense"], ["t_anselmo_brindis"])
	var parsed := SaveFormat.parse(SaveFormat.to_text(document))
	check_equal(parsed["status"], SaveFormat.Status.OK, "la partida antigua es válida")
	SaveSystem.apply_sections(parsed["document"]["sections"])
	check(ConversationLog.is_variant_done("rosa", "pueblo", ConversationLog.BASE_VARIANT), "una pregunta hecha sin nada que entregar")
	check(ConversationLog.is_variant_done("anselmo", "coartada", ConversationLog.BASE_VARIANT), "una pregunta con su testimonio")
	check(ConversationLog.is_variant_done("ortega", "informe", "llegado"), "del informe, la variante que entregó la pista que se tiene")
	check(not ConversationLog.is_variant_done("ortega", "informe", "pendiente"), "y no la otra, que nada prueba")
	var record: Dictionary = GameState.conversations["anselmo/coartada"]["variants"][ConversationLog.BASE_VARIANT]
	check(record.get("recovered", false), "lo rehecho se marca como recuperado")
	check(not record.has("day") and not record.has("minutes"), "sin inventar el día ni la hora")
	check_equal(record.get("gained", {}).get("testimonies", []), ["t_anselmo_brindis"], "con lo que entregó y la partida tiene")
	var order := func(topic_key: String, variant_id: String) -> int: return GameState.conversations[topic_key]["variants"][variant_id]["order"]
	check(order.call("rosa/pueblo", "base") < order.call("anselmo/coartada", "base"), "en el orden en que se hicieron")
	check(order.call("anselmo/coartada", "base") < order.call("ortega/informe", "llegado"), "también la última")


func test_legacy_report_question_without_the_report() -> void:
	SaveSystem.apply_sections(SaveFormat.parse(SaveFormat.to_text(_legacy_document(["ortega/informe"], [], [])))["document"]["sections"])
	check(ConversationLog.is_variant_done("ortega", "informe", "pendiente"), "sin el informe, sólo pudo oír que aún no había llegado")
	check(not ConversationLog.is_variant_done("ortega", "informe", "llegado"), "la del informe recibido sigue pendiente")


func test_an_exclusive_testimony_proves_its_question() -> void:
	# Sin `asked_topics` (una partida editada o muy antigua), el testimonio que sólo da esa pregunta
	# demuestra que se hizo; nada demuestra las demás.
	SaveSystem.apply_sections(SaveFormat.parse(SaveFormat.to_text(_legacy_document([], ["pagare_marcos"], ["t_lucia_escalera", "t_rosa_marcos"])))["document"]["sections"])
	check(ConversationLog.was_asked("lucia", "carta"), "el testimonio de la escalera sólo lo da la pregunta de la carta")
	check(ConversationLog.was_asked("rosa", "marcos"), "el pagaré y su testimonio sólo los da Rosa")
	check(not ConversationLog.was_asked("lucia", "hallazgo"), "nada se inventa")
	check_equal(GameState.conversations.size(), 2, "sólo esas dos")


func test_a_question_saved_halfway_stays_pending() -> void:
	# Antes de guardar el estado previo al salir a mitad de una conversación, una partida podía tener
	# la pregunta empezada sin sus consecuencias. No se da por hecha: repetirla ya no las aplicaría.
	SaveSystem.apply_sections(SaveFormat.parse(SaveFormat.to_text(_legacy_document(["elena/coartada", "rosa/marcos"], ["pagare_marcos"], [])))["document"]["sections"])
	check(not ConversationLog.was_asked("elena", "coartada"), "sin su testimonio, la pregunta vuelve a estar pendiente")
	check(not ConversationLog.was_asked("rosa", "marcos"), "con sólo parte de lo que entrega, también")
	check(not GameState.asked_topics.has("elena/coartada"), "y el resumen lo refleja")
	check(DialogueManager.has_new_topics("elena"), "Elena tiene esa pregunta pendiente")
	_ask("elena", "coartada")
	check(GameState.testimonies.has("t_elena_jaqueca"), "hacerla entrega por fin el testimonio")
	check(GameState.has_flag("hablo_elena"), "y la marca que desbloquea otras conversaciones")


func test_damaged_history_never_blocks_loading() -> void:
	var cases := [
		"no es un diccionario",
		{"anselmo/coartada": "dañada"},
		{"nadie/nada": {"variants": {"base": {"count": 1}}}},
		{"ortega/informe": {"variants": {"inventada": {"count": 3}, "llegado": {"count": -4, "day": 99, "minutes": "tarde"}}}},
	]
	for raw: Variant in cases:
		var parsed := SaveFormat.parse(SaveFormat.to_text(_legacy_document(["anselmo/coartada"], [], ["t_anselmo_brindis"], {"conversations": raw})))
		check_equal(parsed["status"], SaveFormat.Status.OK, "%s: la partida se carga" % str(raw))
		SaveSystem.apply_sections(parsed["document"]["sections"])
		check(ConversationLog.was_asked("anselmo", "coartada"), "%s: lo que prueba asked_topics se conserva" % str(raw))
		check(not GameState.conversations.has("nadie/nada"), "%s: lo desconocido se descarta" % str(raw))
	var variants: Dictionary = GameState.conversations["ortega/informe"]["variants"]
	check(not variants.has("inventada"), "una variante que no existe se descarta")
	check_equal(variants["llegado"]["count"], 1, "un contador imposible vale 1")
	check(not variants["llegado"].has("day"), "un día imposible se quita")
