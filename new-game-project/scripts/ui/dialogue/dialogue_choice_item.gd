class_name DialogueChoiceItem
extends Button
## Una respuesta: tarjeta de pergamino claro con borde marrón y esquinas en escuadra, con su número y
## su texto en tinta. La señalada se vuelve burdeos, con el borde dorado encendido, la letra crema y
## una flecha a la derecha; el cambio se anima para que no sea brusco.
##
## En un interrogatorio cada tarjeta enseña además el estado de su pregunta:
##
## | Estado | Cómo se ve |
## | --- | --- |
## | Pendiente | Papel y tinta plenos, con un rombo a la izquierda |
## | Recién desbloqueada | Además, la cinta «Nuevo» a la derecha |
## | Realizada | Papel más transparente, tinta sepia y una marca de verificación |
## | Repetible | Una flecha circular a la derecha, que deja paso a la de la señalada |
## | Bloqueada | Atenuada, con un candado; no se puede señalar ni elegir |
##
## Señalarla con el ratón le da el foco, así sólo hay una resaltada a la vez. Elegirla sólo ocurre
## al hacer clic o al confirmarla: pasar el ratón por encima nunca la elige.
##
## La tarjeta se dibuja en un hijo que va por detrás del botón, de modo que el texto (que pinta el
## propio botón, con su ajuste de líneas) queda siempre encima.

## Estados que dibuja: los de `ConversationLog` y, para la salida o las réplicas de una escena que ya
## no son nuevas, `NEUTRAL`.
const PENDING := ConversationLog.PENDING
const DONE := ConversationLog.DONE
const LOCKED := ConversationLog.LOCKED
const NEUTRAL := "neutral"

## Márgenes del texto: a la izquierda cabe el icono de estado; a la derecha, la flecha.
## La versión compacta, para listas largas, recorta el alto sin tocar el ancho.
const PADDING := Vector4(58.0, 15.0, 78.0, 15.0)
const PADDING_COMPACT := Vector4(58.0, 10.0, 78.0, 10.0)
const MIN_HEIGHT := 68.0
const MIN_HEIGHT_COMPACT := 56.0
const NOTCH := 7.0
const MARKER_X := 29.0
const ARROW_RIGHT := 34.0
const ARROW_SIZE := 13.0
## Cinta «Nuevo»: ancho, alto y hueco hasta la flecha. El texto deja sitio para ella.
const TAG_TEXT := "Nuevo"
const TAG_WIDTH := 92.0
const TAG_HEIGHT := 28.0
const TAG_GAP := 14.0

const PAPER := Color(0.973, 0.929, 0.835, 0.66)
const PAPER_HOVER := Color(0.98, 0.945, 0.86, 0.85)
## Papel de las preguntas ya hechas y de las bloqueadas: se transparenta más el pergamino de fondo.
const PAPER_DONE := Color(0.973, 0.929, 0.835, 0.34)
const PAPER_LOCKED := Color(0.973, 0.929, 0.835, 0.2)
const BORDER := Color(0.42, 0.29, 0.17, 0.78)
const BORDER_DONE := Color(0.42, 0.29, 0.17, 0.42)

## Identificador de la respuesta, tal como lo emitió `DialogueManager`.
var option_id := ""
## Si es una pregunta que el jugador aún no ha hecho.
var is_new := false
## Estado de la pregunta (`PENDING`, `DONE`, `LOCKED` o `NEUTRAL`).
var state := NEUTRAL
## Recién desbloqueada: lleva la cinta «Nuevo».
var is_fresh := false
## Ya hecha y se puede repetir.
var is_repeatable := false
## Número de su tecla, o 0 si no se puede elegir con un número (oculta o bloqueada).
var number := 0

var _label := ""
var _compact := false
var _padding := PADDING
var _highlight := 0.0
var _flash := 0.0
## Subida de la entrada: la tarjeta y su texto se dibujan desplazados hacia abajo y llegan a su sitio.
var _rise := 0.0
var _tween: Tween
var _flash_tween: Tween
var _enter_tween: Tween
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
	mouse_entered.connect(_card.queue_redraw)
	mouse_exited.connect(_card.queue_redraw)


