class_name InputLabels
extends RefCounted
## Nombres de las teclas y de los botones del mando asignados a cada acción del InputMap, en
## castellano. Las teclas, con la distribución de teclado del jugador cuando el sistema la conoce; los
## botones, con los nombres del mando conectado (Xbox, PlayStation o Nintendo).
##
## Cada consulta dice de qué dispositivo quiere los nombres (`Device`): la lista de controles enseña
## siempre el teclado y la pantalla del mando, siempre el mando; el HUD, las conversaciones, el
## expediente y el tablero piden `CURRENT`, el que el jugador está usando ahora (`Controls`), y
## cambian solos al pasar del teclado al mando y al revés.

enum Device { KEYBOARD, GAMEPAD, CURRENT }

const NAMES := {
	"Shift": "Mayús", "Escape": "Esc", "Enter": "Intro", "Kp Enter": "Intro", "Space": "Espacio",
	"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Backspace": "Retroceso", "Ctrl": "Ctrl",
	"Delete": "Supr", "PageUp": "RePág", "PageDown": "AvPág", "CapsLock": "Bloq Mayús",
}
## Disposiciones de botones que se reconocen y su nombre visible.
const STYLE_NAMES := {"xbox": "Xbox", "playstation": "PlayStation", "nintendo": "Nintendo"}
## Nombre de cada botón según la disposición. `JOY_BUTTON_A` es siempre el de abajo: A en Xbox, la
## cruz en PlayStation y B en Nintendo.
const BUTTON_NAMES := {
	"xbox": {
		JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_BACK: "Vista", JOY_BUTTON_GUIDE: "Xbox", JOY_BUTTON_START: "Menú",
		JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	},
	"playstation": {
		JOY_BUTTON_A: "✕", JOY_BUTTON_B: "○", JOY_BUTTON_X: "□", JOY_BUTTON_Y: "△",
		JOY_BUTTON_BACK: "Create", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_START: "Options",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	},
	"nintendo": {
		JOY_BUTTON_A: "B", JOY_BUTTON_B: "A", JOY_BUTTON_X: "Y", JOY_BUTTON_Y: "X",
		JOY_BUTTON_BACK: "-", JOY_BUTTON_GUIDE: "Home", JOY_BUTTON_START: "+",
		JOY_BUTTON_LEFT_STICK: "LS", JOY_BUTTON_RIGHT_STICK: "RS",
		JOY_BUTTON_LEFT_SHOULDER: "L", JOY_BUTTON_RIGHT_SHOULDER: "R",
	},
}
## Gatillos izquierdo y derecho según la disposición.
const TRIGGER_NAMES := {"xbox": ["LT", "RT"], "playstation": ["L2", "R2"], "nintendo": ["ZL", "ZR"]}
const ARROWS := {Vector2i.UP: "↑", Vector2i.DOWN: "↓", Vector2i.LEFT: "←", Vector2i.RIGHT: "→"}


## Nombre de una tecla. Si la acción usa la tecla física, se traduce a la distribución activa.
static func key_name(event: InputEventKey) -> String:
	var keycode := event.keycode
	if event.physical_keycode != KEY_NONE:
		keycode = event.physical_keycode
		# El servidor sin ventana de las pruebas no conoce distribuciones de teclado.
		if DisplayServer.get_name() != "headless":
			keycode = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
	var text := OS.get_keycode_string(keycode)
	return NAMES.get(text, text)


## Nombre de una tecla por su código físico, como el de las teclas del InputMap.
static func code_name(code: Key) -> String:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return key_name(event)


## Disposición de botones de un mando por el nombre que da el sistema: «xbox» (también para los
## genéricos), «playstation» o «nintendo».
static func style_for(pad_name: String) -> String:
	var lower := pad_name.to_lower()
	for word: String in ["playstation", "dualshock", "dualsense", "ps3", "ps4", "ps5", "sony"]:
		if lower.contains(word):
			return "playstation"
	for word: String in ["nintendo", "switch", "joy-con", "joycon"]:
		if lower.contains(word):
			return "nintendo"
	return "xbox"


