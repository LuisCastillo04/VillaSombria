extends TestCase
## Integridad de los escenarios: geometría agrupada, salidas, puntos de aparición y
## alcance real de cada elemento con el que el jugador debe interactuar.

const LOCATIONS := ["plaza", "cafe", "mansion", "archivo", "estacion"]
const GRID_STEP := 0.4
const PLAYER_RADIUS := 0.3
const REACH := 2.0


func _instantiate(location_id: String) -> LocationBase:
	var scene: PackedScene = load("res://scenes/world/locations/%s.tscn" % location_id)
	var location: LocationBase = scene.instantiate()
	add_child(location)
	return location


func test_geometry_is_batched() -> void:
	for location_id: String in LOCATIONS:
		var location := _instantiate(location_id)
		var meshes := 0
		for child in location.get_children():
			if child is MeshInstance3D:
				meshes += 1
		check(meshes <= 3, "%s debe dibujarse con un máximo de 3 mallas, tiene %d" % [location_id, meshes])
		location.queue_free()


func test_spawns_are_not_inside_obstacles() -> void:
	for location_id: String in LOCATIONS:
		var location := _instantiate(location_id)
		await wait_physics_frames(3)
		for spawn_id: String in location._spawns:
			var where: Vector3 = location.get_spawn(spawn_id)["position"]
			check(_is_free(location, where), "%s/%s aparece dentro de un obstáculo" % [location_id, spawn_id])
		location.queue_free()


func test_exits_lead_to_real_spawns() -> void:
	for location_id: String in LOCATIONS:
		var location := _instantiate(location_id)
		var targets: Array[LocationExit] = []
		for child in location.get_children():
			if child is LocationExit:
				targets.append(child)
		check(not targets.is_empty(), location_id + " necesita una salida")
		for exit_node in targets:
			check(GameData.locations.has(exit_node.target_location), "destino desconocido: " + exit_node.target_location)
			var target := _instantiate(exit_node.target_location)
			check(target.has_spawn(exit_node.target_spawn), "%s no tiene el punto %s" % [exit_node.target_location, exit_node.target_spawn])
			target.queue_free()
		location.queue_free()


func test_plaza_has_an_exit_for_every_destination() -> void:
	var location := _instantiate("plaza")
	var destinations: Array[String] = []
	for child in location.get_children():
		if child is LocationExit:
			destinations.append((child as LocationExit).target_location)
	for expected: String in ["cafe", "mansion", "archivo", "estacion"]:
		check(destinations.has(expected), "falta la salida hacia " + expected)
	location.queue_free()


func test_schedule_markers_exist() -> void:
	var loaded := {}
	for location_id: String in LOCATIONS:
		loaded[location_id] = _instantiate(location_id)
	for npc_id: String in GameData.schedules:
		for slot: Dictionary in GameData.schedules[npc_id]:
			var location_id: String = slot["location"]
			if location_id == "none":
				continue
			var location: LocationBase = loaded[location_id]
			check(location.has_marker(slot["marker"]), "%s: falta el marcador %s en %s" % [npc_id, slot["marker"], location_id])
			for marker_id: String in slot.get("patrol", []):
				check(location.has_marker(marker_id), "%s: falta el punto de ruta %s" % [npc_id, marker_id])
	for location_id: String in loaded:
		(loaded[location_id] as LocationBase).queue_free()


func test_every_clue_can_be_obtained() -> void:
	var obtainable := {}
	for location_id: String in LOCATIONS:
		var location := _instantiate(location_id)
		for child in location.get_children():
			if child is ClueObject:
				var clue_id: String = (child as ClueObject).clue_id
				check(GameData.clues.has(clue_id), "objeto con pista inexistente: " + clue_id)
				obtainable[clue_id] = true
		location.queue_free()
	var scan := func(block: Dictionary) -> void:
		for clue_id: String in block.get("clues", []):
			obtainable[clue_id] = true
	var effects_of := func(value: Variant, visitor: Callable, walker: Callable) -> void:
		if value is Dictionary:
			if value.has("effects"):
				visitor.call(value["effects"])
			for key: String in value:
				walker.call(value[key], visitor, walker)
		elif value is Array:
			for item: Variant in value:
				walker.call(item, visitor, walker)
	for character_id: String in GameData.characters:
		if character_id != "detective":
			effects_of.call(GameData.get_dialogue(character_id), scan, effects_of)
	effects_of.call(GameData.scenes, scan, effects_of)
	for clue_id: String in GameData.clues:
		check(obtainable.has(clue_id), "nadie concede la pista " + clue_id)


## Recorre cada escenario con colisiones reales y comprueba que el detective pueda
## llegar hasta todo aquello con lo que debe interactuar.
func test_everything_is_reachable() -> void:
	for location_id: String in LOCATIONS:
		var location := _instantiate(location_id)
		await wait_physics_frames(3)
		var start: Vector3 = location._spawns.values()[0]["position"]
		var reachable := _flood_fill(location, start)
		check(reachable.size() > 50, "%s: área transitable demasiado pequeña" % location_id)
		for spawn_id: String in location._spawns:
			var spawn: Vector3 = location.get_spawn(spawn_id)["position"]
			check(_is_near(reachable, spawn, REACH), "%s: inalcanzable el punto %s" % [location_id, spawn_id])
		for child in location.get_children():
			if child is Interactable:
				check(_is_near(reachable, (child as Node3D).global_position, REACH), "%s: inalcanzable %s" % [location_id, (child as Interactable).get_prompt()])
		for marker_id: String in location.get_marker_ids():
			check(_is_near(reachable, location.get_marker(marker_id), REACH), "%s: inalcanzable el marcador %s" % [location_id, marker_id])
		location.queue_free()


func _flood_fill(location: LocationBase, start: Vector3) -> Dictionary:
	var origin := Vector2i(roundi(start.x / GRID_STEP), roundi(start.z / GRID_STEP))
	var visited := {origin: true}
	var frontier: Array[Vector2i] = [origin]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + offset
			if visited.has(next) or absi(next.x) > 150 or absi(next.y) > 150:
				continue
			if _is_free(location, Vector3(float(next.x) * GRID_STEP, 0.1, float(next.y) * GRID_STEP)):
				visited[next] = true
				frontier.append(next)
	return visited


func _is_near(reachable: Dictionary, point: Vector3, distance: float) -> bool:
	var cell := Vector2i(roundi(point.x / GRID_STEP), roundi(point.z / GRID_STEP))
	var radius := int(ceil(distance / GRID_STEP))
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			if reachable.has(cell + Vector2i(x, y)) and Vector2(x, y).length() * GRID_STEP <= distance:
				return true
	return false


func _is_free(location: LocationBase, where: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_RADIUS
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, where + Vector3.UP * 1.0)
	query.collision_mask = 1
	return location.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
