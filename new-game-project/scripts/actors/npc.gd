class_name Npc
extends CharacterBody3D
## Personaje no jugable. Sus datos vienen de `characters.json` (aspecto y, en «ambient», su
## carácter), su rutina de `schedules.json` y sus conversaciones de `data/dialogues/<id>.json`.
## Camina con la navegación del escenario; los parámetros de su comportamiento están en
## `NpcProfile`. Ver docs/NPC.md.

## IDLE: en reposo, con pausas, miradas y giros. WANDER: paseo corto o visita a un punto.
## PATROL: hacia el siguiente punto de su ronda. RETURN: de vuelta a su puesto.
## DIALOGUE: conversación activa.
enum State { IDLE, WANDER, PATROL, RETURN, DIALOGUE }

signal state_changed(state: State)

## Distancia en planta a la que un destino se da por alcanzado.
const ARRIVE_DISTANCE := 0.3
## Si la navegación termina antes, a esta distancia aún se da por llegado.
const NEAR_ENOUGH := 0.6
## Distancia al puesto a partir de la cual el NPC está fuera de él.
const HOME_TOLERANCE := 0.6
## Segundos sin avanzar antes de dar el camino por bloqueado y recalcularlo.
const BLOCKED_SECONDS := 1.5
## Intentos fallidos seguidos de volver al puesto antes de recolocarlo allí (último recurso).
const RETURN_ATTEMPTS := 3
## Intentos de encontrar un sitio libre para cada paseo.
const WANDER_ATTEMPTS := 8
const GRAVITY := 22.0
## Rapidez con que el cuerpo gira hacia donde quiere mirar.
const TURN_RATE := 5.0

var npc_id := ""
var display_name := ""
var personality := ""
var current_slot: Dictionary = {}
var profile := NpcProfile.new()
var state := State.IDLE
## Puesto del tramo actual: el marcador de su rutina.
var home := Vector3.ZERO
var location: LocationBase
## Rutas pedidas a la navegación desde que apareció. Se piden al decidir un movimiento, nunca en
## cada fotograma; las pruebas lo vigilan.
var path_requests := 0

var _home_yaw: Variant = null
var _patrol: Array[Vector3] = []
var _patrol_yaws: Array = []
var _patrol_index := 0
var _visits: Array[Vector3] = []
var _visit_yaws: Array = []
var _target := Vector3.ZERO
var _target_yaw: Variant = null
var _on_visit := false
var _idle_left := 0.0
var _glance_left := 0.0
var _desired_yaw := 0.0
var _last_position := Vector3.ZERO
var _blocked := 0.0
var _return_failures := 0
var _resume_state := State.IDLE
var _resume_pending := false
var _partner: Node3D
var _rng := RandomNumberGenerator.new()

@onready var model: CharacterModel = $Model
@onready var interaction: NpcInteraction = $Interaction
@onready var agent: NavigationAgent3D = $Navigation
@onready var guard: FallGuard = $FallGuard


func _ready() -> void:
	DialogueManager.closed.connect(_on_dialogue_closed)
	agent.velocity_computed.connect(_on_velocity_computed)
	guard.recovered.connect(_on_recovered)


## Carga identidad y aspecto. Debe llamarse con el nodo ya en el árbol.
func setup(id: String) -> void:
	npc_id = id
	name = "Npc_%s" % id
	var data: Dictionary = GameData.characters.get(id, {})
	display_name = data.get("name", id)
	personality = data.get("personality", "")
	model.build(data.get("model", {}))
	interaction.setup(self)
	# Cada personaje tiene su propia secuencia: no se mueven todos a la vez ni igual.
	_rng.seed = hash(id)


## Coloca al NPC en el puesto de un tramo de su rutina al aparecer, mirando hacia donde toca.
func place(where: LocationBase, slot: Dictionary) -> void:
	_configure(where, slot)
	global_position = home + Vector3.UP * 0.05
	_last_position = global_position
	guard.reset(global_position)
	if _home_yaw != null:
		model.rotation.y = float(_home_yaw)
	_desired_yaw = model.rotation.y
	_target = home
	_target_yaw = _home_yaw
	# Primera pausa escalonada para que no arranquen todos en el mismo instante.
	_enter_idle(_rng.randf_range(0.5, profile.pause_range.y))


