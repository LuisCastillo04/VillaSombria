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
## Los datos viven en `GameState` (`conversations` y el resumen `asked_topics`) y se guardan con la
## partida, cada ranura con el suyo; aquí sólo están las reglas, también las que limpian lo que trae
## una partida y rehacen el registro de las anteriores a él (`clean_records`, `recover`).

const BASE_VARIANT := "base"
## Preferencia de Configuración → Jugabilidad con la modalidad de los interrogatorios.
const MODE_KEY := "jugabilidad/sistema_dialogos"
## Todas las preguntas siguen en su sitio y se repiten sin límite.
const MODE_FREE := "libre"
## Las nuevas primero; las hechas, aparte y repetibles. Es la modalidad por defecto.
const MODE_SMART := "inteligente"
## Cada pregunta se hace una sola vez.
const MODE_SINGLE := "unico"
const MODES: Array[String] = [MODE_FREE, MODE_SMART, MODE_SINGLE]

## Estado de una pregunta en el menú.
const PENDING := "pendiente"
const DONE := "realizada"
## Hecha en la modalidad de diálogo único: se ve, pero ya no se puede elegir.
const LOCKED := "bloqueada"

## Parte del menú en que aparece una pregunta: la principal o «Preguntas realizadas».
const SECTION_MAIN := "principal"
const SECTION_ASKED := "realizadas"


## Modalidad vigente: `MODE_FREE`, `MODE_SMART` (por defecto) o `MODE_SINGLE`. Sólo cambia cómo se
## presenta el menú de preguntas: cambiarla nunca borra ni altera el registro.
static func mode() -> String:
	var value := String(Settings.get_value(MODE_KEY))
	return value if MODES.has(value) else MODE_SMART


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


## Conversaciones pensadas para repetirse (como reunir a los sospechosos para acusar): ninguna
## modalidad las bloquea ni las aparta, y sus efectos se aplican cada vez.
static func is_repeatable(topic: Dictionary) -> bool:
	return bool(topic.get("repeatable", false))


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


# --- Menú -----------------------------------------------------------------------------------

## Preguntas que ofrece el personaje ahora mismo, ya ordenadas para la modalidad `menu_mode` (sin
## ella, la de Configuración). Cada entrada: `id`, `label`, `variant`, `state` (`PENDING`, `DONE` o
## `LOCKED`), `asked`, `section` (`SECTION_MAIN` o `SECTION_ASKED`), `repeatable` y `count`.
##
## - Libre: todas en el orden de los datos, en la parte principal, como siempre.
## - Inteligente: primero las pendientes, en el orden de los datos; las hechas pasan a «Preguntas
##   realizadas» y se pueden repetir.
## - Única: como la inteligente, pero las hechas quedan bloqueadas. Si la investigación desbloquea
##   otra variante de una de ellas, esa variante vuelve como pregunta pendiente.
## Las conversaciones repetibles (`repeatable`) siguen siempre en la parte principal, tras las
## pendientes, y nunca se bloquean.
## Sólo aparecen las preguntas cuya condición se cumple: una que sus propios datos retiran al hacerla
## (un «not_clues» con lo que entrega) no vuelve, como antes.
static func menu(npc_id: String, menu_mode: String = "") -> Array[Dictionary]:
	if menu_mode.is_empty():
		menu_mode = mode()
	var pending: Array[Dictionary] = []
	var standing: Array[Dictionary] = []
	var asked: Array[Dictionary] = []
	for topic: Dictionary in GameData.get_dialogue(npc_id).get("topics", []):
		if not Conditions.check(topic.get("if", {})):
			continue
		var variant_id := current_variant(topic)
		if variant_id.is_empty():
			continue
		var topic_id := String(topic["id"])
		var done := is_variant_done(npc_id, topic_id, variant_id)
		var repeatable := is_repeatable(topic)
		var entry := {
			"id": topic_id,
			"label": String(topic.get("label", "")),
			"variant": variant_id,
			"state": DONE if done else PENDING,
			"asked": done,
			"section": SECTION_MAIN,
			"repeatable": repeatable,
			"count": times_asked(npc_id, topic_id, variant_id),
		}
		if not done or menu_mode == MODE_FREE:
			pending.append(entry)
		elif repeatable:
			standing.append(entry)
		else:
			entry["section"] = SECTION_ASKED
			if menu_mode == MODE_SINGLE:
				entry["state"] = LOCKED
			asked.append(entry)
	pending.append_array(standing)
	pending.append_array(asked)
	return pending


## Entrada del menú actual para esa pregunta, o vacía si ahora no se ofrece.
static func menu_entry(npc_id: String, topic_id: String, menu_mode: String = "") -> Dictionary:
	for entry in menu(npc_id, menu_mode):
		if entry["id"] == topic_id:
			return entry
	return {}


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


