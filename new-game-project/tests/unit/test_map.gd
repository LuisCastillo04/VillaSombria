extends TestCase
## Datos y calibración del mapa: que cada zona exterior se convierta al lienzo sin deformarse, que
## lo dibujado coincida con las colisiones reales de los escenarios, que cada escenario jugable
## tenga su lugar y que nada se sitúe en una posición inventada.

const TOWN_MAP_SCRIPT := "res://scripts/autoload/town_map.gd"
## Error admitido al comparar el dibujo con las colisiones, en metros.
const FOOTPRINT_TOLERANCE := 0.15


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()


func after_each() -> void:
	GameState.reset()
	GameClock.reset()
	TownMap.reset()


func _instantiate(location_id: String) -> LocationBase:
	var scene: PackedScene = load("res://scenes/world/locations/%s.tscn" % location_id)
	var location: LocationBase = scene.instantiate()
	add_child(location)
	return location


## Registro independiente del autoload, para probar datos sin tocar los del juego.
func _fresh_registry() -> Node:
	return (load(TOWN_MAP_SCRIPT) as GDScript).new()


func _exits(location: LocationBase) -> Array[LocationExit]:
	var exits: Array[LocationExit] = []
	for child in location.get_children():
		if child is LocationExit:
			exits.append(child)
	return exits


func _ground(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func test_map_data_loads_without_problems() -> void:
	check(TownMap.get_problems().is_empty(), "los datos del mapa no tienen errores: %s" % ", ".join(TownMap.get_problems()))
	check_equal(TownMap.canvas_size, Vector2(1600.0, 1000.0), "tamaño del lienzo")
	var region_ids: Array[String] = []
	for region in TownMap.get_regions():
		region_ids.append(region.id)
	region_ids.sort()
	check_equal(region_ids, ["estacion", "plaza"] as Array[String], "sólo los exteriores reales están calibrados")


func test_calibration_reproduces_every_reference_point() -> void:
	for region in TownMap.get_regions():
		# Con tres puntos el ajuste afín siempre es exacto; el cuarto permite notar uno mal medido.
		check(region.anchors.size() >= 4, "%s tiene al menos cuatro puntos de referencia" % region.id)
		for anchor_id: String in region.residuals:
			check(float(region.residuals[anchor_id]) < 0.5, "%s/%s encaja con un error de %.2f" % [region.id, anchor_id, region.residuals[anchor_id]])
		var basis_x := region.transform.x
		var basis_y := region.transform.y
		check(region.transform.determinant() > 0.0, "%s no se ve en espejo" % region.id)
		check(absf(basis_x.length() - basis_y.length()) < basis_x.length() * 0.01, "%s se escala igual en los dos ejes" % region.id)
		check(absf(basis_x.normalized().dot(basis_y.normalized())) < 0.01, "%s no se deforma" % region.id)
		check(is_equal_approx(snappedf(region.map_units_per_meter(), 0.01), 12.0), "%s usa la escala común de 12 unidades por metro" % region.id)


func test_walking_up_on_screen_moves_the_marker_up_on_the_map() -> void:
	# La cámara mira con el mismo giro en todos los exteriores: «arriba» avanza hacia -Z girado.
	var camera := ExplorationCamera.new()
	var camera_yaw := deg_to_rad(camera.yaw_degrees)
	camera.free()
	var forward_3d := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, camera_yaw)
	var right_3d := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, camera_yaw)
	for region in TownMap.get_regions():
		var up := region.map_direction(_ground(forward_3d))
		var right := region.map_direction(_ground(right_3d))
		check(up.distance_to(Vector2.UP) < 0.01, "%s: arriba en pantalla es arriba en el mapa (%s)" % [region.id, up])
		check(right.distance_to(Vector2.RIGHT) < 0.01, "%s: derecha en pantalla es derecha en el mapa (%s)" % [region.id, right])


