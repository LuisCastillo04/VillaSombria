class_name MenuFrame
extends PanelContainer
## Panel oscuro de los menús: translúcido para que el escenario se siga viendo detrás, con un
## filete dorado envejecido y las esquinas recortadas hacia dentro, como la portada de un
## expediente. El del menú principal lleva un rombo en lo alto y una lupa al pie; los de pausa,
## configuración y controles, un medallón con su icono sobre una cresta y un rombo al pie.
## Todo se dibuja aquí, sin texturas ni desenfoques.

enum Footer { MAGNIFIER, DIAMOND }

const FILL := Color(0.035, 0.03, 0.035, 0.72)
const NOTCH := 16.0
const INNER_INSET := 7.0
const ARC_STEPS := 8
## Altura de la lupa sobre el borde inferior.
const ORNAMENT_LIFT := 40.0
const EMBLEM_RADIUS := 34.0
## La cresta es el tramo central del borde superior que se eleva bajo el medallón.
const CREST_HEIGHT := 12.0
const CREST_HALF_WIDTH := 110.0
const CREST_SHOULDER := 50.0
const CREST_STEPS := 12

## Icono del medallón que corona el panel. Sin él, el borde superior es recto y lleva un rombo.
@export var emblem: Texture2D:
	set(value):
		emblem = value
		_update_padding()
		queue_redraw()
@export var footer := Footer.MAGNIFIER
@export var fill_color := FILL
@export var padding_side := 57.0
@export var padding_top := 52.0
@export var padding_bottom := 86.0

var _shadow: StyleBoxFlat
var _padding := StyleBoxEmpty.new()


func _ready() -> void:
	_update_padding()
	add_theme_stylebox_override("panel", _padding)
	# Sólo el halo exterior: el interior no se oscurece más que el propio panel.
	_shadow = StyleBoxFlat.new()
	_shadow.draw_center = false
	_shadow.set_corner_radius_all(int(NOTCH))
	_shadow.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	_shadow.shadow_size = 28
	_shadow.shadow_offset = Vector2(0.0, 6.0)
	resized.connect(queue_redraw)


func _update_padding() -> void:
	_padding.content_margin_left = padding_side
	_padding.content_margin_right = padding_side
	_padding.content_margin_top = padding_top + (EMBLEM_RADIUS * 2.0 if emblem != null else 0.0)
	_padding.content_margin_bottom = padding_bottom


func _draw() -> void:
	var top := _body_top()
	draw_style_box(_shadow, Rect2(0.0, top, size.x, size.y - top).grow(-4.0))
	var outline := _notched_outline(0.0)
	draw_colored_polygon(outline, fill_color)
	var gold := CaseFileStyle.GOLD
	draw_polyline(_closed(outline), Color(gold, 0.9), 2.0, true)
	draw_polyline(_closed(_notched_outline(INNER_INSET)), Color(gold, 0.32), 1.0, true)
	_draw_corner_dots(Color(gold, 0.7))
	if emblem != null:
		_draw_emblem(gold)
	else:
		_draw_diamond_on_border(0.0, gold)
	if footer == Footer.MAGNIFIER:
		_draw_magnifier_rule(gold)
	else:
		_draw_diamond_on_border(size.y, gold)


## Borde superior del cuerpo del panel: bajo el medallón, si lo hay.
func _body_top() -> float:
	return EMBLEM_RADIUS + CREST_HEIGHT if emblem != null else 0.0


## Contorno con las esquinas recortadas en cuarto de círculo hacia dentro, a `inset` del borde.
## Los arcos de todos los contornos comparten centro, así los filetes quedan paralelos.
func _notched_outline(inset: float) -> PackedVector2Array:
	var top := _body_top()
	var radius := NOTCH + inset
	var along := sqrt(radius * radius - inset * inset)
	var start := atan2(inset, along)
	var end := atan2(along, inset)
	# Esquina, sentido hacia el interior y si el arco se recorre al revés, en el sentido de las agujas.
	var corners := [
		[Vector2(size.x, top), Vector2(-1.0, 1.0), false],
		[size, Vector2(-1.0, -1.0), true],
		[Vector2(0.0, size.y), Vector2(1.0, -1.0), false],
		[Vector2(0.0, top), Vector2(1.0, 1.0), true],
	]
	var points := PackedVector2Array()
	for corner: Array in corners:
		for step in ARC_STEPS + 1:
			var t := float(step) / ARC_STEPS
			var angle := lerpf(end, start, t) if corner[2] else lerpf(start, end, t)
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * radius * corner[1])
	if emblem != null:
		points.append_array(_crest(top + inset))
	return points


## Tramo elevado del borde superior, de izquierda a derecha, con hombros suaves.
func _crest(edge: float) -> PackedVector2Array:
	var middle := size.x * 0.5
	var points := PackedVector2Array()
	for side: float in [-1.0, 1.0]:
		for step in CREST_STEPS + 1:
			var t := float(step) / CREST_STEPS
			# Por la izquierda se sube hacia el centro; por la derecha se baja desde él.
			var rise := smoothstep(0.0, 1.0, t if side < 0.0 else 1.0 - t)
			var offset := CREST_HALF_WIDTH + CREST_SHOULDER * (1.0 - t if side < 0.0 else t)
			points.append(Vector2(middle + side * offset, edge - CREST_HEIGHT * rise))
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed


## Un punto dorado dentro de cada recorte, como los remaches de una carpeta.
func _draw_corner_dots(color: Color) -> void:
	var top := _body_top()
	var reach := (NOTCH + INNER_INSET + 7.0) * 0.7071
	for corner: Vector2 in [Vector2(0.0, top), Vector2(size.x, top), size, Vector2(0.0, size.y)]:
		var inward := Vector2(1.0 if corner.x == 0.0 else -1.0, 1.0 if corner.y == top else -1.0)
		draw_circle(corner + inward * reach, 2.2, color, true, -1.0, true)


## Medallón sobre la cresta con el icono del menú.
func _draw_emblem(gold: Color) -> void:
	var center := Vector2(size.x * 0.5, EMBLEM_RADIUS)
	draw_circle(center, EMBLEM_RADIUS - 1.0, Color(fill_color, 0.97), true, -1.0, true)
	draw_arc(center, EMBLEM_RADIUS - 1.0, 0.0, TAU, 56, gold, 2.2, true)
	draw_arc(center, EMBLEM_RADIUS - 6.0, 0.0, TAU, 56, Color(gold, 0.35), 1.0, true)
	var icon_size := Vector2.ONE * EMBLEM_RADIUS * 1.05
	draw_texture_rect(emblem, Rect2(center - icon_size * 0.5, icon_size), false, MenuStyle.TEXT)


## Rombo sobre un filete horizontal; su relleno tapa la línea para que parezca engastado.
func _draw_diamond_on_border(y: float, gold: Color) -> void:
	var center := Vector2(size.x * 0.5, y)
	var outer := _diamond(center, 10.0)
	draw_colored_polygon(outer, Color(fill_color, 0.96))
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
