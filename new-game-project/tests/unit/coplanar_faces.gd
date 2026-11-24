extends RefCounted
## Busca caras que la cámara ve y que comparten plano y superficie con otra cara del mismo escenario
## (z-fighting). Dos caras así tienen la misma profundidad en cada píxel: cuál gana depende del
## redondeo de la rasterización, que cambia con cada desplazamiento de la cámara, y la zona parpadea
## mientras el detective camina. Trabaja con los triángulos ya fusionados en el lote del escenario
## (modelos de Blender incluidos) y con las tres capas: el brillo y el suelo son mallas aparte, pero
## también se pelean con la capa opaca si comparten plano.
##
## Lo usan `test_scene_graphics.gd` y `tools/modelos/detectar_coplanares.tscn`.

## Dirección hacia la cámara de exploración (guiñada 45°, cabeceo -36°): sólo cuentan las caras que
## pueden verse.
const TOWARD_CAMERA := Vector3(0.5721, 0.5878, 0.5721)
## Dos caras con la misma normal están en el mismo plano si sus distancias al origen difieren menos.
const PLANE_TOLERANCE := 0.0004
## Superficie compartida mínima para considerarla un fallo (1 cm²).
const MIN_AREA := 0.0001


## Lista de solapes: {where, normal, colors, layers, area}. `batch` es el lote ya construido.
static func find(batch: MeshBatcher) -> Array[Dictionary]:
	var triangles: Array[Dictionary] = []
	for layer: MeshBatcher.Layer in [MeshBatcher.Layer.OPAQUE, MeshBatcher.Layer.GLOW, MeshBatcher.Layer.GROUND]:
		if not batch._buffers.has(layer):
			continue
		var buffers: MeshBatcher.Buffers = batch._buffers[layer]
		for start in range(0, buffers.vertices.size() - 2, 3):
			var a := buffers.vertices[start]
			var b := buffers.vertices[start + 1]
			var c := buffers.vertices[start + 2]
			var normal := (b - a).cross(c - a)
			if normal.length_squared() < 1e-12:
				continue
			normal = normal.normalized()
			if normal.dot(buffers.normals[start]) < 0.0:
				normal = -normal
			if normal.dot(TOWARD_CAMERA) <= 0.02:
				continue
			triangles.append({
				"points": PackedVector3Array([a, b, c]),
				"normal": normal,
				"distance": normal.dot(a),
				"color": buffers.colors[start],
				"layer": layer,
			})
	# Agrupa por normal y plano. Cada triángulo entra en su casilla y se compara con la vecina.
	var bins: Dictionary = {}
	for index in triangles.size():
		var triangle: Dictionary = triangles[index]
		var key := _bin_key(triangle["normal"], floori(float(triangle["distance"]) / (PLANE_TOLERANCE * 2.0)))
		if not bins.has(key):
			bins[key] = []
		(bins[key] as Array).append(index)
	var overlaps: Array[Dictionary] = []
	for key: String in bins:
		var members: Array = bins[key]
		var parts := key.split("|")
		var neighbour := "%s|%d" % [parts[0], int(parts[1]) + 1]
		var others: Array = members.duplicate()
		if bins.has(neighbour):
			others.append_array(bins[neighbour])
		_compare(triangles, members, others, overlaps)
	return overlaps


## Agrupa los solapes por zona (10 cm) para leerlos: cada pareja de piezas suele dar varios
## triángulos.
static func summarize(overlaps: Array[Dictionary]) -> Array[Dictionary]:
	var zones: Dictionary = {}
	for overlap in overlaps:
		var where: Vector3 = overlap["where"]
		var key := "%d,%d,%d|%s" % [roundi(where.x * 10.0), roundi(where.y * 10.0), roundi(where.z * 10.0), overlap["colors"]]
		if not zones.has(key):
			zones[key] = overlap.duplicate()
		else:
			zones[key]["area"] = float(zones[key]["area"]) + float(overlap["area"])
	var result: Array[Dictionary] = []
	for zone: Dictionary in zones.values():
		result.append(zone)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["area"]) > float(b["area"]))
	return result


static func describe(overlap: Dictionary) -> String:
	var where: Vector3 = overlap["where"]
	var normal: Vector3 = overlap["normal"]
	return "(%.2f, %.2f, %.2f) normal (%.2f, %.2f, %.2f) %.1f cm² %s capas %s" % [
		where.x, where.y, where.z, normal.x, normal.y, normal.z, float(overlap["area"]) * 10000.0, overlap["colors"], overlap["layers"]]


