class_name JournalOrnaments
extends RefCounted
## Adornos dibujados del expediente que no comparte el HUD: el clip de latón de las fotografías, las
## ondas del matasellos, los pespuntes del cuero y las esquinas de la carpeta. Como `HudOrnaments`
## (rombos, escuadras, cintas), son funciones sin estado que pintan sobre el `CanvasItem` recibido.

## Recorrido del alambre de un clip, de ancho 1 y largo 3,2, con el extremo abierto abajo.
static var _clip_wire: PackedVector2Array


## Clip de latón. `origin` es el centro de su extremo superior y `angle` lo inclina, en radianes.
static func draw_paperclip(canvas: CanvasItem, origin: Vector2, width: float, angle: float) -> void:
	var points := PackedVector2Array()
	var shadow := PackedVector2Array()
	var transform := Transform2D(angle, origin)
	for point in _wire():
		var local := (point - Vector2(0.5, 0.0)) * width
		points.append(transform * local)
		shadow.append(transform * local + Vector2(2.0, 3.0))
	var thickness := maxf(width * 0.12, 2.0)
	canvas.draw_polyline(shadow, Color(0.0, 0.0, 0.0, 0.3), thickness + 0.8, true)
	canvas.draw_polyline(points, JournalStyle.BRASS.darkened(0.25), thickness + 1.0, true)
	canvas.draw_polyline(points, JournalStyle.BRASS, thickness, true)
	var shine := PackedVector2Array()
	for point in points:
		shine.append(point + Vector2(-0.5, -0.6))
	canvas.draw_polyline(shine, Color(JournalStyle.BRASS_LIGHT, 0.7), maxf(thickness * 0.35, 1.0), true)


static func _wire() -> PackedVector2Array:
	if not _clip_wire.is_empty():
		return _clip_wire
	var wire := PackedVector2Array()
	# Brazo interior, curva pequeña arriba y bajada por dentro.
	wire.append(Vector2(0.33, 2.1))
	_add_arc(wire, Vector2(0.53, 0.62), 0.2, PI, 0.0, true)
	wire.append(Vector2(0.73, 2.72))
	# Curva grande abajo, subida por fuera y curva media arriba.
	_add_arc(wire, Vector2(0.4, 2.72), 0.33, 0.0, PI, false)
	wire.append(Vector2(0.07, 0.46))
	_add_arc(wire, Vector2(0.48, 0.46), 0.41, PI, 0.0, true)
	wire.append(Vector2(0.89, 2.25))
	_clip_wire = wire
	return wire


## Arco de `from` a `to` (radianes); `over` lo dibuja por encima del centro, si no por debajo.
static func _add_arc(points: PackedVector2Array, center: Vector2, radius: float, from: float, to: float, over: bool) -> void:
	for step in 13:
		var angle := lerpf(from, to, step / 12.0)
		var direction := Vector2(cos(angle), -sin(angle) if over else sin(angle))
		points.append(center + direction * radius)


## Ondas de un matasellos dentro de `rect`.
static func draw_postal_waves(canvas: CanvasItem, rect: Rect2, count: int, color: Color) -> void:
	var gap := rect.size.y / maxf(count - 1, 1)
	for line in count:
		var points := PackedVector2Array()
		var y := rect.position.y + line * gap
		for step in 49:
			var t := step / 48.0
			points.append(Vector2(rect.position.x + t * rect.size.x, y + sin(t * TAU * 2.6 + line * 0.5) * 3.2))
		canvas.draw_polyline(points, color, 1.6, true)


## Pespunte: trazos cortos a lo largo de un rectángulo, como el cosido de una carpeta de cuero.
static func draw_stitches(canvas: CanvasItem, rect: Rect2, color: Color, dash: float = 7.0, gap: float = 5.0) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for side in 4:
		var from: Vector2 = corners[side]
		var to: Vector2 = corners[(side + 1) % 4]
		var length := from.distance_to(to)
		var direction := (to - from) / maxf(length, 0.001)
		var along := gap
		while along + dash < length - gap:
			canvas.draw_line(from + direction * along, from + direction * (along + dash), color, 1.4, true)
			along += dash + gap


## Esquina de latón de la carpeta: un ángulo con dos volutas y un rombo burdeos.
static func draw_folder_corner(canvas: CanvasItem, origin: Vector2, inward: Vector2, size: float, color: Color) -> void:
	var arm_x := PackedVector2Array()
	var arm_y := PackedVector2Array()
	for step in 21:
		var t := step / 20.0
		arm_x.append(origin + Vector2(t * size, sin(t * PI) * -size * 0.08) * inward)
		arm_y.append(origin + Vector2(sin(t * PI) * -size * 0.08, t * size) * inward)
	canvas.draw_polyline(arm_x, color, 1.8, true)
	canvas.draw_polyline(arm_y, color, 1.8, true)
	for tip: Vector2 in [Vector2(size, 0.0), Vector2(0.0, size)]:
		var spiral := PackedVector2Array()
		var center := origin + (tip + Vector2(3.0, 3.0)) * inward
		for step in 24:
			var t := step / 23.0
			var angle := t * TAU * 1.2
			spiral.append(center + Vector2(cos(angle), sin(angle)) * 5.0 * (1.0 - t * 0.7) * inward)
		canvas.draw_polyline(spiral, color, 1.4, true)
	HudOrnaments.draw_diamond(canvas, origin + Vector2(7.0, 7.0) * inward, 5.0, JournalStyle.BURGUNDY, color)
