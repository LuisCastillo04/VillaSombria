extends Node
## Gestor de partidas guardadas. Cada sistema aporta su parte del estado como una sección
## con nombre; aquí se reúnen en un documento de `SaveFormat`, se escriben en una de las
## cinco ranuras de `user://saves/` mediante `SaveFile` y se validan antes de aplicar nada.
##
## El guardado manual, el autoguardado y el guardado al salir usan el mismo flujo de
## escritura (`_begin_write`), que trabaja en un hilo secundario para no congelar el juego.
## Mientras dura, las demás escrituras esperan o se rechazan, y el resultado llega con
## `save_finished`.
##
## La ranura activa es la única fuente de verdad sobre a qué ranura pertenece la partida en
## curso: la última en la que se guardó con éxito o la que se cargó. El autoguardado sólo
## escribe en ella, y sólo si en disco sigue la versión que conoce el juego. Se conserva
## entre sesiones junto con la huella (`save_id`) de esa versión.
##
## Cada guardado lleva una imagen real de la escena (`SavePreview`), guardada junto a la
## ranura y ligada a ella por su huella SHA-256 en los metadatos.
##
## Los autoguardados se piden con `request_autosave` desde los eventos de la partida; ver
## esa función para la política que evita guardados redundantes o en momentos inseguros.

signal save_started(slot_id: String)
signal save_finished(slot_id: String, ok: bool, message: String)
signal slot_deleted(slot_id: String)
signal slots_changed
signal active_slot_changed(slot_id: String)

const SLOT_COUNT := 5
## Los archivos se llaman `manual_N.json` desde la primera versión con ranuras; se conserva
## el nombre para que las partidas existentes sigan valiendo.
const SLOT_PREFIX := "manual_"
const DEFAULT_STORAGE := "user://saves"
## Archivo único de la versión 1, que se importa una vez a la primera ranura libre.
const DEFAULT_LEGACY_PATH := "user://partida.json"
const LEGACY_MARKER := ".importada_v1"
## Antes los autoguardados rotaban en tres archivos propios; el más reciente se importa una vez.
const LEGACY_AUTO_PREFIX := "auto_"
const LEGACY_AUTO_COUNT := 3
const LEGACY_AUTO_MARKER := ".importada_auto"
## Ranura activa y huella del archivo que le corresponde, para retomarla en otra sesión.
const ACTIVE_SLOT_FILE := "ranura_activa.cfg"
## Bloqueos del jugador compatibles con guardar: desde la pausa el estado es estable.
const SAVE_SAFE_LOCKS: Array[String] = ["pausa"]
const TRANSITION_LOCK := "transicion"
const CASE_CLOSED_FLAG := "caso_resuelto"
## Datos que cambian sin que la partida avance: no cuentan como progreso sin guardar.
const NON_PROGRESS_SECTIONS: Array[String] = ["player"]
const NON_PROGRESS_STATE_KEYS: Array[String] = ["play_seconds"]
## Espera entre comprobaciones mientras el momento no es seguro para guardar.
const AUTOSAVE_RETRY_SECONDS := 1.0
## Al salir se espera a que termine una transición en curso, como mucho este tiempo.
const EXIT_TRANSITION_WAIT := 3.0

## El guardado automático se puede desactivar durante las pruebas.
var autosave_enabled := true
## Espera desde la última petición antes de escribir: agrupa las ráfagas de eventos.
var autosave_delay := 1.5
## Separación mínima entre un guardado y el siguiente autoguardado, salvo en los puntos de
## control, que se guardan en cuanto el momento es seguro.
var autosave_min_interval := 30.0

var _storage_dir := DEFAULT_STORAGE
var _legacy_path := DEFAULT_LEGACY_PATH
var _storage_ready := false
## Secciones registradas: clave -> {"save": Callable, "load": Callable}.
var _sections: Dictionary = {}
var _session_owner: Object = null
var _pending_load: Dictionary = {}
var _writing_slot := ""
var _writing_digest := ""
var _writing_save_id := ""
var _writing_kind := ""
var _writing_reason := ""
var _write_task := -1
var _active_slot := ""
var _active_save_id := ""
## Huella del progreso tal como quedó en el último guardado o carga de la sesión.
var _saved_digest := ""
var _last_save_msec := 0
var _missing_slot_notified := false
var _autosave_reason := ""
var _autosave_checkpoint := false
var _autosave_timer: Timer
## Devuelve {"camera": Camera3D, "fog": float} para fotografiar la escena; lo registra la
## escena de juego.
var _preview_source := Callable()
## Texturas de las imágenes ya leídas, por ranura, con su huella y la fecha del archivo:
## si el archivo cambia, se vuelve a comprobar.
var _preview_cache: Dictionary = {}
## Estado justo antes de la conversación en curso: lo que se guarda si se sale en mitad de
## ella, porque a media conversación el estado puede estar a medio aplicar.
var _pre_dialogue_sections: Dictionary = {}


