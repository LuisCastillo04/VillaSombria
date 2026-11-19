class_name CaseStamp
extends Control
## Sello de tinta «EXPEDIENTE DEL CASO» con una lupa, como el que se estampa en las carpetas
## de la policía. El texto se dibuja letra a letra siguiendo el círculo.

@export var top_text := "EXPEDIENTE"
@export var bottom_text := "DEL CASO"
@export var ink := Color(0.48, 0.11, 0.13, 0.82)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	draw_arc(center, radius, 0.0, TAU, 72, ink, 3.0, true)
	draw_arc(center, radius - 7.0, 0.0, TAU, 72, ink, 1.5, true)
	draw_arc(center, radius * 0.5, 0.0, TAU, 48, ink, 1.5, true)
	var font := CaseFileStyle.serif_bold()
	var font_size := int(radius * 0.21)
	_arched_text(top_text, center, radius - 13.0 - font_size * 0.75, font, font_size, true)
	_arched_text(bottom_text, center, radius - 13.0 - font_size * 0.1, font, font_size, false)
	for side: float in [-1.0, 1.0]:
		var dot := center + Vector2(side * (radius - 13.0 - font_size * 0.4), 0.0)
		draw_circle(dot, 2.5, ink)
	var lens := center + Vector2(-radius * 0.07, -radius * 0.07)
	var lens_radius := radius * 0.2
	draw_arc(lens, lens_radius, 0.0, TAU, 32, ink, 3.0, true)
	var handle_start := lens + Vector2(lens_radius, lens_radius) * 0.72
	draw_line(handle_start, handle_start + Vector2(radius * 0.17, radius * 0.17), ink, 5.0, true)


## Coloca cada letra sobre el arco superior (leyendo de izquierda a derecha por arriba) o
## sobre el inferior (de izquierda a derecha por abajo).
func _arched_text(text: String, center: Vector2, radius: float, font: Font, font_size: int, top: bool) -> void:
	var widths: Array[float] = []
	var total := 0.0
	for character in text:
		var width := font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + font_size * 0.08
		widths.append(width)
		total += width
	var span := total / radius
	var angle := -PI * 0.5 - span * 0.5 if top else PI * 0.5 + span * 0.5
	for index in text.length():
		var step := widths[index] / radius
		var middle := angle + step * 0.5 if top else angle - step * 0.5
		var glyph_position := center + Vector2(cos(middle), sin(middle)) * radius
		var glyph_rotation := middle + PI * 0.5 if top else middle - PI * 0.5
		draw_set_transform(glyph_position, glyph_rotation, Vector2.ONE)
		draw_string(font, Vector2(-widths[index] * 0.5, font_size * 0.35), text[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
		angle = angle + step if top else angle - step
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