# --- Guardado ---------------------------------------------------------------------------------

## Registro limpio a partir de lo que trae una partida: sólo preguntas y variantes que existen en los
## datos, con contadores, días y horas válidos. Lo que no se entiende se descarta (con un aviso si
## `report`); nunca impide cargar, porque el resto de la partida reconstruye lo esencial.
static func clean_records(raw: Variant, report: bool = true) -> Dictionary:
	var result := {}
	if raw == null:
		return result
	if not raw is Dictionary:
		_warn(report, "el registro de conversaciones está dañado; se rehace con las preguntas hechas")
		return result
	for topic_key: Variant in raw:
		var topic := _topic_for_key(topic_key)
		if topic.is_empty():
			_warn(report, "se ignora una conversación desconocida («%s»)" % str(topic_key))
			continue
		var entry: Variant = raw[topic_key]
		var variants: Variant = entry.get("variants") if entry is Dictionary else null
		if not variants is Dictionary:
			_warn(report, "se descarta una conversación dañada («%s»)" % topic_key)
			continue
		var known := variant_ids(topic)
		var clean_variants := {}
		for variant_id: Variant in variants:
			var data: Variant = variants[variant_id]
			if not variant_id is String or not known.has(variant_id) or not data is Dictionary:
				_warn(report, "se ignora una variante desconocida o dañada de «%s»" % topic_key)
				continue
			clean_variants[variant_id] = _clean_variant(data)
		if not clean_variants.is_empty():
			result[topic_key] = {"variants": clean_variants}
	_fill_missing_orders(result)
	return result


## Partidas anteriores al registro detallado: reconstruye lo que se puede probar con lo que ya
## guardaban, sin inventar conversaciones.
##
## - `asked` (el antiguo `asked_topics`) dice qué preguntas se empezaron, en el orden en que se
##   hicieron. Una variante cuenta como completada si la partida tiene todo lo que entrega (marcas,
##   pistas y testimonios); si no entrega nada, sólo cuando es la única así de su pregunta (como «aún
##   no ha llegado el informe»). Una pregunta empezada cuyas consecuencias no constan (una partida
##   guardada a mitad de la respuesta) queda pendiente: así repetirla no puede dejar sin entregar
##   algo que la historia necesita.
## - Un testimonio o una pista que sólo entrega una pregunta prueba que esa pregunta se hizo, con la
##   misma exigencia.
## Lo reconstruido se marca `recovered`, sin día ni hora, que no se conocen.
static func recover(records: Dictionary, asked: Array, clues: Array, testimonies: Array, flags: Array = []) -> Dictionary:
	var result := records.duplicate(true)
	var owned: Array = clues + testimonies
	var pending: Array[String] = []
	for topic_key: Variant in asked:
		if topic_key is String and not pending.has(topic_key):
			pending.append(topic_key)
	var producers := _exclusive_producers()
	for item: Variant in owned:
		if producers.has(item):
			var source: String = (producers[item] as String).get_slice("#", 0)
			if not pending.has(source):
				pending.append(source)
	for topic_key in pending:
		if result.has(topic_key):
			continue
		var topic := _topic_for_key(topic_key)
		if topic.is_empty():
			continue
		var done := _proven_variants(topic, owned + flags, asked.has(topic_key))
		var variants := {}
		for variant_id in done:
			var data := {"count": 1, "recovered": true}
			var gained := _owned_effects(variant_block(topic, variant_id), clues, testimonies)
			if not gained.is_empty():
				data["gained"] = gained
			variants[variant_id] = data
		if not variants.is_empty():
			result[topic_key] = {"variants": variants}
	_fill_missing_orders(result)
	return result


## Variantes de una pregunta que se pueden dar por completadas con lo que tiene la partida (`owned`:
## marcas, pistas y testimonios). Las consecuencias de una respuesta se aplican todas a la vez, así
## que basta con sus pistas y testimonios; sólo si no entrega ninguno se miran sus marcas. Una
## variante que no entrega nada sólo se da por hecha si la pregunta consta como empezada
## (`was_asked`) y ninguna otra cosa lo explica.
static func _proven_variants(topic: Dictionary, owned: Array, was_asked: bool) -> Array[String]:
	var proven: Array[String] = []
	var silent: Array[String] = []
	for variant_id in variant_ids(topic):
		var effects: Dictionary = variant_block(topic, variant_id).get("effects", {})
		var needed: Array = effects.get("clues", []) + effects.get("testimonies", [])
		if needed.is_empty():
			needed = effects.get("flags", [])
		if needed.is_empty():
			silent.append(variant_id)
		elif needed.all(func(item: Variant) -> bool: return owned.has(item)):
			proven.append(variant_id)
	if proven.is_empty() and was_asked and silent.size() == 1:
		proven.append(silent[0])
	return proven


