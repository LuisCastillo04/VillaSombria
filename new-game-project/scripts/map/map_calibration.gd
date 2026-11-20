class_name MapCalibration
extends RefCounted
## Calcula la transformación entre el suelo de un escenario (X y Z del mundo, en metros) y el
## lienzo del mapa a partir de puntos de referencia: lugares reconocibles cuya posición se conoce en
## los dos sistemas, como la fuente de la plaza o la puerta del archivo.
##
## Con dos puntos se obtiene una semejanza (giro, escala uniforme y desplazamiento); con tres o más,
## una transformación afín por mínimos cuadrados, que también admite la perspectiva isométrica de un
## mapa pintado a mano. El resultado incluye el error de cada punto: si alguno se aleja, el punto
## está mal medido o el dibujo no corresponde al escenario.

## Error máximo admitido en un punto de referencia, en unidades del lienzo.
const MAX_RESIDUAL := 2.0


## Devuelve {"ok": bool, "transform": Transform2D, "residuals": {id: float}, "error": String}.
## Cada punto es {"id": String, "world": [x, z], "map": [u, v]}.
static func fit(anchors: Array) -> Dictionary:
	var world: Array[Vector2] = []
	var map: Array[Vector2] = []
	for anchor: Variant in anchors:
		var pair := _read_anchor(anchor)
		if pair.is_empty():
			return _failure("Punto de referencia mal escrito: %s" % str(anchor))
		world.append(pair[0])
		map.append(pair[1])
	var result: Dictionary
	if world.size() == 2:
		result = _similarity(world, map)
	elif world.size() >= 3:
		result = _affine(world, map)
	else:
		return _failure("Hacen falta al menos dos puntos de referencia.")
	if not result["ok"]:
		return result
	var xform: Transform2D = result["transform"]
	if xform.determinant() <= 0.0:
		return _failure("La calibración refleja el escenario como en un espejo: revisa los puntos.")
	var residuals := {}
	var worst := 0.0
	for index in world.size():
		var distance := (xform * world[index]).distance_to(map[index])
		residuals[str((anchors[index] as Dictionary).get("id", index))] = distance
		worst = maxf(worst, distance)
	result["residuals"] = residuals
	if worst > MAX_RESIDUAL:
		result["ok"] = false
		result["error"] = "Los puntos de referencia no encajan entre sí (error de %.1f unidades)." % worst
	return result


static func _read_anchor(anchor: Variant) -> Array:
	if not anchor is Dictionary:
		return []
	var world: Variant = (anchor as Dictionary).get("world")
	var map: Variant = (anchor as Dictionary).get("map")
	if not (world is Array and map is Array and (world as Array).size() == 2 and (map as Array).size() == 2):
		return []
	return [Vector2(float(world[0]), float(world[1])), Vector2(float(map[0]), float(map[1]))]


## Dos puntos: el lienzo es el escenario girado, escalado y desplazado, sin deformarlo.
static func _similarity(world: Array[Vector2], map: Array[Vector2]) -> Dictionary:
	var world_span := world[1] - world[0]
	if world_span.length_squared() < 0.0001:
		return _failure("Los dos puntos de referencia coinciden en el escenario.")
	var map_span := map[1] - map[0]
	# Cociente de números complejos: giro y escala que llevan un segmento al otro.
	var denominator := world_span.length_squared()
	var re := (map_span.x * world_span.x + map_span.y * world_span.y) / denominator
	var im := (map_span.y * world_span.x - map_span.x * world_span.y) / denominator
	var xform := Transform2D(Vector2(re, im), Vector2(-im, re), Vector2.ZERO)
	xform.origin = map[0] - xform.basis_xform(world[0])
	return {"ok": true, "transform": xform, "error": ""}


## Tres o más puntos: afín por mínimos cuadrados, resuelta con las ecuaciones normales.
static func _affine(world: Array[Vector2], map: Array[Vector2]) -> Dictionary:
	var normal := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	var rhs_u := [0.0, 0.0, 0.0]
	var rhs_v := [0.0, 0.0, 0.0]
	for index in world.size():
		var row := [world[index].x, world[index].y, 1.0]
		for i in 3:
			for j in 3:
				normal[i][j] += row[i] * row[j]
			rhs_u[i] += row[i] * map[index].x
			rhs_v[i] += row[i] * map[index].y
	var u := _solve3(normal, rhs_u)
	var v := _solve3(normal, rhs_v)
	if u.is_empty() or v.is_empty():
		return _failure("Los puntos de referencia están alineados: hacen falta puntos repartidos por el escenario.")
	var xform := Transform2D(Vector2(u[0], v[0]), Vector2(u[1], v[1]), Vector2(u[2], v[2]))
	return {"ok": true, "transform": xform, "error": ""}


## Sistema 3 × 3 por la regla de Cramer. Vacío si es singular.
static func _solve3(m: Array, b: Array) -> Array:
	var det := _det3(m)
	if absf(det) < 0.000001:
		return []
	var solution := []
	for column in 3:
		var replaced := [m[0].duplicate(), m[1].duplicate(), m[2].duplicate()]
		for row in 3:
			replaced[row][column] = b[row]
		solution.append(_det3(replaced) / det)
	return solution


static func _det3(m: Array) -> float:
	return (
		m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
		- m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
		+ m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])
	)


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "transform": Transform2D.IDENTITY, "residuals": {}, "error": message}
