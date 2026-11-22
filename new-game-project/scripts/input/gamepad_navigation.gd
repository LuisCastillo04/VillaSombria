class_name GamepadNavigation
extends RefCounted
## Moverse por los menús con la cruceta y el stick izquierdo del mando.
##
## Godot entrega el stick como una serie de valores: un solo empujón produce varios eventos por encima
## de la zona muerta, y cada uno cuenta como una pulsación de `ui_down` para los scripts que leen
## eventos (las respuestas de una conversación, las ranuras, las pestañas del expediente, los
## selectores de Configuración...). Por eso el stick y la cruceta no están en las acciones `ui_*` del
## InputMap: `Controls` les pasa su estado cada fotograma y esta clase lo traduce en pulsaciones
## limpias de `ui_up`, `ui_down`, `ui_left` y `ui_right`:
##
## - Una pulsación al empujar (o al cambiar de dirección) y su suelta al volver al centro.
## - Mantenida, se repite como una tecla: tras `REPEAT_DELAY` y después cada `REPEAT_INTERVAL`.
## - Zona muerta con histéresis: hace falta pasar de `PRESS_THRESHOLD` para empujar y bajar de
##   `RELEASE_THRESHOLD` para soltar, así un stick que tiembla en el borde no pulsa dos veces.
## - La cruceta manda sobre el stick, y de una diagonal sólo cuenta el eje dominante.
## - Un toque de cruceta más corto que un fotograma (pulsado y soltado entre dos llamadas) no se
##   pierde: llega en `taps` y se envía como pulsación y suelta.
##
## El detective no usa esta traducción: camina con `Input.get_vector` sobre las acciones de
## movimiento, que sí incluyen el stick (con su zona muerta radial) y la cruceta.

const PRESS_THRESHOLD := 0.5
const RELEASE_THRESHOLD := 0.3
const REPEAT_DELAY := 0.45
const REPEAT_INTERVAL := 0.12
## Acción de los menús de cada dirección.
const ACTIONS := {
	Vector2i.UP: "ui_up",
	Vector2i.DOWN: "ui_down",
	Vector2i.LEFT: "ui_left",
	Vector2i.RIGHT: "ui_right",
}
## Botones de la cruceta de cada dirección.
const DPAD := {
	JOY_BUTTON_DPAD_UP: Vector2i.UP,
	JOY_BUTTON_DPAD_DOWN: Vector2i.DOWN,
	JOY_BUTTON_DPAD_LEFT: Vector2i.LEFT,
	JOY_BUTTON_DPAD_RIGHT: Vector2i.RIGHT,
}

var _held := Vector2i.ZERO
var _from_stick := false
var _timer := 0.0


## Dirección que se mantiene ahora (cero si ninguna).
func get_held() -> Vector2i:
	return _held


## Recibe el estado del stick izquierdo y de la cruceta, y las direcciones de la cruceta pulsadas
## desde la llamada anterior, y devuelve las pulsaciones y sueltas que hay que enviar, en orden.
func update(stick: Vector2, dpad: Vector2i, delta: float, taps: Array[Vector2i] = []) -> Array[InputEventAction]:
	var events: Array[InputEventAction] = []
	var direction := _direction(stick, dpad)
	for tap in taps:
		# Si sigue pulsada, la pulsación normal de abajo ya la envía.
		if tap != direction and tap != _held:
			events.append(make_event(tap, true))
			events.append(make_event(tap, false))
	if direction != _held:
		if _held != Vector2i.ZERO:
			events.append(make_event(_held, false))
		_held = direction
		_from_stick = dpad == Vector2i.ZERO
		if direction != Vector2i.ZERO:
			events.append(make_event(direction, true))
			_timer = REPEAT_DELAY
	elif _held != Vector2i.ZERO:
		_timer -= delta
		if _timer <= 0.0:
			events.append(make_event(_held, true))
			_timer = REPEAT_INTERVAL
	return events


## Suelta lo que se mantenía (al desconectar el mando, por ejemplo).
func release() -> Array[InputEventAction]:
	var events: Array[InputEventAction] = []
	if _held != Vector2i.ZERO:
		events.append(make_event(_held, false))
	_held = Vector2i.ZERO
	return events


## Eventos del mando que esta clase traduce a una acción de los menús (la cruceta y el stick izquierdo
## en esa dirección), para poder nombrarlos. Vacío para las demás acciones.
static func virtual_events(action: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for direction: Vector2i in ACTIONS:
		if ACTIONS[direction] != action:
			continue
		var button := InputEventJoypadButton.new()
		button.button_index = DPAD.find_key(direction)
		events.append(button)
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_LEFT_X if direction.x != 0 else JOY_AXIS_LEFT_Y
		motion.axis_value = float(direction.x if direction.x != 0 else direction.y)
		events.append(motion)
	return events


static func make_event(direction: Vector2i, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = ACTIONS[direction]
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	return event


func _direction(stick: Vector2, dpad: Vector2i) -> Vector2i:
	if dpad != Vector2i.ZERO:
		return Vector2i(0, dpad.y) if dpad.y != 0 else Vector2i(dpad.x, 0)
	var threshold := RELEASE_THRESHOLD if _held != Vector2i.ZERO and _from_stick else PRESS_THRESHOLD
	var x := absf(stick.x)
	var y := absf(stick.y)
	if maxf(x, y) < threshold:
		return Vector2i.ZERO
	if y >= x:
		return Vector2i(0, 1 if stick.y > 0.0 else -1)
	return Vector2i(1 if stick.x > 0.0 else -1, 0)
