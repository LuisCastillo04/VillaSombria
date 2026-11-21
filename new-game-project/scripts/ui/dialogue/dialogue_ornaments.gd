class_name DialogueOrnaments
extends RefCounted
## Adornos dibujados de las conversaciones. Como `HudOrnaments` (rombos, escuadras, cintas) y
## `JournalOrnaments` (esquinas de latón, pespuntes), son funciones sin estado que pintan sobre el
## `CanvasItem` recibido, así la ventana, la placa del nombre y las respuestas comparten trazos.


## Contorno de rectángulo con las esquinas recortadas en escuadra hacia dentro, como el filete de
## un sello o de una lámina antigua.
static func notched_rect(rect: Rect2, notch: float) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([
		Vector2(a.x + notch, a.y), Vector2(b.x - notch, a.y), Vector2(b.x - notch, a.y + notch),
		Vector2(b.x, a.y + notch), Vector2(b.x, b.y - notch), Vector2(b.x - notch, b.y - notch),
		Vector2(b.x - notch, b.y), Vector2(a.x + notch, b.y), Vector2(a.x + notch, b.y - notch),
		Vector2(a.x, b.y - notch), Vector2(a.x, a.y + notch), Vector2(a.x + notch, a.y + notch),
	])


## Polígono relleno con un degradado vertical, más claro arriba, como el lustre de una placa.
static func draw_gradient_polygon(canvas: CanvasItem, points: PackedVector2Array, top: Color, bottom: Color) -> void:
	var low := INF
	var high := -INF
	for point in points:
		low = minf(low, point.y)
		high = maxf(high, point.y)
	var colors := PackedColorArray()
	for point in points:
		colors.append(top.lerp(bottom, inverse_lerp(low, high, point.y) if high > low else 0.0))
	canvas.draw_polygon(points, colors)


## Esquina de latón de la ventana: dos brazos dorados que abrazan la esquina y un rombo en el vértice.
## `inward` apunta hacia el interior (por ejemplo, (1, 1) en la esquina superior izquierda).
static func draw_corner_piece(canvas: CanvasItem, origin: Vector2, inward: Vector2, length: float, color: Color, fill: Color) -> void:
	var points := PackedVector2Array([
		origin + Vector2(0.0, inward.y * length),
		origin,
		origin + Vector2(inward.x * length, 0.0),
	])
	canvas.draw_polyline(points, Color(0.0, 0.0, 0.0, 0.35), 4.6, true)
	canvas.draw_polyline(points, color, 2.4, true)
	for tip: Vector2 in [Vector2(0.0, inward.y * length), Vector2(inward.x * length, 0.0)]:
		canvas.draw_circle(origin + tip, 2.2, color, true, -1.0, true)
	HudOrnaments.draw_diamond(canvas, origin, 5.0, color, fill)
