extends Node
## Estado de la partida en curso. Sólo guarda datos: las reglas viven en los sistemas
## que lo modifican, y todo lo que aparece aquí se persiste al guardar.

var flags: Dictionary = {}
var clues: Array[String] = []
var testimonies: Array[String] = []
var deductions: Array[String] = []
## Preguntas ya hechas, con claves de la forma "npc/pregunta": el resumen de `conversations`.
var asked_topics: Dictionary = {}
## Registro de los interrogatorios: "npc/pregunta" -> {"variants": {variante: {"count", "order",
## "day", "minutes", "gained"}}}. Una variante se anota al terminar su respuesta, nunca antes; las
## reglas están en `ConversationLog`.
var conversations: Dictionary = {}
## Hipótesis del jugador por sospechoso: {"status": String, "note": String}.
var hypotheses: Dictionary = {}
## Borrador del formulario de acusación: campo -> sospechoso o elemento elegido. Sólo guarda los
## campos rellenos; las reglas que lo validan están en `Investigation`.
var accusation_draft: Dictionary = {}
var location_id := ""
var spawn_id := ""
var accusation_attempts := 0
## Tiempo real jugado en esta partida, sin contar la pausa ni los menús.
var play_seconds := 0.0

var _player_locks: Dictionary = {}


func reset() -> void:
	flags.clear()
	clues.clear()
	testimonies.clear()
	deductions.clear()
	asked_topics.clear()
	conversations.clear()
	hypotheses.clear()
	accusation_draft.clear()
	location_id = ""
	spawn_id = ""
	accusation_attempts = 0
	play_seconds = 0.0
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
	if _player_locks.has(reason):
		return
	_player_locks[reason] = true
	EventBus.player_locks_changed.emit()


func unlock_player(reason: String) -> void:
	if _player_locks.erase(reason):
		EventBus.player_locks_changed.emit()


func is_player_locked() -> bool:
	return not _player_locks.is_empty()


func get_player_lock_reasons() -> Array[String]:
	var reasons: Array[String] = []
	reasons.assign(_player_locks.keys())
	return reasons


func clear_player_locks() -> void:
	if _player_locks.is_empty():
		return
	_player_locks.clear()
	EventBus.player_locks_changed.emit()


func to_dict() -> Dictionary:
	return {
		"flags": flags.keys(),
		"clues": clues,
		"testimonies": testimonies,
		"deductions": deductions,
		"asked_topics": asked_topics.keys(),
		"conversations": conversations.duplicate(true),
		"hypotheses": hypotheses,
		"accusation_draft": accusation_draft.duplicate(),
		"location_id": location_id,
		"spawn_id": spawn_id,
		"accusation_attempts": accusation_attempts,
		"play_seconds": play_seconds,
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
	# Las partidas anteriores al registro detallado sólo traen `asked_topics`: se rehace lo que se
	# puede probar con lo que guardaban, sin inventar conversaciones (`ConversationLog.recover`).
	var records := ConversationLog.clean_records(data.get("conversations", {}), false)
	conversations = ConversationLog.recover(records, asked_topics.keys(), data.get("clues", []), data.get("testimonies", []), data.get("flags", []))
	# El resumen sale del registro: una pregunta empezada pero sin completar vuelve a estar pendiente.
	asked_topics.clear()
	for topic_key: String in conversations:
		asked_topics[topic_key] = true
	hypotheses = data.get("hypotheses", {})
	# Las partidas anteriores al borrador no lo traen: el formulario empieza vacío.
	var draft: Variant = data.get("accusation_draft", {})
	if draft is Dictionary:
		for field: Variant in draft:
			var value: Variant = draft[field]
			if field is String and value is String and not (value as String).is_empty():
				accusation_draft[field] = value
	location_id = data.get("location_id", "")
	spawn_id = data.get("spawn_id", "")
	accusation_attempts = int(data.get("accusation_attempts", 0))
	play_seconds = float(data.get("play_seconds", 0.0))
