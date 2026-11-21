class_name InputBindings
extends RefCounted
## Teclas del jugador: qué acciones se pueden reasignar, cuáles son sus teclas de fábrica y qué teclas
## admite cada una. Sólo lógica, sin estado ni interfaz: el autoload `Controls` guarda las teclas
## vigentes y las aplica, y las pantallas las presentan.
##
## **Fuente única de las teclas de fábrica.** Son las del InputMap de `project.godot`, leídas de
## `ProjectSettings` (`input/<acción>`). Ningún script repite una tecla por defecto: cambiar una en
## el editor de Godot cambia también la que recupera «Restaurar las teclas predeterminadas».
##
## **Huecos.** Cada acción tiene una tecla principal y, si se quiere, una alternativa (W y ↑). La
## principal nunca queda vacía: ninguna acción se puede quedar sin tecla.
##
## **Teclas fijas.** Las de los menús (flechas, Intro, Espacio, Esc...) no se reasignan, para que
## siempre se pueda navegar, confirmar y volver atrás. Algunas acciones sí pueden compartirlas: las
## que sólo sirven explorando (moverse, correr, esperar) no hacen nada en los menús, así que no
## estorban. Las que también funcionan dentro de una pantalla (abrir y cerrar el expediente, el
## tablero y el mapa; interactuar, que avanza el diálogo) no pueden usar las de moverse por ella.
##
## Para añadir una acción reasignable: créala en el InputMap y añade su entrada a `ACTIONS`.

## Huecos de cada acción: la tecla principal y una alternativa.
const SLOTS := 2

## Categorías de la pantalla de reasignación, en orden (las mismas que la lista de controles).
const CATEGORIES: Array[String] = ["Movimiento", "Interacción", "Menús", "Otros"]

## Acciones que el jugador puede reasignar.
## - `label`: nombre en la pantalla de reasignación y en los avisos de conflicto.
## - `category`: categoría de `CATEGORIES`.
## - `shares`: grupos de teclas de los menús (`MENU_GROUPS`) que puede usar también.
const ACTIONS: Array[Dictionary] = [
	{"id": "move_forward", "label": "Avanzar", "category": "Movimiento", "shares": ["navegacion", "confirmar", "pagina"]},
	{"id": "move_back", "label": "Retroceder", "category": "Movimiento", "shares": ["navegacion", "confirmar", "pagina"]},
	{"id": "move_left", "label": "Ir a la izquierda", "category": "Movimiento", "shares": ["navegacion", "confirmar", "pagina"]},
	{"id": "move_right", "label": "Ir a la derecha", "category": "Movimiento", "shares": ["navegacion", "confirmar", "pagina"]},
	{"id": "sprint", "label": "Correr (mantener)", "category": "Movimiento", "shares": ["navegacion", "confirmar", "pagina"]},
	# Interactuar también avanza el diálogo y confirma la respuesta señalada: puede usar Intro o
	# Espacio (allí hacen lo mismo), pero no las flechas, que recorren las respuestas.
	{"id": "interact", "label": "Interactuar y avanzar el diálogo", "category": "Interacción", "shares": ["confirmar"]},
	{"id": "open_journal", "label": "Abrir o cerrar el expediente", "category": "Menús", "shares": []},
	{"id": "open_board", "label": "Abrir o cerrar el tablero", "category": "Menús", "shares": []},
	{"id": "open_map", "label": "Abrir o cerrar el mapa", "category": "Menús", "shares": []},
	{"id": "wait_time", "label": "Dejar pasar una hora", "category": "Otros", "shares": ["navegacion", "confirmar", "pagina"]},
]

## Teclas de los menús, leídas de sus acciones del InputMap. Ninguna se reasigna.
const MENU_GROUPS := {
	"navegacion": {"actions": ["ui_up", "ui_down", "ui_left", "ui_right"], "use": "moverse por los menús"},
	"confirmar": {"actions": ["ui_accept"], "use": "confirmar en los menús"},
	"pagina": {"actions": ["ui_page_up", "ui_page_down"], "use": "pasar página en el expediente"},
}
## Acciones de teclas fijas que ninguna acción reasignable puede usar: volver atrás y pausar.
const RESERVED_ACTIONS: Array[String] = ["pause", "ui_cancel"]
## Teclas del sistema operativo o con estado propio. Alt forma parte de Alt + F4 y Alt + Tab, y la
## tecla de Windows abre el menú de inicio: asignarlas estorbaría al sistema.
const SYSTEM_KEYS: Array[Key] = [KEY_ALT, KEY_META, KEY_PRINT, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK, KEY_MENU, KEY_HYPER]
## Teclas modificadoras. Solas sí se pueden asignar (correr usa Mayús), salvo las del sistema.
const MODIFIER_KEYS: Array[Key] = [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]


static func action_ids() -> Array[String]:
	var ids: Array[String] = []
	for definition in ACTIONS:
		ids.append(definition["id"])
	return ids


static func has_action(action: String) -> bool:
	return definition_of(action) != {}


static func definition_of(action: String) -> Dictionary:
	for definition in ACTIONS:
		if definition["id"] == action:
			return definition
	return {}


