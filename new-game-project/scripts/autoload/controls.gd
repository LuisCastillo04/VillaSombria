extends Node
## Controles del jugador: las teclas que ha elegido para cada acción y el dispositivo con el que
## juega (teclado y ratón, o mando).
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
##
## **Mandos.** Los botones del mando son los del InputMap de `project.godot` (fijos: no se reasignan).
## Este autoload, además:
## - Sabe qué usa el jugador: la última pulsación de un mando pasa a «mando» y la de una tecla, un
##   clic o un movimiento claro del ratón vuelve a «teclado y ratón» (`input_device_changed`). Los
##   rótulos de teclas del juego (`InputLabels` con `Device.CURRENT`) cambian con él. Lo lee de la
##   ventana (`Window.window_input`), antes de que ninguna pantalla consuma la pulsación.
## - Detecta mandos al arrancar y al conectarlos o desconectarlos durante la partida; al desconectar
##   el que se usaba, suelta el movimiento para que el detective no siga andando solo y vuelve al
##   teclado. La escena de juego, además, abre la pausa.
## - Traduce la cruceta y el stick izquierdo a las direcciones de los menús (`GamepadNavigation`).

## Cambiaron las teclas de estas acciones (ya aplicadas al InputMap y guardadas).
signal bindings_changed(actions: PackedStringArray)
## El jugador pasó a usar el mando (`true`) o el teclado y el ratón (`false`).
signal input_device_changed(using_gamepad: bool)
## Se conectó un mando.
signal gamepad_connected(device: int, gamepad_name: String)
## Se desconectó un mando. `was_in_use` dice si el jugador estaba jugando con él.
signal gamepad_disconnected(device: int, was_in_use: bool)

## Sección de `ajustes.cfg` donde se guardan las teclas.
const SECTION := "controles"
## Desplazamiento del ratón (en píxeles) que cuenta como usarlo: un roce de la mesa no cambia los
## rótulos del mando a los del teclado.
const MOUSE_ACTIVITY := 6.0
## Empuje de un stick o de un gatillo que cuenta como usar el mando.
const AXIS_ACTIVITY := 0.5
## Acciones que se sueltan al desconectar el mando, para que el detective no siga andando solo.
const HELD_ACTIONS: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "sprint"]

## Disposición de botones que se muestra aunque el mando sea otro (para capturas y pruebas); vacío,
## la del mando en uso.
var style_override := ""

## Teclas vigentes de cada acción reasignable: códigos físicos, la principal primero.
var _keys: Dictionary = {}
## Qué pasó en la última lectura: acciones leídas y descartadas.
var _load_report: Dictionary = {}

var _using_gamepad := false
## Mando que se usó por última vez (o el primero conectado): da nombre a los botones.
var _active_pad := -1
## Stick izquierdo de cada mando y botones de la cruceta pulsados, leídos de sus eventos.
var _sticks: Dictionary = {}
var _dpads: Dictionary = {}
## Direcciones de la cruceta pulsadas desde el último fotograma, aunque ya se hayan soltado.
var _dpad_taps: Array[Vector2i] = []
var _navigation := GamepadNavigation.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reloaded.connect(load_bindings)
	load_bindings()
	get_tree().root.window_input.connect(_on_window_input)
	Input.joy_connection_changed.connect(handle_connection_change)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		_active_pad = pads[0]


func _process(delta: float) -> void:
	for event in _navigation.update(_stick(), _dpad(), delta, _dpad_taps):
		Input.parse_input_event(event)
	_dpad_taps.clear()


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


# --- Mandos ---

## Si el jugador está usando el mando (su última pulsación fue del mando).
func is_using_gamepad() -> bool:
	return _using_gamepad


## Cambia a mano el dispositivo en uso, como si se acabara de pulsar uno de ellos.
func set_using_gamepad(using: bool) -> void:
	if using == _using_gamepad:
		return
	_using_gamepad = using
	input_device_changed.emit(using)


## Mandos conectados ahora mismo.
func get_connected_gamepads() -> Array[int]:
	return Input.get_connected_joypads()


