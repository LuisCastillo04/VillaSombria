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
	check(not cafe.navigation.is_on_floor_mesh(Vector3(-12.8, 0.8, -3.6)), "la cama de la pensión no es suelo")
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
	var straight := Vector2(to.x - from.x, to.z - from.z).length()
	check(LocationNavigation.path_length(path) > straight + 1.0, "rodea las paredes en lugar de cruzarlas")
	# Cada tramo del recorrido pasa por suelo libre.
	for index in range(1, path.size()):
		var middle := (path[index - 1] + path[index]) * 0.5
		middle.y = 0.0
		check(mansion.is_standing_point(middle, 0.25), "el tramo %d pasa por suelo libre (%s)" % [index, str(middle)])


## Cada escenario tiene su mapa: dos cargados a la vez no se mezclan.
func test_each_location_has_its_own_map() -> void:
	var cafe := await _load("cafe")
	var mansion := await _load("mansion")
	check(cafe.navigation.get_map() != mansion.navigation.get_map(), "mapas distintos")
	check(cafe.navigation.get_map() != cafe.get_world_3d().navigation_map, "y distintos del mapa del mundo")
	# En el café no hay malla donde la mansión tiene su salón.
	check(not cafe.navigation.is_on_floor_mesh(Vector3(0.0, 0.0, -8.0)), "el café no ve la malla de la mansión")