func _ready() -> void:
	register_section("state", GameState.to_dict, GameState.from_dict)
	register_section("clock", GameClock.to_dict, GameClock.from_dict)
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	add_child(_autosave_timer)
	EventBus.location_changed.connect(_on_location_changed)
	EventBus.clue_discovered.connect(_on_clue_discovered)
	EventBus.deduction_made.connect(_on_deduction_made)
	EventBus.flag_set.connect(_on_flag_set)
	EventBus.day_changed.connect(_on_day_changed)
	DialogueManager.opened.connect(_on_dialogue_opened)
	DialogueManager.closed.connect(_on_dialogue_closed)


## Una escritura en curso debe terminar antes de cerrar el juego.
func _exit_tree() -> void:
	_wait_for_write()


# --- Secciones ---------------------------------------------------------------------------

## Incorpora una parte del estado a las partidas. `save_callable` devuelve un diccionario
## que se pueda escribir en JSON y `load_callable` lo recibe al cargar, vacío si la partida
## no lo incluía. Las secciones se restauran en el orden en que se registraron.
func register_section(key: String, save_callable: Callable, load_callable: Callable) -> void:
	_sections[key] = {"save": save_callable, "load": load_callable}


## Retira una sección. Con `section_owner`, sólo si la registró ese objeto.
func unregister_section(key: String, section_owner: Object = null) -> void:
	if not _sections.has(key):
		return
	if section_owner != null and (_sections[key]["save"] as Callable).get_object() != section_owner:
		return
	_sections.erase(key)


func capture_sections() -> Dictionary:
	var sections := {}
	for key: String in _sections:
		var saver: Callable = _sections[key]["save"]
		if saver.is_valid():
			sections[key] = saver.call()
	return sections


## Aplica las secciones de una partida ya validada.
func apply_sections(sections: Dictionary) -> void:
	for key: String in _sections:
		var loader: Callable = _sections[key]["load"]
		if loader.is_valid():
			loader.call(sections.get(key, {}))


## La escena de juego indica de dónde sacar la imagen de cada guardado.
func register_preview_source(source: Callable) -> void:
	_preview_source = source


func unregister_preview_source(source_owner: Object) -> void:
	if _preview_source.is_valid() and _preview_source.get_object() == source_owner:
		_preview_source = Callable()


# --- Sesión de juego ---------------------------------------------------------------------

## La escena de juego abre la sesión cuando el estado ya es el definitivo. Con el documento
## de la partida cargada, su ranura pasa a ser la activa; sin él (partida nueva) no hay ranura
## activa hasta que el jugador guarde en una.
func begin_session(session_owner: Object, loaded_document: Dictionary = {}) -> void:
	_session_owner = session_owner
	if loaded_document.is_empty():
		_clear_active_slot()
	else:
		var meta: Dictionary = loaded_document["meta"]
		_bind_active_slot(meta.get("slot", ""), meta.get("save_id", ""))
	_saved_digest = _progress_digest()
	_last_save_msec = Time.get_ticks_msec()
	_missing_slot_notified = false
	_cancel_autosave()


func end_session(session_owner: Object) -> void:
	if _session_owner == session_owner:
		_session_owner = null
		_cancel_autosave()


## Indica si la partida ha avanzado desde el último guardado o carga.
func has_unsaved_progress() -> bool:
	return has_session() and _progress_digest() != _saved_digest


func has_session() -> bool:
	return _session_owner != null and is_instance_valid(_session_owner)


func is_busy() -> bool:
	return not _writing_slot.is_empty()


## Origen de la escritura en curso: "manual" o "auto" (autoguardado o guardado al salir).
func get_writing_kind() -> String:
	return _writing_kind if is_busy() else ""


## Motivo de la escritura en curso, como "manual", "pista" o "salida".
func get_writing_reason() -> String:
	return _writing_reason if is_busy() else ""


