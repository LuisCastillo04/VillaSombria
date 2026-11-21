extends Node
## Controles del jugador: las teclas que ha elegido para cada acción.
##
## Las teclas vigentes se aplican al InputMap, así que todo el juego (el detective, las pantallas, el
## HUD, la lista de controles) las usa sin saber que existe la reasignación: sigue preguntando por
## acciones (`interact`, `open_journal`...). Sólo se sustituyen las teclas; los botones del mando de
## cada acción se conservan.
##
## Qué acciones se pueden cambiar, cuáles son sus teclas de fábrica y qué teclas admite cada una lo
## decide `InputBindings`. Aquí se comprueba cada cambio antes de hacerlo: una tecla que ya usa otra
## acción no se asigna sin más, sino que se ofrece intercambiarla (`check` y `swap`), y ninguna
## acción se queda nunca sin tecla.
##
## **Persistencia.** Las teclas son una preferencia del jugador, común a todas las partidas: se
## guardan en `user://ajustes.cfg` (sección `controles`) a través de `Settings`, nunca en las ranuras.
## Sólo se escriben las acciones que difieren de las de fábrica, por su nombre de tecla:
##
##     [controles]
##     interact=["F"]
##     move_forward=["W", "Up"]
##
## Se leen al arrancar y cada vez que `Settings` vuelve a leer su archivo. Lo que no sea válido (una
## tecla desconocida o reservada, dos acciones con la misma tecla) se descarta y el archivo se corrige.
## Restaurar las teclas de fábrica retira la sección entera; el resto de preferencias no cambia.

## Cambiaron las teclas de estas acciones (ya aplicadas al InputMap y guardadas).
signal bindings_changed(actions: PackedStringArray)

## Sección de `ajustes.cfg` donde se guardan las teclas.
const SECTION := "controles"

## Teclas vigentes de cada acción reasignable: códigos físicos, la principal primero.
var _keys: Dictionary = {}
## Qué pasó en la última lectura: acciones leídas y descartadas.
var _load_report: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reloaded.connect(load_bindings)
	load_bindings()


# --- Lectura ---

## Lee las teclas guardadas y las aplica al InputMap. Lo que falte toma las de fábrica; lo que no sea
## válido se descarta y el archivo se reescribe sin ello.
func load_bindings() -> void:
	var stored := Settings.read_section(SECTION)
	var map := InputBindings.defaults()
	var loaded := PackedStringArray()
	var rejected := PackedStringArray()
	for action: String in stored:
		var keys := _parse_keys(action, stored[action])
		if keys.is_empty():
			rejected.append(action)
		else:
			map[action] = keys
			loaded.append(action)
	# Un juego incoherente (dos acciones con la misma tecla) no se aplica a medias: se vuelve a las de
	# fábrica para que ninguna acción quede inservible.
	if not InputBindings.validate_map(map).is_empty():
		rejected.append_array(loaded)
		loaded.clear()
		map = InputBindings.defaults()
	_keys = map
	_apply_all()
	_load_report = {"loaded": loaded, "rejected": rejected}
	if not rejected.is_empty():
		_save()
	bindings_changed.emit(PackedStringArray(InputBindings.action_ids()))


## Qué pasó en la última lectura, para las pruebas y el diagnóstico.
func get_load_report() -> Dictionary:
	return _load_report.duplicate(true)


## Teclas de una entrada del archivo, o vacío si no es válida para esa acción.
static func _parse_keys(action: String, value: Variant) -> Array[Key]:
	var keys: Array[Key] = []
	if not InputBindings.has_action(action):
		return keys
	var names: Array = []
	match typeof(value):
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY:
			names.assign(value)
		TYPE_STRING, TYPE_STRING_NAME:
			names.append(value)
		_:
			return keys
	if names.is_empty() or names.size() > InputBindings.SLOTS:
		return [] as Array[Key]
	for name: Variant in names:
		if typeof(name) != TYPE_STRING and typeof(name) != TYPE_STRING_NAME:
			return [] as Array[Key]
		var code := InputBindings.key_from_text(String(name))
		if keys.has(code) or not InputBindings.blocked_reason(action, code).is_empty():
			return [] as Array[Key]
		keys.append(code)
	return keys


# --- Consulta ---

## Teclas vigentes de una acción, la principal primero.
func get_keys(action: String) -> Array[Key]:
	var keys: Array[Key] = []
	keys.assign(_keys.get(action, []))
	return keys


## Tecla de un hueco (0, la principal; 1, la alternativa), o `KEY_NONE` si está vacío.
func get_key(action: String, slot: int) -> Key:
	var keys: Array = _keys.get(action, [])
	return keys[slot] if slot >= 0 and slot < keys.size() else KEY_NONE


## Si la acción usa otras teclas que las de fábrica.
func is_customized(action: String) -> bool:
	return get_keys(action) != InputBindings.default_keys(action)


## Acciones con teclas distintas de las de fábrica.
func customized_actions() -> PackedStringArray:
	var found := PackedStringArray()
	for action in InputBindings.action_ids():
		if is_customized(action):
			found.append(action)
	return found


# --- Cambios ---