func test_regions_cover_the_real_walkable_area() -> void:
	var canvas := Rect2(Vector2.ZERO, TownMap.canvas_size)
	for region in TownMap.get_regions():
		var location := _instantiate(region.location_id)
		for spawn_id: String in location._spawns:
			var where: Vector3 = location.get_spawn(spawn_id)["position"]
			check(region.contains(_ground(where)), "%s/%s está dentro del área calibrada" % [region.id, spawn_id])
		for exit_node in _exits(location):
			check(region.contains(_ground(exit_node.global_position)), "la salida hacia %s está dentro del área calibrada" % exit_node.target_location)
		for corner in region.map_outline():
			check(canvas.grow(-30.0).has_point(corner), "%s cabe dentro del pergamino (%s)" % [region.id, corner])
		location.queue_free()
	await get_tree().process_frame


## Lo dibujado está donde están las colisiones del juego: la ilustración y el marcador usan la
## misma transformación, así que si el dibujo coincide, el marcador también.
func test_drawn_buildings_match_the_scene_colliders() -> void:
	var drawn := {"plaza": TownMapArt.PLAZA_BUILDINGS, "estacion": TownMapArt.STATION_BUILDINGS}
	for location_id: String in drawn:
		var location := _instantiate(location_id)
		var footprints := _collider_footprints(location)
		for building: Dictionary in drawn[location_id]:
			if not bool(building["collider"]):
				continue
			var rect: Rect2 = building["rect"]
			var matched := false
			for footprint: Rect2 in footprints:
				if footprint.position.distance_to(rect.position) < FOOTPRINT_TOLERANCE and footprint.end.distance_to(rect.end) < FOOTPRINT_TOLERANCE:
					matched = true
					break
			check(matched, "%s: el edificio «%s» dibujado en %s tiene su colisión en el escenario" % [location_id, building["id"], rect])
		location.queue_free()
	await get_tree().process_frame


func _collider_footprints(location: LocationBase) -> Array[Rect2]:
	var footprints: Array[Rect2] = []
	for shape_node in location.get_node("Colisiones").get_children():
		var shape := shape_node as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D:
			continue
		var half := (shape.shape as BoxShape3D).size * 0.5
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for corner: Vector3 in [Vector3(-half.x, 0.0, -half.z), Vector3(half.x, 0.0, -half.z), Vector3(half.x, 0.0, half.z), Vector3(-half.x, 0.0, half.z)]:
			var world := _ground(shape.global_transform * corner)
			low = low.min(world)
			high = high.max(world)
		footprints.append(Rect2(low, high - low))
	return footprints


func test_every_playable_location_has_its_place() -> void:
	for location_id: String in GameData.locations:
		if location_id == "test_ground":
			continue
		var place := TownMap.get_place_for_location(location_id)
		check(place != null, "%s figura en el mapa" % location_id)
		if place != null:
			check(TownMap.is_place_shown(place), "%s se muestra desde el principio" % location_id)
	check(TownMap.get_place_for_location("test_ground") == null, "el campo de pruebas no figura en el mapa")
	var objective_ids: Array[String] = []
	for objective: Dictionary in GameData.story["objectives"]:
		objective_ids.append(objective["id"])
	for place in TownMap.get_places():
		check(TownMap.is_place_implemented(place), "%s es un escenario que existe" % place.id)
		for objective_id in place.objective_ids:
			check(objective_ids.has(objective_id), "%s nombra un objetivo que existe: %s" % [place.id, objective_id])


## Cada puerta de la plaza queda más cerca del edificio al que lleva que de cualquier otro lugar,
## y la calle Mayor del mapa empieza y acaba en las salidas reales de la plaza y de la estación.
func test_exits_point_to_the_places_they_lead_to() -> void:
	var plaza := TownMap.get_region("plaza")
	var station := TownMap.get_region("estacion")
	var street := TownMapArt.main_street_points(plaza, station)
	var plaza_scene := _instantiate("plaza")
	for exit_node in _exits(plaza_scene):
		var spot := plaza.world_to_map(_ground(exit_node.global_position))
		if exit_node.target_location == "estacion":
			check(spot.distance_to(street[0]) < 3.0 * plaza.map_units_per_meter(), "la calle Mayor sale de la salida de la plaza")
			continue
		var nearest := ""
		var nearest_distance := INF
		for place in TownMap.get_places():
			if place.region_id != "plaza":
				continue
			var distance := spot.distance_to(TownMap.get_place_point(place))
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = place.id
		check_equal(nearest, exit_node.target_location, "la puerta hacia %s señala su edificio" % exit_node.target_location)
	plaza_scene.queue_free()
	var station_scene := _instantiate("estacion")
	for exit_node in _exits(station_scene):
		var spot := station.world_to_map(_ground(exit_node.global_position))
		check(spot.distance_to(street[street.size() - 1]) < 3.0 * station.map_units_per_meter(), "la calle Mayor llega a la salida de la estación")
	station_scene.queue_free()
	await get_tree().process_frame


