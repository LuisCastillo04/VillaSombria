extends TestCase
## Límites de los escenarios. Todo lo que el detective puede alcanzar tiene suelo debajo y queda
## dentro del área transitable, y las puertas a la calle se usan con E, no cruzándolas.

const LOCATIONS := ["plaza", "cafe", "mansion", "archivo", "estacion", "test_ground"]
const GRID_STEP := 0.4
const PLAYER_RADIUS := 0.3
## Tope de celdas del recorrido: muy por encima del escenario más grande cerrado.
const MAX_CELLS := 20000
## Puertas a la calle: punto de partida delante del umbral y línea de la pared (eje Z).
const STREET_DOORS := {
	"cafe": {"start": Vector3(0.0, 0.1, 4.4), "wall": 6.0},
	"mansion": {"start": Vector3(0.5, 0.1, 7.2), "wall": 9.0},
	"archivo": {"start": Vector3(0.0, 0.1, 5.4), "wall": 7.0},
}

var game: Game


func after_each() -> void:
	for action: String in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(action)
	DialogueManager.close()
	GameState.clear_player_locks()
	if game != null:
		game.queue_free()
		game = null
	await get_tree().process_frame


func _instantiate(location_id: String) -> LocationBase:
	var scene: PackedScene = load("res://scenes/world/locations/%s.tscn" % location_id)
	var location: LocationBase = scene.instantiate()
	add_child(location)
	return location


## El fallo original: por la puerta de la calle (o por la esquina del andén) se llegaba a un
## suelo invisible que terminaba en el vacío.
func test_every_reachable_point_has_floor_inside_the_play_area() -> void:
	for location_id: String in LOCATIONS:
		var location := _instantiate(location_id)
		await wait_physics_frames(3)
		check(location.play_area.has_area(), "%s debe declarar su área transitable" % location_id)
		for spawn_id: String in location._spawns:
			var start: Vector3 = location.get_spawn(spawn_id)["position"]
			var result := _explore(location, start)
			check(int(result["cells"]) < MAX_CELLS, "%s/%s: el recorrido no termina, el escenario está abierto" % [location_id, spawn_id])
			var voids: Array = result["void"]
			check(voids.is_empty(), "%s/%s: se llega a %d puntos sin suelo, como %s" % [location_id, spawn_id, voids.size(), str(voids.slice(0, 3))])
			var outside: Array = result["outside"]
			check(outside.is_empty(), "%s/%s: se sale del área transitable por %s" % [location_id, spawn_id, str(outside.slice(0, 3))])
		location.queue_free()
		await get_tree().process_frame


## Con las teclas de verdad: andar contra la puerta de la calle deja al detective en el umbral,
## sin cruzarlo, y la salida sigue enfocada para usarla con E.
func test_walking_into_a_street_door_stops_at_the_threshold() -> void:
	GameState.set_flag("llamada_atendida")
	game = await make_game()
	for location_id: String in STREET_DOORS:
		var door: Dictionary = STREET_DOORS[location_id]
		await game.go_to(location_id, "desde_plaza")
		await wait_physics_frames(3)
		GameState.clear_player_locks()
		game.player.teleport(door["start"], PI)
		# S y A a la vez llevan hacia +Z en el mundo con la cámara a 45 grados: hacia la calle.
		for action: String in ["move_back", "move_left", "sprint"]:
			Input.action_press(action)
		await wait_physics_frames(150)
		for action: String in ["move_back", "move_left", "sprint"]:
			Input.action_release(action)
		await wait_physics_frames(2)
		var where := game.player.global_position
		check(where.z < float(door["wall"]) + 0.1, "%s: el detective cruza la puerta (z=%.2f)" % [location_id, where.z])
		check(where.z > float(door["wall"]) - 0.8, "%s: el detective debe llegar al umbral (z=%.2f)" % [location_id, where.z])
		check(game.player.is_on_floor(), "%s: el detective sigue pisando suelo" % location_id)
		var focused := game.player.detector.get_focused()
		check(focused is LocationExit, "%s: la salida debe quedar enfocada en el umbral" % location_id)


## Los huecos entre estancias siguen abiertos: el detective cruza la mansión por sus puertas.
func test_inner_doorways_stay_open() -> void:
	var location := _instantiate("mansion")
	await wait_physics_frames(3)
	check(location.get_doorways().size() == 8, "la mansión registra sus huecos de paso")
	for doorway: Vector3 in location.get_doorways():
		if absf(doorway.z - 9.0) < 0.1:
			continue
		check(location.is_standing_point(doorway), "se puede estar en el hueco de paso %s" % str(doorway))
	location.queue_free()
	await get_tree().process_frame


func _explore(location: LocationBase, start: Vector3) -> Dictionary:
	var origin := Vector2i(roundi(start.x / GRID_STEP), roundi(start.z / GRID_STEP))
	var visited := {origin: true}
	var frontier: Array[Vector2i] = [origin]
	var voids: Array = []
	var outside: Array = []
	while not frontier.is_empty() and visited.size() < MAX_CELLS:
		var cell: Vector2i = frontier.pop_back()
		var point := Vector3(float(cell.x) * GRID_STEP, 0.1, float(cell.y) * GRID_STEP)
		if not _has_floor(location, point):
			voids.append(Vector2(point.x, point.z))
			continue
		if not location.is_inside_play_area(point, PLAYER_RADIUS):
			outside.append(Vector2(point.x, point.z))
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + offset
			if visited.has(next):
				continue
			if _is_free(location, Vector3(float(next.x) * GRID_STEP, 0.1, float(next.y) * GRID_STEP)):
				visited[next] = true
				frontier.append(next)
	return {"cells": visited.size(), "void": voids, "outside": outside}


func _has_floor(location: LocationBase, point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.4, point + Vector3.DOWN * 1.0, 1)
	return not location.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _is_free(location: LocationBase, point: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.0)
	query.collision_mask = 1
	return location.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
