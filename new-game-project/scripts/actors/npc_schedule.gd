class_name NpcSchedule
extends RefCounted
## Consulta las rutinas de `data/schedules.json`.
##
## Un tramo puede llevar una condición `if` (con el formato de `Conditions`): sólo vale mientras
## se cumple. Así un personaje espera en un sitio hasta que ocurre algo en la historia, como el
## sargento en el café hasta que el inspector llega. Gana el primer tramo que encaje, de modo que
## el tramo condicionado va antes del que lo sustituye después.


## Tramo de la rutina de un NPC para un momento dado, o un diccionario vacío.
static func get_slot(npc_id: String, day: int, minutes: int) -> Dictionary:
	for slot: Dictionary in GameData.schedules.get(npc_id, []):
		if int(slot["day"]) != day:
			continue
		var from_time := GameClock.parse_time(slot["from"])
		var to_time := GameClock.parse_time(slot["to"])
		if minutes >= from_time and minutes < to_time and Conditions.check(slot.get("if", {})):
			return slot
	return {}


## Identificadores de los NPC que deben estar ahora en un escenario.
static func get_npcs_at(location_id: String, day: int, minutes: int) -> Array[String]:
	var present: Array[String] = []
	for npc_id: String in GameData.schedules:
		if get_slot(npc_id, day, minutes).get("location", "") == location_id:
			present.append(npc_id)
	return present