## Motivo por el que ahora no se puede guardar, o una cadena vacía si se puede. Al salir
## (`for_exit`) basta con que haya partida y no esté cerrada: las conversaciones se
## resuelven con el estado previo y las transiciones se esperan.
func get_save_blocker(for_exit: bool = false) -> String:
	if not has_session():
		return "No hay ninguna partida en curso."
	if is_busy():
		return "Ya se está guardando la partida."
	if for_exit:
		return "El caso ya está cerrado." if GameState.has_flag(CASE_CLOSED_FLAG) else ""
	if DialogueManager.active:
		return "Termina la conversación antes de guardar."
	if GameState.has_flag(CASE_CLOSED_FLAG):
		return "El caso ya está cerrado."
	for reason in GameState.get_player_lock_reasons():
		if reason == TRANSITION_LOCK:
			return "Espera a que termine el cambio de lugar."
		if not SAVE_SAFE_LOCKS.has(reason):
			return "Cierra lo que tengas abierto antes de guardar."
	return ""


## Ranura a la que pertenece la partida en curso, o "" si todavía no tiene ninguna.
func get_active_slot() -> String:
	_ensure_storage()
	return _active_slot


func has_active_slot() -> bool:
	return not get_active_slot().is_empty()


## Ranura que retoma «Continuar»: la activa si sigue siendo válida; si no, la más reciente.
func get_continue_slot() -> String:
	var active := get_active_slot()
	if not active.is_empty() and read_slot(active)["status"] == SaveFormat.Status.OK:
		return active
	return find_latest_slot()


## Comprueba que se puede sobrescribir la ranura activa: que exista y que en disco siga la
## versión que escribió o cargó esta partida. Devuelve "" si se puede, o el motivo. Si la
## ranura ha cambiado por fuera, deja de ser la activa para no pisar otra partida.
func check_active_slot() -> String:
	var slot_id := get_active_slot()
	if slot_id.is_empty():
		return "Esta partida todavía no tiene ranura: guárdala en una para activar el autoguardado."
	var result := read_slot(slot_id)
	match result["status"]:
		SaveFormat.Status.EMPTY:
			return ""
		SaveFormat.Status.OK:
			if str(result["document"]["meta"].get("save_id", "")) == _active_save_id:
				return ""
	_clear_active_slot()
	return "La ranura de esta partida ha cambiado fuera del juego: elige otra para no sobrescribirla."


# --- Ranuras -----------------------------------------------------------------------------

## Cambia la carpeta de partidas. Las pruebas la usan para no tocar las del jugador.
func use_storage(directory: String, legacy_path: String = "") -> void:
	_wait_for_write()
	_storage_dir = directory
	_legacy_path = legacy_path if not legacy_path.is_empty() else directory.path_join("partida.json")
	_storage_ready = false
	_preview_cache.clear()


func get_storage_dir() -> String:
	return _storage_dir


func get_slots() -> Array[String]:
	var slots: Array[String] = []
	for index in SLOT_COUNT:
		slots.append("%s%d" % [SLOT_PREFIX, index + 1])
	return slots


func is_valid_slot(slot_id: String) -> bool:
	return get_slots().has(slot_id)


func get_slot_number(slot_id: String) -> int:
	return int(slot_id.get_slice("_", 1))


func get_slot_path(slot_id: String) -> String:
	return _storage_dir.path_join("%s.json" % slot_id)


func get_preview_path(slot_id: String) -> String:
	return _storage_dir.path_join("%s.jpg" % slot_id)


## Imagen de la partida de una ranura, o null si no tiene, falta o no corresponde a esa
## partida (su huella no coincide). Las imágenes se leen una vez y se reutilizan.
func get_slot_preview(slot_id: String) -> Texture2D:
	var result := read_slot(slot_id)
	if result["status"] != SaveFormat.Status.OK:
		return null
	var preview: Variant = result["document"]["meta"].get("preview")
	if not preview is Dictionary or preview["file"] != get_preview_path(slot_id).get_file():
		return null
	var digest: String = preview["sha256"]
	var path := get_preview_path(slot_id)
	var modified := FileAccess.get_modified_time(path)
	var cached: Dictionary = _preview_cache.get(slot_id, {})
	if cached.get("sha256", "") == digest and cached.get("modified", -1) == modified:
		return cached["texture"]
	_preview_cache.erase(slot_id)
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or SaveFile.sha256_hex(bytes) != digest:
		return null
	var image := Image.new()
	if image.load_jpg_from_buffer(bytes) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_preview_cache[slot_id] = {"sha256": digest, "modified": modified, "texture": texture}
	return texture


