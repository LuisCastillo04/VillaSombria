class_name SaveFormat
extends RefCounted
## Formato de las partidas guardadas: un documento JSON con identificador, versión,
## metadatos y una sección por sistema. Antes de aplicar nada se comprueban la estructura,
## los tipos y las referencias a los datos del juego, y las versiones antiguas se
## convierten a la actual paso a paso.

enum Status { OK, EMPTY, CORRUPT, INCOMPATIBLE }

const FORMAT_ID := "villa_sombria.partida"
const VERSION := 2
const KINDS: Array[String] = ["manual", "auto"]
## Secciones sin las que no se puede reconstruir una partida.
const REQUIRED_SECTIONS: Array[String] = ["state", "clock"]
const STRING_LISTS: Array[String] = ["flags", "clues", "testimonies", "deductions", "asked_topics"]
const MAX_NOTE_LENGTH := 4000


## Crea un documento de la versión actual.
static func build(meta: Dictionary, sections: Dictionary) -> Dictionary:
	return {"format": FORMAT_ID, "version": VERSION, "meta": meta, "sections": sections}


static func to_text(document: Dictionary) -> String:
	return JSON.stringify(document, "\t")


## Interpreta el texto de un archivo. Devuelve {"status": Status, "error": String,
## "document": Dictionary}; el documento sólo se rellena si la partida es válida, y ya
## convertido a la versión actual. `fallback` aporta lo que las versiones antiguas no
## registraban, como la fecha de guardado.
static func parse(text: String, fallback: Dictionary = {}) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return failure(Status.CORRUPT, "El archivo está dañado o no es una partida.")
	var document: Dictionary = json.data
	var version := _read_version(document)
	if version > VERSION:
		return failure(Status.INCOMPATIBLE, "La partida se creó con una versión más reciente del juego.")
	if version < 1:
		return failure(Status.CORRUPT, "El archivo no indica una versión válida.")
	document = _migrate(document, version, fallback)
	var problem := validate(document)
	if not problem.is_empty():
		return problem
	return {"status": Status.OK, "error": "", "document": document}


static func failure(status: Status, message: String) -> Dictionary:
	return {"status": status, "error": message, "document": {}}


## Comprueba un documento de la versión actual y corrige lo que se puede recuperar sin
## inventar datos: quita referencias desconocidas y descarta la posición del detective si
## no es válida. Devuelve un diccionario vacío si la partida se puede cargar.
static func validate(document: Dictionary) -> Dictionary:
	var meta: Variant = document.get("meta")
	if not meta is Dictionary:
		return failure(Status.CORRUPT, "Faltan los metadatos de la partida.")
	var problem := _validate_meta(meta)
	if not problem.is_empty():
		return failure(Status.CORRUPT, problem)
	var sections: Variant = document.get("sections")
	if not sections is Dictionary:
		return failure(Status.CORRUPT, "Faltan los datos de la partida.")
	for key: Variant in (sections as Dictionary).keys():
		if not key is String or not sections[key] is Dictionary:
			return failure(Status.CORRUPT, "Una sección de la partida está dañada.")
	for key in REQUIRED_SECTIONS:
		if not sections.has(key):
			return failure(Status.CORRUPT, "Falta la sección «%s»." % key)
	var state_problem := _validate_state(sections["state"])
	if not state_problem.is_empty():
		return state_problem
	problem = _validate_clock(sections["clock"])
	if not problem.is_empty():
		return failure(Status.CORRUPT, problem)
	if sections.has("player") and not _is_valid_pose(sections["player"]):
		push_warning("Posición del detective no válida: aparecerá en la entrada del lugar.")
		(sections as Dictionary).erase("player")
	return {}


static func _read_version(document: Dictionary) -> int:
	var version: Variant = document.get("version")
	if not _is_whole(version):
		return 0
	# Desde la versión 2 el documento se identifica; la 1 no lo hacía.
	if int(version) >= 2 and int(version) <= VERSION and document.get("format") != FORMAT_ID:
		return 0
	return int(version)


## Cada paso convierte un documento de la versión N en uno de la N + 1.
static func _migrate(document: Dictionary, version: int, fallback: Dictionary) -> Dictionary:
	var current := document
	for step in range(version, VERSION):
		match step:
			1:
				current = _migrate_from_v1(current, fallback)
	return current


## La versión 1 era un único archivo con "state" y "clock", sin metadatos ni posición.
static func _migrate_from_v1(old: Dictionary, fallback: Dictionary) -> Dictionary:
	var sections := {}
	for key: String in ["state", "clock"]:
		if old.get(key) is Dictionary:
			sections[key] = old[key]
	var meta := {
		"kind": fallback.get("kind", "manual"),
		"saved_at": int(fallback.get("saved_at", 0)),
		"reason": "importada",
	}
	return build(meta, sections)


static func _validate_meta(meta: Dictionary) -> String:
	var kind: Variant = meta.get("kind")
	if not (kind is String and KINDS.has(kind)):
		return "El tipo de partida no es válido."
	var saved_at: Variant = meta.get("saved_at")
	if not _is_number(saved_at) or not is_finite(float(saved_at)) or float(saved_at) < 0.0:
		return "La fecha de guardado no es válida."
	# Se conservan las fracciones de segundo: la rotación de autoguardados las necesita.
	meta["saved_at"] = float(saved_at)
	if not meta.get("reason", "") is String:
		meta["reason"] = ""
	if meta.has("save_id") and not meta["save_id"] is String:
		meta.erase("save_id")
	if meta.has("preview") and not _is_valid_preview(meta["preview"]):
		meta.erase("preview")
	return ""


