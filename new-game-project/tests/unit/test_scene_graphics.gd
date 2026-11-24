extends TestCase
## Correcciones gráficas de los escenarios: sin z-fighting en las puertas del archivo y del café,
## en la taquilla, en las estanterías ni en la sala de la mansión; el Banco Valdés cerrado (puerta
## decorativa con colisión, aviso, valla y la tapia terminada en su esquina); árboles en alcorques;
## sillón de cara al sofá, y parterres que no cortan ningún camino. Los solapes se buscan con la
## cámara real y los modelos de Blender (`coplanar_faces.gd`); cada escenario se carga solo y activo.

const CoplanarFaces := preload("res://tests/unit/coplanar_faces.gd")
const PLAZA := preload("res://scripts/world/locations/plaza.gd")
const STATION := preload("res://scripts/world/locations/estacion.gd")
const MANSION := preload("res://scripts/world/locations/mansion.gd")
## Capa de la malla de visibilidad, fuera de las que usa el juego.
const PROBE_LAYER := 1 << 19

var _loaded: Array[LocationBase] = []


func before_each() -> void:
	GameState.reset()
	GameClock.reset()


func after_each() -> void:
	for location in _loaded:
		if is_instance_valid(location):
			location.queue_free()
	_loaded.clear()
	await get_tree().process_frame


func test_doors_and_ticket_office_do_not_flicker() -> void:
	var plaza := await _load("plaza")
	var shown := await _visible_overlaps(plaza)
	check_equal(_inside(shown, AABB(Vector3(7.8, -0.1, -14.2), Vector3(3.4, 3.8, 1.2))).size(), 0, "la puerta del archivo no comparte plano con el zócalo")
	check_equal(_inside(shown, AABB(Vector3(-7.4, -0.1, -14.2), Vector3(2.6, 3.0, 1.2))).size(), 0, "ni la del café")
	# Las puertas siguen siendo salidas, en su sitio.
	for target: String in ["archivo", "cafe"]:
		var exit := _find(plaza, func(node: Node) -> bool: return node is LocationExit and (node as LocationExit).target_location == target)
		check(exit != null, "la puerta de %s sigue llevando dentro" % target)
	var station := await _load("estacion")
	var station_shown := await _visible_overlaps(station)
	check_equal(_inside(station_shown, AABB(Vector3(-11.2, -0.1, -0.5), Vector3(1.2, 4.8, 5.0))).size(), 0, "ni la taquilla de la estación")


func test_shelves_books_and_salon_do_not_flicker() -> void:
	# Cada variante de estantería por separado, con todas sus caras (también las ocultas).
	for size: Vector2 in [Vector2(3.2, 2.6), Vector2(4.0, 3.0), Vector2(3.0, 2.5), Vector2(3.0, 2.0)]:
		var batch := MeshBatcher.new()
		InteriorKit._bookshelf_mesh(batch, size.x, size.y)
		check_equal(CoplanarFaces.find(batch).size(), 0, "estantería %s: ninguna cara comparte plano con otra" % size)
		var top := -INF
		for vertex: Vector3 in (batch._buffers[MeshBatcher.Layer.OPAQUE] as MeshBatcher.Buffers).vertices:
			top = maxf(top, vertex.y)
		check(top <= size.y + 0.001, "estantería %s: ningún libro sobresale por arriba" % size)
	var mansion := await _load("mansion")
	var shown := await _visible_overlaps(mansion)
	for shelf: AABB in [AABB(Vector3(6.4, -0.1, -9.05), Vector3(7.4, 2.8, 0.75)), AABB(Vector3(13.1, -0.1, 1.3), Vector3(0.8, 2.2, 3.4))]:
		check_equal(_inside(shown, shelf).size(), 0, "las estanterías de la mansión no parpadean (%s)" % shelf)
	check_equal(_inside(shown, AABB(Vector3(-2.0, -0.1, -6.0), Vector3(5.8, 1.3, 1.7))).size(), 0, "ni el sofá ni el sillón")
	var archive := await _load("archivo")
	var archive_shown := await _visible_overlaps(archive)
	for shelf: AABB in [AABB(Vector3(-5.2, -0.1, -7.2), Vector3(10.4, 3.2, 0.8)), AABB(Vector3(6.3, -0.1, -2.6), Vector3(3.4, 2.7, 8.6))]:
		check_equal(_inside(archive_shown, shelf).size(), 0, "las estanterías del archivo no parpadean (%s)" % shelf)


