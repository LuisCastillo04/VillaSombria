class_name Conditions
extends RefCounted
## Evalúa las condiciones declaradas en los datos. Una condición es un diccionario
## cuyas claves deben cumplirse todas; `any` exige que se cumpla al menos una subcondición.


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
	if condition.has("day_min") and GameClock.day < int(condition["day_min"]):
		return false
	if condition.has("day_max") and GameClock.day > int(condition["day_max"]):
		return false
	if condition.has("any"):
		return _check_any(condition["any"])
	return true


static func _check_any(options: Array) -> bool:
	for option: Dictionary in options:
		if check(option):
			return true
	return false
