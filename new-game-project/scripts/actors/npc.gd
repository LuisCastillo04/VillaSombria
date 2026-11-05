class_name Npc
extends CharacterBody3D
## Personaje no jugable. Sus datos vienen de `characters.json`, su rutina de
## `schedules.json` y sus conversaciones de `data/dialogues/<id>.json`.

enum State { IDLE, WALKING, WAITING, TALKING }

const ARRIVE_DISTANCE := 0.2
const STUCK_SECONDS := 4.0

@export var walk_speed := 1.8
@export var wait_seconds := 5.0

var npc_id := ""
var display_name := ""
var personality := ""
var state := State.IDLE
var current_slot: Dictionary = {}

var _route: Array[Vector3] = []
var _route_index := 0
var _wait_left := 0.0
var _stuck_time := 0.0
var _state_before_talk := State.IDLE

@onready var model: CharacterModel = $Model
@onready var interaction: NpcInteraction = $Interaction


func _ready() -> void:
	DialogueManager.closed.connect(_on_dialogue_closed)


## Carga identidad y aspecto. Debe llamarse con el nodo ya en el árbol.
func setup(id: String) -> void:
	npc_id = id
	name = "Npc_%s" % id
	var data: Dictionary = GameData.characters.get(id, {})
	display_name = data.get("name", id)
	personality = data.get("personality", "")
	model.build(data.get("model", {}))
	interaction.setup(self)


## Recorre los puntos en bucle, esperando en cada uno. Con un solo punto se queda allí.
func set_route(points: Array[Vector3]) -> void:
	_route = points
	_route_index = 0
	if _route.size() <= 1:
		state = State.WALKING if _route.size() == 1 and _distance_to(_route[0]) > ARRIVE_DISTANCE else State.IDLE
	else:
		state = State.WALKING


## Encara un punto del mundo sin desplazarse.
func face_towards(point: Vector3) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		model.rotation.y = atan2(-direction.x, -direction.z)


## Detiene al personaje para conversar.
func begin_talk(with: Node3D) -> void:
	if state != State.TALKING:
		_state_before_talk = state
	state = State.TALKING
	velocity = Vector3.ZERO
	model.set_motion(0.0)
	model.set_talking(true)
	face_towards(with.global_position)


func _physics_process(delta: float) -> void:
	match state:
		State.WALKING:
			_walk(delta)
		State.WAITING:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_route_index = (_route_index + 1) % _route.size()
				state = State.WALKING
		_:
			model.set_motion(0.0)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
		move_and_slide()


func _walk(delta: float) -> void:
	if _route.is_empty():
		state = State.IDLE
		return
	var target := _route[_route_index]
	if _distance_to(target) <= ARRIVE_DISTANCE:
		_on_arrived()
		return
	var direction := target - global_position
	direction.y = 0.0
	direction = direction.normalized()
	var before := global_position
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	velocity.y = -0.5 if is_on_floor() else velocity.y
	move_and_slide()
	face_towards(global_position + direction)
	model.set_motion(walk_speed / 6.0)
	# Sin navegación un obstáculo imprevisto podría atascarlo: si no avanza, salta al destino.
	if before.distance_to(global_position) < walk_speed * delta * 0.2:
		_stuck_time += delta
		if _stuck_time >= STUCK_SECONDS:
			global_position = Vector3(target.x, global_position.y, target.z)
			_stuck_time = 0.0
	else:
		_stuck_time = 0.0


func _on_arrived() -> void:
	velocity = Vector3.ZERO
	model.set_motion(0.0)
	_stuck_time = 0.0
	if _route.size() > 1:
		state = State.WAITING
		_wait_left = wait_seconds
	else:
		state = State.IDLE


func _distance_to(point: Vector3) -> float:
	return Vector2(global_position.x, global_position.z).distance_to(Vector2(point.x, point.z))


func _on_dialogue_closed(finished_npc: String) -> void:
	if finished_npc != npc_id or state != State.TALKING:
		return
	model.set_talking(false)
	state = _state_before_talk
	interaction.refresh_marker()