func test_salon_armchair_faces_the_sofa() -> void:
	var mansion := await _load("mansion")
	var armchair: Vector3 = MANSION.SALON_ARMCHAIR
	var sofa: Vector3 = MANSION.SALON_SOFA
	var table: Vector3 = MANSION.SALON_TABLE
	var facing := Basis(Vector3.UP, deg_to_rad(MANSION.SALON_ARMCHAIR_YAW)) * Vector3.BACK
	check(facing.dot((sofa - armchair).normalized()) > 0.99, "el sillón mira de frente al sofá")
	check(absf(armchair.z - sofa.z) < 0.01 and absf(table.z - sofa.z) < 0.01, "sofá, mesa y sillón están en línea")
	check_equal(_hits(mansion, armchair + Vector3.UP * 0.55, Vector3(0.9, 1.0, 0.85), MANSION.SALON_ARMCHAIR_YAW), 1, "el sillón tiene colisión y no se mete en la mesa ni en otro mueble")
	var middle := (armchair + table) * 0.5
	check(mansion.is_standing_point(Vector3(middle.x, 0.0, middle.z)), "entre la mesa y el sillón cabe el detective")
	for marker: String in ["salon_sofa", "salon_chimenea", "salon_ventana", "salon_este"]:
		check(mansion.is_standing_point(mansion.get_marker(marker)), "el puesto %s sigue libre" % marker)
	var path := mansion.navigation.find_path(Vector3(0.5, 0.0, -0.4), mansion.get_marker("salon_este"))
	check(path.size() > 1 and _flat_distance(path[path.size() - 1], mansion.get_marker("salon_este")) < 0.3, "se rodea el sillón para llegar al lado este")


func test_bank_is_closed_for_maintenance() -> void:
	var plaza := await _load("plaza")
	var shown := await _visible_overlaps(plaza)
	check_equal(_inside(shown, AABB(Vector3(-14.4, -0.1, 3.8), Vector3(2.6, 6.6, 10.4))).size(), 0, "nada parpadea en la fachada del banco")
	var origin: Vector3 = PLAZA.BANK_ORIGIN
	var facade := Basis(Vector3.UP, PI * 0.5)
	var door := origin + facade * Vector3(0.0, 0.0, 0.4)
	# La puerta es decorativa: ninguna salida ni interacción cerca y no se puede atravesar.
	var near := _find(plaza, func(node: Node) -> bool: return node is Interactable and _flat_distance((node as Node3D).global_position, origin) < 4.0)
	check(near == null, "ninguna salida ni interacción en la puerta del banco")
	check(not plaza.is_standing_point(door), "el marco y el escalón tienen colisión")
	check(_gap(plaza, door + Vector3(1.5, 1.5, 0.0), Vector3.LEFT) < 1.75, "al acercarse de frente, la puerta detiene al detective")
	var barrier := origin + facade * PLAZA.BANK_BARRIER
	check_equal(_hits(plaza, barrier + Vector3.UP * 0.5, Vector3(0.3, 0.6, 0.3)), 1, "la valla de obras tiene colisión")
	check(plaza.is_standing_point(plaza.get_marker("puerta_banco")), "el puesto delante del banco queda fuera de la valla")
	# La tapia ya no está delante de la fachada: termina en la esquina del banco.
	for z: float in [4.5, 6.0, 7.5]:
		check_equal(_hits(plaza, Vector3(-13.9, 1.0, z), Vector3(0.1, 1.4, 0.4)), 0, "nada tapa la planta baja del banco en Z = %.1f" % z)
	check_equal(_hits(plaza, Vector3(-13.85, 1.0, 3.8), Vector3(0.2, 1.0, 0.3)), 1, "la tapia llega hasta la esquina del banco")
	check(_hits(plaza, Vector3(-14.0, 1.7, -0.6), Vector3(0.3, 1.0, 0.3)) >= 1, "y termina en el pilar de la verja")
	var labels := plaza.find_children("", "Label3D", false, false)
	var notice := labels.filter(func(label: Label3D) -> bool: return label.text.begins_with("CERRADO POR"))
	check_equal(notice.size(), 1, "el aviso de cierre está sobre la puerta")
	if notice.size() == 1:
		check(_flat_distance((notice[0] as Label3D).global_position, origin) < 0.3, "centrado sobre ella")
	var barriers := ModelCatalog.MODELS.has("valla_obras")
	check(barriers, "la valla de obras tiene su modelo")


func test_plaza_trees_grow_from_tree_pits() -> void:
	var plaza := await _load("plaza")
	var shown := await _visible_overlaps(plaza)
	for tree: Dictionary in PLAZA.PIT_TREES:
		var at: Vector3 = tree["at"]
		check(at.y == 0.0, "el tronco arranca del suelo (%s)" % at)
		check(PropsKit.TREE_PIT_SOIL > 0.01 + 0.02 and PropsKit.TREE_PIT_SOIL < PropsKit.TREE_PIT_CURB_HEIGHT, "la tierra queda sobre el empedrado y bajo el bordillo")
		var half := PropsKit.TREE_PIT_SIZE * 0.5
		check_equal(_inside(shown, AABB(at - Vector3(half + 0.1, 0.1, half + 0.1), Vector3(half * 2.0 + 0.2, 4.6, half * 2.0 + 0.2))).size(), 0, "el alcorque de %s no parpadea" % at)
		check(not plaza.is_standing_point(at + Vector3(half - 0.2, 0.0, 0.0)), "el alcorque de %s no se pisa" % at)
		check(plaza.is_standing_point(at + Vector3(half + 0.4, 0.0, 0.0)), "pero se puede rodear")
		check(not plaza.navigation.is_on_floor_mesh(at), "ni es suelo para los NPC")
	var drawn := TownMapArt.PLAZA_TREES.filter(func(tree: Dictionary) -> bool: return tree.get("pit", false))
	check_equal(drawn.size(), PLAZA.PIT_TREES.size(), "el mapa dibuja los alcorques")