## Qué pasaría al poner `code` en un hueco de una acción, sin cambiar nada. `result` es:
## - `"ok"`: se puede asignar sin más (`assign`).
## - `"unchanged"`: ya está ahí, o es la principal y se pide como alternativa.
## - `"reorder"`: es la otra tecla de la misma acción; `assign` intercambia los dos huecos.
## - `"blocked"`: la tecla no se admite; `reason` y `use` dicen por qué (`InputBindings.blocked_reason`).
## - `"conflict"`: la usa otra acción (`action`, `slot`). `swap_ok` dice si se pueden intercambiar
##   sin que esa acción se quede sin tecla, y `gives` qué tecla recibiría (`KEY_NONE` si ninguna).
func check(action: String, slot: int, code: Key) -> Dictionary:
	if not InputBindings.has_action(action) or slot < 0 or slot >= InputBindings.SLOTS:
		return {"result": "blocked", "reason": "accion", "use": ""}
	var keys := get_keys(action)
	var current := get_key(action, slot)
	if code == current:
		return {"result": "unchanged"}
	var blocked := InputBindings.blocked_reason(action, code)
	if not blocked.is_empty():
		return {"result": "blocked", "reason": blocked["reason"], "use": blocked["use"]}
	if keys.has(code):
		return {"result": "reorder"} if current != KEY_NONE else {"result": "unchanged"}
	var owner := InputBindings.find_owner(_keys, code, action)
	if owner.is_empty():
		return {"result": "ok"}
	var other_keys := get_keys(owner["action"])
	var swap_ok := current != KEY_NONE or other_keys.size() > 1
	# La tecla que se le daría a cambio tiene que servirle a la otra acción.
	if current != KEY_NONE and not InputBindings.blocked_reason(owner["action"], current).is_empty():
		swap_ok = false
	return {"result": "conflict", "action": owner["action"], "slot": owner["slot"], "swap_ok": swap_ok, "gives": current}


## Pone una tecla en un hueco si `check` lo permite sin conflicto («ok» o «reorder»). Devuelve si
## cambió algo.
func assign(action: String, slot: int, code: Key) -> bool:
	var outcome := check(action, slot, code)
	var keys := get_keys(action)
	match outcome["result"]:
		"ok":
			if slot < keys.size():
				keys[slot] = code
			else:
				keys.append(code)
		"reorder":
			var other := keys.find(code)
			keys[other] = keys[slot]
			keys[slot] = code
		_:
			return false
	return _commit({action: keys})


## Resuelve un conflicto intercambiando: la acción recibe `code` y la que lo tenía recibe a cambio la
## tecla que había en el hueco (o, si estaba vacío, se queda con las demás). Devuelve si cambió algo.
func swap(action: String, slot: int, code: Key) -> bool:
	var outcome := check(action, slot, code)
	if outcome["result"] != "conflict" or not outcome["swap_ok"]:
		return false
	var other: String = outcome["action"]
	var other_keys := get_keys(other)
	var given: Key = outcome["gives"]
	if given != KEY_NONE:
		other_keys[int(outcome["slot"])] = given
	else:
		other_keys.remove_at(int(outcome["slot"]))
	var keys := get_keys(action)
	if slot < keys.size():
		keys[slot] = code
	else:
		keys.append(code)
	return _commit({action: keys, other: other_keys})


## Quita la tecla alternativa. La principal no se puede quitar: la acción se quedaría sin tecla.
func clear_slot(action: String, slot: int) -> bool:
	var keys := get_keys(action)
	if slot <= 0 or slot >= keys.size():
		return false
	keys.remove_at(slot)
	return _commit({action: keys})


## Vuelve a las teclas de fábrica de todas las acciones reasignables y retira del archivo las
## personalizadas. Las demás preferencias (gráficos, audio, accesibilidad...) no cambian.
func restore_defaults() -> void:
	var changes := {}
	for action in InputBindings.action_ids():
		changes[action] = InputBindings.default_keys(action)
	if not _commit(changes):
		# Ya eran las de fábrica: aun así, que no quede nada personalizado en el archivo.
		_save()


## Aplica un juego de cambios si el resultado es válido. Devuelve si cambió algo.
func _commit(changes: Dictionary) -> bool:
	var next := _keys.duplicate(true)
	var changed := PackedStringArray()
	for action: String in changes:
		var keys: Array[Key] = []
		keys.assign(changes[action])
		if keys != get_keys(action):
			next[action] = keys
			changed.append(action)
	if changed.is_empty():
		return false
	var problem := InputBindings.validate_map(next)
	if not problem.is_empty():
		push_warning("Teclas rechazadas: %s" % problem)
		return false
	_keys = next
	for action in changed:
		InputBindings.apply(action, get_keys(action))
	_save()
	bindings_changed.emit(changed)
	return true


## Escribe en `ajustes.cfg` las acciones que difieren de las de fábrica; sin ninguna, retira la
## sección.
func _save() -> void:
	var values := {}
	for action in customized_actions():
		var names: Array[String] = []
		for code in get_keys(action):
			names.append(InputBindings.key_to_text(code))
		values[action] = names
	if values.is_empty() and Settings.read_section(SECTION).is_empty():
		return
	Settings.write_section(SECTION, values)


func _apply_all() -> void:
	for action in InputBindings.action_ids():
		InputBindings.apply(action, get_keys(action))
