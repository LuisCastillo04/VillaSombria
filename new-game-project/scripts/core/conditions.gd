class_name Conditions
extends RefCounted
## Evalúa las condiciones declaradas en los datos. Una condición es un diccionario
## cuyas claves deben cumplirse todas; `any` exige que se cumpla al menos una subcondición.
##
## Claves: `flags` y `not_flags` (marcas), `clues` y `not_clues` (pistas), `testimonies`,
## `deductions` (también las contradicciones), `day_min` y `day_max`, `asked` y `not_asked`
## (conversaciones completadas, como «irene/quien»), `visited` (lugares de `locations.json` que el
## detective ya ha pisado) y `any`.


static func check(condition: Dictionary) -> bool:
	for flag: String in condition.get("flags", []):
		if not GameState.has_flag(flag):
			return false
	for flag: String in condition.get("not_flags", []):
		if GameState.has_flag(flag):
			return false
	for clue_id: String in condition.get("clues", []):
		if not GameState.clues.has(clue_id):
			return false
	for clue_id: String in condition.get("not_clues", []):
		if GameState.clues.has(clue_id):
			return false
	for testimony_id: String in condition.get("testimonies", []):
		if not GameState.testimonies.has(testimony_id):
			return false
	for deduction_id: String in condition.get("deductions", []):
		if not GameState.deductions.has(deduction_id):
			return false
	for topic_key: String in condition.get("asked", []):
		if not _was_asked(topic_key):
			return false
	for topic_key: String in condition.get("not_asked", []):
		if _was_asked(topic_key):
			return false
	for location_id: String in condition.get("visited", []):
		if not _was_visited(location_id):
			return false
	if condition.has("day_min") and GameClock.day < int(condition["day_min"]):
		return false
	if condition.has("day_max") and GameClock.day > int(condition["day_max"]):
		return false
	if condition.has("any"):
		return _check_any(condition["any"])
	return true


## Si la condición ya no podrá cumplirse nunca en esta partida: lo que se tiene no se pierde (marcas,
## pistas, conversaciones) y los días no vuelven atrás. Sirve para saber si un personaje todavía puede
## contar algo más; una condición que sólo espera algo que aún no ha pasado no está descartada.
static func is_closed(condition: Dictionary) -> bool:
	for flag: String in condition.get("not_flags", []):
		if GameState.has_flag(flag):
			return true
	for clue_id: String in condition.get("not_clues", []):
		if GameState.clues.has(clue_id):
			return true
	for topic_key: String in condition.get("not_asked", []):
		if _was_asked(topic_key):
			return true
	if condition.has("day_max") and GameClock.day > int(condition["day_max"]):
		return true
	if condition.has("any"):
		var options: Array = condition["any"]
		if options.is_empty():
			return true
		for option: Dictionary in options:
			if not is_closed(option):
				return false
		return true
	return false


static func _check_any(options: Array) -> bool:
	for option: Dictionary in options:
		if check(option):
			return true
	return false


static func _was_asked(topic_key: String) -> bool:
	return ConversationLog.was_asked(topic_key.get_slice("/", 0), topic_key.get_slice("/", 1))


static func _was_visited(location_id: String) -> bool:
	var place := TownMap.get_place_for_location(location_id)
	return place != null and TownMap.is_visited(place.id)
