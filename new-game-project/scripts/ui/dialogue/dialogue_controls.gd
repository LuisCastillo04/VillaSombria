class_name DialogueControls
extends RefCounted
## Qué entradas manejan una conversación y cómo se anuncian en pantalla.
##
## Avanzar usa las acciones reales del InputMap («interact» y «ui_accept») y el clic izquierdo. Con
## las respuestas en pantalla, las teclas numéricas (fila superior o teclado numérico) eligen una,
## «ui_up» y «ui_down» las recorren y las mismas acciones de avanzar confirman la señalada; el
## ratón señala al moverse y elige al hacer clic. Los rótulos se construyen con las teclas asignadas
## de verdad (`InputLabels`), así que una reasignación futura se verá aquí sin tocar la interfaz.

## Acciones que hacen avanzar el texto, en el orden en que se anuncian.
const ADVANCE_ACTIONS: Array[String] = ["interact", "ui_accept"]
## Teclas de las respuestas: la fila de números y el teclado numérico.
const NUMBER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
const KEYPAD_KEYS: Array[Key] = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9]


## Si el evento es una pulsación que hace avanzar: la tecla de interactuar, la de aceptar o un clic.
## Las repeticiones de una tecla mantenida no cuentan, para no saltarse intervenciones.
static func is_advance(event: InputEvent) -> bool:
	for action in ADVANCE_ACTIONS:
		if event.is_action_pressed(action):
			return true
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT


## Si el evento confirma la respuesta señalada: la tecla de interactuar o la de aceptar, sin
## repeticiones. El clic lo recoge cada tarjeta.
static func is_confirm(event: InputEvent) -> bool:
	for action in ADVANCE_ACTIONS:
		if event.is_action_pressed(action):
			return true
	return false


## Posición de la respuesta que elige una tecla numérica (0 para el 1), o -1 si no es una de ellas.
static func number_index(event: InputEvent) -> int:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return -1
	var index := NUMBER_KEYS.find(key.keycode)
	if index < 0:
		index = KEYPAD_KEYS.find(key.keycode)
	return index


## Nombre de la tecla con la que se avanza: la primera de interactuar o, si no tiene, la de aceptar.
static func advance_key() -> String:
	for action in ADVANCE_ACTIONS:
		var keys := InputLabels.keys_of(action)
		if not keys.is_empty():
			return keys[0]
	return ""


## Rótulo del aviso para continuar, con la tecla real entre corchetes («[E] Continuar»).
static func continue_text() -> String:
	var key := advance_key()
	return "Continuar" if key.is_empty() else "[%s] Continuar" % key


## Ayuda bajo las respuestas. Siempre se puede elegir con el ratón; las teclas numéricas sólo
## llegan a las nueve primeras, así que sólo se mencionan si hay alguna respuesta que elegir.
static func choice_hint(option_count: int) -> String:
	if option_count <= 0:
		return "Elige con el ratón"
	return "Elige con el ratón o con las teclas numéricas"
