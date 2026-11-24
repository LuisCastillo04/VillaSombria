extends TestCase
## Clasificación deductiva de las pruebas, testimonios y deducciones para la acusación: cobertura de
## los datos, solución alcanzable, alternativas incorrectas y listas que sólo enseñan lo descubierto.


func before_each() -> void:
	GameState.reset()


func after_each() -> void:
	GameState.reset()


func _all_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for collection: Dictionary in [GameData.clues, GameData.testimonies, GameData.deductions]:
		for item_id: String in collection:
			ids.append(item_id)
	return ids


func _discover_everything() -> void:
	for clue_id: String in GameData.clues:
		GameState.clues.append(clue_id)
	for testimony_id: String in GameData.testimonies:
		GameState.testimonies.append(testimony_id)
	for deduction_id: String in GameData.deductions:
		GameState.deductions.append(deduction_id)


func _ids(options: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for option in options:
		ids.append(option["id"])
	return ids


func test_every_item_is_classified_with_known_categories() -> void:
	var items: Dictionary = GameData.evidence_categories.get("items", {})
	check(not items.is_empty(), "el archivo de clasificación se carga")
	for item_id in _all_item_ids():
		check(EvidenceCategories.is_classified(item_id), "falta clasificar " + item_id)
		check(not EvidenceCategories.categories_of(item_id).is_empty(), "%s no sirve para ninguna categoría" % item_id)
	for item_id: String in items:
		check(_all_item_ids().has(item_id), "se clasifica un elemento que no existe: " + item_id)
		var declared: Array = items[item_id].get("categories", [])
		for key: Variant in declared:
			check(EvidenceCategories.is_category(str(key)), "%s usa una categoría desconocida: %s" % [item_id, key])
		check_equal(declared.size(), EvidenceCategories.categories_of(item_id).size(), "%s no repite categorías" % item_id)


func test_clue_types_are_valid_and_cover_the_interface_icons() -> void:
	var items: Dictionary = GameData.evidence_categories["items"]
	var used := {}
	for clue_id: String in GameData.clues:
		var declared := str(items.get(clue_id, {}).get("type", ""))
		check(EvidenceCategories.TYPES.has(declared), "la pista %s declara una clase válida (%s)" % [clue_id, declared])
		used[EvidenceCategories.type_of(clue_id)] = true
	for testimony_id: String in GameData.testimonies:
		check_equal(EvidenceCategories.type_of(testimony_id), "testimonio", "clase de " + testimony_id)
		check(not items.get(testimony_id, {}).has("type"), "los testimonios no declaran clase: " + testimony_id)
	for deduction_id: String in GameData.deductions:
		check_equal(EvidenceCategories.type_of(deduction_id), "deduccion", "clase de " + deduction_id)
	for type_name: String in ["documento", "carta", "fotografia", "objeto", "registro", "informe"]:
		check(used.has(type_name), "alguna pista es de la clase " + type_name)


func test_solution_is_reachable_through_its_categories() -> void:
	var rules: Dictionary = GameData.story["accusation"]
	for key in EvidenceCategories.KEYS:
		for item_id: String in rules[key]:
			check(EvidenceCategories.belongs(item_id, key), "la respuesta válida %s debe aparecer en %s" % [item_id, key])


func test_each_category_keeps_plausible_wrong_answers() -> void:
	var rules: Dictionary = GameData.story["accusation"]
	_discover_everything()
	for key in EvidenceCategories.KEYS:
		var ids := _ids(Investigation.get_accusation_options(key))
		var accepted: Array = rules[key]
		var wrong := ids.filter(func(item_id: String) -> bool: return not accepted.has(item_id))
		check(wrong.size() >= accepted.size() * 2, "%s ofrece bastantes alternativas incorrectas (%d frente a %d)" % [key, wrong.size(), accepted.size()])
		check(ids.size() < _all_item_ids().size(), "%s no enseña todo el expediente" % key)
		var kinds := {}
		for item_id in wrong:
			kinds[Investigation.get_item(item_id)["kind"]] = true
		check(kinds.size() >= 2, "%s mezcla clases de elementos entre las incorrectas" % key)


func test_wrong_answers_include_evidence_against_other_suspects() -> void:
	_discover_everything()
	var motive := _ids(Investigation.get_accusation_options("motive"))
	var opportunity := _ids(Investigation.get_accusation_options("opportunity"))
	var means := _ids(Investigation.get_accusation_options("means"))
	# Deudas de Marcos, la huida de Elena, el secreto de Irene y la carta de los amantes.
	for item_id: String in ["pagare_marcos", "billete_tren", "t_irene_verdad", "carta_amor"]:
		check(motive.has(item_id), "el motivo incluye la pista falsa " + item_id)
	for item_id: String in ["registro_billetes", "t_rosa_marcos", "t_irene_despacho", "huellas_betun"]:
		check(opportunity.has(item_id), "la oportunidad incluye " + item_id)
	for item_id: String in ["llave_reloj", "t_marcos_relojes", "recortes_prensa", "reloj_despacho"]:
		check(means.has(item_id), "los medios incluyen " + item_id)


func test_unrelated_items_stay_out_of_each_category() -> void:
	_discover_everything()
	var motive := _ids(Investigation.get_accusation_options("motive"))
	var opportunity := _ids(Investigation.get_accusation_options("opportunity"))
	var means := _ids(Investigation.get_accusation_options("means"))
	check(not motive.has("libro_bodega"), "un registro de horas no explica un motivo")
	check(not motive.has("informe_forense"), "el informe forense no explica un motivo")
	check(not opportunity.has("transferencia"), "una transferencia no sitúa a nadie")
	check(not opportunity.has("foto_clara"), "un retrato no sitúa a nadie")
	check(not means.has("t_marcos_lucia"), "un romance no explica el método")
	check(not means.has("registro_pension"), "una coartada no explica el método")


func test_options_only_show_discovered_items_without_duplicates() -> void:
	check(Investigation.get_accusation_options("motive").is_empty(), "sin hallazgos no hay opciones")
	Investigation.discover_clue("transferencia")
	Investigation.discover_clue("libro_bodega")
	Investigation.record_testimony("t_elena_clara")
	# Una partida dañada podría repetir un elemento: la lista no lo duplica.
	GameState.testimonies.append("t_elena_clara")
	var motive := _ids(Investigation.get_accusation_options("motive"))
	check_equal(motive, ["transferencia", "t_elena_clara"] as Array[String], "motivo con lo hallado, en orden y sin repetir")
	check(not motive.has("d_dinero"), "una deducción sin hacer no aparece")
	check_equal(_ids(Investigation.get_accusation_options("opportunity")), ["libro_bodega"] as Array[String], "oportunidad")
	check(Investigation.get_accusation_options("means").is_empty(), "medios sin hallazgos")
	check(Investigation.get_accusation_options("culpable").is_empty(), "una categoría desconocida no ofrece nada")
