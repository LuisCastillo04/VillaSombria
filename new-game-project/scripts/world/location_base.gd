class_name LocationBase
extends Node3D
## Escenario jugable. Cada escenario hereda de esta clase y declara su geometría en
## `build()` con las utilidades de aquí; la clase agrupa las mallas en una sola y
## registra los puntos de aparición y los marcadores que usan los NPC.

const NPC_SCENE := "res://scenes/actors/npc.tscn"
## Altura del suelo transitable de todos los escenarios.
const FLOOR_HEIGHT := 0.0
## Altura de los muros invisibles: más que cualquier salto o pendiente posible.
const BARRIER_HEIGHT := 3.0
## Separación mínima entre los sitios donde se paran dos NPC a la vez.
const NPC_SPACING := 1.2
## Distancia mínima entre un sitio de parada y un hueco de paso: un NPC no cierra puertas.
const NPC_DOORWAY_CLEARANCE := 1.1
## Distancia mínima entre un sitio de parada y una pista, salida o cama: no las tapa.
const NPC_INTERACTABLE_CLEARANCE := 0.9

@export var location_id := ""

## Límites XZ del punto que enfoca la cámara.
var camera_limits := Rect2()
## Rectángulo XZ que encierra todo lo transitable. Lo usan la red de seguridad contra caídas y
## la navegación de los NPC; las colisiones deben impedir salir de él. Sin área, sólo se vigila
## la altura.
var play_area := Rect2()
var batch := MeshBatcher.new()
## Navegación de los NPC, horneada con las colisiones del escenario al construirlo.
var navigation: LocationNavigation

var _spawns: Dictionary = {}
var _markers: Dictionary = {}
## Orientación (yaw del modelo) con la que se espera en los marcadores que la tienen.
var _marker_facing: Dictionary = {}
## Centros de los huecos de paso entre estancias y hacia la calle.
var _doorways: Array[Vector3] = []
var _body: StaticBody3D
var _npcs: Dictionary = {}
## NPC presentes que intervienen en la escena narrativa en curso.
var _scene_cast: Array[Npc] = []


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "Colisiones"
	add_child(_body)
	build()
	batch.attach_to(self)
	navigation = LocationNavigation.new()
	navigation.name = "Navegacion"
	add_child(navigation)
	navigation.bake(_body, play_area)
	EventBus.time_changed.connect(_on_time_changed)
	# Las rutinas pueden depender de la historia (un tramo con «if»): una marca nueva puede
	# cambiar quién está aquí.
	EventBus.flag_set.connect(_on_flag_set)
	DialogueManager.scene_started.connect(_on_scene_started)
	DialogueManager.line_shown.connect(_on_line_shown)
	DialogueManager.closed.connect(_on_dialogue_closed)
	refresh_npcs()


## Sobrescribir para construir el escenario.
func build() -> void:
	pass


func get_npc(npc_id: String) -> Npc:
	return _npcs.get(npc_id)


func get_npcs() -> Array:
	return _npcs.values()


## Indica si un NPC puede pararse en `point` sin estorbar: lejos de los huecos de paso, de las
## pistas y salidas, y de los puestos, posiciones y destinos de los demás NPC.
func is_spot_clear_for_npc(point: Vector3, npc: Npc = null) -> bool:
	for doorway in _doorways:
		if _flat_distance(point, doorway) < NPC_DOORWAY_CLEARANCE:
			return false
	for child in get_children():
		if child is Interactable and _flat_distance(point, (child as Node3D).global_position) < NPC_INTERACTABLE_CLEARANCE:
			return false
	for other: Npc in _npcs.values():
		if other == npc:
			continue
		for occupied: Vector3 in [other.home, other.global_position, other.get_target()]:
			if _flat_distance(point, occupied) < NPC_SPACING:
				return false
	return true


## Indica si un recorrido cruza algún hueco de paso (cambia de estancia o sale a la calle).
func path_crosses_doorway(path: PackedVector3Array) -> bool:
	for doorway in _doorways:
		if LocationNavigation.passes_near(path, doorway, 0.6):
			return true
	return false


