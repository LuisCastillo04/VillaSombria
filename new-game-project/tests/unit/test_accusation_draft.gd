extends TestCase
## Borrador de la acusación: qué elecciones acepta, cuándo se vacía y cómo viaja con las partidas
## guardadas (ranuras independientes, autoguardado, partidas antiguas y datos dañados).


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.clear_save_storage()
	SaveSystem.begin_session(self)


func after_each() -> void:
	SaveSystem.end_session(self)
	SaveSystem.take_pending_load()
	SaveSystem.autosave_enabled = false
	SaveSystem.autosave_delay = 1.5
	SaveSystem.autosave_min_interval = 30.0
	GameState.unlock_player("acusacion")
	DialogueManager.close()
	TestCase.clear_save_storage()
	GameState.reset()
	GameClock.reset()


func _discover(ids: Array[String]) -> void:
	for item_id in ids:
		if GameData.clues.has(item_id):
			Investigation.discover_clue(item_id)
		elif GameData.testimonies.has(item_id):
			Investigation.record_testimony(item_id)
		else:
			GameState.deductions.append(item_id)


func _draft_in(slot_id: String) -> Dictionary:
	var result := SaveSystem.read_slot(slot_id)
	if result["status"] != SaveFormat.Status.OK:
		return {"error": result["error"]}
	return result["document"]["sections"]["state"].get("accusation_draft", {})


func _load(slot_id: String) -> bool:
	var result := SaveSystem.read_slot(slot_id)
	if result["status"] != SaveFormat.Status.OK:
		return false
	SaveSystem.apply_sections(result["document"]["sections"])
	return true


func _document_with_draft(draft: Variant) -> Dictionary:
	var state := {
		"flags": [], "clues": ["transferencia", "libro_bodega"], "testimonies": ["t_elena_clara"],
		"deductions": [], "asked_topics": [], "hypotheses": {}, "location_id": "mansion",
		"spawn_id": "", "accusation_attempts": 1,
	}
	if draft != null:
		state["accusation_draft"] = draft
	return SaveFormat.build({"kind": "manual", "saved_at": 1763500000, "reason": "manual"}, {"state": state, "clock": {"day": 3, "minutes": 600}})


# --- Elecciones ---

func test_draft_starts_empty_with_every_field() -> void:
	var draft := Investigation.get_accusation_draft()
	check_equal(draft.keys(), ["suspect", "motive", "opportunity", "means"], "los cuatro campos, en orden")
	for field: String in draft:
		check_equal(draft[field], "", "%s empieza vacío" % field)
	check(not Investigation.is_accusation_complete(draft), "vacío no está completo")


func test_valid_choices_are_recorded_and_announced() -> void:
	_discover(["transferencia", "libro_bodega", "informe_forense"])
	var changed: Array[String] = []
	var listener := func(field: String) -> void: changed.append(field)
	EventBus.accusation_draft_changed.connect(listener)
	check(Investigation.set_accusation_choice("suspect", "lucia"), "un sospechoso vale")
	check(Investigation.set_accusation_choice("motive", "transferencia"), "una prueba de su categoría vale")
	check(Investigation.set_accusation_choice("motive", "transferencia"), "repetir la misma elección no falla")
	check(Investigation.set_accusation_choice("opportunity", "libro_bodega"), "oportunidad")
	check(Investigation.set_accusation_choice("means", "informe_forense"), "medios")
	EventBus.accusation_draft_changed.disconnect(listener)
	check_equal(changed, ["suspect", "motive", "opportunity", "means"] as Array[String], "cada cambio se avisa una vez")
	var draft := Investigation.get_accusation_draft()
	check_equal(draft["suspect"], "lucia", "sospechoso anotado")
	check(Investigation.is_accusation_complete(draft), "con los cuatro campos está completo")
	check_equal(GameState.accusation_attempts, 0, "anotar no cuenta como intento")


