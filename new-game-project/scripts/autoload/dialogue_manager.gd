extends Node
## Lógica de las conversaciones, sin dependencia de la interfaz. Reproduce líneas,
## ofrece las preguntas disponibles y aplica sus efectos. La interfaz escucha las
## señales y responde llamando a `advance` y `choose`.

signal opened(npc_id: String)
signal line_shown(speaker_id: String, text: String)
signal options_shown(options: Array)
signal closed(npc_id: String)

const EXIT_OPTION := "__salir"
const TOPIC_MINUTES := 10

var active := false
var npc_id := ""

var _queue: Array = []
var _after_lines: Callable
var _choices: Array = []
var _pending_after: Dictionary = {}
var _is_scene := false


## Abre una conversación con un NPC.
func start(target_npc: String) -> void:
	if active:
		return
	_open(target_npc, false)
	var data := GameData.get_dialogue(target_npc)
	var intro := _first_matching(data.get("intro", []))
	_play(intro.get("lines", []), func() -> void:
		Effects.apply(intro.get("effects", {}))
		_show_topics()
	)


## Reproduce una escena narrativa de `escenas.json`, sin menú de preguntas.
func play_scene(scene_id: String) -> void:
	if active:
		return
	_open("", true)
	_play_block(GameData.scenes[scene_id])


## La interfaz avisa de que el jugador ha terminado de leer la línea actual.
func advance() -> void:
	if not active:
		return
	if not _queue.is_empty():
		var line: Dictionary = _queue.pop_front()
		line_shown.emit(line.get("s", "narrador"), line.get("t", ""))
		return
	if _after_lines.is_valid():
		var next := _after_lines
		_after_lines = Callable()
		next.call()


## El jugador elige una opción del menú actual.
func choose(option_id: String) -> void:
	if not active:
		return
	if option_id == EXIT_OPTION:
		close()
		return
	if not _choices.is_empty():
		var choice: Dictionary = _choices[int(option_id)]
		_choices = []
		var after := _pending_after
		_pending_after = {}
		_play(choice.get("lines", []), func() -> void:
			Effects.apply(choice.get("effects", {}))
			if after.is_empty():
				_finish_conversation_step()
			else:
				_play_block(after)
		)
		return
	var topic := _find_topic(option_id)
	if topic.is_empty():
		return
	_play_topic(topic)


func close() -> void:
	if not active:
		return
	var finished_npc := npc_id
	active = false
	npc_id = ""
	_queue.clear()
	_choices = []
	_pending_after = {}
	_after_lines = Callable()
	GameState.unlock_player("dialogo")
	closed.emit(finished_npc)


## Preguntas que se pueden hacer ahora mismo a un NPC.
func get_available_topics(target_npc: String) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for topic: Dictionary in GameData.get_dialogue(target_npc).get("topics", []):
		if Conditions.check(topic.get("if", {})):
			available.append(topic)
	return available


## Indica si el NPC tiene alguna pregunta que el jugador aún no ha hecho.
func has_new_topics(target_npc: String) -> bool:
	for topic in get_available_topics(target_npc):
		if not was_asked(target_npc, topic["id"]):
			return true
	return false


func was_asked(target_npc: String, topic_id: String) -> bool:
	return GameState.asked_topics.has("%s/%s" % [target_npc, topic_id])


func _open(target_npc: String, is_scene: bool) -> void:
	active = true
	npc_id = target_npc
	_is_scene = is_scene
	GameState.lock_player("dialogo")
	opened.emit(target_npc)


func _play(lines: Array, then: Callable) -> void:
	_queue = lines.duplicate()
	_after_lines = then
	advance()


func _play_topic(topic: Dictionary) -> void:
	var key := "%s/%s" % [npc_id, topic["id"]]
	var first_time := not GameState.asked_topics.has(key)
	GameState.asked_topics[key] = true
	var block := topic
	if topic.has("variants"):
		block = _first_matching(topic["variants"])
	var effects: Dictionary = block.get("effects", {}).duplicate()
	if first_time and not effects.has("minutes"):
		effects["minutes"] = TOPIC_MINUTES
	elif not first_time:
		effects.erase("minutes")
	var with_effects := block.duplicate()
	with_effects["effects"] = effects
	_play_block(with_effects)


## Reproduce un bloque con líneas, efectos, elecciones y continuación opcionales.
func _play_block(block: Dictionary) -> void:
	_play(block.get("lines", []), func() -> void:
		var effects: Dictionary = block.get("effects", {})
		var choices: Array = block.get("choices", [])
		if not choices.is_empty():
			Effects.apply(effects)
			_show_choices(choices, block.get("after", {}))
		elif effects.has("action"):
			# La acción puede abrir otra pantalla, así que la conversación termina antes.
			close()
			Effects.apply(effects)
		else:
			Effects.apply(effects)
			_finish_conversation_step()
	)


func _finish_conversation_step() -> void:
	if _is_scene:
		close()
	else:
		_show_topics()


func _show_topics() -> void:
	var options: Array = []
	for topic in get_available_topics(npc_id):
		options.append({"id": topic["id"], "label": topic["label"], "asked": was_asked(npc_id, topic["id"])})
	options.append({"id": EXIT_OPTION, "label": "Terminar la conversación.", "asked": true})
	options_shown.emit(options)


func _show_choices(choices: Array, after: Dictionary) -> void:
	_choices = choices
	_pending_after = after
	var options: Array = []
	for index in choices.size():
		options.append({"id": str(index), "label": choices[index]["label"], "asked": false})
	options_shown.emit(options)


func _find_topic(topic_id: String) -> Dictionary:
	for topic in get_available_topics(npc_id):
		if topic["id"] == topic_id:
			return topic
	return {}


func _first_matching(variants: Array) -> Dictionary:
	for variant: Dictionary in variants:
		if Conditions.check(variant.get("if", {})):
			return variant
	return {}