## Sincroniza los NPC presentes con sus rutinas para la hora y el punto de la historia actuales.
## Quien ya no debe estar aquí sale andando por la puerta (`Npc.leave`); quien sigue, pero con
## otro tramo, camina hasta su nuevo puesto. Nunca hay dos copias del mismo personaje: el que se
## va sigue en la lista hasta cruzar la salida, y si su rutina lo vuelve a traer, se queda.
func refresh_npcs() -> void:
	if DialogueManager.active:
		return
	var expected := NpcSchedule.get_npcs_at(location_id, GameClock.day, GameClock.minutes)
	for npc_id: String in _npcs.keys():
		if not expected.has(npc_id):
			_send_away(_npcs[npc_id])
	for npc_id in expected:
		var slot := NpcSchedule.get_slot(npc_id, GameClock.day, GameClock.minutes)
		var npc: Npc = _npcs.get(npc_id)
		if npc == null:
			_spawn_npc(npc_id, slot)
		elif npc.current_slot != slot or npc.is_leaving():
			_assign_slot(npc, slot)
		(_npcs[npc_id] as Npc).interaction.refresh_marker()


## Salida por la que un NPC deja el escenario: la que lleva a su destino o, si ninguna lo hace, la
## más cercana. Null si el escenario no tiene salidas.
func get_exit_toward(destination: String, from: Vector3) -> LocationExit:
	var best: LocationExit = null
	var best_score := INF
	for child in get_children():
		if not child is LocationExit:
			continue
		var exit := child as LocationExit
		var score := _flat_distance(from, exit.global_position)
		if exit.target_location != destination:
			score += 1000.0
		if score < best_score:
			best_score = score
			best = exit
	return best


## Punto del suelo junto a una salida desde el que se cruza y hacia dónde: si la salida está junto
## a un hueco de puerta, hacia él.
func get_exit_route(exit: LocationExit) -> Dictionary:
	var point := exit.global_position
	if navigation != null and navigation.is_map_ready():
		point = navigation.closest_point(point)
	point.y = FLOOR_HEIGHT
	var outward := Vector3.ZERO
	var nearest := 1.5
	for doorway in _doorways:
		var distance := _flat_distance(point, doorway)
		if distance < nearest:
			nearest = distance
			outward = Vector3(doorway.x - point.x, 0.0, doorway.z - point.z).normalized()
	return {"point": point, "outward": outward}


## NPC del escenario que intervienen en persona en la escena narrativa en curso.
func get_scene_cast() -> Array[Npc]:
	return _scene_cast


func _spawn_npc(npc_id: String, slot: Dictionary) -> void:
	var npc: Npc = (load(NPC_SCENE) as PackedScene).instantiate()
	add_child(npc)
	npc.setup(npc_id)
	npc.left.connect(_on_npc_left)
	_npcs[npc_id] = npc
	npc.place(self, slot)


## Nuevo tramo en el mismo escenario: el NPC camina hasta su nuevo puesto.
func _assign_slot(npc: Npc, slot: Dictionary) -> void:
	npc.assign(slot)


## Su rutina lo lleva a otro lugar: camina hasta la salida hacia allí y la cruza. Sin salidas (el
## campo de pruebas) desaparece sin más.
func _send_away(npc: Npc) -> void:
	if npc.is_leaving():
		return
	var destination: String = NpcSchedule.get_slot(npc.npc_id, GameClock.day, GameClock.minutes).get("location", "none")
	var exit := get_exit_toward(destination, npc.global_position)
	if exit == null:
		_npcs.erase(npc.npc_id)
		npc.queue_free()
		return
	var route := get_exit_route(exit)
	npc.leave(route["point"], route["outward"])


func _on_npc_left(npc: Npc) -> void:
	if _npcs.get(npc.npc_id) == npc:
		_npcs.erase(npc.npc_id)


func _on_time_changed(_day: int, minutes: int) -> void:
	Atmosphere.apply_time_of_day(self, minutes)
	refresh_npcs()


func _on_flag_set(_flag: String) -> void:
	if is_inside_tree():
		refresh_npcs()


