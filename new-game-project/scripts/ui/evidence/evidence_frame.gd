class_name EvidenceFrame
extends Control
## Marco ornamental alrededor del documento: un filete dorado viejo, otro más fino por dentro,
## volutas en las cuatro esquinas y, en el lado inferior, un hueco para el botón de cerrar donde
## los filetes terminan en caracol. Ocupa toda la pantalla y sólo dibuja: no recibe el ratón.
##
## La interfaz le dice dónde está el marco (`frame_rect`) y qué hueco dejar (`bottom_gap`) cada vez
## que coloca las piezas, así el marco sigue al documento en cualquier pantalla.

const INNER_INSET := 6.0
const CORNER_REACH := 20.0
const GAP_MARGIN := 24.0

var frame_rect := Rect2():
	set(value):
		frame_rect = value
		queue_redraw()
var bottom_gap := Rect2():
	set(value):
		bottom_gap = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var rect := frame_rect
	if rect.size.x < CORNER_REACH * 6.0 or rect.size.y < CORNER_REACH * 4.0:
		return
	var outer := Color(EvidenceStyle.GOLD, 0.9)
	var inner := Color(EvidenceStyle.GOLD, 0.4)
	var left := rect.position.x
	var right := rect.end.x
	var top := rect.position.y
	var bottom := rect.end.y
	# Lados superior y laterales del filete exterior; el inferior se interrumpe en el botón.
	draw_line(Vector2(left + CORNER_REACH, top), Vector2(right - CORNER_REACH, top), outer, 1.8, true)
	draw_line(Vector2(left, top + CORNER_REACH), Vector2(left, bottom - CORNER_REACH), outer, 1.8, true)
	draw_line(Vector2(right, top + CORNER_REACH), Vector2(right, bottom - CORNER_REACH), outer, 1.8, true)
	var gap := bottom_gap
	if gap.size.x <= 0.0:
		gap = Rect2(rect.get_center().x, bottom, 0.0, 0.0)
	EvidenceOrnaments.draw_scroll_line(self, Vector2(left + CORNER_REACH, bottom), Vector2(gap.position.x - GAP_MARGIN, bottom), outer, true, 1.8)
	EvidenceOrnaments.draw_scroll_line(self, Vector2(right - CORNER_REACH, bottom), Vector2(gap.end.x + GAP_MARGIN, bottom), outer, true, 1.8)
	# Filete interior, más tenue; también se aparta del botón.
	var inside := rect.grow(-INNER_INSET)
	draw_polyline(PackedVector2Array([
		Vector2(gap.position.x - 10.0, inside.end.y), Vector2(inside.position.x, inside.end.y),
		inside.position, Vector2(inside.end.x, inside.position.y), inside.end,
		Vector2(gap.end.x + 10.0, inside.end.y),
	]), inner, 1.0, true)
	var corners := [
		[rect.position, Vector2(-1.0, -1.0)], [Vector2(right, top), Vector2(1.0, -1.0)],
		[rect.end, Vector2(1.0, 1.0)], [Vector2(left, bottom), Vector2(-1.0, 1.0)],
	]
	for corner: Array in corners:
		EvidenceOrnaments.draw_corner_scroll(self, corner[0], corner[1], outer, 1.6)
