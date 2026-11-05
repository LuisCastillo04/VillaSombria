class_name MeshBatcher
extends RefCounted
## Acumula primitivas low-poly de caras planas y las fusiona en una malla por capa.
## Un escenario entero termina en dos mallas, lo que mantiene bajas las llamadas de
## dibujado sin necesidad de modelos externos.

enum Layer { OPAQUE, GLOW }


class Buffers:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()


## Transformación aplicada a todas las primitivas añadidas mientras esté activa.
var xform := Transform3D.IDENTITY
## Variación de brillo por cara. Rompe la uniformidad de las superficies grandes.
var color_jitter := 0.035

var _buffers: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(random_seed: int = 7) -> void:
	_rng.seed = random_seed


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
	var shade := _rng.randf_range(-color_jitter, color_jitter) if layer == Layer.OPAQUE else 0.0
	var tinted := Color(
		clampf(color.r + shade, 0.0, 1.0),
		clampf(color.g + shade, 0.0, 1.0),
		clampf(color.b + shade, 0.0, 1.0),
		color.a
	)
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
	var material: Material = MaterialLibrary.vertex_lit() if layer == Layer.OPAQUE else MaterialLibrary.glow()
	mesh.surface_set_material(0, material)
	return mesh


## Crea un MeshInstance3D por capa con contenido y lo añade a `parent`.
func attach_to(parent: Node3D, node_name: String = "Geometria") -> void:
	for layer: Layer in [Layer.OPAQUE, Layer.GLOW]:
		var mesh := build_mesh(layer)
		if mesh == null:
			continue
		var instance := MeshInstance3D.new()
		instance.name = node_name + ("Luz" if layer == Layer.GLOW else "")
		instance.mesh = mesh
		if layer == Layer.GLOW:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)


func _sphere_point(
	center: Vector3, radius: float, stretch: Vector3, ring: int, side: int, rings: int, sides: int
) -> Vector3:
	var polar := PI * float(ring) / float(rings)
	var angle := TAU * float(side) / float(sides)
	var unit := Vector3(sin(polar) * cos(angle), cos(polar), sin(polar) * sin(angle))
	return center + unit * radius * stretch


func _get_buffers(layer: Layer) -> Buffers:
	if not _buffers.has(layer):
		_buffers[layer] = Buffers.new()
	return _buffers[layer]