## Cambia de tramo sin cambiar de escenario: camina hasta su nuevo puesto.
func assign(slot: Dictionary) -> void:
	_configure(location, slot)
	if state == State.DIALOGUE:
		_resume_state = State.RETURN
		_target = home
		_target_yaw = _home_yaw
		return
	_go(State.RETURN, home, _home_yaw)


## Encara un punto del mundo al instante, sin desplazarse.
func face_towards(point: Vector3) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		model.rotation.y = atan2(-direction.x, -direction.z)
		_desired_yaw = model.rotation.y


## Detiene al personaje para conversar, mirando a su interlocutor.
func begin_talk(with: Node3D) -> void:
	if state != State.DIALOGUE:
		_resume_state = state
	_partner = with
	_stop()
	_set_state(State.DIALOGUE)
	model.set_talking(true)
	model.set_head_turn(0.0)
	if with != null:
		face_towards(with.global_position)


func is_walking() -> bool:
	return state == State.WANDER or state == State.PATROL or state == State.RETURN


## Destino del movimiento en curso, o la posición actual si está quieto.
func get_target() -> Vector3:
	return _target if is_walking() else global_position


func _configure(where: LocationBase, slot: Dictionary) -> void:
	location = where
	current_slot = slot
	profile = NpcProfile.build(GameData.characters.get(npc_id, {}).get("ambient", {}), slot)
	var marker: String = slot.get("marker", "")
	home = where.get_marker(marker)
	_home_yaw = where.get_marker_facing(marker)
	_patrol.clear()
	_patrol_yaws.clear()
	for marker_id: String in slot.get("patrol", []):
		_patrol.append(where.get_marker(marker_id))
		_patrol_yaws.append(where.get_marker_facing(marker_id))
	# La ronda empieza en su puesto: el primer destino es el punto siguiente.
	_patrol_index = maxi(_patrol.find(home), 0)
	_visits.clear()
	_visit_yaws.clear()
	for marker_id: String in slot.get("visits", []):
		_visits.append(where.get_marker(marker_id))
		_visit_yaws.append(where.get_marker_facing(marker_id))
	_on_visit = false
	_return_failures = 0
	model.set_head_tilt(profile.head_tilt)
	agent.max_speed = profile.walk_speed
	if where.navigation != null:
		agent.set_navigation_map(where.navigation.get_map())
	guard.location = where
	guard.fallback = home


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			_update_idle(delta)
		State.WANDER, State.PATROL, State.RETURN:
			_update_walk(delta)
	model.rotation.y = lerp_angle(model.rotation.y, _desired_yaw, 1.0 - exp(-TURN_RATE * delta))
	# Quieto en el suelo no hace falta mover el cuerpo: sólo si está en el aire (al aparecer).
	if not is_walking() and not is_on_floor():
		velocity = Vector3(0.0, velocity.y - GRAVITY * delta, 0.0)
		move_and_slide()


# --- Reposo -----------------------------------------------------------------------------------

func _enter_idle(seconds: float) -> void:
	_stop()
	_idle_left = seconds
	_glance_left = profile.random_glance(_rng) * 0.5
	_set_state(State.IDLE)


func _update_idle(delta: float) -> void:
	_idle_left -= delta
	_glance_left -= delta
	if _glance_left <= 0.0:
		_glance_left = profile.random_glance(_rng)
		_glance()
	if _idle_left <= 0.0:
		_decide()


