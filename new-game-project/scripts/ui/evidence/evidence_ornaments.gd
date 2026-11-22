class_name EvidenceOrnaments
extends RefCounted
## Adornos dibujados de la inspección de evidencias: volutas de las esquinas del marco, filetes que
## terminan en un caracol y la placa con las esquinas cortadas. Como `HudOrnaments` o
## `DialogueOrnaments`, son funciones sin estado que pintan sobre el `CanvasItem` recibido.


## Puntos de una espiral alrededor de `center`, del radio inicial al final, empezando en
## `start_angle` (radianes) y dando `turns` vueltas; con `turns` negativo gira al revés.
static func spiral(center: Vector2, start_radius: float, end_radius: float, start_angle: float, turns: float, segments: int = 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in segments + 1:
		var t := float(step) / segments
		var angle := start_angle + TAU * turns * t
		points.append(center + Vector2.from_angle(angle) * lerpf(start_radius, end_radius, t))
	return points


## Voluta de una esquina del marco: los dos filetes se juntan en un caracol que asoma por fuera,
## con dos hojitas a lo largo de los lados. `outward` apunta hacia fuera, p. ej. (-1, -1) arriba a
## la izquierda.
static func draw_corner_scroll(canvas: CanvasItem, corner: Vector2, outward: Vector2, color: Color, width: float = 1.6) -> void:
	var center := corner + outward * 7.0
	var start := (corner - center).angle()
	var direction := 1.0 if outward.x * outward.y > 0.0 else -1.0
	canvas.draw_polyline(spiral(center, 8.5, 2.2, start, 1.15 * direction), color, width, true)
	canvas.draw_circle(center, 1.9, color, true, -1.0, true)
	for axis: Vector2 in [Vector2(-outward.x, 0.0), Vector2(0.0, -outward.y)]:
		var base := corner + axis * 16.0
		var side := Vector2(axis.y, axis.x).abs() * outward
		var leaf := PackedVector2Array([base, base + axis * 7.0 + side * 4.5, base + axis * 15.0])
		canvas.draw_polyline(leaf, Color(color, 0.8), width * 0.8, true)
		canvas.draw_circle(base + axis * 19.0, 1.4, Color(color, 0.8), true, -1.0, true)


## Filete de `from` a `to` que acaba en un pequeño caracol hacia arriba (o hacia abajo con
## `curl_up` falso), como los que salen a los lados del aviso y del botón de cerrar.
static func draw_scroll_line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, curl_up: bool = true, width: float = 1.4) -> void:
	canvas.draw_line(from, to, color, width, true)
	var along := (to - from).normalized()
	var center := to + Vector2(0.0, -5.0 if curl_up else 5.0)
	# Con el eje y hacia abajo, un ángulo que decrece gira en sentido antihorario en pantalla.
	var turns := -1.1 if (along.x > 0.0) == curl_up else 1.1
	canvas.draw_polyline(spiral(center, 5.0, 1.4, (to - center).angle(), turns), color, width, true)
	canvas.draw_circle(center, 1.3, color, true, -1.0, true)
	# Un punto suelto más allá del caracol remata el trazo.
	canvas.draw_circle(to + along * 11.0, 1.6, color, true, -1.0, true)


## Placa con las esquinas cortadas: rellena con un degradado vertical, con sombra, filete dorado
## y un segundo filete fino por dentro.
static func draw_plate(canvas: CanvasItem, rect: Rect2, cut: float, top: Color, bottom: Color, border: Color, inner: Color) -> void:
	var shape := HudOrnaments.chamfered(rect, cut)
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(0.0, 4.0))
	canvas.draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.45))
	DialogueOrnaments.draw_gradient_polygon(canvas, shape, top, bottom)
	canvas.draw_polyline(HudOrnaments.closed(shape), border, 2.0, true)
	var inner_shape := HudOrnaments.chamfered(rect.grow(-4.5), maxf(cut - 2.0, 1.0))
	canvas.draw_polyline(HudOrnaments.closed(inner_shape), inner, 1.0, true)