## Lee y valida una ranura sin aplicar nada. Devuelve {"status": SaveFormat.Status,
## "error": String, "document": Dictionary}. Si el archivo principal no sirve pero queda
## la copia de una escritura interrumpida, se usa la copia.
func read_slot(slot_id: String) -> Dictionary:
	if not is_valid_slot(slot_id):
		return SaveFormat.failure(SaveFormat.Status.CORRUPT, "Ranura desconocida.")
	_ensure_storage()
	if slot_id == _writing_slot:
		_wait_for_write()
	var path := get_slot_path(slot_id)
	if not SaveFile.exists(path):
		return SaveFormat.failure(SaveFormat.Status.EMPTY, "")
	var result := _read_document(path, slot_id)
	if result["status"] != SaveFormat.Status.OK and SaveFile.has_backup(path):
		var backup := _read_document(path + SaveFile.BACKUP_SUFFIX, slot_id)
		if backup["status"] == SaveFormat.Status.OK:
			return backup
	return result


## Datos de una ranura para los menús, tomados sólo de lo que registra el archivo.
## `kind` es el origen del último guardado: "manual" o "auto".
func get_slot_info(slot_id: String) -> Dictionary:
	var result := read_slot(slot_id)
	var info := {
		"id": slot_id,
		"number": get_slot_number(slot_id),
		"active": slot_id == get_active_slot(),
		"status": result["status"],
		"error": result["error"],
		"kind": "",
		"summary": {},
	}
	if result["status"] == SaveFormat.Status.OK:
		info["kind"] = result["document"]["meta"]["kind"]
		info["summary"] = _summarize(result["document"])
	return info


## Las cinco ranuras, en orden fijo.
func list_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot_id in get_slots():
		slots.append(get_slot_info(slot_id))
	return slots


## La ranura válida guardada más recientemente, o "" si no hay ninguna.
func find_latest_slot() -> String:
	var latest := ""
	var latest_time := -1.0
	for slot_id in get_slots():
		var result := read_slot(slot_id)
		if result["status"] != SaveFormat.Status.OK:
			continue
		var saved_at := float(result["document"]["meta"]["saved_at"])
		if saved_at > latest_time:
			latest_time = saved_at
			latest = slot_id
	return latest


func has_any_save() -> bool:
	return not find_latest_slot().is_empty()


# --- Guardar -----------------------------------------------------------------------------

## Guardado manual en la ranura que eligió el jugador, que pasa a ser la activa si la
## escritura termina bien. Devuelve {"ok": bool, "error": String} según se haya podido
## iniciar; el resultado llega después con `save_finished`. Con `for_exit`, el jugador eligió
## la ranura para poder salir, y valen las mismas reglas que en `save_for_exit`.
func save_to_slot(slot_id: String, for_exit: bool = false) -> Dictionary:
	if not is_valid_slot(slot_id):
		return _refuse("Ranura desconocida.")
	var blocker := get_save_blocker(for_exit)
	if not blocker.is_empty():
		return _refuse(blocker)
	var sections := _exit_sections() if for_exit else capture_sections()
	return _begin_write(slot_id, "manual", "salida" if for_exit else "manual", sections)


## Guardado al salir del juego o volver al menú, por el mismo flujo que los demás: escribe
## en la ranura activa y espera el resultado. Antes espera a la escritura en curso y a que
## termine una transición. Devuelve {"status": String, "message": String}, con estado
## "saved", "nothing" (no hay nada que guardar), "no_slot" (hay que elegir ranura) o
## "failed".
func save_for_exit() -> Dictionary:
	if not has_session() or GameState.has_flag(CASE_CLOSED_FLAG):
		return {"status": "nothing", "message": ""}
	_cancel_autosave()
	while is_busy():
		await save_finished
	var waited := 0.0
	while _is_in_transition() and waited < EXIT_TRANSITION_WAIT:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if not has_active_slot():
		if has_unsaved_progress():
			return {"status": "no_slot", "message": "Esta partida todavía no se ha guardado en ninguna ranura."}
		return {"status": "nothing", "message": ""}
	var problem := check_active_slot()
	if not problem.is_empty():
		return {"status": "no_slot", "message": problem}
	var started := _begin_write(_active_slot, "auto", "salida", _exit_sections())
	if not started["ok"]:
		return {"status": "failed", "message": started["error"]}
	var outcome: Array = await save_finished
	if outcome[1]:
		return {"status": "saved", "message": ""}
	return {"status": "failed", "message": outcome[2]}