func test_exteriors_are_located_point_by_point() -> void:
	var plaza := TownMap.get_region("plaza")
	var west := TownMap.locate("plaza", Vector3(-7.0, 0.1, 3.0), 0.0)
	var east := TownMap.locate("plaza", Vector3(14.0, 0.1, 3.0), 0.0)
	check(bool(west["precise"]) and bool(east["precise"]), "en la plaza la posición es exacta")
	check_equal(west["place_id"], "plaza", "y pertenece a la plaza")
	var moved: Vector2 = east["map_point"] - west["map_point"]
	check(moved.distance_to(plaza.transform.basis_xform(Vector2(21.0, 0.0))) < 0.01, "cruzar la plaza desplaza el punto en proporción")
	check(moved.length() > 200.0, "y el desplazamiento se nota en el mapa (%.0f unidades)" % moved.length())
	var facing: Vector2 = west["heading"]
	check(facing.distance_to(plaza.map_direction(Vector2(0.0, -1.0))) < 0.01, "la orientación se convierte con la misma transformación")


func test_positions_outside_the_walkable_area_are_kept_inside() -> void:
	var fix := TownMap.locate("plaza", Vector3(80.0, 0.1, -60.0))
	var region := TownMap.get_region("plaza")
	check(bool(fix["clamped"]), "se detecta que estaba fuera")
	check(fix["map_point"].distance_to(region.world_to_map(Vector2(29.1, -14.0))) < 0.01, "y se lleva a la esquina más cercana del área transitable")
	var lost := TownMap.locate("plaza", Vector3(NAN, 0.0, 0.0))
	check(not bool(lost["known"]), "una posición inválida no se dibuja")


func test_interiors_point_at_their_building_without_inventing_positions() -> void:
	for location_id: String in ["cafe", "archivo", "mansion"]:
		var near := TownMap.locate(location_id, Vector3(-3.0, 0.1, 2.0), 1.0)
		var far := TownMap.locate(location_id, Vector3(6.0, 0.1, -4.0), 2.0)
		var place := TownMap.get_place_for_location(location_id)
		check(bool(near["known"]) and not bool(near["precise"]), "%s se conoce, pero sin posición exacta" % location_id)
		check_equal(near["map_point"], TownMap.get_place_point(place), "%s señala su edificio" % location_id)
		check_equal(far["map_point"], near["map_point"], "%s: moverse dentro no mueve el marcador" % location_id)
		check_equal(near["heading"], Vector2.ZERO, "%s: sin orientación inventada" % location_id)
	var unknown := TownMap.locate("test_ground", Vector3(1.0, 0.1, 1.0))
	check(not bool(unknown["known"]), "un escenario que no está en el mapa no tiene posición")
	check_equal(unknown["map_point"], Vector2.ZERO, "ni siquiera una por defecto que se pudiera dibujar")


func test_objectives_are_linked_to_the_places_where_they_happen() -> void:
	check_equal(TownMap.get_objective_place_ids(), PackedStringArray(["cafe"]), "al llegar, el objetivo es el café")
	GameState.set_flag("llamada_atendida")
	check_equal(TownMap.get_objective_place_ids(), PackedStringArray(["mansion"]), "tras la llamada, la mansión")
	GameClock.day = 2
	var places := TownMap.get_objective_place_ids()
	places.sort()
	check_equal(places, PackedStringArray(["archivo", "estacion"]), "el lunes, la estación y el archivo")
	var texts := PackedStringArray()
	for objective in TownMap.get_pending_objectives():
		texts.append(objective["text"])
	var expected := PackedStringArray()
	for objective in StoryDirector.get_objectives():
		if not bool(objective["done"]):
			expected.append(objective["text"])
	check_equal(texts, expected, "los objetivos son los de la historia, sin inventar ninguno")


