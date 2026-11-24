extends TestCase
## Borrador de la acusación: qué elecciones acepta y cuándo se vacía.


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