## Guarda ya en la ranura activa, sin tocar ninguna otra. Si la partida no tiene ranura
## activa, o en disco ya no está la versión que conoce el juego, no escribe nada.
func autosave(reason: String) -> Dictionary:
	if not autosave_enabled:
		return _refuse("El guardado automático está desactivado.")
	var blocker := get_save_blocker()
	if not blocker.is_empty():
		return _refuse(blocker)
	var problem := check_active_slot()
	if not problem.is_empty():
		return _refuse(problem)
	return _begin_write(_active_slot, "auto", reason, capture_sections())


## Pide un autoguardado sin escribir enseguida. Las peticiones seguidas se agrupan durante
## `autosave_delay`; después se respeta `autosave_min_interval` desde el último guardado,
## salvo en un punto de control (`checkpoint`). Mientras haya una conversación, una
## transición o un panel abierto se espera, y si la partida no ha avanzado desde el último
## guardado la petición se descarta. Una petición nunca se pierde por llegar en mal momento.
func request_autosave(reason: String, checkpoint: bool = false) -> void:
	if not autosave_enabled or not has_session() or GameState.has_flag(CASE_CLOSED_FLAG):
		return
	if checkpoint or not _autosave_checkpoint:
		_autosave_reason = reason
	_autosave_checkpoint = _autosave_checkpoint or checkpoint
	_autosave_timer.start(maxf(autosave_delay, 0.01))


func has_pending_autosave() -> bool:
	return not _autosave_reason.is_empty()


func delete_slot(slot_id: String) -> Dictionary:
	if not is_valid_slot(slot_id):
		return _refuse("Ranura desconocida.")
	if slot_id == _writing_slot:
		return _refuse("Esa ranura se está guardando ahora mismo.")
	_ensure_storage()
	var error := SaveFile.remove(get_slot_path(slot_id))
	if error != OK:
		return _refuse("No se pudo eliminar la partida (%s)." % error_string(error))
	SaveFile.remove(get_preview_path(slot_id))
	_preview_cache.erase(slot_id)
	if slot_id == _active_slot:
		_clear_active_slot()
	slot_deleted.emit(slot_id)
	slots_changed.emit()
	return {"ok": true, "error": ""}


# --- Cargar ------------------------------------------------------------------------------

## Valida la ranura ahora, para poder avisar en el menú, y la deja pendiente hasta que la
## escena de juego esté construida y la recoja con `take_pending_load`.
func request_load(slot_id: String) -> Dictionary:
	var result := read_slot(slot_id)
	match result["status"]:
		SaveFormat.Status.OK:
			_pending_load = result["document"]
			return {"ok": true, "error": ""}
		SaveFormat.Status.EMPTY:
			return _refuse("La ranura está vacía.")
		_:
			return _refuse(result["error"])


func has_pending_load() -> bool:
	return not _pending_load.is_empty()


func take_pending_load() -> Dictionary:
	var document := _pending_load
	_pending_load = {}
	return document


# --- Interno -----------------------------------------------------------------------------

func _ensure_storage() -> void:
	if _storage_ready:
		return
	_storage_ready = true
	if not DirAccess.dir_exists_absolute(_storage_dir):
		var error := DirAccess.make_dir_recursive_absolute(_storage_dir)
		if error != OK:
			push_error("No se pudo crear la carpeta de partidas: %s" % error_string(error))
			return
	_import_legacy_save()
	_import_legacy_autosave()
	_load_active_slot()