## Al mover el ratón por encima, la tarjeta toma el foco. Sólo con movimiento real: si las respuestas
## aparecen bajo un cursor quieto, el foco sigue donde lo dejó el teclado.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and focus_mode != Control.FOCUS_NONE and not has_focus():
		grab_focus()


## Prepara la tarjeta con su número (el de su tecla), su texto y si es una pregunta nueva.
func setup(id: String, option_number: int, label: String, new_question: bool) -> void:
	option_id = id
	_label = label
	set_state(PENDING if new_question else NEUTRAL)
	set_number(option_number)


## Estado de la pregunta. Una bloqueada no recibe el foco ni se puede pulsar, pero se sigue leyendo.
func set_state(value: String, fresh: bool = false, repeatable: bool = false) -> void:
	state = value
	is_new = value == PENDING
	is_fresh = fresh and value == PENDING
	is_repeatable = repeatable and value == DONE
	var locked := value == LOCKED
	disabled = locked
	focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	match value:
		LOCKED:
			tooltip_text = "Ya respondida. Su declaración está en el expediente."
		DONE:
			tooltip_text = "Ya la has hecho. Puedes repetirla." if is_repeatable else ""
		_:
			tooltip_text = ""
	set_compact(_compact)
	_apply_highlight(_highlight)


## Número de su tecla; con 0, la tarjeta no lo muestra.
func set_number(value: int) -> void:
	number = value
	text = "%d. %s" % [value, _label] if value > 0 else _label
	_card.queue_redraw()


func get_label() -> String:
	return _label


func is_locked() -> bool:
	return state == LOCKED


## Versión compacta, para listas largas: menos alto y letra algo menor.
func set_compact(compact: bool) -> void:
	_compact = compact
	_padding = PADDING_COMPACT if compact else PADDING
	if is_fresh:
		_padding.z += TAG_WIDTH + TAG_GAP
	var box := StyleBoxEmpty.new()
	box.content_margin_left = _padding.x
	box.content_margin_top = _padding.y + _rise
	box.content_margin_right = _padding.z
	box.content_margin_bottom = _padding.w - _rise
	for style_name: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, box)
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


## Aparece con un fundido y una subida corta, tras `delay` segundos. El contenedor coloca la
## tarjeta; la subida sólo desplaza su dibujo, así que no altera la lista ni lo que señala el ratón.
func play_entrance(delay: float) -> void:
	if _enter_tween != null:
		_enter_tween.kill()
	modulate.a = 0.0
	var rise := DialogueStyle.CHOICE_ENTER_RISE * UiAccessibility.motion()
	_set_rise(rise)
	_enter_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_enter_tween.tween_property(self, "modulate:a", 1.0, DialogueStyle.CHOICE_ENTER_SECONDS).set_delay(delay)
	_enter_tween.tween_method(_set_rise, rise, 0.0, DialogueStyle.CHOICE_ENTER_SECONDS).set_delay(delay)


func _set_rise(value: float) -> void:
	_rise = value
	_card.position.y = value
	# El texto del botón baja lo mismo que la tarjeta, con sus márgenes.
	var box := get_theme_stylebox("normal") as StyleBoxEmpty
	if box != null:
		box.content_margin_top = _padding.y + value
		box.content_margin_bottom = _padding.w - value


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


## Tinta de la tarjeta: plena en las pendientes y en la salida, sepia en las hechas y las bloqueadas,
## crema en la señalada.
func _apply_highlight(value: float) -> void:
	_highlight = value
	var base := DialogueStyle.INK_MUTED if state == DONE or state == LOCKED else DialogueStyle.INK
	var ink := base.lerp(DialogueStyle.CREAM, value)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		add_theme_color_override(key, ink)
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.0))
	_card.queue_redraw()


