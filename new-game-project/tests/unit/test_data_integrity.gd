extends TestCase
## Comprueba que los archivos de `data/` sean coherentes entre sí: ninguna referencia
## rota, ningún personaje sin datos y ninguna rutina con huecos.

const NPCS_WITHOUT_ROUTINE := ["detective"]


func _all_item_ids() -> Array:
	return GameData.clues.keys() + GameData.testimonies.keys() + GameData.deductions.keys()


## Recorre recursivamente un bloque de diálogo y aplica `visitor` a cada diccionario.
func _walk(value: Variant, visitor: Callable) -> void:
	if value is Dictionary:
		visitor.call(value)
		for key: String in value:
			_walk(value[key], visitor)
	elif value is Array:
		for item: Variant in value:
			_walk(item, visitor)


func _dialogue_files() -> Dictionary:
	var files := {"escenas": GameData.scenes}
	for character_id: String in GameData.characters:
		if not NPCS_WITHOUT_ROUTINE.has(character_id):
			files[character_id] = GameData.get_dialogue(character_id)
	return files


func test_core_files_loaded() -> void:
	check_equal(GameData.characters.size(), 10, "personajes")
	check(GameData.clues.size() >= 15, "debe haber al menos 15 pistas")
	check(GameData.deductions.size() >= 3, "el encargo pide al menos 3 relaciones")
	check_equal(GameData.get_suspects().size(), 5, "sospechosos")


func test_clue_entries_are_complete() -> void:
	var categories := ["documentos", "fotografias", "relojes", "cartas", "objetos", "huellas"]
	var used := {}
	for clue_id: String in GameData.clues:
		var clue: Dictionary = GameData.clues[clue_id]
		for field: String in ["name", "category", "description", "where"]:
			check(clue.has(field), "%s no tiene %s" % [clue_id, field])
		check(categories.has(clue.get("category", "")), "%s: categoría desconocida" % clue_id)
		used[clue.get("category", "")] = true
	for category: String in categories:
		check(used.has(category), "el encargo exige pistas de tipo " + category)


func test_dialogue_references_exist() -> void:
	var visitor := func(block: Dictionary) -> void:
		for clue_id: String in block.get("clues", []) + block.get("not_clues", []):
			check(GameData.clues.has(clue_id), "pista inexistente: " + clue_id)
		for testimony_id: String in block.get("testimonies", []):
			check(GameData.testimonies.has(testimony_id), "testimonio inexistente: " + testimony_id)
		for deduction_id: String in block.get("deductions", []):
			check(GameData.deductions.has(deduction_id), "deducción inexistente: " + deduction_id)
		if block.has("s"):
			var speaker: String = block["s"]
			check(speaker == "narrador" or GameData.characters.has(speaker), "orador desconocido: " + speaker)
	var files := _dialogue_files()
	for file_name: String in files:
		_walk(files[file_name], visitor)
	_walk(GameData.story, visitor)
	_walk(GameData.deductions, visitor)


func test_topic_ids_are_unique_per_npc() -> void:
	var files := _dialogue_files()
	for file_name: String in files:
		var seen := {}
		for topic: Dictionary in files[file_name].get("topics", []):
			check(not seen.has(topic["id"]), "%s repite la pregunta %s" % [file_name, topic["id"]])
			seen[topic["id"]] = true


func test_deduction_pairs_use_known_items() -> void:
	var ids := _all_item_ids()
	for deduction_id: String in GameData.deductions:
		for pair: Array in GameData.deductions[deduction_id]["pairs"]:
			for item_id: String in pair:
				check(ids.has(item_id), "%s usa un elemento inexistente: %s" % [deduction_id, item_id])


func test_every_testimony_can_be_obtained() -> void:
	var obtainable := {}
	var visitor := func(block: Dictionary) -> void:
		# Sólo cuentan los efectos: una condición `testimonies` exige, no concede.
		if block.has("effects"):
			for testimony_id: String in (block["effects"] as Dictionary).get("testimonies", []):
				obtainable[testimony_id] = true
	var files := _dialogue_files()
	for file_name: String in files:
		_walk(files[file_name], visitor)
	for testimony_id: String in GameData.testimonies:
		check(obtainable.has(testimony_id), "ningún diálogo concede " + testimony_id)


func test_accusation_rules_are_valid() -> void:
	var rules: Dictionary = GameData.story["accusation"]
	var ids := _all_item_ids()
	check(GameData.get_suspects().has(rules["culprit"]), "el culpable debe ser un sospechoso")
	for key: String in ["motive", "opportunity", "means"]:
		check(not (rules[key] as Array).is_empty(), "la acusación necesita " + key)
		for item_id: String in rules[key]:
			check(ids.has(item_id), "%s acepta un elemento inexistente: %s" % [key, item_id])
	for suspect: String in GameData.get_suspects():
		if suspect != rules["culprit"]:
			check((rules["rejections"] as Dictionary).has(suspect), "falta la refutación de " + suspect)


func test_schedules_cover_every_hour() -> void:
	for character_id: String in GameData.characters:
		if NPCS_WITHOUT_ROUTINE.has(character_id):
			continue
		check(GameData.schedules.has(character_id), "falta la rutina de " + character_id)
		for day in range(1, 4):
			for minutes in range(GameClock.DAY_START, GameClock.DAY_LIMIT + 1, 30):
				var slot := NpcSchedule.get_slot(character_id, day, minutes)
				check(not slot.is_empty(), "%s no tiene tramo el día %d a las %d" % [character_id, day, minutes])


func test_schedule_locations_exist() -> void:
	for character_id: String in GameData.schedules:
		for slot: Dictionary in GameData.schedules[character_id]:
			var location: String = slot["location"]
			check(location == "none" or GameData.locations.has(location), "lugar desconocido: " + location)


func test_portraits_load() -> void:
	for character_id: String in GameData.characters:
		var path: String = GameData.characters[character_id]["portrait"]
		check(ResourceLoader.exists(path), "falta la silueta " + path)
		check(load(path) is Texture2D, "la silueta no es una textura: " + path)