func test_invalid_choices_are_rejected() -> void:
	_discover(["transferencia", "libro_bodega"])
	check(not Investigation.set_accusation_choice("suspect", "ortega"), "Ortega no es sospechoso")
	check(not Investigation.set_accusation_choice("suspect", "nadie"), "un personaje que no existe")
	check(not Investigation.set_accusation_choice("motive", "d_dinero"), "una deducción que aún no se hizo")
	check(not Investigation.set_accusation_choice("motive", "libro_bodega"), "una prueba de otra categoría")
	check(not Investigation.set_accusation_choice("culpable", "anselmo"), "un campo que no existe")
	check_equal(GameState.accusation_draft, {}, "nada inválido llega al borrador")


func test_a_field_can_be_changed_and_emptied() -> void:
	_discover(["transferencia", "pagare_marcos"])
	Investigation.set_accusation_choice("motive", "transferencia")
	Investigation.set_accusation_choice("motive", "pagare_marcos")
	check_equal(Investigation.get_accusation_draft()["motive"], "pagare_marcos", "la última elección manda")
	Investigation.set_accusation_choice("motive", "")
	check_equal(Investigation.get_accusation_draft()["motive"], "", "se puede vaciar")
	check(not GameState.accusation_draft.has("motive"), "el estado sólo guarda los campos rellenos")


func test_options_do_not_depend_on_the_chosen_suspect() -> void:
	for clue_id: String in GameData.clues:
		GameState.clues.append(clue_id)
	var ids := func() -> Array: return Investigation.get_accusation_options("means").map(func(item: Dictionary) -> String: return item["id"])
	var before: Array = ids.call()
	Investigation.set_accusation_choice("suspect", "elena")
	check_equal(ids.call(), before, "elegir un sospechoso no filtra las pruebas")
	Investigation.set_accusation_choice("suspect", "anselmo")
	check_equal(ids.call(), before, "tampoco elegir al culpable")


func test_case_solved_and_new_game_clear_the_draft() -> void:
	_discover(["transferencia"])
	Investigation.set_accusation_choice("suspect", "anselmo")
	Investigation.set_accusation_choice("motive", "transferencia")
	GameState.set_flag("dia_3_iniciado")
	check_equal(Investigation.get_accusation_draft()["suspect"], "anselmo", "otras marcas no lo tocan")
	GameState.set_flag(Investigation.CASE_SOLVED_FLAG)
	check_equal(GameState.accusation_draft, {}, "al cerrar el caso se descarta")
	Investigation.set_accusation_choice("suspect", "irene")
	GameState.reset()
	check_equal(GameState.accusation_draft, {}, "una partida nueva empieza sin borrador")


# --- Partidas guardadas ---

func test_draft_round_trips_through_a_save() -> void:
	GameState.location_id = "mansion"
	_discover(["transferencia", "libro_bodega", "d_bodega"])
	Investigation.set_accusation_choice("suspect", "anselmo")
	Investigation.set_accusation_choice("motive", "transferencia")
	Investigation.set_accusation_choice("opportunity", "d_bodega")
	check(await save_and_wait("manual_1"), "se guarda")
	check_equal(_draft_in("manual_1"), {"suspect": "anselmo", "motive": "transferencia", "opportunity": "d_bodega"}, "el archivo guarda identificadores, no posiciones de una lista")
	GameState.reset()
	check(_load("manual_1"), "se carga")
	var draft := Investigation.get_accusation_draft()
	check_equal(draft["suspect"], "anselmo", "sospechoso")
	check_equal(draft["motive"], "transferencia", "motivo")
	check_equal(draft["opportunity"], "d_bodega", "oportunidad")
	check_equal(draft["means"], "", "los medios siguen vacíos")


func test_each_slot_keeps_its_own_draft() -> void:
	GameState.location_id = "mansion"
	_discover(["transferencia", "pagare_marcos"])
	Investigation.set_accusation_choice("suspect", "anselmo")
	Investigation.set_accusation_choice("motive", "transferencia")
	await save_and_wait("manual_1")
	Investigation.set_accusation_choice("suspect", "marcos")
	Investigation.set_accusation_choice("motive", "pagare_marcos")
	await save_and_wait("manual_2")
	check_equal(_draft_in("manual_1")["suspect"], "anselmo", "la primera ranura conserva su borrador")
	check_equal(_draft_in("manual_2")["suspect"], "marcos", "la segunda tiene el suyo")
	check(_load("manual_1"), "se carga la primera")
	check_equal(Investigation.get_accusation_draft()["motive"], "transferencia", "con su motivo")
	check(_load("manual_2"), "se carga la segunda")
	check_equal(Investigation.get_accusation_draft()["motive"], "pagare_marcos", "con el suyo")
	for slot_id: String in ["manual_3", "manual_4", "manual_5"]:
		check_equal(SaveSystem.get_slot_info(slot_id)["status"], SaveFormat.Status.EMPTY, "el borrador no crea ranuras")


