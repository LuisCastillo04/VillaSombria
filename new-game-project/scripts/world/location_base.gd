class_name LocationBase
extends Node3D
## Escenario jugable. Cada escenario hereda de esta clase y declara su geometría en
## `build()` con las utilidades de aquí; la clase agrupa las mallas en una sola y
## registra los puntos de aparición y los marcadores que usan los NPC.

const NPC_SCENE := "res://scenes/actors/npc.tscn"

@export var location_id := ""

## Límites XZ del punto que enfoca la cámara.
var camera_limits := Rect2()
var batch := MeshBatcher.new()

var _spawns: Dictionary = {}
var _markers: Dictionary = {}
var _body: StaticBody3D
var _npcs: Dictionary = {}


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Colisiones"
	add_child(_body)
	build()
	batch.attach_to(self)
	EventBus.time_changed.connect(_on_time_changed)
	DialogueManager.closed.connect(_on_dialogue_closed)
	refresh_npcs()


## Sobrescribir para construir el escenario.
func build() -> void:
	pass


func get_npc(npc_id: String) -> Npc:
	return _npcs.get(npc_id)


## Sincroniza los NPC presentes con sus rutinas para la hora actual.
func refresh_npcs() -> void:
	if DialogueManager.active:
		return
	var expected := NpcSchedule.get_npcs_at(location_id, GameClock.day, GameClock.minutes)
	for npc_id: String in _npcs.keys():
		if not expected.has(npc_id):
			(_npcs[npc_id] as Npc).queue_free()
			_npcs.erase(npc_id)
	for npc_id in expected:
		var slot := NpcSchedule.get_slot(npc_id, GameClock.day, GameClock.minutes)
		if not _npcs.has(npc_id):
			_spawn_npc(npc_id, slot)
		elif (_npcs[npc_id] as Npc).current_slot != slot:
			_assign_slot(_npcs[npc_id], slot)
		(_npcs[npc_id] as Npc).interaction.refresh_marker()


func _spawn_npc(npc_id: String, slot: Dictionary) -> void:
	var npc: Npc = (load(NPC_SCENE) as PackedScene).instantiate()
	add_child(npc)
	npc.setup(npc_id)
	npc.global_position = get_marker(slot["marker"]) + Vector3.UP * 0.05
	_npcs[npc_id] = npc
	_assign_slot(npc, slot)


func _assign_slot(npc: Npc, slot: Dictionary) -> void:
	npc.current_slot = slot
	var points: Array[Vector3] = []
	for marker_id: String in slot.get("patrol", [slot["marker"]]):
		points.append(get_marker(marker_id))
	npc.set_route(points)


func _on_time_changed(_day: int, _minutes: int) -> void:
	refresh_npcs()


func _on_dialogue_closed(_npc_id: String) -> void:
	refresh_npcs()


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
	shape.transform = batch.xform * Transform3D(Basis(Vector3.UP, yaw), center)
	_body.add_child(shape)


func add_spawn(spawn_id: String, where: Vector3, yaw_degrees: float = 0.0) -> void:
	_spawns[spawn_id] = {"position": batch.xform * where, "yaw": deg_to_rad(yaw_degrees)}


func add_marker(marker_id: String, where: Vector3) -> void:
	_markers[marker_id] = batch.xform * where


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
	light.position = batch.xform * where
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = shadows
	add_child(light)
	return light


func add_interactable(node: Interactable, where: Vector3) -> Interactable:
	node.position = batch.xform * where
	add_child(node)
	return node


## Rótulo sobre una pared. El texto mira hacia el eje +Z local.
func add_sign(text: String, where: Vector3, height: float, color: Color, yaw: float = 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UiTheme.serif()
	label.font_size = 96
	label.outline_size = 0
	label.pixel_size = height / 96.0
	label.modulate = color
	label.shaded = false
	label.double_sided = false
	label.transform = batch.xform * Transform3D(Basis(Vector3.UP, yaw), where)
	add_child(label)
	return label
