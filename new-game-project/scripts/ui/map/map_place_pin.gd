class_name MapPlacePin
extends BaseButton
## Chincheta de un lugar con su rótulo, como las cartelas de un mapa antiguo. Es un botón: se
## señala con el ratón, el teclado, el mando o el dedo, y al pulsarla queda seleccionada. Sobre la
## cabeza lleva el rombo de objetivo si en el lugar hay algo pendiente.
##
## El nodo abarca la chincheta y el rótulo, para que sean fáciles de tocar en una pantalla táctil;
## `place_at` lo coloca de modo que la punta caiga en el punto del mapa.

const HEAD_RADIUS := 11.0
const FONT_SIZE := 19
const PLATE_PADDING := Vector2(12.0, 4.0)
const PLATE_GAP := 4.0
const DIAMOND_RADIUS := 9.0
const HIGHLIGHT_SECONDS := 0.16
## Ancho mínimo del área que responde al dedo.
const MIN_TOUCH_WIDTH := 48.0

const PLATE := Color("efe0bc")
const PLATE_LIT := Color("f6e2b6")
const PLATE_MUTED := Color("cbbd9f")

var place_id := ""
var title := "":
	set(value):
		title = value
		_update_size()
## Rótulo debajo ("below") o encima ("above") de la chincheta.
var label_side := "below":
	set(value):
		label_side = value
		_update_size()
## Hay un objetivo pendiente en este lugar.
var objective := false:
	set(value):
		objective = value
		set_process(objective)
		queue_redraw()
## Abierto según los datos del lugar; cerrado se ve atenuado.
var available := true:
	set(value):
		available = value
		queue_redraw()
## Elegido por el jugador: el rótulo queda marcado en burdeos.
var selected := false:
	set(value):
		selected = value
		queue_redraw()

var _highlight := 0.0
var _tween: Tween
var _bob := 0.0
var _plate_size := Vector2.ZERO
var _plate_style: StyleBoxFlat


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_plate_style = CaseFileStyle.box(PLATE, CaseFileStyle.INK, 2, 4)
	_plate_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	_plate_style.shadow_size = 4
	_plate_style.shadow_offset = Vector2(0.0, 2.0)
	focus_entered.connect(_refresh_highlight)
	focus_exited.connect(_refresh_highlight)
	mouse_entered.connect(_on_mouse_entered)
	set_process(objective)
	_update_size()


## Coloca el nodo para que la punta de la chincheta caiga en `tip` (píxeles del padre).
func place_at(tip: Vector2) -> void:
	position = (tip - get_tip_offset()).round()


## Punta de la chincheta, en coordenadas del propio nodo.
func get_tip_offset() -> Vector2:
	var pin_height := HEAD_RADIUS * MapSymbols.PIN_REACH
	if label_side == "above":
		return Vector2(size.x * 0.5, _plate_size.y + PLATE_GAP + pin_height)
	return Vector2(size.x * 0.5, pin_height)


func is_highlighted() -> bool:
	return _highlight > 0.5


func _on_mouse_entered() -> void:
	if focus_mode != Control.FOCUS_NONE and is_visible_in_tree():
		grab_focus()


func _refresh_highlight() -> void:
	var target := 1.0 if has_focus() else 0.0
	if _tween != null:
		_tween.kill()
	if not is_visible_in_tree():
		_set_highlight(target)
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_highlight, _highlight, target, HIGHLIGHT_SECONDS)


func _set_highlight(value: float) -> void:
	_highlight = value
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	# Con el movimiento reducido, el rombo del objetivo no sube ni baja.
	_bob = 0.0 if UiAccessibility.reduced_motion() else fmod(_bob + delta * 1.4, TAU)
	queue_redraw()


func _update_size() -> void:
	var font := CaseFileStyle.serif_bold()
	var text_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	_plate_size = Vector2(ceilf(text_size.x) + PLATE_PADDING.x * 2.0, ceilf(font.get_height(FONT_SIZE)) + PLATE_PADDING.y * 2.0)
	var pin_height := HEAD_RADIUS * MapSymbols.PIN_REACH
	custom_minimum_size = Vector2(maxf(_plate_size.x, MIN_TOUCH_WIDTH), pin_height + PLATE_GAP + _plate_size.y)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	var tip := get_tip_offset()
	var lift := 1.0 + 0.12 * _highlight
	if objective:
		var head_top := tip.y - HEAD_RADIUS * MapSymbols.PIN_REACH * lift
		var center := Vector2(tip.x, head_top - DIAMOND_RADIUS - 6.0 + sin(_bob) * 2.0)
		MapSymbols.draw_diamond(self, center, DIAMOND_RADIUS, 0.7 + 0.3 * sin(_bob * 2.0))
	MapSymbols.draw_pin(self, tip, HEAD_RADIUS * lift, _highlight, not available)
	_draw_plate(tip)


func _draw_plate(tip: Vector2) -> void:
	var top := tip.y + PLATE_GAP if label_side != "above" else 0.0
	var plate := Rect2(Vector2((size.x - _plate_size.x) * 0.5, top), _plate_size)
	var marked := maxf(_highlight, 1.0 if selected else 0.0)
	_plate_style.bg_color = (PLATE if available else PLATE_MUTED).lerp(PLATE_LIT, _highlight)
	_plate_style.border_color = CaseFileStyle.INK.lerp(CaseFileStyle.BURGUNDY, marked)
	_plate_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4).lerp(Color(0.62, 0.09, 0.1, 0.5), marked)
	_plate_style.shadow_size = roundi(lerpf(4.0, 9.0, marked))
	draw_style_box(_plate_style, plate)
	draw_rect(plate.grow(-4.0), Color(MapSymbols.GOLD_DARK, 0.45), false, 1.0, true)
	var font := CaseFileStyle.serif_bold()
	var baseline := plate.position.y + PLATE_PADDING.y + font.get_ascent(FONT_SIZE)
	var ink := CaseFileStyle.INK if available else CaseFileStyle.INK_SOFT
	draw_string(font, Vector2(plate.position.x, baseline), title, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, FONT_SIZE, ink.lerp(CaseFileStyle.BURGUNDY_DARK, marked * 0.6))
