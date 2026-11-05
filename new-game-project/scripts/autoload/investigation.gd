extends Node
## Reglas de la investigación: registro de pistas y testimonios, deducciones y
## evaluación de la acusación final.

enum LinkResult { NONE, NEW, ALREADY_KNOWN, MISSING_ITEM }

const CLUE_MINUTES := 5


## Registra una pista una sola vez. Devuelve si era nueva.
func discover_clue(clue_id: String) -> bool:
	if GameState.clues.has(clue_id):
		return false
	if not GameData.clues.has(clue_id):
		push_error("Pista desconocida: %s" % clue_id)
		return false
	GameState.clues.append(clue_id)
	EventBus.clue_discovered.emit(clue_id)
	EventBus.objectives_changed.emit()
	EventBus.notification_requested.emit("Pista registrada", GameData.clues[clue_id]["name"], "pista")
	return true


func record_testimony(testimony_id: String) -> bool:
	if GameState.testimonies.has(testimony_id):
		return false
	if not GameData.testimonies.has(testimony_id):
		push_error("Testimonio desconocido: %s" % testimony_id)
		return false
	GameState.testimonies.append(testimony_id)
	EventBus.testimony_recorded.emit(testimony_id)
	EventBus.objectives_changed.emit()
	return true


## Comprueba si dos elementos del expediente forman una deducción real.
func try_link(first_id: String, second_id: String) -> Dictionary:
	if not has_item(first_id) or not has_item(second_id):
		return {"result": LinkResult.MISSING_ITEM, "deduction": ""}
	var deduction_id := find_deduction(first_id, second_id)
	if deduction_id.is_empty():
		return {"result": LinkResult.NONE, "deduction": ""}
	if GameState.deductions.has(deduction_id):
		return {"result": LinkResult.ALREADY_KNOWN, "deduction": deduction_id}
	GameState.deductions.append(deduction_id)
	EventBus.deduction_made.emit(deduction_id)
	EventBus.objectives_changed.emit()
	Effects.apply(GameData.deductions[deduction_id].get("effects", {}))
	EventBus.notification_requested.emit("Deducción", GameData.deductions[deduction_id]["title"], "pista")
	return {"result": LinkResult.NEW, "deduction": deduction_id}


func find_deduction(first_id: String, second_id: String) -> String:
	for deduction_id: String in GameData.deductions:
		for pair: Array in GameData.deductions[deduction_id]["pairs"]:
			if (pair[0] == first_id and pair[1] == second_id) or (pair[0] == second_id and pair[1] == first_id):
				return deduction_id
	return ""


func has_item(item_id: String) -> bool:
	return (
		GameState.clues.has(item_id)
		or GameState.testimonies.has(item_id)
		or GameState.deductions.has(item_id)
	)


## Describe un elemento del expediente de forma uniforme para la interfaz.
func get_item(item_id: String) -> Dictionary:
	if GameData.clues.has(item_id):
		var clue: Dictionary = GameData.clues[item_id]
		return {"id": item_id, "kind": "pista", "title": clue["name"], "text": clue["description"], "tag": clue["category"]}
	if GameData.testimonies.has(item_id):
		var testimony: Dictionary = GameData.testimonies[item_id]
		var speaker := GameData.get_character_name(testimony["speaker"])
		return {"id": item_id, "kind": "testimonio", "title": "%s: %s" % [speaker, testimony["topic"]], "text": testimony["text"], "tag": testimony["speaker"]}
	if GameData.deductions.has(item_id):
		var deduction: Dictionary = GameData.deductions[item_id]
		return {"id": item_id, "kind": "deduccion", "title": deduction["title"], "text": deduction["text"], "tag": deduction["kind"]}
	return {}


## Elementos con los que el jugador puede trabajar en el tablero, en orden de hallazgo.
func get_board_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for collection: Array[String] in [GameState.clues, GameState.testimonies, GameState.deductions]:
		for item_id in collection:
			items.append(get_item(item_id))
	return items


## Valora la acusación. Devuelve {"ok": bool, "reason": String}.
func evaluate_accusation(suspect_id: String, motive_id: String, opportunity_id: String, means_id: String) -> Dictionary:
	var rules: Dictionary = GameData.story["accusation"]
	var rejections: Dictionary = rules["rejections"]
	if suspect_id != rules["culprit"]:
		return {"ok": false, "reason": rejections.get(suspect_id, "Esa acusación no se sostiene.")}
	var weak: Dictionary = rules["weak"]
	if not (rules["motive"] as Array).has(motive_id):
		return {"ok": false, "reason": weak["motive"]}
	if not (rules["opportunity"] as Array).has(opportunity_id):
		return {"ok": false, "reason": weak["opportunity"]}
	if not (rules["means"] as Array).has(means_id):
		return {"ok": false, "reason": weak["means"]}
	return {"ok": true, "reason": ""}
