extends Node
## Lógica de las conversaciones, sin dependencia de la interfaz. Reproduce líneas,
## ofrece las preguntas disponibles y aplica sus efectos. La interfaz escucha las
## señales y responde llamando a `advance` y `choose`.

signal opened(npc_id: String)
## Empieza una escena narrativa. Se emite antes de su primera línea, para que el escenario
## coloque a los personajes que intervienen en ella (`get_scene_cast`).
signal scene_started(scene_id: String)
signal line_shown(speaker_id: String, text: String)
signal options_shown(options: Array)
signal closed(npc_id: String)

const EXIT_OPTION := "__salir"
const TOPIC_MINUTES := 10

var active := false
var npc_id := ""
## Escena narrativa en curso, o vacío si no hay ninguna.
var scene_id := ""

var _queue: Array = []
var _after_lines: Callable
var _choices: Array = []
var _pending_after: Dictionary = {}
var _is_scene := false
## Pregunta cuya respuesta se está oyendo: se anota en `ConversationLog` cuando termina, nunca
## antes, así que una conversación interrumpida la deja pendiente.
var _topic_in_progress: Dictionary = {}


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
func play_scene(target_scene: String) -> void:
	if active:
		return
	_open("", true)
	scene_id = target_scene
	scene_started.emit(target_scene)
	_play_block(GameData.scenes[target_scene])


## Personajes que intervienen en persona en una escena (su bloque `cast`): si están en el
## escenario, se detienen y miran al detective mientras dura. Los demás que hablan en ella (el
## narrador, una voz que no está en la sala) no necesitan estar.
func get_scene_cast(target_scene: String) -> Array:
	return GameData.scenes.get(target_scene, {}).get("cast", [])


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


## Preguntas que ofrece ahora el NPC, ordenadas y con su estado según la modalidad de Configuración
## (ver `ConversationLog.menu`).
func get_topic_menu(target_npc: String) -> Array[Dictionary]:
	return ConversationLog.menu(target_npc)


func close() -> void:
	if not active:
		return
	var finished_npc := npc_id
	active = false
	npc_id = ""
	scene_id = ""
	_queue.clear()
	_choices = []
	_pending_after = {}
	_after_lines = Callable()
	_topic_in_progress = {}
	GameState.unlock_player("dialogo")
	closed.emit(finished_npc)


## Preguntas que se pueden hacer ahora mismo a un NPC.
func get_available_topics(target_npc: String) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for topic: Dictionary in GameData.get_dialogue(target_npc).get("topics", []):
		if Conditions.check(topic.get("if", {})):
			available.append(topic)
	return available


## Indica si el NPC tiene alguna pregunta que el jugador aún no ha hecho (o una variante nueva de
## una que ya hizo).
func has_new_topics(target_npc: String) -> bool:
	return ConversationLog.has_pending(target_npc)


## Pregunta cuya respuesta se está oyendo ahora mismo, o vacío. Todavía no cuenta como hecha.
func get_current_topic() -> String:
	return String(_topic_in_progress.get("topic", ""))


## Si el jugador ya completó alguna vez esa pregunta, con cualquiera de sus variantes.
func was_asked(target_npc: String, topic_id: String) -> bool:
	return ConversationLog.was_asked(target_npc, topic_id)


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


## Reproduce la variante vigente de una pregunta. Cada variante es una conversación independiente:
## la primera vez que se completa cuesta tiempo y aplica sus consecuencias (marcas, pistas,
## testimonios, avisos, acciones). Repetirla sólo reproduce lo que se dijo: no cuesta tiempo ni
## vuelve a ejecutar nada, salvo en las conversaciones pensadas para repetirse (`repeatable`), cuyas
## consecuencias se aplican cada vez.
func _play_topic(topic: Dictionary) -> void:
	var topic_id := String(topic["id"])
	var variant_id := ConversationLog.current_variant(topic)
	var block := ConversationLog.variant_block(topic, variant_id)
	var first_time := not ConversationLog.is_variant_done(npc_id, topic_id, variant_id)
	var effects: Dictionary = block.get("effects", {}).duplicate()
	if not first_time and not ConversationLog.is_repeatable(topic):
		effects = {}
	if first_time and not effects.has("minutes"):
		effects["minutes"] = TOPIC_MINUTES
	elif not first_time:
		effects.erase("minutes")
	var with_effects := block.duplicate()
	with_effects["effects"] = effects
	_topic_in_progress = {"npc": npc_id, "topic": topic_id, "variant": variant_id}
	_play_block(with_effects)


## Reproduce un bloque con líneas, efectos, elecciones y continuación opcionales.
func _play_block(block: Dictionary) -> void:
	_play(block.get("lines", []), func() -> void:
		var effects: Dictionary = block.get("effects", {})
		var choices: Array = block.get("choices", [])
		var completion := _complete_topic()
		if not choices.is_empty():
			Effects.apply(effects)
			_note_gained(completion)
			_show_choices(choices, block.get("after", {}))
		elif effects.has("action"):
			# La acción puede abrir otra pantalla, así que la conversación termina antes.
			close()
			Effects.apply(effects)
			_note_gained(completion)
		else:
			Effects.apply(effects)
			_note_gained(completion)
			_finish_conversation_step()
	)


## Terminada la respuesta de una pregunta, la anota en el registro antes de aplicar sus efectos.
## Devuelve lo necesario para saber después qué entregó, o vacío si no era una pregunta.
func _complete_topic() -> Dictionary:
	if _topic_in_progress.is_empty():
		return {}
	var topic := _topic_in_progress
	_topic_in_progress = {}
	return {
		"npc": topic["npc"],
		"topic": topic["topic"],
		"entry": ConversationLog.record(topic["npc"], topic["topic"], topic["variant"]),
		"clues": GameState.clues.size(),
		"testimonies": GameState.testimonies.size(),
	}


## Apunta las pistas y los testimonios que llegaron con la respuesta y avisa del registro.
func _note_gained(completion: Dictionary) -> void:
	if completion.is_empty():
		return
	ConversationLog.note_gained(completion["entry"], GameState.clues.slice(completion["clues"]), GameState.testimonies.slice(completion["testimonies"]))
	EventBus.conversation_recorded.emit(completion["npc"], completion["topic"])


func _finish_conversation_step() -> void:
	if _is_scene:
		close()
	else:
		_show_topics()


## Menú de preguntas: lo ordena `ConversationLog` según la modalidad y termina con la de salir.
func _show_topics() -> void:
	var options: Array = []
	for entry in get_topic_menu(npc_id):
		options.append(entry)
	options.append({"id": EXIT_OPTION, "label": "Terminar la conversación.", "asked": true, "section": "salida"})
	options_shown.emit(options)


func _show_choices(choices: Array, after: Dictionary) -> void:
	_choices = choices
	_pending_after = after
	var options: Array = []
	for index in choices.size():
		options.append({"id": str(index), "label": choices[index]["label"], "asked": false})
	options_shown.emit(options)


## La pregunta, si el menú la ofrece ahora mismo y se puede elegir; si no (no está o, en la
## modalidad de diálogo único, ya se hizo), vacía.
func _find_topic(topic_id: String) -> Dictionary:
	var entry := ConversationLog.menu_entry(npc_id, topic_id)
	if entry.is_empty() or entry["state"] == ConversationLog.LOCKED:
		return {}
	return ConversationLog.find_topic(npc_id, topic_id)


func _first_matching(variants: Array) -> Dictionary:
	for variant: Dictionary in variants:
		if Conditions.check(variant.get("if", {})):
			return variant
	return {}
