class_name InputLabels
extends RefCounted
## Nombres de las teclas asignadas a cada acción del InputMap, en castellano y con la distribución
## de teclado del jugador cuando el sistema la conoce. Sólo lee el teclado: cuando haya mandos o
## reasignación, este es el punto que hay que ampliar.

const NAMES := {
	"Shift": "Mayús", "Escape": "Esc", "Enter": "Intro", "Kp Enter": "Intro", "Space": "Espacio",
	"Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Backspace": "Retroceso", "Ctrl": "Ctrl",
}


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


## Teclas de una acción, en el orden del InputMap y sin repetir.
static func keys_of(action: String) -> PackedStringArray:
	var keys := PackedStringArray()
	if not InputMap.has_action(action):
		return keys
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null and not keys.has(key_name(key)):
			keys.append(key_name(key))
	return keys


## Alternativas para pulsar cualquiera de las acciones: cada tecla es una alternativa.
static func alternatives(actions: Array) -> Array[PackedStringArray]:
	var groups: Array[PackedStringArray] = []
	var seen := PackedStringArray()
	for action: String in actions:
		for key in keys_of(action):
			if not seen.has(key):
				seen.append(key)
				groups.append(PackedStringArray([key]))
	return groups


## Acciones que se usan juntas, como las cuatro direcciones: la primera alternativa reúne la
## primera tecla de cada acción (W A S D), la segunda la segunda (las flechas), y así.
static func combined(actions: Array) -> Array[PackedStringArray]:
	var per_action: Array[PackedStringArray] = []
	var count := 0
	for action: String in actions:
		var keys := keys_of(action)
		per_action.append(keys)
		count = maxi(count, keys.size())
	var groups: Array[PackedStringArray] = []
	for index in count:
		var group := PackedStringArray()
		for keys in per_action:
			if index < keys.size():
				group.append(keys[index])
		groups.append(group)
	return groups
