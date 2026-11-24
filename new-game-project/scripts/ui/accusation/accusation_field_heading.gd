class_name AccusationFieldHeading
extends Control
## Encabezado de un campo de la acusación: un medallón con su icono (o un signo, como «?») y una
## cinta burdeos con el rótulo («Motivo:» en negrita y la pregunta que responde). El medallón es
## oscuro mientras el campo está pendiente y burdeos con el filete dorado cuando ya tiene una
## elección; mientras se edita, el medallón y la cinta se iluminan.

const POINT := 16.0
const TEXT_GAP := 16.0

var label_text := "":
	set(value):
		label_text = value
		_refit()
var prompt_text := "":
	set(value):
		prompt_text = value
		_refit()
var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
var glyph := "":
	set(value):
		glyph = value
		queue_redraw()
var completed := false:
	set(value):
		completed = value
		queue_redraw()
var editing := false:
	set(value):
		editing = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0.0, AccusationStyle.MEDALLION + 4.0)


func get_ribbon_width() -> float:
	var font_size := AccusationStyle.RIBBON_SIZE
	var width := AccusationStyle.heading_font().get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if not prompt_text.is_empty():
		width += AccusationStyle.ribbon_font().get_string_size(" " + prompt_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return AccusationStyle.MEDALLION * 0.5 + TEXT_GAP + 14.0 + width + 22.0 + POINT


func _refit() -> void:
	custom_minimum_size.x = minf(get_ribbon_width() + AccusationStyle.MEDALLION * 0.5, 720.0)
	queue_redraw()


func _draw() -> void:
	var radius := AccusationStyle.MEDALLION * 0.5
	var center := Vector2(radius + 2.0, size.y * 0.5)
	var ribbon_height := AccusationStyle.RIBBON_HEIGHT
	var ribbon_left := center.x
	var ribbon_right := minf(center.x + get_ribbon_width() - radius, size.x)
	var top := center.y - ribbon_height * 0.5
	var bottom := center.y + ribbon_height * 0.5
	# Cinta en forma de banderín: recta por la izquierda (la tapa el medallón) y en punta a la derecha.
	var shape := PackedVector2Array([
		Vector2(ribbon_left, top), Vector2(ribbon_right - POINT, top), Vector2(ribbon_right, center.y),
		Vector2(ribbon_right - POINT, bottom), Vector2(ribbon_left, bottom),
	])
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(0.0, 3.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.25))
	var fill := AccusationStyle.BURGUNDY_LIGHT if editing else AccusationStyle.BURGUNDY
	DialogueOrnaments.draw_gradient_polygon(self, shape, fill.lightened(0.06), fill.darkened(0.18))
	draw_polyline(HudOrnaments.closed(shape), Color(AccusationStyle.GOLD, 0.9 if editing else 0.65), 1.4, true)
	# Rótulo: «Motivo:» en negrita y la pregunta en redonda.
	var font_size := AccusationStyle.RIBBON_SIZE
	var bold := AccusationStyle.heading_font()
	var regular := AccusationStyle.ribbon_font()
	var baseline := center.y - bold.get_height(font_size) * 0.5 + bold.get_ascent(font_size)
	var cursor := center.x + radius + TEXT_GAP
	var limit := ribbon_right - POINT - 8.0
	draw_string(bold, Vector2(cursor, baseline), label_text, HORIZONTAL_ALIGNMENT_LEFT, maxf(limit - cursor, 1.0), font_size, AccusationStyle.CREAM)
	cursor += bold.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if not prompt_text.is_empty() and cursor < limit:
		draw_string(regular, Vector2(cursor, baseline), " " + prompt_text, HORIZONTAL_ALIGNMENT_LEFT, maxf(limit - cursor, 1.0), font_size, AccusationStyle.CREAM)
	_draw_medallion(center, radius)


func _draw_medallion(center: Vector2, radius: float) -> void:
	var lit := completed or editing
	var fill := AccusationStyle.BURGUNDY_DARK if lit else AccusationStyle.CHARCOAL_LIGHT
	var ring := AccusationStyle.GOLD_LIGHT if editing else (AccusationStyle.GOLD if completed else AccusationStyle.GOLD_DARK)
	if editing:
		draw_circle(center, radius + 7.0, Color(AccusationStyle.GOLD_LIGHT, 0.25), true, -1.0, true)
	draw_circle(center + Vector2(0.0, 3.0), radius + 2.0, Color(0.0, 0.0, 0.0, 0.35), true, -1.0, true)
	draw_circle(center, radius + 2.0, AccusationStyle.FRAME_DARK, true, -1.0, true)
	draw_circle(center, radius, fill, true, -1.0, true)
	draw_arc(center, radius, 0.0, TAU, 48, ring, 2.2, true)
	draw_arc(center, radius - 4.5, 0.0, TAU, 48, Color(ring, 0.45), 1.0, true)
	var ink := AccusationStyle.CREAM if lit else AccusationStyle.CREAM_SOFT
	if not glyph.is_empty():
		var font := AccusationStyle.heading_font()
		var glyph_size := int(radius * 1.25)
		var glyph_width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
		var baseline := center.y - font.get_height(glyph_size) * 0.5 + font.get_ascent(glyph_size)
		draw_string(font, Vector2(center.x - glyph_width * 0.5, baseline), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, ink)
	elif icon != null:
		var icon_size := radius * 1.15
		draw_texture_rect(icon, Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size)), false, ink)