## Copia la partida de la versión 1 a la primera ranura libre. El archivo original no se
## modifica; una marca evita importarlo dos veces.
func _import_legacy_save() -> void:
	var marker := _storage_dir.path_join(LEGACY_MARKER)
	if FileAccess.file_exists(marker) or not FileAccess.file_exists(_legacy_path):
		return
	var target := _first_free_slot()
	if target.is_empty():
		return
	var file := SaveFile.read_text(_legacy_path)
	if file["error"] != OK:
		return
	var fallback := {"saved_at": FileAccess.get_modified_time(_legacy_path), "kind": "manual"}
	var result := SaveFormat.parse(file["text"], fallback)
	if result["status"] != SaveFormat.Status.OK:
		push_warning("No se pudo importar la partida anterior: %s" % result["error"])
		return
	var document: Dictionary = result["document"]
	document["meta"]["slot"] = target
	document["meta"]["kind"] = "manual"
	if SaveFile.write_atomic(get_slot_path(target), SaveFormat.to_text(document)) != OK:
		return
	var flag := FileAccess.open(marker, FileAccess.WRITE)
	if flag != null:
		flag.store_string(target)


## Las versiones anteriores guardaban los autoguardados en `auto_N.json`, fuera de las
## ranuras. El más reciente y válido se copia una vez a la primera ranura libre para no
## perder ese progreso; los archivos originales no se tocan.
func _import_legacy_autosave() -> void:
	var marker := _storage_dir.path_join(LEGACY_AUTO_MARKER)
	if FileAccess.file_exists(marker):
		return
	var newest: Dictionary = {}
	for index in LEGACY_AUTO_COUNT:
		var path := _storage_dir.path_join("%s%d.json" % [LEGACY_AUTO_PREFIX, index + 1])
		if not SaveFile.exists(path):
			continue
		var result := _read_document(path, "")
		if result["status"] != SaveFormat.Status.OK:
			continue
		var document: Dictionary = result["document"]
		if newest.is_empty() or float(document["meta"]["saved_at"]) > float(newest["meta"]["saved_at"]):
			newest = document
	if newest.is_empty():
		return
	var target := _first_free_slot()
	if target.is_empty():
		return
	newest["meta"]["slot"] = target
	newest["meta"]["reason"] = "importada"
	newest["meta"].erase("preview")
	if SaveFile.write_atomic(get_slot_path(target), SaveFormat.to_text(newest)) != OK:
		return
	var flag := FileAccess.open(marker, FileAccess.WRITE)
	if flag != null:
		flag.store_string(target)


func _first_free_slot() -> String:
	for slot_id in get_slots():
		if not SaveFile.exists(get_slot_path(slot_id)):
			return slot_id
	return ""


func _read_document(path: String, slot_id: String) -> Dictionary:
	var file := SaveFile.read_text(path)
	if file["error"] != OK:
		return SaveFormat.failure(SaveFormat.Status.CORRUPT, "No se pudo leer el archivo (%s)." % error_string(file["error"]))
	var fallback := {"saved_at": FileAccess.get_modified_time(path), "kind": "manual"}
	var result := SaveFormat.parse(file["text"], fallback)
	if result["status"] == SaveFormat.Status.OK and not slot_id.is_empty():
		# La ranura la decide el nombre del archivo, no lo que diga su contenido.
		result["document"]["meta"]["slot"] = slot_id
	return result


func _summarize(document: Dictionary) -> Dictionary:
	var meta: Dictionary = document["meta"]
	var state: Dictionary = document["sections"]["state"]
	var clock: Dictionary = document["sections"]["clock"]
	var location_id: String = state["location_id"]
	var day := int(clock["day"])
	return {
		"saved_at": float(meta["saved_at"]),
		"reason": meta.get("reason", ""),
		"day": day,
		"day_title": GameData.story["days"].get(str(day), {}).get("title", ""),
		"minutes": int(clock["minutes"]),
		"location_id": location_id,
		"location_name": GameData.locations[location_id].get("name", location_id),
		# -1 indica que el archivo no registraba el tiempo jugado.
		"play_seconds": float(state.get("play_seconds", -1.0)),
		"clues": (state["clues"] as Array).size(),
	}


## Flujo único de escritura para el guardado manual, el autoguardado y el guardado al
## salir. `kind` es "manual" o "auto"; `reason` explica el origen en los metadatos.
func _begin_write(slot_id: String, kind: String, reason: String, sections: Dictionary) -> Dictionary:
	_ensure_storage()
	var meta := {
		"slot": slot_id,
		"kind": kind,
		"saved_at": Time.get_unix_time_from_system(),
		"reason": reason,
		"save_id": _new_save_id(),
	}
	var document := SaveFormat.build(meta, sections.duplicate(true))
	# Nunca se escribe una partida que después no se podría cargar.
	var problem := SaveFormat.validate(document.duplicate(true))
	if not problem.is_empty():
		push_warning("Estado no guardable: %s" % problem["error"])
		return _refuse("El estado actual de la partida no se puede guardar.")
	_cancel_autosave()
	_writing_slot = slot_id
	_writing_digest = _digest_of(document["sections"])
	_writing_save_id = meta["save_id"]
	_writing_kind = kind
	_writing_reason = reason
	save_started.emit(slot_id)
	_capture_and_write(slot_id, document)
	return {"ok": true, "error": ""}


