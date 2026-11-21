class_name GoldDivider
extends Control
## Filete dorado que se desvanece en los extremos, con un rombo opcional en el centro. Separa
## el encabezado de los menús y, en vertical, las categorías de su contenido. Con `hollow`, el
## rombo es sólo un contorno y el filete se interrumpe a su alrededor (el pie del diálogo).

const DIAMOND_RADIUS := 4.5
const HOLLOW_RADIUS := 6.0
## Hueco del filete alrededor del rombo hueco.
const HOLLOW_GAP := 7.0

@export var vertical := false
@export var diamond := true
@export var hollow := false
@export var color := Color(MenuStyle.GOLD, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(14.0, 0.0) if vertical else Vector2(0.0, 14.0)
	resized.connect(queue_redraw)


func _draw() -> void:
	var length := size.y if vertical else size.x
	var middle := (size.x if vertical else size.y) * 0.5
	if diamond and hollow:
		_draw_hollow(length, middle)
		return
	var points := PackedVector2Array()
	for t: float in [0.0, 0.2, 0.8, 1.0]:
		points.append(_point(t * length, middle))
	var faded := Color(color, 0.0)
	draw_polyline_colors(points, PackedColorArray([faded, color, color, faded]), 1.2, true)
	if diamond:
		var center := _point(length * 0.5, middle)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -DIAMOND_RADIUS), center + Vector2(DIAMOND_RADIUS, 0.0),
			center + Vector2(0.0, DIAMOND_RADIUS), center + Vector2(-DIAMOND_RADIUS, 0.0),
		]), color)


## Dos tramos de filete que se desvanecen hacia fuera y un rombo hueco entre ellos.
func _draw_hollow(length: float, middle: float) -> void:
	var faded := Color(color, 0.0)
	var half := length * 0.5
	var gap := HOLLOW_RADIUS + HOLLOW_GAP
	if half > gap:
		var left := PackedVector2Array([_point(0.0, middle), _point(length * 0.2, middle), _point(half - gap, middle)])
		var right := PackedVector2Array([_point(half + gap, middle), _point(length * 0.8, middle), _point(length, middle)])
		draw_polyline_colors(left, PackedColorArray([faded, color, color]), 1.2, true)
		draw_polyline_colors(right, PackedColorArray([color, color, faded]), 1.2, true)
	var center := _point(half, middle)
	var outline := PackedVector2Array([
		center + Vector2(0.0, -HOLLOW_RADIUS), center + Vector2(HOLLOW_RADIUS, 0.0),
		center + Vector2(0.0, HOLLOW_RADIUS), center + Vector2(-HOLLOW_RADIUS, 0.0),
		center + Vector2(0.0, -HOLLOW_RADIUS),
	])
	draw_polyline(outline, color, 1.4, true)


func _point(along: float, across: float) -> Vector2:
	return Vector2(across, along) if vertical else Vector2(along, across)