## Nombre que da el sistema al mando en uso (o al primero conectado); vacío si no hay ninguno.
func get_gamepad_name() -> String:
	return Input.get_joy_name(_active_pad) if _active_pad >= 0 else ""


## Disposición de botones del mando en uso: «xbox», «playstation» o «nintendo».
func get_gamepad_style() -> String:
	if not style_override.is_empty():
		return style_override
	return InputLabels.style_for(get_gamepad_name())


## Un mando se ha conectado o desconectado. Lo llama `Input.joy_connection_changed`; las pruebas lo
## usan para simularlo.
func handle_connection_change(device: int, connected: bool) -> void:
	if connected:
		if _active_pad < 0:
			_active_pad = device
		var pad_name := Input.get_joy_name(device)
		EventBus.notification_requested.emit("Mando conectado", "%s. Ya puedes jugar con él." % (pad_name if not pad_name.is_empty() else "Mando"), "info")
		gamepad_connected.emit(device, pad_name)
		return
	_sticks.erase(device)
	_dpads.erase(device)
	var others: Array[int] = []
	for pad in Input.get_connected_joypads():
		if pad != device:
			others.append(pad)
	var was_in_use := _using_gamepad and (_active_pad == device or _active_pad < 0)
	if _active_pad == device:
		_active_pad = others[0] if not others.is_empty() else -1
	# Lo que el mando tenía pulsado se suelta: ni el detective sigue andando ni un menú sigue bajando.
	for event in _navigation.release():
		Input.parse_input_event(event)
	for action in HELD_ACTIONS:
		Input.action_release(action)
	if was_in_use and others.is_empty():
		set_using_gamepad(false)
	EventBus.notification_requested.emit("Mando desconectado", "Puedes seguir con el teclado y el ratón, o volver a conectarlo.", "info")
	gamepad_disconnected.emit(device, was_in_use)


## Cada pulsación llega aquí antes que a ninguna pantalla: decide qué dispositivo se está usando y
## guarda el estado de la cruceta y del stick izquierdo para la navegación de los menús. Las
## pulsaciones que genera la propia navegación (`InputEventAction`) no cuentan.
func _on_window_input(event: InputEvent) -> void:
	var button := event as InputEventJoypadButton
	if button != null:
		if GamepadNavigation.DPAD.has(button.button_index):
			if not _dpads.has(button.device):
				_dpads[button.device] = {}
			(_dpads[button.device] as Dictionary)[button.button_index] = button.pressed
			if button.pressed:
				_dpad_taps.append(GamepadNavigation.DPAD[button.button_index])
		if button.pressed:
			_use_pad(button.device)
		return
	var motion := event as InputEventJoypadMotion
	if motion != null:
		if motion.axis == JOY_AXIS_LEFT_X or motion.axis == JOY_AXIS_LEFT_Y:
			var stick: Vector2 = _sticks.get(motion.device, Vector2.ZERO)
			if motion.axis == JOY_AXIS_LEFT_X:
				stick.x = motion.axis_value
			else:
				stick.y = motion.axis_value
			_sticks[motion.device] = stick
		if absf(motion.axis_value) >= AXIS_ACTIVITY:
			_use_pad(motion.device)
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		set_using_gamepad(false)
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() >= MOUSE_ACTIVITY:
		set_using_gamepad(false)


func _use_pad(device: int) -> void:
	if device >= 0:
		_active_pad = device
	set_using_gamepad(true)


## El stick izquierdo más empujado de todos los mandos.
func _stick() -> Vector2:
	var strongest := Vector2.ZERO
	for device: int in _sticks:
		var stick: Vector2 = _sticks[device]
		if stick.length() > strongest.length():
			strongest = stick
	return strongest


## Dirección de la cruceta, sumando todos los mandos.
func _dpad() -> Vector2i:
	var direction := Vector2i.ZERO
	for device: int in _dpads:
		var pressed: Dictionary = _dpads[device]
		for button: int in pressed:
			if pressed[button]:
				direction += GamepadNavigation.DPAD[button]
	return direction.clamp(-Vector2i.ONE, Vector2i.ONE)
