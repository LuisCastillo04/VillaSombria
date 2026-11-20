class_name HudOrnaments
extends RefCounted
## Adornos dibujados del HUD: rombos, escuadras de esquina, la cinta del encabezado y los remates
## de la barra. Son funciones de dibujo sin estado que reciben el `CanvasItem` donde pintar, así el
## pergamino, la barra y el marco de la pantalla comparten exactamente los mismos trazos.


static func diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -radius), center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius), center + Vector2(-radius, 0.0),
	])


static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result


## Rombo relleno, con un contorno opcional que lo engasta sobre una línea.
static func draw_diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	if outline.a > 0.0:
		canvas.draw_colored_polygon(diamond(center, radius + 1.6), outline)
	canvas.draw_colored_polygon(diamond(center, radius), color)


## Escuadras doradas en las cuatro esquinas de `rect`, con un punto en el vértice interior.
static func draw_corner_brackets(canvas: CanvasItem, rect: Rect2, length: float, color: Color, width: float = 1.6) -> void:
	for corner in _corners(rect):
		var origin: Vector2 = corner[0]
		var inward: Vector2 = corner[1]
		var points := PackedVector2Array([
			origin + Vector2(0.0, inward.y * length),
			origin,
			origin + Vector2(inward.x * length, 0.0),
		])
		canvas.draw_polyline(points, color, width, true)
		canvas.draw_circle(origin + inward * 4.5, 1.6, color, true, -1.0, true)


## Esquinas de `rect` con la dirección hacia su interior.
static func _corners(rect: Rect2) -> Array:
	return [
		[rect.position, Vector2(1.0, 1.0)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1.0, 1.0)],
		[rect.end, Vector2(-1.0, -1.0)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1.0, -1.0)],
	]


## Contorno de rectángulo con las esquinas cortadas en chaflán, como una placa de latón.
static func chamfered(rect: Rect2, cut: float) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([
		Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut),
		Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y),
		Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut),
	])


## Cinta con los extremos en punta hacia dentro, como la de un sello: la del encabezado «OBJETIVO».
static func ribbon(rect: Rect2, notch: float) -> PackedVector2Array:
	var middle := rect.position.y + rect.size.y * 0.5
	return PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y),
		Vector2(rect.end.x - notch, middle), rect.end,
		Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + notch, middle),
	])


## Remate de un extremo de la barra: un rombo engastado en el borde y dos trazos que lo abrazan.
## `direction` es -1 en el extremo izquierdo y 1 en el derecho.
static func draw_end_cap(canvas: CanvasItem, center: Vector2, direction: float, color: Color, fill: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var start := center + Vector2(-direction * 3.0, side * 9.0)
		var end := center + Vector2(-direction * 11.0, side * 15.0)
		canvas.draw_line(start, end, Color(color, 0.7), 1.4, true)
	draw_diamond(canvas, center, 5.5, color, fill)
	canvas.draw_colored_polygon(diamond(center, 2.0), fill)