## Empieza una escena narrativa: los personajes que intervienen en ella y están aquí se detienen
## y se vuelven hacia el detective. Así, en la llamada del café, Rosa y el sargento están en la
## sala y miran al inspector mientras le hablan.
func _on_scene_started(scene_id: String) -> void:
	_scene_cast.clear()
	if not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group(PlayerController.GROUP) as Node3D
	for npc_id: String in DialogueManager.get_scene_cast(scene_id):
		var npc := get_npc(npc_id)
		if npc != null and not npc.is_leaving():
			npc.join_scene(player)
			_scene_cast.append(npc)


## En una escena, sólo gesticula quien tiene la palabra.
func _on_line_shown(speaker_id: String, _text: String) -> void:
	for npc in _scene_cast:
		if is_instance_valid(npc):
			npc.set_speaking(npc.npc_id == speaker_id)


func _on_dialogue_closed(_npc_id: String) -> void:
	for npc in _scene_cast:
		if is_instance_valid(npc):
			npc.end_scene()
	_scene_cast.clear()
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


## Muro invisible entre dos puntos del suelo, en coordenadas del escenario. Sirve para cerrar
## huecos concretos sin rodear el escenario con una caja que bloquearía caminos válidos.
func block_passage(from: Vector2, to: Vector2, thickness: float = 0.3) -> void:
	var length := from.distance_to(to)
	if length <= 0.01:
		return
	var middle := (from + to) * 0.5
	var yaw := -atan2(to.y - from.y, to.x - from.x)
	var previous := batch.xform
	batch.xform = Transform3D.IDENTITY
	collider(Vector3(middle.x, BARRIER_HEIGHT * 0.5, middle.y), Vector3(length, BARRIER_HEIGHT, thickness), yaw)
	batch.xform = previous


## Registra un hueco de paso. Los NPC no se detienen en ellos para no cerrarle el camino al
## detective. `InteriorKit.wall` lo hace con cada hueco de pared.
func add_doorway(center: Vector3) -> void:
	_doorways.append(batch.xform * center)


func get_doorways() -> Array[Vector3]:
	return _doorways


## Indica si un punto está dentro del área transitable, con un margen en metros.
func is_inside_play_area(point: Vector3, margin: float = 0.0) -> bool:
	if not play_area.has_area():
		return true
	return play_area.grow(margin).has_point(Vector2(point.x, point.z))


## Indica si alguien puede estar de pie en ese punto: dentro del área, sin obstáculos y con
## suelo debajo. Sirve para validar posiciones guardadas o recuperadas.
func is_standing_point(point: Vector3, radius: float = 0.3) -> bool:
	if not is_inside_play_area(point) or absf(point.y - FLOOR_HEIGHT) > 0.6:
		return false
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point + Vector3.DOWN * 0.8, 1)
	if space.intersect_ray(ray).is_empty():
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, Vector3(point.x, FLOOR_HEIGHT + 1.0, point.z))
	query.collision_mask = 1
	return space.intersect_shape(query, 1).is_empty()


func add_spawn(spawn_id: String, where: Vector3, yaw_degrees: float = 0.0) -> void:
	_spawns[spawn_id] = {"position": batch.xform * where, "yaw": deg_to_rad(yaw_degrees)}


func add_marker(marker_id: String, where: Vector3) -> void:
	_markers[marker_id] = batch.xform * where


## Orienta a quien espera en un marcador hacia un punto, en las mismas coordenadas que el
## marcador: la camarera hacia la clientela, el sargento hacia la puerta.
func face_marker(marker_id: String, toward: Vector3) -> void:
	var direction := batch.xform * toward - get_marker(marker_id)
	if Vector2(direction.x, direction.z).length_squared() > 0.0001:
		_marker_facing[marker_id] = atan2(-direction.x, -direction.z)


## Yaw del modelo con el que se espera en el marcador, o null si da igual hacia dónde mire.
func get_marker_facing(marker_id: String) -> Variant:
	return _marker_facing.get(marker_id)


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
	# Las sombras pedidas se respetan en calidad alta; los niveles inferiores las reducen.
	GraphicsQuality.register_light(light)
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


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