## Pistas y testimonios que sólo entrega una variante de una pregunta: elemento -> «npc/pregunta#variante».
static func _exclusive_producers() -> Dictionary:
	var producers := {}
	var repeated := {}
	for npc_id in GameData.get_dialogue_ids():
		for topic: Dictionary in GameData.get_dialogue(npc_id).get("topics", []):
			for variant_id in variant_ids(topic):
				for item in _effect_items(variant_block(topic, variant_id)):
					if producers.has(item):
						repeated[item] = true
					producers[item] = "%s#%s" % [key(npc_id, topic["id"]), variant_id]
	for scene_id: String in GameData.scenes:
		for item in _scene_items(GameData.scenes[scene_id]):
			repeated[item] = true
	for item: String in repeated:
		producers.erase(item)
	return producers


static func _effect_items(block: Dictionary) -> Array[String]:
	var items: Array[String] = []
	var effects: Dictionary = block.get("effects", {})
	for list: String in ["clues", "testimonies"]:
		for item: Variant in effects.get(list, []):
			items.append(String(item))
	return items


## Pistas y testimonios que puede entregar una escena, en cualquiera de sus bloques y respuestas.
static func _scene_items(block: Variant) -> Array[String]:
	var items: Array[String] = []
	if block is Dictionary:
		items.append_array(_effect_items(block))
		for child_key: String in ["after"]:
			items.append_array(_scene_items(block.get(child_key)))
		for choice: Variant in block.get("choices", []):
			items.append_array(_scene_items(choice))
	return items


static func _owned_effects(block: Dictionary, clues: Array, testimonies: Array) -> Dictionary:
	var effects: Dictionary = block.get("effects", {})
	var gained := {}
	var owned_clues: Array = effects.get("clues", []).filter(func(item: Variant) -> bool: return clues.has(item))
	var owned_testimonies: Array = effects.get("testimonies", []).filter(func(item: Variant) -> bool: return testimonies.has(item))
	if not owned_clues.is_empty():
		gained["clues"] = owned_clues
	if not owned_testimonies.is_empty():
		gained["testimonies"] = owned_testimonies
	return gained


static func _clean_variant(data: Dictionary) -> Dictionary:
	var clean := {"count": maxi(_whole(data.get("count"), 1), 1)}
	var order := _whole(data.get("order"), -1)
	if order >= 0:
		clean["order"] = order
	var day := _whole(data.get("day"), 0)
	if day >= 1 and day <= GameClock.LAST_DAY:
		clean["day"] = day
		var minutes := _whole(data.get("minutes"), -1)
		if minutes >= 0 and minutes <= 24 * 60:
			clean["minutes"] = minutes
	var gained: Variant = data.get("gained")
	if gained is Dictionary:
		var clean_gained := {}
		for pair: Array in [["clues", GameData.clues], ["testimonies", GameData.testimonies]]:
			var list: Variant = gained.get(pair[0])
			if list is Array:
				var known: Array = (list as Array).filter(func(item: Variant) -> bool: return item is String and (pair[1] as Dictionary).has(item))
				if not known.is_empty():
					clean_gained[pair[0]] = known
		if not clean_gained.is_empty():
			clean["gained"] = clean_gained
	if data.get("recovered") == true:
		clean["recovered"] = true
	return clean


## Las entradas sin orden (reconstruidas o dañadas) van detrás de las que lo tienen, en el orden en
## que aparecen.
static func _fill_missing_orders(records: Dictionary) -> void:
	var highest := -1
	for topic_key: String in records:
		var variants: Dictionary = records[topic_key]["variants"]
		for variant_id: String in variants:
			highest = maxi(highest, int((variants[variant_id] as Dictionary).get("order", -1)))
	for topic_key: String in records:
		var variants: Dictionary = records[topic_key]["variants"]
		for variant_id: String in variants:
			var data: Dictionary = variants[variant_id]
			if not data.has("order"):
				highest += 1
				data["order"] = highest


static func _topic_for_key(topic_key: Variant) -> Dictionary:
	if not topic_key is String or (topic_key as String).get_slice_count("/") != 2:
		return {}
	var npc_id := (topic_key as String).get_slice("/", 0)
	if not GameData.characters.has(npc_id) or not GameData.has_dialogue(npc_id):
		return {}
	return find_topic(npc_id, (topic_key as String).get_slice("/", 1))


static func _whole(value: Variant, fallback: int) -> int:
	if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floorf(float(value)):
		return int(value)
	return fallback


static func _warn(report: bool, message: String) -> void:
	if report:
		push_warning("Partida guardada: %s." % message)