## Movimiento sutil en reposo: mirar al detective si está cerca, girar la cabeza o cambiar un
## poco de orientación alrededor de la que corresponde a su sitio.
func _glance() -> void:
	var player := _find_player()
	if player != null and _flat_distance(player.global_position, global_position) < profile.notice_distance and _rng.randf() < 0.5:
		_look_at_point(player.global_position)
		return
	var roll := _rng.randf()
	if roll < 0.45:
		model.set_head_turn(_rng.randf_range(-0.6, 0.6))
	elif roll < 0.7:
		model.set_head_turn(0.0)
	else:
		model.set_head_turn(0.0)
		_desired_yaw = _rest_yaw() + _rng.randf_range(-0.7, 0.7)


## Gira la cabeza hacia un punto y, si queda muy de lado, también el cuerpo.
func _look_at_point(point: Vector3) -> void:
	var direction := point - global_position
	if Vector2(direction.x, direction.z).length_squared() < 0.01:
		return
	var yaw := atan2(-direction.x, -direction.z)
	var offset := wrapf(yaw - model.rotation.y, -PI, PI)
	if absf(offset) > 0.8:
		_desired_yaw = yaw - signf(offset) * 0.3
		offset = signf(offset) * 0.3
	model.set_head_turn(offset)


## Orientación natural en el sitio actual: la del marcador si la tiene.
func _rest_yaw() -> float:
	if _target_yaw != null and _flat_distance(global_position, _target) < HOME_TOLERANCE:
		return float(_target_yaw)
	if _home_yaw != null and _flat_distance(global_position, home) < HOME_TOLERANCE:
		return float(_home_yaw)
	return _desired_yaw


## Qué hacer al terminar una pausa, según el modo de su tramo.
func _decide() -> void:
	if location == null or location.navigation == null or not location.navigation.is_map_ready():
		_enter_idle(0.5)
		return
	if _resume_pending:
		_resume_pending = false
		_resume()
		return
	if _on_visit:
		_on_visit = false
		_go(State.RETURN, home, _home_yaw)
		return
	if profile.mode == NpcProfile.Mode.PATROL and _patrol.size() >= 2:
		_patrol_index = (_patrol_index + 1) % _patrol.size()
		_go(State.PATROL, _patrol[_patrol_index], _patrol_yaws[_patrol_index])
		return
	if profile.mode == NpcProfile.Mode.WANDER:
		if not _visits.is_empty() and _rng.randf() < profile.visit_chance and not _is_needed_for_story():
			var index := _rng.randi() % _visits.size()
			if location.is_spot_clear_for_npc(_visits[index], self):
				_on_visit = true
				_go(State.WANDER, _visits[index], _visit_yaws[index])
				return
		if _rng.randf() < profile.wander_chance:
			var spot: Variant = _pick_wander_spot()
			if spot != null:
				_go(State.WANDER, spot as Vector3, null)
				return
	if _flat_distance(global_position, home) > HOME_TOLERANCE:
		_go(State.RETURN, home, _home_yaw)
		return
	_enter_idle(profile.random_pause(_rng))


## Con preguntas pendientes, la investigación lo necesita a mano: no se va de visita.
func _is_needed_for_story() -> bool:
	return DialogueManager.has_new_topics(npc_id)


## Busca un sitio libre a poca distancia de su puesto, en la misma estancia y con camino seguro.
func _pick_wander_spot() -> Variant:
	var navigation := location.navigation
	for attempt in WANDER_ATTEMPTS:
		var angle := _rng.randf() * TAU
		var distance := profile.wander_radius * sqrt(_rng.randf_range(0.15, 1.0))
		var candidate := home + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if not navigation.is_on_floor_mesh(candidate, 0.15):
			continue
		if not location.is_spot_clear_for_npc(candidate, self):
			continue
		path_requests += 1
		var path := navigation.find_path(global_position, candidate)
		if path.is_empty() or _flat_distance(path[path.size() - 1], candidate) > 0.3:
			continue
		# Un paseo corto no da rodeos ni cruza puertas: no cambia de estancia sin motivo.
		if LocationNavigation.path_length(path) > profile.wander_radius * 2.5 + 1.0:
			continue
		if location.path_crosses_doorway(path):
			continue
		return Vector3(candidate.x, home.y, candidate.z)
	return null


