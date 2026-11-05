extends TestCase
## Integridad de los escenarios: geometría agrupada, salidas y puntos de aparición.

const LOCATIONS := ["plaza"]


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
		var space := location.get_world_3d().direct_space_state
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.3
		capsule.height = 1.8
		for spawn_id: String in location._spawns:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			var where: Vector3 = location.get_spawn(spawn_id)["position"]
			query.transform = Transform3D(Basis.IDENTITY, where + Vector3.UP * 1.0)
			query.collision_mask = 1
			var hits := space.intersect_shape(query)
			check(hits.is_empty(), "%s/%s aparece dentro de un obstáculo" % [location_id, spawn_id])
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