static func label_of(action: String) -> String:
	return String(definition_of(action).get("label", action))


## Acciones reasignables de una categoría, en orden.
static func actions_in(category: String) -> Array[String]:
	var ids: Array[String] = []
	for definition in ACTIONS:
		if definition["category"] == category:
			ids.append(definition["id"])
	return ids


# --- Teclas ---

## Código de una tecla: el físico si lo tiene (la posición en el teclado, como guarda el InputMap del
## juego) y, si no, el lógico. Las teclas que no son letras tienen el mismo código en los dos.
static func code_of(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


## Teclas de fábrica de una acción, en el orden de `project.godot`.
static func default_keys(action: String) -> Array[Key]:
	var setting: Variant = ProjectSettings.get_setting("input/" + action)
	var keys: Array[Key] = []
	if typeof(setting) != TYPE_DICTIONARY:
		return keys
	for event: InputEvent in (setting as Dictionary).get("events", []):
		var key := event as InputEventKey
		if key != null and not keys.has(code_of(key)) and keys.size() < SLOTS:
			keys.append(code_of(key))
	return keys


## Teclas de fábrica de todas las acciones reasignables.
static func defaults() -> Dictionary:
	var map := {}
	for action in action_ids():
		map[action] = default_keys(action)
	return map


## Teclas de una acción tal como están ahora en el InputMap.
static func current_keys(action: String) -> Array[Key]:
	var keys: Array[Key] = []
	if not InputMap.has_action(action):
		return keys
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null and not keys.has(code_of(key)):
			keys.append(code_of(key))
	return keys


## Pone en el InputMap las teclas de una acción. Sólo sustituye las del teclado: los botones y ejes
## del mando de la acción se conservan.
static func apply(action: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action):
		return
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for code in keys:
		var key := InputEventKey.new()
		key.physical_keycode = code
		InputMap.action_add_event(action, key)


## Nombre interno de una tecla para el archivo de ajustes («W», «Shift», «Up»); no depende de la
## distribución del teclado ni del idioma.
static func key_to_text(code: Key) -> String:
	return OS.get_keycode_string(code)


## Tecla de un nombre del archivo de ajustes, o `KEY_NONE` si no se reconoce.
static func key_from_text(text: String) -> Key:
	if text.strip_edges().is_empty():
		return KEY_NONE
	return OS.find_keycode_from_string(text.strip_edges())


# --- Qué teclas admite cada acción ---

## Por qué una tecla no puede ir en una acción. Vacío si puede. Si no, `reason` («sistema»,
## «reservada» o «menu») y `use`, para qué la usa el juego («moverse por los menús»).
static func blocked_reason(action: String, code: Key) -> Dictionary:
	if code == KEY_NONE or code == KEY_UNKNOWN or code in SYSTEM_KEYS:
		return {"reason": "sistema", "use": "el sistema operativo"}
	for reserved in RESERVED_ACTIONS:
		if _action_keys(reserved).has(code):
			return {"reason": "reservada", "use": "pausar el juego y volver atrás"}
	if code in DialogueControls.NUMBER_KEYS or code in DialogueControls.KEYPAD_KEYS:
		return {"reason": "reservada", "use": "elegir respuestas y secciones del expediente"}
	var shares: Array = definition_of(action).get("shares", [])
	for group: String in MENU_GROUPS:
		if shares.has(group):
			continue
		for menu_action: String in MENU_GROUPS[group]["actions"]:
			if _action_keys(menu_action).has(code):
				return {"reason": "menu", "use": MENU_GROUPS[group]["use"]}
	return {}


static func is_modifier(code: Key) -> bool:
	return code in MODIFIER_KEYS


## Qué acción reasignable usa una tecla en un juego de teclas, sin contar `except_action`.
## Devuelve `{"action": ..., "slot": ...}` o vacío.
static func find_owner(map: Dictionary, code: Key, except_action: String = "") -> Dictionary:
	for action: String in map:
		if action == except_action:
			continue
		var keys: Array = map[action]
		var slot := keys.find(code)
		if slot >= 0:
			return {"action": action, "slot": slot}
	return {}


## Comprueba un juego completo de teclas: cada acción reasignable con una o dos teclas admitidas y
## ninguna tecla en dos acciones. Devuelve el primer problema o vacío si es válido.
static func validate_map(map: Dictionary) -> String:
	var used := {}
	for action in action_ids():
		if not map.has(action):
			return "falta %s" % action
		var keys: Array = map[action]
		if keys.is_empty() or keys.size() > SLOTS:
			return "%s debe tener entre 1 y %d teclas" % [action, SLOTS]
		for code: Key in keys:
			if not blocked_reason(action, code).is_empty():
				return "%s no admite %s" % [action, key_to_text(code)]
			if used.has(code):
				return "%s y %s comparten %s" % [action, used[code], key_to_text(code)]
			used[code] = action
	return ""


static func _action_keys(action: String) -> Array[Key]:
	var keys: Array[Key] = []
	if not InputMap.has_action(action):
		return keys
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null:
			keys.append(code_of(key))
	return keys
