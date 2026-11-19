class_name CaseFileFrame
extends Control
## Marco del expediente: banda de madera con filetes dorados, un filete fino interior y
## volutas en las cuatro esquinas. Se dibuja por encima del pergamino y no recibe clics.

@export var band_width := 14.0
@export var corner_radius := 22.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var band := StyleBoxFlat.new()
	band.draw_center = false
	band.border_color = Color("3a2618")
	band.set_border_width_all(int(band_width))
	band.set_corner_radius_all(int(corner_radius))
	band.anti_aliasing = true
	draw_style_box(band, rect)
	_outline(rect, CaseFileStyle.GOLD.darkened(0.25), 2.0, corner_radius)
	_outline(rect.grow(-band_width + 1.0), CaseFileStyle.GOLD, 2.0, corner_radius - band_width + 2.0)
	_outline(rect.grow(-band_width - 9.0), Color(CaseFileStyle.SEPIA, 0.55), 1.0, maxf(corner_radius - band_width - 6.0, 4.0))
	var inset := band_width + 18.0
	_corner(Vector2(inset, inset), Vector2(1, 1))
	_corner(Vector2(size.x - inset, inset), Vector2(-1, 1))
	_corner(Vector2(inset, size.y - inset), Vector2(1, -1))
	_corner(Vector2(size.x - inset, size.y - inset), Vector2(-1, -1))


func _outline(rect: Rect2, color: Color, width: float, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(int(width))
	style.set_corner_radius_all(int(maxf(radius, 0.0)))
	style.anti_aliasing = true
	draw_style_box(style, rect)


## Voluta de esquina: dos trazos curvos que nacen en la esquina y terminan en espiral.
func _corner(origin: Vector2, direction: Vector2) -> void:
	var color := Color(CaseFileStyle.SEPIA, 0.85)
	var along_x := PackedVector2Array()
	var along_y := PackedVector2Array()
	for step in 25:
		var t := step / 24.0
		along_x.append(origin + Vector2(t * 120.0, sin(t * PI) * -10.0 + t * 4.0) * direction)
		along_y.append(origin + Vector2(sin(t * PI) * -10.0 + t * 4.0, t * 80.0) * direction)
	draw_polyline(along_x, color, 1.6, true)
	draw_polyline(along_y, color, 1.6, true)
	_spiral(origin + Vector2(124.0, 4.0) * direction, 7.0, direction, color)
	_spiral(origin + Vector2(4.0, 84.0) * direction, 6.0, direction, color)
	var diamond := PackedVector2Array([
		origin + Vector2(0, -6) * direction, origin + Vector2(6, 0) * direction,
		origin + Vector2(0, 6) * direction, origin + Vector2(-6, 0) * direction,
	])
	draw_colored_polygon(diamond, CaseFileStyle.BURGUNDY)
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), CaseFileStyle.GOLD, 1.2, true)


func _spiral(center: Vector2, radius: float, direction: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 30:
		var t := step / 29.0
		var angle := t * TAU * 1.4
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * (1.0 - t * 0.8) * direction)
	draw_polyline(points, color, 1.4, true)