# --- Movimiento -------------------------------------------------------------------------------

func _go(next_state: State, target: Vector3, facing: Variant) -> void:
	_target = target
	_target_yaw = facing
	_blocked = 0.0
	_last_position = global_position
	path_requests += 1
	agent.target_position = target
	model.set_head_turn(0.0)
	_set_state(next_state)


func _update_walk(delta: float) -> void:
	var remaining := _flat_distance(global_position, _target)
	if remaining <= ARRIVE_DISTANCE:
		_arrive()
		return
	if agent.is_navigation_finished():
		# La navegación no acerca más: o casi ha llegado o no hay camino hasta el destino.
		if remaining <= NEAR_ENOUGH:
			_arrive()
		else:
			_on_blocked()
		return
	var direction := agent.get_next_path_position() - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		agent.velocity = direction.normalized() * profile.walk_speed
	_count_blocked(delta)


## Mueve el cuerpo con la velocidad que deja la evitación de otros personajes.
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if not is_walking() or not can_process():
		return
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * get_physics_process_delta_time()
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length_squared() > 0.04:
		_desired_yaw = atan2(-flat.x, -flat.y)
	model.set_motion(flat.length() / 6.0)


func _count_blocked(delta: float) -> void:
	var moved := _flat_distance(global_position, _last_position)
	_last_position = global_position
	if moved < profile.walk_speed * delta * 0.25:
		_blocked += delta
	else:
		_blocked = maxf(_blocked - delta, 0.0)
	if _blocked >= BLOCKED_SECONDS:
		_on_blocked()


func _arrive() -> void:
	if state == State.RETURN:
		_return_failures = 0
	if _target_yaw != null:
		_desired_yaw = float(_target_yaw)
	_enter_idle(profile.random_pause(_rng))


## Sin camino o con el paso cortado: se detiene, espera y vuelve a decidir desde donde está.
func _on_blocked() -> void:
	_blocked = 0.0
	if state == State.RETURN:
		_return_failures += 1
		if _return_failures >= RETURN_ATTEMPTS:
			_relocate_home()
			return
	_on_visit = false
	_enter_idle(_rng.randf_range(1.0, 2.5))


## Último recurso si tras varios intentos no hay forma de volver andando a su puesto.
func _relocate_home() -> void:
	push_warning("%s no encuentra camino a su puesto; se le recoloca." % npc_id)
	_return_failures = 0
	global_position = home + Vector3.UP * 0.05
	guard.reset(global_position)
	if _home_yaw != null:
		_desired_yaw = float(_home_yaw)
	_enter_idle(profile.random_pause(_rng))


func _stop() -> void:
	velocity = Vector3(0.0, velocity.y, 0.0)
	agent.velocity = Vector3.ZERO
	model.set_motion(0.0)


# --- Conversación -----------------------------------------------------------------------------

## Retoma lo que hacía antes de la conversación.
func _resume() -> void:
	match _resume_state:
		State.WANDER, State.PATROL, State.RETURN:
			_go(_resume_state, _target, _target_yaw)
		_:
			_enter_idle(_rng.randf_range(1.0, profile.pause_range.x))


func _on_dialogue_closed(finished_npc: String) -> void:
	if finished_npc != npc_id or state != State.DIALOGUE:
		return
	model.set_talking(false)
	interaction.refresh_marker()
	# Recupera poco a poco lo que hacía: primero una pausa, todavía pendiente del detective.
	_resume_pending = true
	_enter_idle(profile.random_talk_pause(_rng))
	if _partner != null and is_instance_valid(_partner):
		_look_at_point(_partner.global_position)


func _on_recovered(_from: Vector3, _to: Vector3) -> void:
	_on_visit = false
	_resume_pending = false
	_enter_idle(1.0)


func _find_player() -> Node3D:
	return get_tree().get_first_node_in_group(PlayerController.GROUP) as Node3D


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(state)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
