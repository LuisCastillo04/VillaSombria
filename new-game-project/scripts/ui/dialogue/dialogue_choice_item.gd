class_name DialogueChoiceItem
extends Button
## Una respuesta: tarjeta de pergamino claro con borde marrón y esquinas en escuadra, con su número y
## su texto en tinta. La señalada se vuelve burdeos, con el borde dorado encendido, la letra crema y
## una flecha a la derecha; el cambio se anima para que no sea brusco. Las preguntas que el jugador
## aún no ha hecho llevan un rombo a la izquierda.
##
## Señalarla con el ratón le da el foco, así sólo hay una resaltada a la vez. Elegirla sólo ocurre
## al hacer clic o al confirmarla: pasar el ratón por encima nunca la elige.
##
## La tarjeta se dibuja en un hijo que va por detrás del botón, de modo que el texto (que pinta el
## propio botón, con su ajuste de líneas) queda siempre encima.

## Márgenes del texto: a la izquierda cabe el rombo de las preguntas nuevas; a la derecha, la flecha.
## La versión compacta, para listas largas, recorta el alto sin tocar el ancho.
const PADDING := Vector4(58.0, 15.0, 78.0, 15.0)
const PADDING_COMPACT := Vector4(58.0, 10.0, 78.0, 10.0)
const MIN_HEIGHT := 68.0
const MIN_HEIGHT_COMPACT := 56.0
const NOTCH := 7.0
const MARKER_X := 29.0
const ARROW_RIGHT := 34.0
const ARROW_SIZE := 13.0

const PAPER := Color(0.973, 0.929, 0.835, 0.66)
const PAPER_HOVER := Color(0.98, 0.945, 0.86, 0.85)
const BORDER := Color(0.42, 0.29, 0.17, 0.78)

## Identificador de la respuesta, tal como lo emitió `DialogueManager`.
var option_id := ""
## Si es una pregunta que el jugador aún no ha hecho.
var is_new := false

var _compact := false
var _padding := PADDING
var _highlight := 0.0
var _flash := 0.0
var _tween: Tween
var _flash_tween: Tween
var _card: Control


func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0.0, MIN_HEIGHT)
	_card = Control.new()
	_card.name = "Card"
	_card.show_behind_parent = true
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card, false, Node.INTERNAL_MODE_FRONT)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.draw.connect(_draw_card)
	add_theme_font_override("font", DialogueStyle.option_font())
	set_compact(false)
	_apply_highlight(0.0)


func _ready() -> void:
	focus_entered.connect(_refresh_highlight)
	focus_exited.connect(_refresh_highlight)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_card.queue_redraw)


## Prepara la tarjeta con su número (el de su tecla), su texto y si es una pregunta nueva.
func setup(id: String, number: int, label: String, new_question: bool) -> void:
	option_id = id
	is_new = new_question
	text = "%d. %s" % [number, label]
	_card.queue_redraw()


## Versión compacta, para listas largas: menos alto y letra algo menor.
func set_compact(compact: bool) -> void:
	_compact = compact
	_padding = PADDING_COMPACT if compact else PADDING
	var box := StyleBoxEmpty.new()
	box.content_margin_left = _padding.x
	box.content_margin_top = _padding.y
	box.content_margin_right = _padding.z
	box.content_margin_bottom = _padding.w
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, box)
	add_theme_font_size_override("font_size", _font_size())
	_card.queue_redraw()


func is_compact() -> bool:
	return _compact


## Alto que necesita la tarjeta con este ancho, con el texto partido en las líneas que haga falta.
func get_height_for_width(width: float) -> float:
	var font := DialogueStyle.option_font()
	var text_width := maxf(width - _padding.x - _padding.z, 1.0)
	var flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var text_size := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, text_width, _font_size(), -1, flags)
	var minimum := MIN_HEIGHT_COMPACT if _compact else MIN_HEIGHT
	return maxf(minimum, ceilf(text_size.y) + _padding.y + _padding.w)