## La imagen de la ranura se describe con el nombre de un archivo de la misma carpeta y su
## huella; cualquier otra cosa se descarta y la ranura se muestra sin imagen.
static func _is_valid_preview(preview: Variant) -> bool:
	if not preview is Dictionary:
		return false
	var file: Variant = preview.get("file")
	var digest: Variant = preview.get("sha256")
	if not file is String or not digest is String:
		return false
	var name_ok := (file as String).is_valid_filename() and (file as String).get_extension() == "jpg"
	return name_ok and (digest as String).length() == 64 and (digest as String).is_valid_hex_number()


static func _validate_state(state: Dictionary) -> Dictionary:
	for key in STRING_LISTS:
		if not state.has(key):
			state[key] = []
		elif not _is_string_array(state[key]):
			return failure(Status.CORRUPT, "La lista «%s» está dañada." % key)
	state["clues"] = _known_ids(state["clues"], GameData.clues, "pista")
	state["testimonies"] = _known_ids(state["testimonies"], GameData.testimonies, "testimonio")
	state["deductions"] = _known_ids(state["deductions"], GameData.deductions, "deducción")
	var hypotheses: Variant = state.get("hypotheses", {})
	if not hypotheses is Dictionary:
		return failure(Status.CORRUPT, "Las hipótesis del tablero están dañadas.")
	state["hypotheses"] = _clean_hypotheses(hypotheses)
	state["accusation_draft"] = _clean_accusation_draft(state)
	# Registro de los interrogatorios: opcional (las partidas anteriores no lo tienen) y, si está
	# dañado, se descarta lo que no se entiende; `GameState.from_dict` rehace lo que falte.
	state["conversations"] = ConversationLog.clean_records(state.get("conversations", {}))
	state["seen_topics"] = ConversationLog.clean_seen(state.get("seen_topics", [])).keys()
	var location: Variant = state.get("location_id")
	if not location is String:
		return failure(Status.CORRUPT, "Falta el lugar de la partida.")
	var scene: String = GameData.locations.get(location, {}).get("scene", "")
	if scene.is_empty() or not ResourceLoader.exists(scene):
		return failure(Status.INCOMPATIBLE, "El lugar guardado no existe en esta versión del juego.")
	if not state.get("spawn_id", "") is String:
		state["spawn_id"] = ""
	var attempts: Variant = state.get("accusation_attempts", 0)
	if not _is_whole(attempts) or int(attempts) < 0:
		return failure(Status.CORRUPT, "El contador de acusaciones no es válido.")
	state["accusation_attempts"] = int(attempts)
	if state.has("play_seconds"):
		var played: Variant = state["play_seconds"]
		if not _is_number(played) or not is_finite(float(played)) or float(played) < 0.0:
			state.erase("play_seconds")
	return {}


static func _validate_clock(clock: Dictionary) -> String:
	var day: Variant = clock.get("day")
	if not _is_whole(day) or int(day) < 1 or int(day) > GameClock.LAST_DAY:
		return "El día guardado no es válido."
	var minutes: Variant = clock.get("minutes")
	if not _is_whole(minutes) or int(minutes) < 0 or int(minutes) > 24 * 60:
		return "La hora guardada no es válida."
	clock["day"] = int(day)
	clock["minutes"] = int(minutes)
	return ""


static func _is_valid_pose(pose: Dictionary) -> bool:
	var position: Variant = pose.get("position")
	if not position is Array or (position as Array).size() != 3:
		return false
	for value: Variant in position:
		if not _is_number(value) or not is_finite(float(value)):
			return false
	var yaw: Variant = pose.get("yaw", 0.0)
	return _is_number(yaw) and is_finite(float(yaw)) and pose.get("location_id", "") is String


## Quita duplicados y elementos que ya no existen en los datos del caso.
static func _known_ids(ids: Array, known: Dictionary, label: String) -> Array:
	var result: Array = []
	for item_id: String in ids:
		if known.has(item_id) and not result.has(item_id):
			result.append(item_id)
		elif not known.has(item_id):
			push_warning("Partida guardada: se ignora un elemento desconocido (%s «%s»)." % [label, item_id])
	return result


static func _clean_hypotheses(hypotheses: Dictionary) -> Dictionary:
	var result := {}
	for suspect_id: Variant in hypotheses:
		var entry: Variant = hypotheses[suspect_id]
		if not suspect_id is String or not GameData.characters.has(suspect_id) or not entry is Dictionary:
			continue
		var status: Variant = entry.get("status", "")
		var note: Variant = entry.get("note", "")
		if status is String and note is String:
			result[suspect_id] = {"status": status, "note": (note as String).left(MAX_NOTE_LENGTH)}
	return result


## Borrador de la acusación de una partida ya con sus listas limpias. Es opcional (las partidas
## anteriores no lo tienen) y nunca impide cargar: se queda sólo con las elecciones que siguen
## valiendo con lo que esa partida había descubierto, y sin los campos vacíos.
static func _clean_accusation_draft(state: Dictionary) -> Dictionary:
	var raw: Variant = state.get("accusation_draft", {})
	var known: Array = state["clues"] + state["testimonies"] + state["deductions"]
	var clean := Investigation.clean_accusation_draft(raw, known)
	var result := {}
	for field: String in clean:
		if not (clean[field] as String).is_empty():
			result[field] = clean[field]
	if raw is Dictionary:
		for field: Variant in raw:
			if not result.has(field) and not str(raw[field]).is_empty():
				push_warning("Partida guardada: se descarta una elección del borrador de la acusación (%s «%s»)." % [field, raw[field]])
	elif raw != null:
		push_warning("Partida guardada: el borrador de la acusación está dañado y empieza vacío.")
	return result


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_whole(value: Variant) -> bool:
	return _is_number(value) and is_finite(float(value)) and float(value) == floorf(float(value))


static func _is_string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	for item: Variant in value:
		if not item is String:
			return false
	return true
