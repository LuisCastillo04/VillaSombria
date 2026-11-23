extends TestCase
## Navegación de los escenarios: se hornea con las colisiones reales, en un mapa propio, sólo
## dentro del área transitable, sin los tableros de los muebles y conectando las estancias por
## sus puertas.

const LOCATIONS := ["plaza", "cafe", "mansion", "archivo", "estacion"]

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


## Con `frozen` el escenario no se procesa (los NPC no se mueven), pero Godot saca entonces sus
## colisiones del espacio físico: para consultas físicas hay que cargarlo activo.
func _load(location_id: String, frozen: bool = true) -> LocationBase:
	var location: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
	if frozen:
		location.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(location)
	_loaded.append(location)
	for frame in 120:
		if location.navigation.is_map_ready():
			break
		await get_tree().physics_frame
	return location


func test_every_location_bakes_a_ready_mesh() -> void:
	for location_id: String in LOCATIONS:
		var location := await _load(location_id)
		check(location.navigation.is_map_ready(), "%s: la navegación debe quedar lista" % location_id)
		check(location.navigation.navigation_mesh.get_polygon_count() > 10, "%s: la malla tiene polígonos" % location_id)
		check(location.navigation.bake_milliseconds < 1000.0, "%s: hornear tarda %.0f ms" % [location_id, location.navigation.bake_milliseconds])
		print("   navegación de %s horneada en %.1f ms" % [location_id, location.navigation.bake_milliseconds])
		location.queue_free()
		await get_tree().process_frame


func test_every_marker_is_on_the_floor_mesh() -> void:
	for location_id: String in LOCATIONS:
		var location := await _load(location_id)
		for marker_id: String in location.get_marker_ids():
			check(location.navigation.is_on_floor_mesh(location.get_marker(marker_id)), "%s/%s queda fuera de la malla" % [location_id, marker_id])
		location.queue_free()
		await get_tree().process_frame


## Los tableros de mesas, camas y barras forman islas sueltas: no cuentan como suelo.
func test_furniture_tops_are_not_floor() -> void:
	var cafe := await _load("cafe")
	check(not cafe.navigation.is_on_floor_mesh(Vector3(0.0, 1.1, -3.9)), "la barra no es suelo")
	check(not cafe.navigation.is_on_floor_mesh(Vector3(-12.8, 0.8, -4.65)), "la cama de la pensión no es suelo")
	check(cafe.navigation.is_on_floor_mesh(Vector3(0.0, 0.0, 0.0)), "el centro del salón sí")


func test_outside_the_play_area_there_is_no_mesh() -> void:
	var cafe := await _load("cafe")
	# Tras la puerta de la calle sigue el suelo de colisión, pero no se hornea.
	check(not cafe.navigation.is_on_floor_mesh(Vector3(0.0, 0.0, 9.0)), "no hay malla en la calle")
	var path := cafe.navigation.find_path(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 9.0))
	check(not path.is_empty() and path[path.size() - 1].z < 6.0, "ningún camino sale por la puerta")


## En la mansión se va de una estancia a otra por sus puertas, nunca a través de las paredes.
func test_rooms_connect_through_their_doorways() -> void:
	var mansion := await _load("mansion", false)
	var navigation := mansion.navigation
	var from := mansion.get_marker("vestibulo")
	var to := mansion.get_marker("alcoba_elena")
	var path := navigation.find_path(from, to)
	check(not path.is_empty(), "hay camino del vestíbulo a la alcoba")
	if path.is_empty():
		return
	check(Vector2(path[path.size() - 1].x - to.x, path[path.size() - 1].z - to.z).length() < 0.3, "el camino llega a la alcoba")
	check(mansion.path_crosses_doorway(path), "y pasa por las puertas")
	# En línea recta habría que atravesar paredes; el recorrido, en cambio, va siempre por suelo
	# libre. Se comprueba punto a punto (cada 0,25 m), no por la longitud: con las puertas
	# despejadas el rodeo por ellas es corto.
	check(not _blocked_points(mansion, PackedVector3Array([from, to])).is_empty(), "en línea recta se atravesarían paredes")
	var blocked := _blocked_points(mansion, path)
	check(blocked.is_empty(), "el recorrido rodea las paredes en lugar de cruzarlas: %s" % str(blocked.slice(0, 3)))


