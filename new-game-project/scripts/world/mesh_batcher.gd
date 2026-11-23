class_name MeshBatcher
extends RefCounted
## Acumula primitivas low-poly de caras planas y las fusiona en una malla por capa.
## Un escenario entero termina en dos mallas, lo que mantiene bajas las llamadas de
## dibujado sin necesidad de modelos externos.

enum Layer { OPAQUE, GLOW, GROUND }


class Buffers:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()


## Transformación aplicada a todas las primitivas añadidas mientras esté activa.
var xform := Transform3D.IDENTITY
## Variación de brillo por cara. Rompe la uniformidad de las superficies grandes.
var color_jitter := 0.035
## Si está activo, cada cara añadida también se anota en `recorded` (puntos ya orientados, color
## sin variación y capa). Lo usa la exportación de referencias para llevar piezas a Blender.
var recording := false
var recorded: Array[Dictionary] = []

var _buffers: Dictionary = {}
var _seed := 7


func _init(random_seed: int = 7) -> void:
	_seed = random_seed


func is_empty() -> bool:
	return _buffers.is_empty()


## Añade un polígono convexo. `outward` indica hacia dónde debe mirar la cara.
func face(points: PackedVector3Array, color: Color, outward: Vector3, layer: Layer = Layer.OPAQUE) -> void:
	if points.size() < 3:
		return
	var world_points := PackedVector3Array()
	for point in points:
		world_points.append(xform * point)
	var normal := (world_points[1] - world_points[0]).cross(world_points[2] - world_points[0]).normalized()
	var world_outward := xform.basis * outward
	if normal.dot(world_outward) < 0.0:
		world_points.reverse()
		normal = -normal
	if recording:
		recorded.append({"points": world_points.duplicate(), "color": color, "layer": layer})
	var tinted := shaded(color, _centroid(world_points)) if layer == Layer.OPAQUE else color
	var buffers := _get_buffers(layer)
	# Godot considera cara frontal el orden horario, de ahí el recorrido invertido.
	for index in range(1, world_points.size() - 1):
		for vertex: Vector3 in [world_points[0], world_points[index + 1], world_points[index]]:
			buffers.vertices.append(vertex)
			buffers.normals.append(normal)
			buffers.colors.append(tinted)


func box(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0, layer: Layer = Layer.OPAQUE) -> void:
	var half := size * 0.5
	var rotation := Basis(Vector3.UP, yaw)
	var sides := [
		[Vector3.FORWARD, [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]]],
		[Vector3.BACK, [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]]],
		[Vector3.RIGHT, [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]]],
		[Vector3.LEFT, [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]]],
		[Vector3.UP, [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]]],
		[Vector3.DOWN, [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]]],
	]
	for side: Array in sides:
		var points := PackedVector3Array()
		for signs: Array in side[1]:
			points.append(center + rotation * Vector3(half.x * signs[0], half.y * signs[1], half.z * signs[2]))
		face(points, color, rotation * (side[0] as Vector3), layer)


## Rectángulo horizontal de suelo empedrado. `tint` aclara u oscurece la piedra.
func ground(from_corner: Vector2, to_corner: Vector2, tint: Color, height: float = 0.0) -> void:
	var points := PackedVector3Array([
		Vector3(from_corner.x, height, from_corner.y),
		Vector3(to_corner.x, height, from_corner.y),
		Vector3(to_corner.x, height, to_corner.y),
		Vector3(from_corner.x, height, to_corner.y),
	])
	face(points, tint, Vector3.UP, Layer.GROUND)


## Cilindro o tronco de cono con caras planas. `base` es el centro inferior.
func cylinder(
	base: Vector3,
	bottom_radius: float,
	top_radius: float,
	height: float,
	color: Color,
	sides: int = 8,
	layer: Layer = Layer.OPAQUE
) -> void:
	var top := base + Vector3.UP * height
	var bottom_ring := PackedVector3Array()
	var top_ring := PackedVector3Array()
	for index in sides:
		var angle := TAU * float(index) / float(sides)
		var offset := Vector3(cos(angle), 0.0, sin(angle))
		bottom_ring.append(base + offset * bottom_radius)
		top_ring.append(top + offset * top_radius)
	for index in sides:
		var next := (index + 1) % sides
		var middle := (bottom_ring[index] + bottom_ring[next] + top_ring[index] + top_ring[next]) * 0.25 - base
		var outward := Vector3(middle.x, 0.0, middle.z).normalized()
		if top_radius <= 0.001:
			face(PackedVector3Array([bottom_ring[index], bottom_ring[next], top]), color, outward, layer)
		elif bottom_radius <= 0.001:
			face(PackedVector3Array([base, top_ring[next], top_ring[index]]), color, outward, layer)
		else:
			face(
				PackedVector3Array([bottom_ring[index], bottom_ring[next], top_ring[next], top_ring[index]]),
				color,
				outward,
				layer
			)
	if top_radius > 0.001:
		face(top_ring, color, Vector3.UP, layer)
	if bottom_radius > 0.001:
		face(bottom_ring, color, Vector3.DOWN, layer)


