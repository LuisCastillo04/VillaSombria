class_name GoldDivider
extends Control
## Filete dorado que se desvanece en los extremos, con un rombo opcional en el centro. Separa
## el encabezado de los menús y, en vertical, las categorías de su contenido.

@export var vertical := false
@export var diamond := true
@export var color := Color(MenuStyle.GOLD, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(14.0, 0.0) if vertical else Vector2(0.0, 14.0)
	resized.connect(queue_redraw)


func _draw() -> void:
	var length := size.y if vertical else size.x
	var middle := (size.x if vertical else size.y) * 0.5
	var points := PackedVector2Array()
	for t: float in [0.0, 0.2, 0.8, 1.0]:
		points.append(_point(t * length, middle))
	var faded := Color(color, 0.0)
	draw_polyline_colors(points, PackedColorArray([faded, color, color, faded]), 1.2, true)
	if diamond:
		var center := _point(length * 0.5, middle)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -4.5), center + Vector2(4.5, 0.0),
			center + Vector2(0.0, 4.5), center + Vector2(-4.5, 0.0),
		]), color)


func _point(along: float, across: float) -> Vector2:
	return Vector2(across, along) if vertical else Vector2(along, across)
