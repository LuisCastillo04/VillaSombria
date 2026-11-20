class_name MapSymbols
extends RefCounted
## Símbolos del mapa: la chincheta dorada de los puntos de interés, el rombo de los objetivos y el
## círculo luminoso del detective. El lienzo y la leyenda usan estas mismas funciones, así lo que
## explica la leyenda es exactamente lo que aparece en el mapa.

enum Kind { PLACE, OBJECTIVE, PLAYER }

const GOLD := Color("d6ab5c")
const GOLD_LIGHT := Color("f6dc98")
const GOLD_DARK := Color("8a6328")
const INK := Color("21150c")
const AMBER := Color(1.0, 0.68, 0.26)
const CORE := Color("fff3d0")
const DIMMED := Color(0.55, 0.5, 0.42)

## Altura de la chincheta desde la punta hasta lo alto de la cabeza, para un tamaño 1.
const PIN_REACH := 2.75
const PIN_HEAD_LIFT := 1.75


## Chincheta con la punta en `tip`. `size` es el radio de la cabeza; `highlight` (0 a 1) añade un
## halo para la chincheta señalada.
static func draw_pin(canvas: CanvasItem, tip: Vector2, size: float, highlight: float = 0.0, dimmed: bool = false) -> void:
	var head := tip + Vector2(0.0, -PIN_HEAD_LIFT * size)
	_draw_ellipse(canvas, tip + Vector2(size * 0.25, size * 0.1), Vector2(size * 0.9, size * 0.32), Color(0.0, 0.0, 0.0, 0.35))
	if highlight > 0.0:
		for ring in 3:
			var reach := size * (1.55 + 0.35 * ring) * (0.85 + 0.15 * highlight)
			canvas.draw_circle(head, reach, Color(AMBER, 0.16 * highlight / (ring + 1)), true, -1.0, true)
	var body := _pin_outline(head, tip, size)
	var outline := _pin_outline(head, tip + Vector2(0.0, size * 0.18), size * 1.16)
	var gold := DIMMED if dimmed else GOLD.lerp(GOLD_LIGHT, highlight * 0.5)
	canvas.draw_colored_polygon(outline, INK)
	canvas.draw_colored_polygon(body, gold)
	canvas.draw_polyline(_closed(body), Color(GOLD_DARK, 0.9), maxf(size * 0.08, 1.0), true)
	# Brillo en el lado iluminado y agujero central de tinta con un punto dorado.
	canvas.draw_circle(head + Vector2(-size * 0.38, -size * 0.38), size * 0.32, Color(GOLD_LIGHT, 0.0 if dimmed else 0.55), true, -1.0, true)
	canvas.draw_circle(head, size * 0.46, INK, true, -1.0, true)
	canvas.draw_circle(head, size * 0.18, gold, true, -1.0, true)


## Rombo de objetivo centrado en `center`; `radius` es la mitad de su diagonal.
static func draw_diamond(canvas: CanvasItem, center: Vector2, radius: float, glow: float = 0.0) -> void:
	if glow > 0.0:
		for ring in 3:
			canvas.draw_colored_polygon(_diamond(center, radius * (1.5 + 0.4 * ring)), Color(AMBER, 0.13 * glow / (ring + 1)))
	canvas.draw_colored_polygon(_diamond(center, radius + maxf(radius * 0.22, 1.5)), INK)
	canvas.draw_colored_polygon(_diamond(center, radius), GOLD)
	canvas.draw_polyline(_closed(_diamond(center, radius)), GOLD_LIGHT, maxf(radius * 0.1, 1.0), true)
	canvas.draw_colored_polygon(_diamond(center, radius * 0.46), INK)
	canvas.draw_colored_polygon(_diamond(center, radius * 0.2), GOLD_LIGHT)


## Marcador del detective: anillo dorado con el centro encendido, un resplandor ámbar y una onda
## que se expande con `pulse` (0 a 1). `heading` es hacia dónde mira, o cero si no se sabe.
static func draw_player(canvas: CanvasItem, center: Vector2, radius: float, pulse: float, heading: Vector2 = Vector2.ZERO) -> void:
	for step in 6:
		var t := float(step) / 5.0
		canvas.draw_circle(center, radius * lerpf(2.7, 1.2, t), Color(AMBER, lerpf(0.04, 0.2, t)), true, -1.0, true)
	var wave := radius * (1.05 + 1.5 * pulse)
	canvas.draw_arc(center, wave, 0.0, TAU, 48, Color(GOLD_LIGHT, 0.85 * (1.0 - pulse)), maxf(radius * 0.2, 1.5), true)
	if heading.length_squared() > 0.0001:
		var forward := heading.normalized()
		var side := Vector2(-forward.y, forward.x)
		var arrow := PackedVector2Array([
			center + forward * radius * 2.15,
			center + forward * radius * 1.15 + side * radius * 0.7,
			center + forward * radius * 1.15 - side * radius * 0.7,
		])
		canvas.draw_colored_polygon(arrow, GOLD)
		canvas.draw_polyline(_closed(arrow), INK, maxf(radius * 0.12, 1.0), true)
	canvas.draw_circle(center, radius * 1.22, Color(INK, 0.9), true, -1.0, true)
	canvas.draw_arc(center, radius, 0.0, TAU, 40, GOLD, radius * 0.32, true)
	canvas.draw_circle(center, radius * 0.56, AMBER.lerp(CORE, 0.55), true, -1.0, true)
	canvas.draw_circle(center, radius * 0.3, CORE, true, -1.0, true)


## Contorno en forma de gota: arco de la cabeza y los dos lados tangentes hasta la punta.
static func _pin_outline(head: Vector2, tip: Vector2, radius: float) -> PackedVector2Array:
	var to_tip := tip - head
	var distance := to_tip.length()
	var spread := acos(clampf(radius / distance, -1.0, 1.0))
	var toward := to_tip.angle()
	var points := PackedVector2Array([tip])
	var steps := 20
	var start := toward + spread
	var end := toward - spread + TAU
	for step in steps + 1:
		var angle := lerpf(start, end, float(step) / steps)
		points.append(head + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -radius), center + Vector2(radius * 0.78, 0.0),
		center + Vector2(0.0, radius), center + Vector2(-radius * 0.78, 0.0),
	])


static func _draw_ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 24:
		var angle := TAU * step / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	canvas.draw_colored_polygon(points, color)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed
