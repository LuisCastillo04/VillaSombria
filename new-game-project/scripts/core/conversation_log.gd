class_name ConversationLog
extends RefCounted
## Registro de los interrogatorios: qué preguntas ha hecho el jugador a cada personaje, con qué
## variante narrativa, cuántas veces y qué obtuvo. Es la única fuente de verdad sobre si una pregunta
## está hecha; `DialogueManager` lo consulta para montar el menú y lo anota al terminar cada respuesta.
##
## Una pregunta se identifica con «personaje/pregunta» (`key`), nunca con su texto ni con su posición
## en el menú. Si la pregunta tiene variantes (`variants` en `data/dialogues/`), cada una lleva su
## propio identificador y cuenta como una conversación independiente: hecha la de «aún no ha llegado
## el informe», la del informe recibido sigue pendiente. Una pregunta sin variantes usa
## `BASE_VARIANT`.
##
## Los datos viven en `GameState` (`conversations` y el resumen `asked_topics`); aquí sólo están las
## reglas.

const BASE_VARIANT := "base"


static func key(npc_id: String, topic_id: String) -> String:
	return "%s/%s" % [npc_id, topic_id]


## Clave de una variante concreta: «personaje/pregunta#variante».
static func variant_key(npc_id: String, topic_id: String, variant_id: String) -> String:
	return "%s/%s#%s" % [npc_id, topic_id, variant_id]


# --- Datos de las preguntas ----------------------------------------------------------------

## La pregunta de los datos, o un diccionario vacío si el personaje no la tiene.
static func find_topic(npc_id: String, topic_id: String) -> Dictionary:
	for topic: Dictionary in GameData.get_dialogue(npc_id).get("topics", []):
		if String(topic.get("id", "")) == topic_id:
			return topic
	return {}


## Identificadores de las variantes de una pregunta, en el orden de los datos.
static func variant_ids(topic: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	if not topic.has("variants"):
		ids.append(BASE_VARIANT)
		return ids
	for variant: Dictionary in topic["variants"]:
		ids.append(String(variant.get("id", "")))
	return ids


## Bloque de la variante (o de la pregunta, si no tiene variantes) con ese identificador.
static func variant_block(topic: Dictionary, variant_id: String) -> Dictionary:
	if not topic.has("variants"):
		return topic if variant_id == BASE_VARIANT else {}
	for variant: Dictionary in topic["variants"]:
		if String(variant.get("id", "")) == variant_id:
			return variant
	return {}


## Variante que se reproduciría ahora: la primera cuya condición se cumple. Vacía si ninguna.
static func current_variant(topic: Dictionary) -> String:
	if not topic.has("variants"):
		return BASE_VARIANT
	for variant: Dictionary in topic["variants"]:
		if Conditions.check(variant.get("if", {})):
			return String(variant.get("id", ""))
	return ""


## Si la pregunta se puede hacer ahora: su condición se cumple y alguna variante también.
static func is_available(topic: Dictionary) -> bool:
	return Conditions.check(topic.get("if", {})) and not current_variant(topic).is_empty()


# --- Registro -------------------------------------------------------------------------------

## Si esa variante de la pregunta ya se completó alguna vez. Sin registro de la pregunta, vale el
## resumen `asked_topics` (estado anterior al registro detallado, sin variante conocida).
static func is_variant_done(npc_id: String, topic_id: String, variant_id: String) -> bool:
	var record_entry: Variant = GameState.conversations.get(key(npc_id, topic_id))
	if record_entry is Dictionary:
		return (record_entry.get("variants", {}) as Dictionary).has(variant_id)
	return GameState.asked_topics.has(key(npc_id, topic_id))


## Si alguna variante de la pregunta se completó.
static func was_asked(npc_id: String, topic_id: String) -> bool:
	return GameState.asked_topics.has(key(npc_id, topic_id)) or GameState.conversations.has(key(npc_id, topic_id))


## Veces que se ha completado la pregunta (una variante concreta o, sin ella, todas).
static func times_asked(npc_id: String, topic_id: String, variant_id: String = "") -> int:
	var record_entry: Variant = GameState.conversations.get(key(npc_id, topic_id))
	if not record_entry is Dictionary:
		return 1 if GameState.asked_topics.has(key(npc_id, topic_id)) else 0
	var total := 0
	var variants: Dictionary = record_entry.get("variants", {})
	for id: String in variants:
		if variant_id.is_empty() or id == variant_id:
			total += int((variants[id] as Dictionary).get("count", 1))
	return total


## Anota que el jugador terminó de oír la respuesta de esa variante. Devuelve la entrada de la
## variante (para completar después lo que obtuvo con `note_gained`). La primera vez guarda el día y
## la hora; las siguientes sólo suman al contador.
static func record(npc_id: String, topic_id: String, variant_id: String) -> Dictionary:
	var topic_key := key(npc_id, topic_id)
	var entry: Dictionary = GameState.conversations.get(topic_key, {})
	if not entry.has("variants"):
		entry["variants"] = {}
	GameState.conversations[topic_key] = entry
	var variants: Dictionary = entry["variants"]
	if variants.has(variant_id):
		var existing: Dictionary = variants[variant_id]
		existing["count"] = int(existing.get("count", 1)) + 1
		return existing
	var fresh := {"count": 1, "order": _next_order(), "day": GameClock.day, "minutes": GameClock.minutes}
	variants[variant_id] = fresh
	GameState.asked_topics[topic_key] = true
	return fresh


## Pistas y testimonios que entregó la conversación la primera vez que se completó.
static func note_gained(entry: Dictionary, clues: Array, testimonies: Array) -> void:
	if clues.is_empty() and testimonies.is_empty():
		return
	var gained: Dictionary = entry.get("gained", {})
	for pair: Array in [["clues", clues], ["testimonies", testimonies]]:
		var list: Array = gained.get(pair[0], [])
		for item: Variant in pair[1]:
			if not list.has(item):
				list.append(item)
		if not list.is_empty():
			gained[pair[0]] = list
	entry["gained"] = gained


## Si el personaje tiene alguna pregunta disponible que aún no se le ha hecho (con su variante actual).
static func has_pending(npc_id: String) -> bool:
	for topic: Dictionary in GameData.get_dialogue(npc_id).get("topics", []):
		if is_available(topic) and not is_variant_done(npc_id, topic["id"], current_variant(topic)):
			return true
	return false


static func _next_order() -> int:
	var highest := -1
	for topic_key: String in GameState.conversations:
		var variants: Dictionary = (GameState.conversations[topic_key] as Dictionary).get("variants", {})
		for variant_id: String in variants:
			highest = maxi(highest, int((variants[variant_id] as Dictionary).get("order", -1)))
	return highest + 1