## Nombre de un botón o un eje del mando. `grouped` junta los cuatro sentidos de la cruceta y de un
## stick en un solo nombre («Cruceta», «Stick izq.»), como se muestran las cuatro direcciones.
static func button_name(event: InputEvent, grouped: bool = false, style: String = "") -> String:
	if style.is_empty():
		style = Controls.get_gamepad_style()
	var button := event as InputEventJoypadButton
	if button != null:
		if GamepadNavigation.DPAD.has(button.button_index):
			return "Cruceta" if grouped else "Cruceta " + ARROWS[GamepadNavigation.DPAD[button.button_index]]
		var names: Dictionary = BUTTON_NAMES.get(style, BUTTON_NAMES["xbox"])
		if button.button_index == JOY_BUTTON_BACK and style == "playstation" and not _is_dualsense():
			return "Share"
		return String(names.get(button.button_index, "Botón %d" % button.button_index))
	var motion := event as InputEventJoypadMotion
	if motion == null:
		return ""
	var triggers: Array = TRIGGER_NAMES.get(style, TRIGGER_NAMES["xbox"])
	match motion.axis:
		JOY_AXIS_TRIGGER_LEFT:
			return triggers[0]
		JOY_AXIS_TRIGGER_RIGHT:
			return triggers[1]
		JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y:
			var stick := "Stick izq." if motion.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else "Stick der."
			if grouped:
				return stick
			var vertical := motion.axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y]
			var direction := Vector2i(0, 1 if motion.axis_value > 0.0 else -1) if vertical else Vector2i(1 if motion.axis_value > 0.0 else -1, 0)
			return "%s %s" % [stick, ARROWS[direction]]
	return "Eje %d" % motion.axis


## Teclas (o botones) de una acción, en el orden del InputMap y sin repetir.
static func keys_of(action: String, device: Device = Device.KEYBOARD) -> PackedStringArray:
	return _names(action, _uses_gamepad(device), false)


## Alternativas para pulsar cualquiera de las acciones: cada tecla es una alternativa.
static func alternatives(actions: Array, device: Device = Device.KEYBOARD) -> Array[PackedStringArray]:
	var groups: Array[PackedStringArray] = []
	var seen := PackedStringArray()
	for action: String in actions:
		for key in keys_of(action, device):
			if not seen.has(key):
				seen.append(key)
				groups.append(PackedStringArray([key]))
	return groups


## Acciones que se usan juntas, como las cuatro direcciones: la primera alternativa reúne la
## primera tecla de cada acción (W A S D), la segunda la segunda (las flechas), y así. En el mando,
## cada stick y la cruceta cuentan como una sola alternativa («Stick izq.», «Cruceta»).
static func combined(actions: Array, device: Device = Device.KEYBOARD) -> Array[PackedStringArray]:
	var gamepad := _uses_gamepad(device)
	var per_action: Array[PackedStringArray] = []
	var count := 0
	for action: String in actions:
		var keys := _names(action, gamepad, true)
		per_action.append(keys)
		count = maxi(count, keys.size())
	var groups: Array[PackedStringArray] = []
	for index in count:
		var group := PackedStringArray()
		for keys in per_action:
			if index < keys.size() and not group.has(keys[index]):
				group.append(keys[index])
		groups.append(group)
	return groups


## Si una consulta con `device` debe nombrar botones del mando.
static func _uses_gamepad(device: Device) -> bool:
	if device == Device.CURRENT:
		return Controls.is_using_gamepad()
	return device == Device.GAMEPAD


static func _names(action: String, gamepad: bool, grouped: bool) -> PackedStringArray:
	var names := PackedStringArray()
	if not InputMap.has_action(action):
		return names
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if gamepad:
		# Las direcciones de los menús las traduce GamepadNavigation desde la cruceta y el stick.
		events.append_array(GamepadNavigation.virtual_events(action))
	for event in events:
		var text := ""
		if gamepad:
			text = button_name(event, grouped)
		elif event is InputEventKey:
			text = key_name(event)
		if not text.is_empty() and not names.has(text):
			names.append(text)
	return names


static func _is_dualsense() -> bool:
	var lower := Controls.get_gamepad_name().to_lower()
	return lower.contains("dualsense") or lower.contains("ps5")