func test_shrub_beds_rest_on_the_ground_and_keep_paths_clear() -> void:
	for location_id: String in ["plaza", "estacion"]:
		var location := await _load(location_id)
		var shown := await _visible_overlaps(location)
		var beds: Array = PLAZA.SHRUB_BEDS if location_id == "plaza" else STATION.SHRUB_BEDS
		for bed: Dictionary in beds:
			var center: Vector3 = bed["center"]
			var length: float = bed["length"]
			check(center.y == 0.0, "%s: el parterre de %s apoya en el suelo" % [location_id, center])
			check_equal(_hits(location, center + Vector3.UP * 0.4, Vector3(length - 0.06, 0.7, PropsKit.SHRUB_BED_WIDTH - 0.06), bed["yaw"]), 1, "%s: el parterre de %s no se mete en nada" % [location_id, center])
			var extent := Vector3(length * 0.5 + 0.1, 0.0, PropsKit.SHRUB_BED_WIDTH * 0.5 + 0.1)
			if absf(float(bed["yaw"])) > 45.0:
				extent = Vector3(extent.z, 0.0, extent.x)
			check_equal(_inside(shown, AABB(center - extent - Vector3.UP * 0.1, extent * 2.0 + Vector3.UP * 1.0)).size(), 0, "%s: el parterre de %s no parpadea" % [location_id, center])
		# Los caminos de siempre siguen abiertos.
		for spawn_id: String in location._spawns:
			var spawn: Vector3 = location.get_spawn(spawn_id)["position"]
			check(location.is_standing_point(Vector3(spawn.x, 0.0, spawn.z)), "%s: la llegada %s sigue libre" % [location_id, spawn_id])
		for marker: String in location.get_marker_ids():
			check(location.is_standing_point(location.get_marker(marker)), "%s: el puesto %s sigue libre" % [location_id, marker])
		var spawns: Array = location._spawns.keys()
		for index in range(1, spawns.size()):
			var from: Vector3 = location.get_spawn(spawns[0])["position"]
			var to: Vector3 = location.get_spawn(spawns[index])["position"]
			to.y = 0.0
			var path := location.navigation.find_path(Vector3(from.x, 0.0, from.z), to)
			check(path.size() > 1 and _flat_distance(path[path.size() - 1], to) < 0.4, "%s: se llega de %s a %s" % [location_id, spawns[0], spawns[index]])


## Carga un escenario y descarga el anterior: todos están en el origen y sus colisiones se mezclarían.
func _load(location_id: String) -> LocationBase:
	for previous in _loaded:
		if is_instance_valid(previous):
			previous.free()
	_loaded.clear()
	await wait_physics_frames(2)
	var location: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
	add_child(location)
	_loaded.append(location)
	for frame in 120:
		if location.navigation.is_map_ready():
			break
		await get_tree().physics_frame
	await wait_physics_frames(2)
	return location


## Solapes de caras que la cámara llega a ver en el escenario cargado.
func _visible_overlaps(location: LocationBase) -> Array[Dictionary]:
	var overlaps := CoplanarFaces.find(location.batch)
	var probe := CoplanarFaces.add_probe(location, location.batch, PROBE_LAYER)
	await wait_physics_frames(2)
	var shown := CoplanarFaces.visible(overlaps, location.get_world_3d().direct_space_state, PROBE_LAYER)
	probe.queue_free()
	return shown


static func _inside(overlaps: Array[Dictionary], box: AABB) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for overlap in overlaps:
		if box.has_point(overlap["where"]):
			found.append(overlap)
	return found


## Colisiones del escenario (capa 1) que toca una caja; `yaw_degrees` la gira.
func _hits(location: LocationBase, center: Vector3, size: Vector3, yaw_degrees: float = 0.0) -> int:
	var box := BoxShape3D.new()
	box.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), center)
	query.collision_mask = 1
	return location.get_world_3d().direct_space_state.intersect_shape(query, 16).size()


## Distancia desde `from` hasta la primera colisión (capa 1) en `direction`.
func _gap(location: LocationBase, from: Vector3, direction: Vector3, reach: float = 3.0) -> float:
	var ray := PhysicsRayQueryParameters3D.create(from, from + direction * reach, 1)
	var hit := location.get_world_3d().direct_space_state.intersect_ray(ray)
	return from.distance_to(hit["position"]) if not hit.is_empty() else INF


func _find(location: LocationBase, matches: Callable) -> Node3D:
	for child in location.get_children():
		if matches.call(child):
			return child as Node3D
	return null


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