## El estado ya está tomado; aquí se fotografía la escena (dos fotogramas como mucho) y se
## pasa todo al hilo de escritura. La foto la hace este autoload, que nunca se libera, para
## que un cambio de escena no deje la escritura a medias.
func _capture_and_write(slot_id: String, document: Dictionary) -> void:
	var image: Image = null
	var source: Dictionary = _preview_source.call() if _preview_source.is_valid() else {}
	var viewport := SavePreview.build_viewport(source.get("camera"), float(source.get("fog", 0.0)))
	if viewport != null:
		add_child(viewport)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		image = SavePreview.read_image(viewport)
		viewport.queue_free()
	var job := _write_in_background.bind(get_slot_path(slot_id), get_preview_path(slot_id), document, image)
	_write_task = WorkerThreadPool.add_task(job, false, "Guardar partida")


## Estado que se guarda al salir: el actual o, en mitad de una conversación, el de justo
## antes de empezarla.
func _exit_sections() -> Dictionary:
	if DialogueManager.active and not _pre_dialogue_sections.is_empty():
		return _pre_dialogue_sections
	return capture_sections()


func _is_in_transition() -> bool:
	return GameState.get_player_lock_reasons().has(TRANSITION_LOCK)


## Primero la imagen y después la partida, que guarda su huella: si algo falla a medias, la
## partida nunca apunta a una imagen que no sea la suya.
func _write_in_background(path: String, preview_path: String, document: Dictionary, image: Image) -> void:
	var meta: Dictionary = document["meta"]
	if image != null:
		var bytes := image.save_jpg_to_buffer(SavePreview.JPG_QUALITY)
		if not bytes.is_empty() and SaveFile.write_atomic_bytes(preview_path, bytes) == OK:
			meta["preview"] = {"file": preview_path.get_file(), "sha256": SaveFile.sha256_hex(bytes)}
	if not meta.has("preview"):
		SaveFile.remove(preview_path)
	var error := SaveFile.write_atomic(path, SaveFormat.to_text(document))
	_on_write_done.call_deferred(error)


func _on_write_done(error: Error) -> void:
	_wait_for_write()
	var slot_id := _writing_slot
	_writing_slot = ""
	if error == OK:
		_saved_digest = _writing_digest
		_last_save_msec = Time.get_ticks_msec()
		# La última ranura en la que se guardó con éxito es la activa.
		_bind_active_slot(slot_id, _writing_save_id)
		save_finished.emit(slot_id, true, "")
	else:
		# El jugador ya recibe el aviso: en la consola basta una advertencia.
		push_warning("No se pudo guardar la partida en %s: %s" % [slot_id, error_string(error)])
		save_finished.emit(slot_id, false, "No se pudo escribir el archivo (%s)." % error_string(error))
	slots_changed.emit()


## Espera a que el hilo de escritura termine. El resultado se sigue notificando después.
func _wait_for_write() -> void:
	if _write_task == -1:
		return
	WorkerThreadPool.wait_for_task_completion(_write_task)
	_write_task = -1


## Única forma de cambiar la ranura activa. Se guarda en disco para la próxima sesión.
func _bind_active_slot(slot_id: String, save_id: String) -> void:
	_ensure_storage()
	if not is_valid_slot(slot_id):
		_clear_active_slot()
		return
	var changed := slot_id != _active_slot
	_active_slot = slot_id
	_active_save_id = save_id
	_store_active_slot()
	if changed:
		active_slot_changed.emit(slot_id)


func _clear_active_slot() -> void:
	_ensure_storage()
	var changed := not _active_slot.is_empty()
	_active_slot = ""
	_active_save_id = ""
	_store_active_slot()
	if changed:
		active_slot_changed.emit("")


func _store_active_slot() -> void:
	var config := ConfigFile.new()
	config.set_value("activa", "ranura", _active_slot)
	config.set_value("activa", "huella", _active_save_id)
	var error := SaveFile.write_atomic(_storage_dir.path_join(ACTIVE_SLOT_FILE), config.encode_to_text())
	if error != OK:
		push_warning("No se pudo recordar la ranura activa: %s" % error_string(error))


