class_name DialogueContinueButton
extends Control
## Aviso para continuar, encajado en la esquina inferior derecha de la ventana: una pestaña burdeos
## con filete dorado, la tecla real de avanzar en un recuadro oscuro y «Continuar».
##
## La tecla sale del InputMap (`DialogueControls.advance_key`), así que sigue a una reasignación.
## Señalarla con el ratón la aviva; el clic hace avanzar como en cualquier punto de la conversación
## (lo recoge `DialogueUi`). Mientras el texto aún se escribe la pestaña está en reposo, y cuando ya
## se lee entero late despacio para indicar que se puede seguir.

const SLANT := 24.0
const PADDING_LEFT := 30.0
const PADDING_RIGHT := 30.0
const KEY_GAP := 14.0
const KEY_HEIGHT := 36.0

var _key := ""
var _label := "Continuar"
var _hover := 0.0
var _waiting := false
var _pulse := 0.0
## Avance automático: parte transcurrida de la espera (0 a 1), o -1 si no hay cuenta.
var _auto_progress := -1.0
var _clock := 0.0
var _hover_tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = ""
	set_process(false)


func _ready() -> void:
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	refresh()


## Vuelve a leer la tecla de avanzar del InputMap y ajusta el ancho de la pestaña, que crece hacia
## la izquierda desde la esquina en la que está anclada.
func refresh() -> void:
	_key = DialogueControls.advance_key()
	var width := _content_width() + SLANT + PADDING_LEFT + PADDING_RIGHT
	offset_left = offset_right - width
	offset_top = offset_bottom - DialogueStyle.CONTINUE_HEIGHT
	queue_redraw()


func get_key_text() -> String:
	return _key


## Con el texto entero a la vista, la pestaña late despacio; mientras se escribe, reposa.
func set_waiting(waiting: bool) -> void:
	if waiting == _waiting:
		return
	_waiting = waiting
	_clock = 0.0
	set_process(waiting)
	if not waiting:
		_pulse = 0.0
	queue_redraw()


func is_waiting() -> bool:
	return _waiting


## Con el avance automático, un filete bajo el rótulo se llena mientras se espera para pasar sola;
## con -1 desaparece.
func set_auto_progress(progress: float) -> void:
	var value := clampf(progress, 0.0, 1.0) if progress >= 0.0 else -1.0
	if is_equal_approx(value, _auto_progress):
		return
	_auto_progress = value
	queue_redraw()


func get_auto_progress() -> float:
	return _auto_progress


func _process(delta: float) -> void:
	_clock += delta
	# Con el movimiento reducido no late: queda encendida a media luz mientras espera.
	if UiAccessibility.reduced_motion():
		_pulse = 0.5
	else:
		_pulse = 0.5 - 0.5 * cos(_clock * TAU / DialogueStyle.PULSE_SECONDS)
	queue_redraw()


func _set_hover(hovered: bool) -> void:
	if _hover_tween != null:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_method(func(value: float) -> void:
		_hover = value
		queue_redraw()
	, _hover, 1.0 if hovered else 0.0, 0.14)


func _key_width() -> float:
	if _key.is_empty():
		return 0.0
	var font := CaseFileStyle.serif_bold()
	var width := font.get_string_size(_key, HORIZONTAL_ALIGNMENT_LEFT, -1, DialogueStyle.KEY_SIZE).x
	return maxf(width + 18.0, KEY_HEIGHT)


func _content_width() -> float:
	var label_width := DialogueStyle.name_font().get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, DialogueStyle.CONTINUE_SIZE).x
	var key_width := _key_width()
	return label_width + (key_width + KEY_GAP if key_width > 0.0 else 0.0)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var light := maxf(_hover, _pulse * 0.55)
	var shape := DialogueOrnaments.tab(rect, SLANT)
	if light > 0.0:
		for ring in 3:
			var halo := DialogueOrnaments.tab(rect.grow(2.0 + ring * 3.0), SLANT)
			draw_colored_polygon(halo, Color(DialogueStyle.GOLD_LIGHT, 0.08 * light / (ring + 1)))
	var top := DialogueStyle.BURGUNDY_LIGHT.lerp(Color("a8303b"), light * 0.6)
	DialogueOrnaments.draw_gradient_polygon(self, shape, top, DialogueStyle.BURGUNDY_DARK)
	var edge := DialogueStyle.GOLD.lerp(DialogueStyle.GOLD_LIGHT, light)
	# El filete recorre el borde superior y la diagonal; abajo y a la derecha toca el marco.
	draw_polyline(PackedVector2Array([shape[3], shape[0], shape[1]]), edge, 2.0, true)
	var inner := DialogueOrnaments.tab(rect.grow(-5.0), SLANT - 2.0)
	draw_polyline(PackedVector2Array([inner[3], inner[0], inner[1]]), Color(DialogueStyle.GOLD_LIGHT, 0.35), 1.0, true)
	var x := SLANT + PADDING_LEFT
	var middle := rect.size.y * 0.5
	var key_width := _key_width()
	if key_width > 0.0:
		var key_rect := Rect2(x, middle - KEY_HEIGHT * 0.5, key_width, KEY_HEIGHT)
		draw_style_box(MenuStyle.keycap_box(), key_rect)
		var key_font := CaseFileStyle.serif_bold()
		var key_text_width := key_font.get_string_size(_key, HORIZONTAL_ALIGNMENT_LEFT, -1, DialogueStyle.KEY_SIZE).x
		var key_baseline := middle - key_font.get_height(DialogueStyle.KEY_SIZE) * 0.5 + key_font.get_ascent(DialogueStyle.KEY_SIZE) - 1.0
		draw_string(key_font, Vector2(key_rect.get_center().x - key_text_width * 0.5, key_baseline), _key, HORIZONTAL_ALIGNMENT_LEFT, -1, DialogueStyle.KEY_SIZE, DialogueStyle.CREAM)
		x += key_width + KEY_GAP
	var font := DialogueStyle.name_font()
	var baseline := middle - font.get_height(DialogueStyle.CONTINUE_SIZE) * 0.5 + font.get_ascent(DialogueStyle.CONTINUE_SIZE)
	draw_string(font, Vector2(x, baseline + 1.5), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, DialogueStyle.CONTINUE_SIZE, Color(0.0, 0.0, 0.0, 0.4))
	draw_string(font, Vector2(x, baseline), _label, HORIZONTAL_ALIGNMENT_LEFT, -1, DialogueStyle.CONTINUE_SIZE, DialogueStyle.CREAM)
	if _auto_progress >= 0.0:
		var start := SLANT + PADDING_LEFT
		var finish := rect.size.x - PADDING_RIGHT
		var y := rect.size.y - 8.0
		draw_line(Vector2(start, y), Vector2(finish, y), Color(0.0, 0.0, 0.0, 0.45), 4.0, true)
		draw_line(Vector2(start, y), Vector2(lerpf(start, finish, _auto_progress), y), DialogueStyle.GOLD_LIGHT, 4.0, true)