## Tejado a dos aguas con la cumbrera paralela al eje Z local. `center` es el centro
## de la base.
func gable(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0, gable_color: Color = Color.TRANSPARENT) -> void:
	var rotation := Basis(Vector3.UP, yaw)
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	var left_front := center + rotation * Vector3(-half_x, 0.0, half_z)
	var right_front := center + rotation * Vector3(half_x, 0.0, half_z)
	var left_back := center + rotation * Vector3(-half_x, 0.0, -half_z)
	var right_back := center + rotation * Vector3(half_x, 0.0, -half_z)
	var ridge_front := center + rotation * Vector3(0.0, size.y, half_z)
	var ridge_back := center + rotation * Vector3(0.0, size.y, -half_z)
	var end_color := color if gable_color.a <= 0.0 else gable_color
	face(
		PackedVector3Array([left_front, ridge_front, ridge_back, left_back]),
		color,
		rotation * Vector3(-size.y, half_x, 0.0).normalized()
	)
	face(
		PackedVector3Array([right_front, right_back, ridge_back, ridge_front]),
		color,
		rotation * Vector3(size.y, half_x, 0.0).normalized()
	)
	face(PackedVector3Array([left_front, right_front, ridge_front]), end_color, rotation * Vector3.BACK)
	face(PackedVector3Array([right_back, left_back, ridge_back]), end_color, rotation * Vector3.FORWARD)


## Pirámide de base rectangular, para torres y tejados a cuatro aguas.
func pyramid(center: Vector3, size: Vector3, color: Color) -> void:
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	var apex := center + Vector3.UP * size.y
	var corners := [
		center + Vector3(-half_x, 0.0, half_z),
		center + Vector3(half_x, 0.0, half_z),
		center + Vector3(half_x, 0.0, -half_z),
		center + Vector3(-half_x, 0.0, -half_z),
	]
	var outward := [Vector3.BACK, Vector3.RIGHT, Vector3.FORWARD, Vector3.LEFT]
	for index in 4:
		face(PackedVector3Array([corners[index], corners[(index + 1) % 4], apex]), color, outward[index] + Vector3.UP)


## Esfera facetada. `stretch` permite aplastarla para copas de árbol o cabezas.
func sphere(
	center: Vector3,
	radius: float,
	color: Color,
	sides: int = 7,
	rings: int = 4,
	stretch: Vector3 = Vector3.ONE,
	layer: Layer = Layer.OPAQUE
) -> void:
	for ring in rings:
		for side in sides:
			var a := _sphere_point(center, radius, stretch, ring, side, rings, sides)
			var b := _sphere_point(center, radius, stretch, ring, side + 1, rings, sides)
			var c := _sphere_point(center, radius, stretch, ring + 1, side + 1, rings, sides)
			var d := _sphere_point(center, radius, stretch, ring + 1, side, rings, sides)
			var outward := ((a + b + c + d) * 0.25 - center).normalized()
			if ring == 0:
				face(PackedVector3Array([a, c, d]), color, outward, layer)
			elif ring == rings - 1:
				face(PackedVector3Array([a, b, c]), color, outward, layer)
			else:
				face(PackedVector3Array([a, b, c, d]), color, outward, layer)