func _load_active_slot() -> void:
	_active_slot = ""
	_active_save_id = ""
	var file := SaveFile.read_text(_storage_dir.path_join(ACTIVE_SLOT_FILE))
	if file["error"] != OK:
		return
	var config := ConfigFile.new()
	if config.parse(file["text"]) != OK:
		return
	var slot_id := str(config.get_value("activa", "ranura", ""))
	if is_valid_slot(slot_id):
		_active_slot = slot_id
		_active_save_id = str(config.get_value("activa", "huella", ""))


## Identifica cada versión escrita de una ranura: la ranura activa sólo se sobrescribe si
## en disco sigue la versión que conoce el juego.
func _new_save_id() -> String:
	return Crypto.new().generate_random_bytes(8).hex_encode()


func _on_autosave_timer_timeout() -> void:
	if _autosave_reason.is_empty():
		return
	# Con el caso cerrado ya no se guarda: esperar sería reintentar para siempre.
	if not autosave_enabled or not has_session() or GameState.has_flag(CASE_CLOSED_FLAG):
		_cancel_autosave()
		return
	if not _autosave_checkpoint:
		var remaining := autosave_min_interval - (Time.get_ticks_msec() - _last_save_msec) / 1000.0
		if remaining > 0.0:
			_autosave_timer.start(remaining)
			return
	if not get_save_blocker().is_empty():
		_autosave_timer.start(AUTOSAVE_RETRY_SECONDS)
		return
	if not has_unsaved_progress():
		_cancel_autosave()
		return
	var reason := _autosave_reason
	_cancel_autosave()
	var result := autosave(reason)
	if not result["ok"] and not has_active_slot():
		_notify_missing_slot(result["error"])


## Sin ranura activa no se escribe en ninguna: se pide al jugador que elija una, una vez por
## sesión para no insistir.
func _notify_missing_slot(message: String) -> void:
	if _missing_slot_notified:
		return
	_missing_slot_notified = true
	EventBus.notification_requested.emit("Autoguardado en espera", message + " (Esc › Guardar partida)", "info")


func _cancel_autosave() -> void:
	_autosave_reason = ""
	_autosave_checkpoint = false
	if _autosave_timer != null:
		_autosave_timer.stop()


func _progress_digest() -> String:
	return _digest_of(capture_sections())


## Huella de unas secciones sin los datos que cambian sin que la partida avance.
func _digest_of(sections: Dictionary) -> String:
	var tracked := sections.duplicate(true)
	for key in NON_PROGRESS_SECTIONS:
		tracked.erase(key)
	var state: Dictionary = tracked.get("state", {})
	for key in NON_PROGRESS_STATE_KEYS:
		state.erase(key)
	# Repetir una pregunta ya hecha sólo suma a su contador: no hay nada nuevo que guardar.
	var conversations: Variant = state.get("conversations")
	if conversations is Dictionary:
		for topic_key: Variant in conversations:
			var variants: Variant = (conversations[topic_key] as Dictionary).get("variants") if conversations[topic_key] is Dictionary else null
			if variants is Dictionary:
				for variant_id: Variant in variants:
					if variants[variant_id] is Dictionary:
						(variants[variant_id] as Dictionary).erase("count")
	return JSON.stringify(tracked, "", true).sha256_text()


func _on_location_changed(_location_id: String) -> void:
	request_autosave("lugar")


func _on_clue_discovered(_clue_id: String) -> void:
	request_autosave("pista")


func _on_deduction_made(_deduction_id: String) -> void:
	request_autosave("deduccion")


func _on_flag_set(_flag: String) -> void:
	request_autosave("evento")


func _on_day_changed(_day: int) -> void:
	request_autosave("nuevo_dia", true)


func _on_dialogue_opened(_npc_id: String) -> void:
	_pre_dialogue_sections = capture_sections().duplicate(true) if has_session() else {}


## Termina una escena narrativa (sin interlocutor) o un interrogatorio.
func _on_dialogue_closed(npc_id: String) -> void:
	_pre_dialogue_sections = {}
	request_autosave("escena" if npc_id.is_empty() else "interrogatorio")


func _refuse(message: String) -> Dictionary:
	return {"ok": false, "error": message}