func test_changing_the_draft_is_unsaved_progress_and_autosaves_with_it() -> void:
	GameState.location_id = "mansion"
	_discover(["transferencia"])
	await save_and_wait("manual_3")
	check(not SaveSystem.has_unsaved_progress(), "recién guardado no hay nada pendiente")
	Investigation.set_accusation_choice("suspect", "irene")
	check(SaveSystem.has_unsaved_progress(), "cambiar el borrador es algo que guardar al salir")
	check(await autosave_and_wait("lugar"), "el autoguardado escribe")
	check_equal(_draft_in("manual_3"), {"suspect": "irene"}, "con el borrador, en la ranura activa")


func test_draft_edited_after_talking_to_ortega_is_autosaved_on_closing() -> void:
	GameState.location_id = "mansion"
	_discover(["transferencia"])
	await save_and_wait("manual_2")
	SaveSystem.autosave_enabled = true
	SaveSystem.autosave_delay = 0.05
	SaveSystem.autosave_min_interval = 0.0
	# Como en el juego: la conversación con Ortega termina y abre la hoja; su autoguardado espera.
	DialogueManager.closed.emit("ortega")
	GameState.lock_player("acusacion")
	Investigation.set_accusation_choice("suspect", "anselmo")
	Investigation.set_accusation_choice("motive", "transferencia")
	await get_tree().create_timer(0.4).timeout
	check_equal(_draft_in("manual_2"), {}, "con la hoja abierta no se escribe nada")
	check(SaveSystem.has_pending_autosave(), "la petición espera a que se cierre")
	GameState.unlock_player("acusacion")
	var waited := 0.0
	while _draft_in("manual_2").is_empty() and waited < 3.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	check_equal(_draft_in("manual_2"), {"suspect": "anselmo", "motive": "transferencia"}, "al seguir investigando, el autoguardado lleva el borrador")


func test_saves_without_a_draft_still_load() -> void:
	var result := SaveFormat.parse(JSON.stringify(_document_with_draft(null)))
	check_equal(result["status"], SaveFormat.Status.OK, "una partida anterior al borrador se acepta")
	check_equal(result["document"]["sections"]["state"]["accusation_draft"], {}, "con el borrador vacío")
	SaveSystem.apply_sections(result["document"]["sections"])
	check_equal(Investigation.get_accusation_draft()["suspect"], "", "el formulario empieza vacío")
	check(GameState.clues.has("transferencia"), "y el resto de la partida se restaura")


func test_invalid_draft_entries_are_dropped_on_load() -> void:
	var draft := {
		"suspect": "ortega",
		"motive": "transferencia",
		"opportunity": "d_bodega",
		"means": "libro_bodega",
		"culpable": "anselmo",
	}
	var result := SaveFormat.parse(JSON.stringify(_document_with_draft(draft)))
	check_equal(result["status"], SaveFormat.Status.OK, "un borrador raro no impide cargar")
	check_equal(result["document"]["sections"]["state"]["accusation_draft"], {"motive": "transferencia"}, "sólo queda lo que vale con lo descubierto")


func test_damaged_draft_does_not_block_loading() -> void:
	for damaged: Variant in ["anselmo", [1, 2], 42]:
		var result := SaveFormat.parse(JSON.stringify(_document_with_draft(damaged)))
		check_equal(result["status"], SaveFormat.Status.OK, "un borrador dañado (%s) no corrompe la partida" % str(damaged))
		check_equal(result["document"]["sections"]["state"]["accusation_draft"], {}, "y empieza vacío")