func test_visited_places_round_trip_and_reset() -> void:
	EventBus.location_changed.emit("estacion")
	EventBus.location_changed.emit("plaza")
	EventBus.location_changed.emit("test_ground")
	check_equal(TownMap.get_visited_ids(), PackedStringArray(["estacion", "plaza"]), "se anotan los lugares pisados")
	var saved := TownMap.to_dict()
	TownMap.reset()
	check(TownMap.get_visited_ids().is_empty(), "una partida nueva empieza sin lugares visitados")
	TownMap.from_dict(saved)
	check_equal(TownMap.get_visited_ids(), PackedStringArray(["estacion", "plaza"]), "se recuperan al cargar")
	TownMap.from_dict({"visited": ["plaza", "callejon", 7, null]})
	check_equal(TownMap.get_visited_ids(), PackedStringArray(["plaza"]), "se ignoran los lugares que no existen")
	TownMap.from_dict({})
	check(TownMap.get_visited_ids().is_empty(), "una partida anterior al mapa no trae lugares visitados")


func test_broken_map_data_is_discarded_instead_of_guessed() -> void:
	var registry := _fresh_registry()
	registry.load_data({
		"regions": {
			"plaza": {"location": "plaza", "bounds": [-10, -10, 10, 10], "anchors": [
				{"id": "a", "world": [0, 0], "map": [100, 100]},
				{"id": "b", "world": [1, 1], "map": [112, 112]},
				{"id": "c", "world": [2, 2], "map": [124, 124]},
			]},
			"estacion": {"location": "estacion", "anchors": []},
		},
		"places": [
			{"id": "plaza", "locations": ["plaza"], "region": "plaza", "anchor": [0, 0]},
			{"id": "callejon", "locations": ["callejon"], "region": "plaza", "anchor": [3, 3]},
			{"id": "sin_sitio", "locations": ["cafe"], "region": "plaza"},
			"no es un lugar",
		],
	}, false)
	check(registry.get_region("plaza") == null, "con los puntos alineados no hay calibración")
	check(registry.get_region("estacion") == null, "sin área transitable tampoco")
	check(registry.get_places().is_empty(), "ningún lugar queda colocado sobre una zona inválida")
	check(registry.get_problems().size() >= 4, "y cada problema queda anotado")
	check(not bool(registry.locate("plaza", Vector3.ZERO)["known"]), "la plaza deja de tener posición en lugar de inventarla")
	registry.free()


func test_calibration_detects_bad_reference_points() -> void:
	var two := MapCalibration.fit([
		{"id": "a", "world": [0, 0], "map": [100, 100]},
		{"id": "b", "world": [10, 0], "map": [100, 200]},
	])
	check(bool(two["ok"]), "dos puntos bastan para una semejanza")
	var similarity: Transform2D = two["transform"]
	check((similarity * Vector2(5.0, 5.0)).distance_to(Vector2(50.0, 150.0)) < 0.001, "y la semejanza gira y escala sin deformar")
	var mirrored := MapCalibration.fit([
		{"id": "a", "world": [0, 0], "map": [0, 0]},
		{"id": "b", "world": [10, 0], "map": [10, 0]},
		{"id": "c", "world": [0, 10], "map": [0, -10]},
	])
	check(not bool(mirrored["ok"]), "un mapa en espejo se rechaza")
	var inconsistent := MapCalibration.fit([
		{"id": "a", "world": [0, 0], "map": [0, 0]},
		{"id": "b", "world": [10, 0], "map": [100, 0]},
		{"id": "c", "world": [0, 10], "map": [0, 100]},
		{"id": "d", "world": [10, 10], "map": [300, 40]},
	])
	check(not bool(inconsistent["ok"]), "un punto mal medido se detecta por su error")
	check(not bool(MapCalibration.fit([{"id": "a", "world": [0, 0], "map": [0, 0]}])["ok"]), "un solo punto no basta")
