extends Node
## Gestor de partidas guardadas. Cada sistema aporta su parte del estado como una sección
## con nombre; aquí se reúnen en un documento de `SaveFormat`, se escriben en una ranura de
## `user://saves/` mediante `SaveFile` y se validan antes de aplicar nada.
##
## La escritura se hace en un hilo secundario para no congelar el juego. Mientras dura, las
## demás escrituras se rechazan y el resultado llega con `save_finished`.
##
## Los autoguardados se piden con `request_autosave` desde los eventos de la partida; ver
## esa función para la política que evita guardados redundantes o en momentos inseguros.

signal save_started(slot_id: String)
signal save_finished(slot_id: String, ok: bool, message: String)
signal slot_deleted(slot_id: String)
signal slots_changed

const MANUAL_SLOTS := 5
const AUTO_SLOTS := 3
const MANUAL_PREFIX := "manual_"
const AUTO_PREFIX := "auto_"
const DEFAULT_STORAGE := "user://saves"
## Archivo único de la versión 1, que se importa una vez a la primera ranura manual libre.
const DEFAULT_LEGACY_PATH := "user://partida.json"
const LEGACY_MARKER := ".importada_v1"
## Bloqueos del jugador compatibles con guardar: desde la pausa el estado es estable.
const SAVE_SAFE_LOCKS: Array[String] = ["pausa"]
const TRANSITION_LOCK := "transicion"
const CASE_CLOSED_FLAG := "caso_resuelto"
## Datos que cambian sin que la partida avance: no cuentan como progreso sin guardar.
const NON_PROGRESS_SECTIONS: Array[String] = ["player"]
const NON_PROGRESS_STATE_KEYS: Array[String] = ["play_seconds"]
## Espera entre comprobaciones mientras el momento no es seguro para guardar.
const AUTOSAVE_RETRY_SECONDS := 1.0

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
var _write_task := -1
## Huella del progreso tal como quedó en el último guardado o carga de la sesión.
var _saved_digest := ""
var _last_save_msec := 0
var _autosave_reason := ""
var _autosave_checkpoint := false
var _autosave_timer: Timer


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


# --- Sesión de juego ---------------------------------------------------------------------

## La escena de juego abre la sesión cuando el estado ya es el definitivo, sea una partida
## nueva o una cargada. Sin sesión no se puede guardar.
func begin_session(session_owner: Object) -> void:
	_session_owner = session_owner
	_saved_digest = _progress_digest()
	_last_save_msec = Time.get_ticks_msec()
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


## Motivo por el que ahora no se puede guardar, o una cadena vacía si se puede.
func get_save_blocker() -> String:
	if not has_session():
		return "No hay ninguna partida en curso."
	if is_busy():
		return "Ya se está guardando la partida."
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


# --- Ranuras -----------------------------------------------------------------------------

## Cambia la carpeta de partidas. Las pruebas la usan para no tocar las del jugador.
func use_storage(directory: String, legacy_path: String = "") -> void:
	_wait_for_write()
	_storage_dir = directory
	_legacy_path = legacy_path if not legacy_path.is_empty() else directory.path_join("partida.json")
	_storage_ready = false


func get_storage_dir() -> String:
	return _storage_dir


func get_manual_slots() -> Array[String]:
	return _make_slot_ids(MANUAL_PREFIX, MANUAL_SLOTS)


func get_auto_slots() -> Array[String]:
	return _make_slot_ids(AUTO_PREFIX, AUTO_SLOTS)


func get_all_slots() -> Array[String]:
	var slots := get_manual_slots()
	slots.append_array(get_auto_slots())
	return slots


func is_valid_slot(slot_id: String) -> bool:
	return get_all_slots().has(slot_id)


func is_auto_slot(slot_id: String) -> bool:
	return slot_id.begins_with(AUTO_PREFIX) and is_valid_slot(slot_id)


func get_slot_number(slot_id: String) -> int:
	return int(slot_id.get_slice("_", 1))


func get_slot_path(slot_id: String) -> String:
	return _storage_dir.path_join("%s.json" % slot_id)


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
func get_slot_info(slot_id: String) -> Dictionary:
	var result := read_slot(slot_id)
	var info := {
		"id": slot_id,
		"kind": _kind_of(slot_id),
		"number": get_slot_number(slot_id),
		"status": result["status"],
		"error": result["error"],
		"summary": {},
	}
	if result["status"] == SaveFormat.Status.OK:
		info["summary"] = _summarize(result["document"])
	return info


## Todas las ranuras, o sólo las de un tipo ("manual" o "auto"), en orden fijo.
func list_slots(kind: String = "") -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for slot_id in get_all_slots():
		if kind.is_empty() or _kind_of(slot_id) == kind:
			slots.append(get_slot_info(slot_id))
	return slots


