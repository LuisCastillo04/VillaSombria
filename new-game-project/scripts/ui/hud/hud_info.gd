class_name HudInfo
extends RefCounted
## Lo que muestra el HUD de exploración, leído de los sistemas reales del juego: el lugar de
## `GameData`, la fecha de `StoryDirector` y `GameClock`, el objetivo pendiente de `StoryDirector`
## y las teclas del InputMap a través de `InputLabels`. Sólo consulta, nunca modifica nada, de modo
## que la interfaz no duplica lógica narrativa y se puede probar sin pantallas.

## Teclas de la barra inferior, en orden. Cada entrada muestra la primera alternativa del InputMap.
## - `actions`: acciones del InputMap; se muestra la primera tecla.
## - `together`: acciones que se usan como grupo (las cuatro direcciones), en una sola tecla.
## - `priority`: 0 es imprescindible; con poco ancho se ocultan primero los números más altos.
const CONTROL_HINTS: Array[Dictionary] = [
	{"id": "move", "label": "Moverse", "together": ["move_forward", "move_left", "move_back", "move_right"], "priority": 0},
	{"id": "sprint", "label": "Correr", "actions": ["sprint"], "priority": 3},
	{"id": "interact", "label": "Interactuar", "actions": ["interact"], "priority": 0},
	{"id": "journal", "label": "Expediente", "actions": ["open_journal"], "priority": 1},
	{"id": "board", "label": "Tablero", "actions": ["open_board"], "priority": 2},
	{"id": "map", "label": "Mapa", "actions": ["open_map"], "priority": 1},
	{"id": "wait", "label": "Esperar", "actions": ["wait_time"], "priority": 3},
	{"id": "pause", "label": "Pausa", "actions": ["pause"], "priority": 0},
]


static func location_name(location_id: String) -> String:
	return GameData.locations.get(location_id, {}).get("name", "")


## Fecha del día en curso y hora del reloj narrativo.
static func date_text() -> String:
	return "%s  ·  %s" % [StoryDirector.get_day_title(), GameClock.format_time()]


## Primer objetivo pendiente del día, o texto vacío si no queda ninguno.
static func current_objective() -> String:
	for objective in StoryDirector.get_objectives():
		if not bool(objective["done"]):
			return objective["text"]
	return ""


## Teclas que se muestran para una entrada de `CONTROL_HINTS`: la primera alternativa del InputMap.
## Vacío si la acción no existe o no tiene ninguna tecla asignada.
static func hint_keys(hint: Dictionary) -> PackedStringArray:
	var groups: Array[PackedStringArray] = []
	if hint.has("together"):
		groups = InputLabels.combined(hint["together"])
	else:
		groups = InputLabels.alternatives(hint.get("actions", []))
	return groups[0] if not groups.is_empty() else PackedStringArray()


## Primera tecla de una acción, o texto vacío si no tiene ninguna.
static func action_key(action: String) -> String:
	var keys := InputLabels.keys_of(action)
	return keys[0] if not keys.is_empty() else ""
