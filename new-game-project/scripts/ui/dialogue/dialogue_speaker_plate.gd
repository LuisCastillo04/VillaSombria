class_name DialogueSpeakerPlate
extends Control
## Placa burdeos con el nombre de quien habla, montada sobre el borde superior izquierdo de la
## ventana: extremos en punta, filete dorado doble, un rombo a cada lado y el nombre en crema.
##
## El nombre llega de fuera (la interfaz lo lee de `GameData`), así que sirve para cualquier
## personaje. Al cambiar, el nombre anterior se apaga, la placa ajusta su ancho y el nuevo se
## enciende; sin nombre (la narración), la placa entera se desvanece.

const POINT := 16.0
const PADDING := 58.0
const DIAMOND_GAP := 20.0

## Nombre que se está dibujando y nombre pedido, que puede llegar a mitad de un cambio.
var _text := ""
var _target := ""
## Visibilidad del nombre (0 a 1), animada en cada cambio.
var _text_alpha := 1.0
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0


## Muestra un nombre. Vacío, oculta la placa. Con `animate`, el cambio se funde.
func set_text(value: String, animate: bool = true) -> void:
	if value == _target and (animate or _tween == null):
		return
	_target = value
	if _tween != null:
		_tween.kill()
		_tween = null
	if not animate or not is_visible_in_tree():
		_text = value
		_text_alpha = 1.0
		modulate.a = 0.0 if value.is_empty() else 1.0
		_fit()
		return
	_tween = create_tween()
	if value.is_empty():
		_tween.tween_property(self, "modulate:a", 0.0, DialogueStyle.NAME_OUT_SECONDS * 1.5)
		_tween.tween_callback(func() -> void: _text = "")
		return
	if modulate.a < 0.01:
		# La placa estaba oculta: aparece ya con el nombre nuevo.
		_text = value
		_text_alpha = 1.0
		_fit()
		_tween.tween_property(self, "modulate:a", 1.0, DialogueStyle.NAME_IN_SECONDS)
		return
	_tween.tween_method(_set_text_alpha, _text_alpha, 0.0, DialogueStyle.NAME_OUT_SECONDS)
	_tween.tween_callback(func() -> void:
		_text = value
		_fit()
	)
	_tween.parallel().tween_property(self, "modulate:a", 1.0, DialogueStyle.NAME_OUT_SECONDS)
	_tween.tween_method(_set_text_alpha, 0.0, 1.0, DialogueStyle.NAME_IN_SECONDS)


## Nombre que muestra o va a mostrar la placa.
func get_text() -> String:
	return _target


## Si la placa se ve (o está apareciendo) con un nombre.
func is_showing() -> bool:
	return not _text.is_empty() and modulate.a > 0.0


func _set_text_alpha(value: float) -> void:
	_text_alpha = value
	queue_redraw()


## Ajusta el ancho al nombre, sin bajar del mínimo, para que los nombres cortos no encojan la placa.
func _fit() -> void:
	var width := DialogueStyle.PLATE_MIN_WIDTH
	if not _text.is_empty():
		var text_width := DialogueStyle.name_font().get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, DialogueStyle.NAME_SIZE).x
		width = maxf(width, text_width + PADDING * 2.0)
	custom_minimum_size = Vector2(width, DialogueStyle.PLATE_HEIGHT)
	size = custom_minimum_size
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x < POINT * 3.0:
		return
	var shape := DialogueOrnaments.plate(rect, POINT)
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(0.0, 4.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.42))
	DialogueOrnaments.draw_gradient_polygon(self, shape, DialogueStyle.BURGUNDY_LIGHT, DialogueStyle.BURGUNDY_DARK)
	draw_polyline(HudOrnaments.closed(shape), DialogueStyle.GOLD, 2.0, true)
	var inner := DialogueOrnaments.plate(rect.grow(-4.5), POINT - 2.0)
	draw_polyline(HudOrnaments.closed(inner), Color(DialogueStyle.GOLD_LIGHT, 0.4), 1.0, true)
	if _text.is_empty():
		return
	var font := DialogueStyle.name_font()
	var font_size := DialogueStyle.NAME_SIZE
	var text_width := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var center := rect.get_center()
	var baseline := center.y - font.get_height(font_size) * 0.5 + font.get_ascent(font_size)
	var origin := Vector2(center.x - text_width * 0.5, baseline)
	draw_string(font, origin + Vector2(0.0, 2.0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.45 * _text_alpha))
	draw_string(font, origin, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(DialogueStyle.CREAM, _text_alpha))
	for side: float in [-1.0, 1.0]:
		var spot := Vector2(center.x + side * (text_width * 0.5 + DIAMOND_GAP), center.y)
		HudOrnaments.draw_diamond(self, spot, 4.0, Color(DialogueStyle.GOLD_LIGHT, _text_alpha))