func _draw_card() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < NOTCH * 4.0:
		return
	var shape := DialogueOrnaments.notched_rect(rect, NOTCH)
	var light := clampf(_highlight + _flash * 0.6, 0.0, 1.6)
	var quiet := state == DONE or state == LOCKED
	# Brillo dorado alrededor de la señalada.
	if _highlight > 0.0:
		for ring in 3:
			var halo := DialogueOrnaments.notched_rect(rect.grow(2.0 + ring * 2.5), NOTCH + 1.0)
			_card.draw_polyline(HudOrnaments.closed(halo), Color(DialogueStyle.GOLD_LIGHT, 0.16 * _highlight / (ring + 1)), 2.0, true)
	if not quiet or _highlight > 0.0:
		var shadow := PackedVector2Array()
		for point in shape:
			shadow.append(point + Vector2(0.0, 3.0))
		_card.draw_colored_polygon(shadow, Color(0.2, 0.12, 0.06, 0.16 + 0.2 * _highlight))
	var hovered := is_hovered() and _highlight < 0.5 and state != LOCKED
	_card.draw_colored_polygon(shape, _paper(hovered))
	if _highlight > 0.0:
		var top := DialogueStyle.BURGUNDY_LIGHT.lerp(Color("b03442"), clampf(_flash, 0.0, 1.0) * 0.5)
		DialogueOrnaments.draw_gradient_polygon(_card, shape, Color(top, _highlight), Color(DialogueStyle.BURGUNDY_DARK, _highlight))
	var border := (BORDER_DONE if quiet else BORDER).lerp(DialogueStyle.GOLD_LIGHT, minf(light, 1.0))
	_card.draw_polyline(HudOrnaments.closed(shape), border, lerpf(1.6, 2.2, _highlight), true)
	var inner := DialogueOrnaments.notched_rect(rect.grow(-4.0), NOTCH - 1.0)
	_card.draw_polyline(HudOrnaments.closed(inner), Color(DialogueStyle.GOLD_LIGHT, 0.3 * _highlight), 1.0, true)
	var middle := rect.size.y * 0.5
	_draw_state_marker(Vector2(MARKER_X, middle))
	var arrow_tip := Vector2(rect.size.x - ARROW_RIGHT, middle)
	if is_repeatable and _highlight < 0.99:
		DialogueOrnaments.draw_repeat(_card, arrow_tip + Vector2(-8.0, 0.0), 10.0, Color(DialogueStyle.INK_MUTED, 0.85 * (1.0 - _highlight)))
	if is_fresh:
		_draw_tag(Rect2(Vector2(rect.size.x - ARROW_RIGHT - ARROW_SIZE * 1.3 - TAG_GAP - TAG_WIDTH, middle - TAG_HEIGHT * 0.5), Vector2(TAG_WIDTH, TAG_HEIGHT)))
	if _highlight > 0.01:
		_draw_arrow(arrow_tip, Color(DialogueStyle.CREAM, _highlight))


func _paper(hovered: bool) -> Color:
	match state:
		DONE:
			return PAPER_HOVER if hovered else PAPER_DONE
		LOCKED:
			return PAPER_LOCKED
	return PAPER_HOVER if hovered else PAPER


## Icono a la izquierda del texto: rombo (pendiente), verificación (hecha) o candado (bloqueada).
func _draw_state_marker(center: Vector2) -> void:
	match state:
		PENDING:
			HudOrnaments.draw_diamond(_card, center, 5.5, DialogueStyle.BURGUNDY.lerp(DialogueStyle.GOLD_LIGHT, _highlight))
		DONE:
			DialogueOrnaments.draw_check(_card, center, 8.0, DialogueStyle.CHECK.lerp(DialogueStyle.GOLD_LIGHT, _highlight))
		LOCKED:
			DialogueOrnaments.draw_padlock(_card, center + Vector2(0.0, 1.0), 7.5, Color(DialogueStyle.INK_MUTED, 0.9))


## Cinta «Nuevo»: discreta, en burdeos sobre el papel; dorada cuando la tarjeta está señalada.
func _draw_tag(rect: Rect2) -> void:
	var shape := DialogueOrnaments.notched_rect(rect, 4.0)
	var line := DialogueStyle.BURGUNDY.lerp(DialogueStyle.GOLD_LIGHT, _highlight)
	_card.draw_colored_polygon(shape, Color(DialogueStyle.BURGUNDY, 0.08 * (1.0 - _highlight)))
	_card.draw_polyline(HudOrnaments.closed(shape), Color(line, 0.85), 1.4, true)
	var font := DialogueStyle.section_font()
	var font_size := DialogueStyle.TAG_SIZE
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline := rect.position.y + (rect.size.y + ascent - descent) * 0.5
	_card.draw_string(font, Vector2(rect.position.x, baseline), TAG_TEXT.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, line)


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
