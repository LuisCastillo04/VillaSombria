extends Node
## Estado de la partida en curso. Sólo guarda datos: las reglas viven en los sistemas
## que lo modifican, y todo lo que aparece aquí se persiste al guardar.

var flags: Dictionary = {}
var clues: Array[String] = []
var testimonies: Array[String] = []
var deductions: Array[String] = []
## Preguntas ya hechas, con claves de la forma "npc/pregunta".
var asked_topics: Dictionary = {}
## Hipótesis del jugador por sospechoso: {"status": String, "note": String}.
var hypotheses: Dictionary = {}
var location_id := ""
var spawn_id := ""
var accusation_attempts := 0

var _player_locks: Dictionary = {}


func reset() -> void:
	flags.clear()
	clues.clear()
	testimonies.clear()
	deductions.clear()
	asked_topics.clear()
	hypotheses.clear()
	location_id = ""
	spawn_id = ""
	accusation_attempts = 0
	clear_player_locks()


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func set_flag(flag: String) -> void:
	if flags.has(flag):
		return
	flags[flag] = true
	EventBus.flag_set.emit(flag)
	EventBus.objectives_changed.emit()


## Bloquea el control del jugador. Cada sistema usa su propio motivo, de modo que
## cerrar un panel no libera el control si otro sigue abierto.
func lock_player(reason: String) -> void:
	_player_locks[reason] = true


func unlock_player(reason: String) -> void:
	_player_locks.erase(reason)


func is_player_locked() -> bool:
	return not _player_locks.is_empty()


func clear_player_locks() -> void:
	_player_locks.clear()


func to_dict() -> Dictionary:
	return {
		"flags": flags.keys(),
		"clues": clues,
		"testimonies": testimonies,
		"deductions": deductions,
		"asked_topics": asked_topics.keys(),
		"hypotheses": hypotheses,
		"location_id": location_id,
		"spawn_id": spawn_id,
		"accusation_attempts": accusation_attempts,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	for flag: String in data.get("flags", []):
		flags[flag] = true
	clues.assign(data.get("clues", []))
	testimonies.assign(data.get("testimonies", []))
	deductions.assign(data.get("deductions", []))
	for topic: String in data.get("asked_topics", []):
		asked_topics[topic] = true
	hypotheses = data.get("hypotheses", {})
	location_id = data.get("location_id", "")
	spawn_id = data.get("spawn_id", "")
	accusation_attempts = int(data.get("accusation_attempts", 0))
