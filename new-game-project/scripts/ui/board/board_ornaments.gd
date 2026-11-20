class_name BoardOrnaments
extends RefCounted
## Adornos dibujados del tablero: chinchetas, hilos con su caída, nudos de latón, huecos libres del
## corcho y cercos de café. Como `HudOrnaments` y `JournalOrnaments`, son funciones sin estado que
## pintan sobre el `CanvasItem` recibido, así las fichas, los hilos y el corcho comparten trazos.

## Puntos de una curva de hilo.
const THREAD_SEGMENTS := 28


## Chincheta vista desde arriba: sombra, cabeza con borde más oscuro, volumen y un brillo.
## `lift` (0 a 1) la separa del papel, como al levantar la ficha.
static func draw_pin(canvas: CanvasItem, center: Vector2, color: Color, radius: float = BoardStyle.PIN_RADIUS, lift: float = 0.0) -> void:
	var shadow_offset := Vector2(2.5, 3.5) * (1.0 + lift * 0.8)
	canvas.draw_circle(center + shadow_offset, radius * 1.02, Color(0.0, 0.0, 0.0, 0.32), true, -1.0, true)
	canvas.draw_line(center + Vector2(1.0, 1.5), center + shadow_offset * 1.6, Color(0.0, 0.0, 0.0, 0.25), 1.6, true)
	canvas.draw_circle(center, radius, color.darkened(0.45), true, -1.0, true)
	canvas.draw_circle(center + Vector2(-0.3, -0.4), radius * 0.84, color, true, -1.0, true)
	canvas.draw_circle(center + Vector2(-radius * 0.18, -radius * 0.2), radius * 0.5, color.lightened(0.22), true, -1.0, true)
	canvas.draw_circle(center + Vector2(-radius * 0.34, -radius * 0.38), radius * 0.2, Color(1.0, 0.95, 0.88, 0.85), true, -1.0, true)


## Nudo de latón donde se cruzan dos hilos: una chincheta dorada con un aro.
static func draw_knot(canvas: CanvasItem, center: Vector2, radius: float = 8.0) -> void:
	canvas.draw_arc(center, radius + 3.0, 0.0, TAU, 32, Color(BoardStyle.BRASS.darkened(0.3), 0.8), 1.6, true)
	draw_pin(canvas, center, BoardStyle.BRASS, radius)


## Curva de un hilo tendido entre dos chinchetas: cae un poco por su peso, más cuanto más largo.
static func thread_points(from: Vector2, to: Vector2, sag_ratio: float = 0.07) -> PackedVector2Array:
	var distance := from.distance_to(to)
	var sag := clampf(distance * sag_ratio, 4.0, 46.0)
	var control := (from + to) * 0.5 + Vector2(0.0, sag)
	var points := PackedVector2Array()
	for step in THREAD_SEGMENTS + 1:
		var t := float(step) / THREAD_SEGMENTS
		points.append(from.lerp(control, t).lerp(control.lerp(to, t), t))
	return points


## Hilo entre dos puntos, con sombra sobre el corcho y un brillo fino. `progress` (0 a 1) lo dibuja
## a medias, para tenderlo poco a poco; `dashed`, a trazos.
static func draw_thread(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, width: float, progress: float = 1.0, dashed: bool = false) -> void:
	var points := thread_points(from, to)
	if progress < 1.0:
		points = _partial(points, clampf(progress, 0.0, 1.0))
	if points.size() < 2:
		return
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(2.0, 3.0))
	if dashed:
		_dashed(canvas, shadow, Color(0.0, 0.0, 0.0, 0.22 * color.a), width, 11.0, 7.0)
		_dashed(canvas, points, color, width, 11.0, 7.0)
		return
	canvas.draw_polyline(shadow, Color(0.0, 0.0, 0.0, 0.26 * color.a), width + 0.6, true)
	canvas.draw_polyline(points, Color(color.darkened(0.35), color.a), width + 0.8, true)
	canvas.draw_polyline(points, color, width, true)
	var shine := PackedVector2Array()
	for point in points:
		shine.append(point + Vector2(-0.4, -0.5))
	canvas.draw_polyline(shine, Color(1.0, 0.78, 0.72, 0.28 * color.a), maxf(width * 0.3, 0.8), true)


## Hueco libre del corcho para pruebas futuras: papel tenue, borde a trazos y una cruz. Es sólo un
## indicador: no se puede pulsar ni dice cuántas pruebas faltan.
static func draw_placeholder(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Color(BoardStyle.CREAM, 0.16))
	var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position])
	_dashed(canvas, corners, Color(BoardStyle.INK, 0.38), 1.6, 9.0, 6.0)
	var center := rect.get_center()
	var arm := minf(rect.size.x, rect.size.y) * 0.12
	var ink := Color(BoardStyle.INK, 0.34)
	canvas.draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), ink, 2.4, true)
	canvas.draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), ink, 2.4, true)


## Cerco que deja una taza de café: dos arcos incompletos de grosor irregular.
static func draw_coffee_ring(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_arc(center, radius, 0.3, TAU * 0.86, 48, color, 3.2, true)
	canvas.draw_arc(center, radius - 2.5, 2.2, TAU * 0.98, 40, Color(color, color.a * 0.6), 1.4, true)
	canvas.draw_arc(center + Vector2(1.5, -1.0), radius + 1.8, 4.1, 5.6, 16, Color(color, color.a * 0.5), 1.0, true)


static func _partial(points: PackedVector2Array, progress: float) -> PackedVector2Array:
	var total := 0.0
	for index in range(1, points.size()):
		total += points[index - 1].distance_to(points[index])
	var target := total * progress
	var result := PackedVector2Array([points[0]])
	var walked := 0.0
	for index in range(1, points.size()):
		var step := points[index - 1].distance_to(points[index])
		if walked + step >= target:
			result.append(points[index - 1].lerp(points[index], (target - walked) / maxf(step, 0.001)))
			break
		walked += step
		result.append(points[index])
	return result


static func _dashed(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	var drawing := true
	var left := dash
	for index in range(1, points.size()):
		var from := points[index - 1]
		var to := points[index]
		var length := from.distance_to(to)
		var direction := (to - from) / maxf(length, 0.001)
		var along := 0.0
		while along < length:
			var step := minf(left, length - along)
			if drawing:
				canvas.draw_line(from + direction * along, from + direction * (along + step), color, width, true)
			along += step
			left -= step
			if left <= 0.0:
				drawing = not drawing
				left = dash if drawing else gap
