class_name TitleFlourish
extends Control
## Filigrana horizontal que acompaña a los títulos del expediente: una línea que se afina,
## un rombo y una pequeña espiral en el extremo cercano al título.

## Si es verdadero, la espiral queda a la izquierda (filigrana a la derecha del título).
@export var mirrored := false
@export var color := Color(0.42, 0.29, 0.18, 0.9)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var y := size.y * 0.5
	var direction := -1.0 if mirrored else 1.0
	var near := size.x if not mirrored else 0.0
	var far := size.x - near
	var points := PackedVector2Array()
	for step in 40:
		var t := step / 39.0
		points.append(Vector2(lerpf(far, near - direction * 22.0, t), y + sin(t * PI * 2.0) * 2.0 * t))
	draw_polyline(points, color, 1.8, true)
	draw_line(Vector2(lerpf(far, near, 0.25), y + 5.0), Vector2(near - direction * 30.0, y + 5.0), Color(color, 0.5), 1.0, true)
	var diamond_center := Vector2(lerpf(far, near, 0.18), y)
	draw_colored_polygon(PackedVector2Array([
		diamond_center + Vector2(0, -5), diamond_center + Vector2(7, 0),
		diamond_center + Vector2(0, 5), diamond_center + Vector2(-7, 0),
	]), color)
	var spiral := PackedVector2Array()
	var spiral_center := Vector2(near - direction * 14.0, y - 3.0)
	for step in 30:
		var t := step / 29.0
		var angle := t * TAU * 1.3
		spiral.append(spiral_center + Vector2(cos(angle) * direction, sin(angle)) * 8.0 * (1.0 - t * 0.75))
	draw_polyline(spiral, color, 1.6, true)