## La ranura válida guardada más recientemente, manual o automática, o "" si no hay.
func find_latest_slot() -> String:
	var latest := ""
	var latest_time := -1.0
	for slot_id in get_all_slots():
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


## Rotación de los autoguardados: la primera ranura automática vacía; si no hay, una dañada
## o incompatible; si no, la más antigua. Las ranuras manuales nunca entran en la rotación.
func next_autosave_slot() -> String:
	var damaged := ""
	var oldest := ""
	var oldest_time := INF
	for slot_id in get_auto_slots():
		var result := read_slot(slot_id)
		match result["status"]:
			SaveFormat.Status.EMPTY:
				return slot_id
			SaveFormat.Status.OK:
				var saved_at := float(result["document"]["meta"]["saved_at"])
				if saved_at < oldest_time:
					oldest_time = saved_at
					oldest = slot_id
			_:
				if damaged.is_empty():
					damaged = slot_id
	return damaged if not damaged.is_empty() else oldest


# --- Guardar -----------------------------------------------------------------------------

## Empieza a guardar en una ranura. Devuelve {"ok": bool, "error": String} según se haya
## podido iniciar; el resultado de la escritura llega después con `save_finished`.
func save_to_slot(slot_id: String, reason: String = "manual") -> Dictionary:
	if not is_valid_slot(slot_id):
		return _refuse("Ranura desconocida.")
	var blocker := get_save_blocker()
	if not blocker.is_empty():
		return _refuse(blocker)
	_ensure_storage()
	var meta := {
		"slot": slot_id,
		"kind": _kind_of(slot_id),
		"saved_at": Time.get_unix_time_from_system(),
		"reason": reason,
	}
	var document := SaveFormat.build(meta, capture_sections())
	# Nunca se escribe una partida que después no se podría cargar.
	var problem := SaveFormat.validate(document.duplicate(true))
	if not problem.is_empty():
		push_warning("Estado no guardable: %s" % problem["error"])
		return _refuse("El estado actual de la partida no se puede guardar.")
	_writing_slot = slot_id
	_writing_digest = _digest_of(document["sections"])
	save_started.emit(slot_id)
	var text := SaveFormat.to_text(document)
	_write_task = WorkerThreadPool.add_task(_write_in_background.bind(get_slot_path(slot_id), text), false, "Guardar partida")
	return {"ok": true, "error": ""}


## Guarda ya en la ranura automática que corresponde según la rotación.
func autosave(reason: String) -> Dictionary:
	if not autosave_enabled:
		return _refuse("El guardado automático está desactivado.")
	return save_to_slot(next_autosave_slot(), reason)


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


## Copia la partida de la versión 1 a la primera ranura manual libre. El archivo original
## no se modifica; una marca evita importarlo dos veces.
func _import_legacy_save() -> void:
	var marker := _storage_dir.path_join(LEGACY_MARKER)
	if FileAccess.file_exists(marker) or not FileAccess.file_exists(_legacy_path):
		return
	var target := ""
	for slot_id in get_manual_slots():
		if not SaveFile.exists(get_slot_path(slot_id)):
			target = slot_id
			break
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


func _read_document(path: String, slot_id: String) -> Dictionary:
	var file := SaveFile.read_text(path)
	if file["error"] != OK:
		return SaveFormat.failure(SaveFormat.Status.CORRUPT, "No se pudo leer el archivo (%s)." % error_string(file["error"]))
	var fallback := {"saved_at": FileAccess.get_modified_time(path), "kind": _kind_of(slot_id)}
	var result := SaveFormat.parse(file["text"], fallback)
	if result["status"] == SaveFormat.Status.OK:
		# La ranura la decide el nombre del archivo, no lo que diga su contenido.
		var meta: Dictionary = result["document"]["meta"]
		meta["slot"] = slot_id
		meta["kind"] = _kind_of(slot_id)
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


func _write_in_background(path: String, text: String) -> void:
	var error := SaveFile.write_atomic(path, text)
	_on_write_done.call_deferred(error)


func _on_write_done(error: Error) -> void:
	_wait_for_write()
	var slot_id := _writing_slot
	_writing_slot = ""
	if error == OK:
		_saved_digest = _writing_digest
		_last_save_msec = Time.get_ticks_msec()
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
	autosave(reason)


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


## Termina una escena narrativa (sin interlocutor) o un interrogatorio.
func _on_dialogue_closed(npc_id: String) -> void:
	request_autosave("escena" if npc_id.is_empty() else "interrogatorio")


func _kind_of(slot_id: String) -> String:
	return "auto" if slot_id.begins_with(AUTO_PREFIX) else "manual"


func _make_slot_ids(prefix: String, count: int) -> Array[String]:
	var slots: Array[String] = []
	for index in count:
		slots.append("%s%d" % [prefix, index + 1])
	return slots


func _refuse(message: String) -> Dictionary:
	return {"ok": false, "error": message}
