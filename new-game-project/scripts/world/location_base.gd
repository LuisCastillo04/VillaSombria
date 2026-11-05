class_name LocationBase
extends Node3D
## Escenario jugable. Cada escenario hereda de esta clase y declara su geometría en
## `build()` con las utilidades de aquí; la clase agrupa las mallas en una sola y
## registra los puntos de aparición y los marcadores que usan los NPC.

@export var location_id := ""

## Límites XZ del punto que enfoca la cámara.
var camera_limits := Rect2()
var batch := MeshBatcher.new()

var _spawns: Dictionary = {}
var _markers: Dictionary = {}
var _body: StaticBody3D


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Colisiones"
	add_child(_body)
	build()
	batch.attach_to(self)


## Sobrescribir para construir el escenario.
func build() -> void:
	pass


## Caja visible con colisión.
func solid(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	batch.box(center, size, color, yaw)
	collider(center, size, yaw)


## Colisión sin geometría, para muros invisibles y mobiliario compuesto.
func collider(center: Vector3, size: Vector3, yaw: float = 0.0) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	shape.rotation.y = yaw
	_body.add_child(shape)


func add_spawn(spawn_id: String, where: Vector3, yaw_degrees: float = 0.0) -> void:
	_spawns[spawn_id] = {"position": where, "yaw": deg_to_rad(yaw_degrees)}


func add_marker(marker_id: String, where: Vector3) -> void:
	_markers[marker_id] = where


func has_marker(marker_id: String) -> bool:
	return _markers.has(marker_id)


func get_marker(marker_id: String) -> Vector3:
	return _markers.get(marker_id, Vector3.ZERO)


func get_marker_ids() -> Array:
	return _markers.keys()


func has_spawn(spawn_id: String) -> bool:
	return _spawns.has(spawn_id)


## Devuelve el punto de aparición pedido o, si no existe, el primero registrado.
func get_spawn(spawn_id: String) -> Dictionary:
	if _spawns.has(spawn_id):
		return _spawns[spawn_id]
	if not _spawns.is_empty():
		return _spawns.values()[0]
	return {"position": Vector3.ZERO, "yaw": 0.0}


func add_point_light(
	where: Vector3, color: Color, energy: float, light_range: float, shadows: bool = false
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = where
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = shadows
	add_child(light)
	return light


func add_interactable(node: Interactable, where: Vector3) -> Interactable:
	node.position = where
	add_child(node)
	return node