## Cuarto de Lucía: la cómoda está contra la pared del fondo, no suelta en mitad del cuarto delante
## de la puerta de la alcoba. El centro queda libre y entre sus dos puertas se va casi en línea
## recta.
func test_maid_room_dresser_stands_against_the_wall() -> void:
	var mansion := await _load("mansion", false)
	var space := mansion.get_world_3d().direct_space_state
	check(not _solid_at(space, Vector3(-9.0, 0.42, 0.0)), "ya no hay un mueble donde estaba, delante de la puerta de la alcoba")
	check(_solid_at(space, Vector3(-12.0, 0.42, -0.6)), "la cómoda está junto a la pared del fondo")
	# Su espalda queda a ras de la pared (cara sur en z = -0,88) y su frente, despejado.
	check(_solid_at(space, Vector3(-12.0, 0.42, -0.78)), "pegada a la pared")
	check(not _solid_at(space, Vector3(-12.0, 0.42, -0.25)), "y con el frente libre")
	for x: float in [-11.5, -10.5, -9.5, -8.5, -7.5, -6.5]:
		for z: float in [0.6, 1.8, 3.0]:
			check(mansion.is_standing_point(Vector3(x, 0.0, z), 0.35), "el centro del cuarto está despejado en (%.1f, %.1f)" % [x, z])
	for z: float in [-0.5, 0.0, 0.6]:
		check(mansion.is_standing_point(Vector3(-9.5, 0.0, z), 0.35), "el paso a la alcoba está libre en z = %.1f" % z)
	# De la puerta del vestíbulo (x = -5, z = 4) a la de la alcoba (x = -9,5, z = -1).
	var from := Vector3(-5.6, 0.0, 4.0)
	var to := Vector3(-9.5, 0.0, -1.6)
	var path := mansion.navigation.find_path(from, to)
	check(not path.is_empty() and _flat(path[path.size() - 1], to) < 0.3, "hay camino entre las dos puertas del cuarto")
	var straight := _flat(from, to)
	check(LocationNavigation.path_length(path) < straight * 1.15, "casi en línea recta (%.1f m frente a %.1f m)" % [LocationNavigation.path_length(path), straight])


## Cada escenario tiene su mapa: dos cargados a la vez no se mezclan.
func test_each_location_has_its_own_map() -> void:
	var cafe := await _load("cafe")
	var mansion := await _load("mansion")
	check(cafe.navigation.get_map() != mansion.navigation.get_map(), "mapas distintos")
	check(cafe.navigation.get_map() != cafe.get_world_3d().navigation_map, "y distintos del mapa del mundo")
	# En el café no hay malla donde la mansión tiene su salón.
	check(not cafe.navigation.is_on_floor_mesh(Vector3(0.0, 0.0, -8.0)), "el café no ve la malla de la mansión")


## Puntos de un recorrido (cada 0,25 m) que caen dentro de una pared o un mueble. El radio es
## pequeño a propósito: en las esquinas el camino roza el margen de la malla de navegación.
func _blocked_points(location: LocationBase, path: PackedVector3Array) -> Array[Vector3]:
	var blocked: Array[Vector3] = []
	for index in range(1, path.size()):
		var steps := maxi(int(ceil(_flat(path[index - 1], path[index]) / 0.25)), 1)
		for step in steps + 1:
			var point := path[index - 1].lerp(path[index], float(step) / float(steps))
			point.y = 0.0
			if not location.is_standing_point(point, 0.12):
				blocked.append(point.snapped(Vector3.ONE * 0.01))
	return blocked


## Hay algo sólido (del escenario) en ese punto: una esfera pequeña choca con las colisiones.
func _solid_at(space: PhysicsDirectSpaceState3D, point: Vector3) -> bool:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.05
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = 1
	return not space.intersect_shape(query, 1).is_empty()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