static func _compare(triangles: Array[Dictionary], members: Array, others: Array, overlaps: Array[Dictionary]) -> void:
	# Rectángulos de cada triángulo en el plano, para descartar deprisa. Todos con los mismos ejes.
	var basis := _plane_basis(triangles[members[0]]["normal"])
	var flat: Dictionary = {}
	var own: Dictionary = {}
	for index: int in members:
		own[index] = true
	for index: int in others:
		if not flat.has(index):
			flat[index] = _project(triangles[index], basis)
	for i: int in members:
		var first: Dictionary = flat[i]
		for j: int in others:
			if j <= i and own.has(j):
				continue
			var second: Dictionary = flat[j]
			if absf(float(triangles[i]["distance"]) - float(triangles[j]["distance"])) > PLANE_TOLERANCE:
				continue
			if (triangles[i]["normal"] as Vector3).dot(triangles[j]["normal"]) < 0.9999:
				continue
			var rect_a: Rect2 = first["rect"]
			var rect_b: Rect2 = second["rect"]
			if not rect_a.grow(-0.002).intersects(rect_b.grow(-0.002)):
				continue
			var area := 0.0
			var center := Vector2.ZERO
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(first["polygon"], second["polygon"]):
				var polygon_area := _area(polygon)
				area += polygon_area
				center += _centroid(polygon) * polygon_area
			if area < MIN_AREA * 0.05:
				continue
			center /= area
			var normal: Vector3 = triangles[i]["normal"]
			var distance := float(triangles[i]["distance"])
			var colors := [(triangles[i]["color"] as Color).to_html(false), (triangles[j]["color"] as Color).to_html(false)]
			colors.sort()
			var layers := [int(triangles[i]["layer"]), int(triangles[j]["layer"])]
			layers.sort()
			# Puntos de muestra de la zona compartida (centro y hacia cada esquina), para `visible`.
			var samples := PackedVector3Array()
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(first["polygon"], second["polygon"]):
				var middle := _centroid(polygon)
				samples.append(basis.x * middle.x + basis.y * middle.y + normal * distance)
				for corner in polygon:
					var point := middle.lerp(corner, 0.8)
					samples.append(basis.x * point.x + basis.y * point.y + normal * distance)
			overlaps.append({
				"where": basis.x * center.x + basis.y * center.y + normal * distance,
				"normal": normal,
				"colors": "/".join(colors),
				"layers": layers,
				"area": area,
				"samples": samples,
			})


## Deja sólo los solapes que la cámara llega a ver: algún punto de muestra sin nada delante (ni
## dentro de otro sólido). `space` debe contener la malla del escenario en `mask` (ver `add_probe`).
static func visible(overlaps: Array[Dictionary], space: PhysicsDirectSpaceState3D, mask: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for overlap in overlaps:
		var normal: Vector3 = overlap["normal"]
		for sample: Vector3 in overlap["samples"]:
			var start := sample + normal * 0.003
			var query := PhysicsRayQueryParameters3D.create(start, start + TOWARD_CAMERA * 80.0, mask)
			query.hit_back_faces = true
			query.hit_from_inside = true
			if space.intersect_ray(query).is_empty():
				result.append(overlap)
				break
	return result


## Cuerpo con la malla opaca y la de brillo del lote, para las pruebas de visibilidad. Lo añade a
## `parent` en la capa `layer` (sin máscara) y lo devuelve; hay que esperar un fotograma de física.
static func add_probe(parent: Node, batch: MeshBatcher, layer: int) -> StaticBody3D:
	var faces := PackedVector3Array()
	for mesh_layer: MeshBatcher.Layer in [MeshBatcher.Layer.OPAQUE, MeshBatcher.Layer.GLOW]:
		if batch._buffers.has(mesh_layer):
			faces.append_array((batch._buffers[mesh_layer] as MeshBatcher.Buffers).vertices)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.name = "SondaVisibilidad"
	body.collision_layer = layer
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


static func _plane_basis(normal: Vector3) -> Basis:
	var helper := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	var u := helper.cross(normal).normalized()
	return Basis(u, normal.cross(u).normalized(), normal)


static func _project(triangle: Dictionary, basis: Basis) -> Dictionary:
	var polygon := PackedVector2Array()
	for point: Vector3 in triangle["points"]:
		polygon.append(Vector2(point.dot(basis.x), point.dot(basis.y)))
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		rect = rect.expand(point)
	return {"polygon": polygon, "rect": rect}


static func _bin_key(normal: Vector3, distance_bin: int) -> String:
	return "%d,%d,%d|%d" % [roundi(normal.x * 200.0), roundi(normal.y * 200.0), roundi(normal.z * 200.0), distance_bin]


static func _area(polygon: PackedVector2Array) -> float:
	var total := 0.0
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5


static func _centroid(polygon: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for point in polygon:
		sum += point
	return sum / float(polygon.size())
