class_name MenuFrame
extends PanelContainer
## Panel del menú principal: negro translúcido para que la plaza se siga viendo detrás, con un
## filete dorado envejecido, las esquinas recortadas hacia dentro, un rombo en lo alto y una lupa
## al pie, como la portada de un expediente. Todo se dibuja aquí, sin texturas ni desenfoques.

const FILL := Color(0.035, 0.03, 0.035, 0.72)
const NOTCH := 16.0
const INNER_INSET := 7.0
const ARC_STEPS := 8
const PADDING_SIDE := 57.0
const PADDING_TOP := 52.0
const PADDING_BOTTOM := 86.0
## Altura de la lupa sobre el borde inferior.
const ORNAMENT_LIFT := 40.0

var _shadow: StyleBoxFlat


func _ready() -> void:
	var padding := StyleBoxEmpty.new()
	padding.content_margin_left = PADDING_SIDE
	padding.content_margin_right = PADDING_SIDE
	padding.content_margin_top = PADDING_TOP
	padding.content_margin_bottom = PADDING_BOTTOM
	add_theme_stylebox_override("panel", padding)
	# Sólo el halo exterior: el interior no se oscurece más que el propio panel.
	_shadow = StyleBoxFlat.new()
	_shadow.draw_center = false
	_shadow.set_corner_radius_all(int(NOTCH))
	_shadow.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	_shadow.shadow_size = 28
	_shadow.shadow_offset = Vector2(0.0, 6.0)
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_style_box(_shadow, Rect2(Vector2.ZERO, size).grow(-4.0))
	var outline := _notched_outline(0.0)
	draw_colored_polygon(outline, FILL)
	var gold := CaseFileStyle.GOLD
	draw_polyline(_closed(outline), Color(gold, 0.9), 2.0, true)
	draw_polyline(_closed(_notched_outline(INNER_INSET)), Color(gold, 0.32), 1.0, true)
	_draw_corner_dots(Color(gold, 0.7))
	_draw_top_diamond(gold)
	_draw_magnifier_rule(gold)


## Contorno con las esquinas recortadas en cuarto de círculo hacia dentro, a `inset` del borde.
## Los arcos de todos los contornos comparten centro, así los filetes quedan paralelos.
func _notched_outline(inset: float) -> PackedVector2Array:
	var radius := NOTCH + inset
	var along := sqrt(radius * radius - inset * inset)
	var start := atan2(inset, along)
	var end := atan2(along, inset)
	# Esquina, sentido hacia el interior y si el arco se recorre al revés, en el sentido de las agujas.
	var corners := [
		[Vector2(size.x, 0.0), Vector2(-1.0, 1.0), false],
		[size, Vector2(-1.0, -1.0), true],
		[Vector2(0.0, size.y), Vector2(1.0, -1.0), false],
		[Vector2.ZERO, Vector2(1.0, 1.0), true],
	]
	var points := PackedVector2Array()
	for corner: Array in corners:
		for step in ARC_STEPS + 1:
			var t := float(step) / ARC_STEPS
			var angle := lerpf(end, start, t) if corner[2] else lerpf(start, end, t)
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * radius * corner[1])
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed


## Un punto dorado dentro de cada recorte, como los remaches de una carpeta.
func _draw_corner_dots(color: Color) -> void:
	var reach := (NOTCH + INNER_INSET + 7.0) * 0.7071
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]:
		var inward := Vector2(1.0 if corner.x == 0.0 else -1.0, 1.0 if corner.y == 0.0 else -1.0)
		draw_circle(corner + inward * reach, 2.2, color, true, -1.0, true)


## Rombo sobre el filete superior; su relleno tapa la línea para que parezca engastado.
func _draw_top_diamond(gold: Color) -> void:
	var center := Vector2(size.x * 0.5, 0.0)
	var outer := _diamond(center, 10.0)
	draw_colored_polygon(outer, Color(FILL, 0.96))
	draw_polyline(_closed(outer), gold, 1.8, true)
	draw_colored_polygon(_diamond(center, 3.5), gold)


func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
	])


## Filete con una lupa en el centro, al pie del panel.
func _draw_magnifier_rule(gold: Color) -> void:
	var y := size.y - ORNAMENT_LIFT
	var middle := size.x * 0.5
	var line_color := Color(gold, 0.75)
	for side: float in [-1.0, 1.0]:
		var near := Vector2(middle + side * 26.0, y)
		var far := Vector2(middle + side * 170.0, y)
		draw_line(near, far, line_color, 1.5, true)
		draw_circle(far + Vector2(side * 6.0, 0.0), 2.2, line_color, true, -1.0, true)
	var lens := Vector2(middle - 3.0, y - 3.0)
	draw_arc(lens, 9.5, 0.0, TAU, 36, gold, 2.2, true)
	var handle := Vector2(0.7071, 0.7071)
	draw_line(lens + handle * 10.5, lens + handle * 19.0, gold, 3.6, true)