## Añade triángulos ya hechos (un modelo importado, ver `ModelCatalog`) bajo
## `xform * transform`. Cada elemento de `surfaces` es un diccionario con `layer`, `vertices`,
## `normals` y `colors` (triángulos sin índices, en el orden de caras frontales de Godot) y
## `centers`: el centro del polígono al que pertenece cada vértice. La capa opaca recibe la
## misma variación de tono que `face`, calculada con ese centro: un modelo idéntico a una pieza
## procedural se dibuja idéntico.
func add_surfaces(surfaces: Array, transform: Transform3D = Transform3D.IDENTITY) -> void:
	var full := xform * transform
	var normal_basis := full.basis.inverse().transposed()
	var mirrored := full.basis.determinant() < 0.0
	for surface: Dictionary in surfaces:
		var layer: Layer = surface["layer"]
		var vertices: PackedVector3Array = surface["vertices"]
		var normals: PackedVector3Array = surface["normals"]
		var colors: PackedColorArray = surface["colors"]
		var centers: PackedVector3Array = surface["centers"]
		var buffers := _get_buffers(layer)
		var count := vertices.size() - vertices.size() % 3
		for start in range(0, count, 3):
			# Un espejo invierte el sentido de giro: se recorre el triángulo al revés.
			var order := [start, start + 2, start + 1] if mirrored else [start, start + 1, start + 2]
			for index: int in order:
				buffers.vertices.append(full * vertices[index])
				buffers.normals.append((normal_basis * normals[index]).normalized())
				var color := colors[index]
				if layer == Layer.OPAQUE:
					color = shaded(color, full * centers[index])
				buffers.colors.append(color)


## Capa del lote que corresponde a un material de un modelo, por su nombre.
static func layer_for_material(material_name: String) -> Layer:
	match material_name:
		"vs_brillo":
			return Layer.GLOW
		"vs_suelo":
			return Layer.GROUND
	return Layer.OPAQUE


func build_mesh(layer: Layer = Layer.OPAQUE) -> ArrayMesh:
	if not _buffers.has(layer):
		return null
	var buffers: Buffers = _buffers[layer]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = buffers.vertices
	arrays[Mesh.ARRAY_NORMAL] = buffers.normals
	arrays[Mesh.ARRAY_COLOR] = buffers.colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material_for(layer))
	return mesh


## Crea un MeshInstance3D por capa con contenido y lo añade a `parent`.
func attach_to(parent: Node3D, node_name: String = "Geometria") -> void:
	for layer: Layer in [Layer.GROUND, Layer.OPAQUE, Layer.GLOW]:
		var mesh := build_mesh(layer)
		if mesh == null:
			continue
		var instance := MeshInstance3D.new()
		instance.name = node_name + str(Layer.keys()[layer]).capitalize()
		instance.mesh = mesh
		if layer != Layer.OPAQUE:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)


func _material_for(layer: Layer) -> Material:
	match layer:
		Layer.GLOW:
			return MaterialLibrary.glow()
		Layer.GROUND:
			return MaterialLibrary.cobblestone()
	return MaterialLibrary.vertex_lit()


func _sphere_point(
	center: Vector3, radius: float, stretch: Vector3, ring: int, side: int, rings: int, sides: int
) -> Vector3:
	var polar := PI * float(ring) / float(rings)
	var angle := TAU * float(side) / float(sides)
	var unit := Vector3(sin(polar) * cos(angle), cos(polar), sin(polar) * sin(angle))
	return center + unit * radius * stretch


## Color de una cara con su variación de brillo. La variación sale del centro de la cara (en el
## espacio del escenario) y de la semilla, no del orden en que se añaden las caras: quitar,
## añadir o sustituir una pieza no cambia el tono de las demás.
func shaded(color: Color, center: Vector3) -> Color:
	if color_jitter <= 0.0:
		return color
	var unit := float(_hash_point(center)) / 4294967295.0
	var shade := lerpf(-color_jitter, color_jitter, unit)
	return Color(
		clampf(color.r + shade, 0.0, 1.0),
		clampf(color.g + shade, 0.0, 1.0),
		clampf(color.b + shade, 0.0, 1.0),
		color.a
	)


static func _centroid(points: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for point in points:
		sum += point
	return sum / float(points.size())


## Resume un punto en un entero de 32 bits. La rejilla es de 1 cm desplazada 0,37 cm: las
## medidas del juego (múltiplos de medio milímetro) nunca caen en el borde de una celda, así
## que los errores de coma flotante (un modelo exportado y vuelto a leer) no cambian la celda.
func _hash_point(point: Vector3) -> int:
	var hashed := _mix(_seed & 0xFFFFFFFF)
	for value: float in [point.x, point.y, point.z]:
		hashed = _mix(hashed ^ (floori(value * 100.0 + 0.37) & 0xFFFFFFFF))
	return hashed


static func _mix(value: int) -> int:
	value = (((value >> 16) ^ value) * 0x45d9f3b) & 0xFFFFFFFF
	value = (((value >> 16) ^ value) * 0x45d9f3b) & 0xFFFFFFFF
	return (value >> 16) ^ value


func _get_buffers(layer: Layer) -> Buffers:
	if not _buffers.has(layer):
		_buffers[layer] = Buffers.new()
	return _buffers[layer]