func _font_size() -> int:
	return DialogueStyle.OPTION_SIZE_COMPACT if _compact else DialogueStyle.OPTION_SIZE


func is_highlighted() -> bool:
	return _highlight > 0.5


## Destello breve al confirmarla.
func flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(value: float) -> void:
		_flash = value
		_card.queue_redraw()
	, 1.0, 0.0, DialogueStyle.CONFIRM_SECONDS)


func _on_mouse_entered() -> void:
	if focus_mode != Control.FOCUS_NONE and is_visible_in_tree() and not has_focus():
		grab_focus()
	_card.queue_redraw()


func _refresh_highlight() -> void:
	var target := 1.0 if has_focus() else 0.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if not is_visible_in_tree():
		_apply_highlight(target)
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply_highlight, _highlight, target, DialogueStyle.SELECT_SECONDS)


func _apply_highlight(value: float) -> void:
	_highlight = value
	var ink := DialogueStyle.INK.lerp(DialogueStyle.CREAM, value)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(key, ink)
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	_card.queue_redraw()


func _draw_card() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < NOTCH * 4.0:
		return
	var shape := DialogueOrnaments.notched_rect(rect, NOTCH)
	var light := clampf(_highlight + _flash * 0.6, 0.0, 1.6)
	# Brillo dorado alrededor de la señalada.
	if _highlight > 0.0:
		for ring in 3:
			var halo := DialogueOrnaments.notched_rect(rect.grow(2.0 + ring * 2.5), NOTCH + 1.0)
			_card.draw_polyline(HudOrnaments.closed(halo), Color(DialogueStyle.GOLD_LIGHT, 0.16 * _highlight / (ring + 1)), 2.0, true)
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(0.0, 3.0))
	_card.draw_colored_polygon(shadow, Color(0.2, 0.12, 0.06, 0.16 + 0.2 * _highlight))
	var hovered := is_hovered() and _highlight < 0.5
	_card.draw_colored_polygon(shape, PAPER_HOVER if hovered else PAPER)
	if _highlight > 0.0:
		var top := DialogueStyle.BURGUNDY_LIGHT.lerp(Color("b03442"), clampf(_flash, 0.0, 1.0) * 0.5)
		DialogueOrnaments.draw_gradient_polygon(_card, shape, Color(top, _highlight), Color(DialogueStyle.BURGUNDY_DARK, _highlight))
	var border := BORDER.lerp(DialogueStyle.GOLD_LIGHT, minf(light, 1.0))
	_card.draw_polyline(HudOrnaments.closed(shape), border, lerpf(1.6, 2.2, _highlight), true)
	var inner := DialogueOrnaments.notched_rect(rect.grow(-4.0), NOTCH - 1.0)
	_card.draw_polyline(HudOrnaments.closed(inner), Color(DialogueStyle.GOLD_LIGHT, 0.3 * _highlight), 1.0, true)
	var middle := rect.size.y * 0.5
	if is_new:
		var marker := DialogueStyle.BURGUNDY.lerp(DialogueStyle.GOLD_LIGHT, _highlight)
		HudOrnaments.draw_diamond(_card, Vector2(MARKER_X, middle), 5.5, marker)
	if _highlight > 0.01:
		_draw_arrow(Vector2(rect.size.x - ARROW_RIGHT, middle), Color(DialogueStyle.CREAM, _highlight))


## Flecha de la respuesta señalada: una punta rellena con una muesca, como un indicador de imprenta.
func _draw_arrow(tip: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		tip, tip + Vector2(-ARROW_SIZE * 1.3, -ARROW_SIZE), tip + Vector2(-ARROW_SIZE * 0.8, 0.0),
		tip + Vector2(-ARROW_SIZE * 1.3, ARROW_SIZE),
	])
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(0.0, 2.0))
	_card.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.35 * color.a))
	_card.draw_colored_polygon(points, color)
