extends TestCase
## Mobiliario recolocado: el árbol de la plaza en su jardinera, lejos del quiosco; la cama, la
## mesilla y la silla de la pensión del café, y la mesilla del cuarto de Lucía. Cada pieza tiene
## colisión, no se mete en otra ni en la pared, queda pegada a lo que debe y deja al alcance del
## detective la cama y las pistas de alrededor. Cada escenario se carga solo y activo: las consultas
## físicas necesitan sus colisiones en el espacio.

const PLAZA := preload("res://scripts/world/locations/plaza.gd")
const CAFE := preload("res://scripts/world/locations/cafe.gd")
const MANSION := preload("res://scripts/world/locations/mansion.gd")
## Quiosco de prensa de la plaza (centro de su base).
const NEWSSTAND := Vector3(-6.0, 0.0, 10.6)

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


func _load(location_id: String) -> LocationBase:
	var location: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
	add_child(location)
	_loaded.append(location)
	for frame in 120:
		if location.navigation.is_map_ready():
			break
		await get_tree().physics_frame
	await wait_physics_frames(2)
	return location


func test_plaza_tree_leaves_the_newsstand_for_its_planter() -> void:
	var plaza := await _load("plaza")
	var center: Vector3 = PLAZA.PLANTER
	check(_flat_distance(center, NEWSSTAND) > 8.0, "el árbol queda lejos del quiosco")
	check(plaza.is_standing_point(Vector3(-4.8, 0.0, 10.0)), "delante del mostrador, donde estaba el tronco, ya se puede pasar")
	var newspaper := _find(plaza, func(node: Node) -> bool: return node is ClueObject and (node as ClueObject).clue_id == "periodico_aniversario")
	check(newspaper != null, "el periódico sigue en el quiosco")
	if newspaper != null:
		var counter := Vector3(newspaper.global_position.x + 0.6, 0.0, newspaper.global_position.z)
		check(plaza.is_standing_point(counter) and plaza.navigation.is_on_floor_mesh(counter), "y se llega al mostrador para leerlo")
	# Nadie se mete en la jardinera, ni siquiera junto al bordillo por dentro, y se puede rodear.
	var corner := PropsKit.PLANTER_APOTHEM / cos(PI / 8.0)
	check(not plaza.is_standing_point(center), "el centro de la jardinera no es transitable")
	for index in 16:
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(index) / 16.0)
		check(not plaza.is_standing_point(center + direction * (PropsKit.PLANTER_APOTHEM - 0.1)), "el bordillo detiene al detective (%d)" % index)
		check(plaza.is_standing_point(center + direction * (corner + 0.35)), "alrededor de la jardinera se puede andar (%d)" % index)
	check(not plaza.navigation.is_on_floor_mesh(center), "la jardinera no es suelo para los NPC")
	var west := center + Vector3(-2.6, 0.0, 0.0)
	var east := center + Vector3(2.6, 0.0, 0.0)
	var path := plaza.navigation.find_path(west, east)
	check(path.size() > 1 and _flat_distance(path[path.size() - 1], east) < 0.3, "hay camino de un lado a otro de la jardinera")
	check(not LocationNavigation.passes_near(path, center, PropsKit.PLANTER_APOTHEM), "y la rodea sin atravesarla")
	# El mapa del pueblo dibuja el árbol en su sitio nuevo, con la jardinera.
	var drawn := TownMapArt.PLAZA_TREES.filter(func(tree: Dictionary) -> bool: return tree.get("planter", false))
	check_equal(drawn.size(), 1, "el mapa tiene un árbol con jardinera")
	if drawn.size() == 1:
		check((drawn[0]["at"] as Vector2).distance_to(Vector2(center.x, center.z)) < 0.01, "en la misma posición que en la plaza")
	for tree: Dictionary in TownMapArt.PLAZA_TREES:
		check((tree["at"] as Vector2).distance_to(Vector2(NEWSSTAND.x, NEWSSTAND.z)) > 3.0, "el mapa ya no dibuja un árbol sobre el quiosco")


func test_pension_bed_nightstand_and_chair() -> void:
	var cafe := await _load("cafe")
	var bed: Vector3 = CAFE.BED
	var size: Vector3 = CAFE.NIGHTSTAND_SIZE
	var nightstand: Vector3 = CAFE.NIGHTSTAND + Vector3.UP * size.y * 0.5
	check_equal(_hits(cafe, nightstand, size - Vector3.ONE * 0.04), 1, "la mesilla tiene colisión y no se mete en la cama ni en la pared")
	check(_gap(cafe, nightstand, Vector3.FORWARD) - size.z * 0.5 < 0.08, "la mesilla está contra la pared del fondo")
	check(_gap(cafe, nightstand, Vector3.LEFT) - size.x * 0.5 < 0.15, "y junto a la cama")
	var bed_middle := bed + Vector3.UP * 0.4
	check_equal(_hits(cafe, bed_middle, Vector3(1.56, 0.76, 2.16)), 1, "la cama no se mete en ningún mueble")
	check(_gap(cafe, bed_middle, Vector3.FORWARD) - 1.1 < 0.2, "el cabecero queda contra la pared del fondo")
	check_equal(_hits(cafe, CAFE.DESK_CHAIR + Vector3.UP * 0.5, Vector3(0.46, 0.96, 0.46), CAFE.DESK_CHAIR_YAW), 1, "la silla tiene colisión y no se mete en la cómoda")
	check(cafe.is_standing_point(CAFE.DESK_CHAIR + Vector3(-1.0, 0.0, 0.3)), "entre la silla y la cama se puede pasar")
	check(cafe.is_standing_point(Vector3(-9.6, 0.0, -3.2)), "el sitio anterior de la mesilla, junto al paso del tabique, queda libre")
	# La cama sigue al alcance: el detective se levanta a su lado y llega desde la puerta.
	var spawn: Vector3 = cafe.get_spawn("cama")["position"]
	var floor_spawn := Vector3(spawn.x, 0.0, spawn.z)
	check(cafe.is_standing_point(floor_spawn), "el detective se levanta junto a la cama sin chocar con nada")
	var rest := _find(cafe, func(node: Node) -> bool: return node is RestPoint)
	check(rest != null and _flat_distance(rest.global_position, floor_spawn) < 1.6, "con la cama al alcance")
	var path := cafe.navigation.find_path(Vector3(-8.6, 0.0, -1.5), floor_spawn)
	check(path.size() > 1 and _flat_distance(path[path.size() - 1], floor_spawn) < 0.3, "se llega a la cama desde la puerta de la pensión")


func test_lucia_nightstand_against_the_wall_with_its_missal() -> void:
	var mansion := await _load("mansion")
	var nightstand: Vector3 = MANSION.LUCIA_NIGHTSTAND
	var middle := nightstand + Vector3.UP * 0.3
	check_equal(_hits(mansion, middle, Vector3(0.66, 0.56, 0.66)), 1, "la mesilla no se mete en la cama ni en la pared")
	check(_gap(mansion, middle, Vector3.LEFT) - 0.35 < 0.12, "la mesilla está contra la pared del fondo")
	check(_gap(mansion, middle, Vector3.BACK) - 0.35 < 0.3, "y junto al cabecero de la cama")
	check(mansion.is_standing_point(Vector3(-11.4, 0.0, 4.6)), "su sitio anterior, en mitad del cuarto, queda libre")
	var clue := _find(mansion, func(node: Node) -> bool: return node is ClueObject and (node as ClueObject).clue_id == "carta_amor")
	check(clue != null, "la carta sigue en el misal de la mesilla")
	if clue != null:
		var spot := Vector3(clue.global_position.x, 0.0, clue.global_position.z)
		check(mansion.is_standing_point(spot), "delante de la mesilla se puede estar de pie para examinarla")
		check(mansion.navigation.is_on_floor_mesh(spot), "y se llega andando")
		check(_flat_distance(spot, nightstand) < 1.1, "la pista queda junto a la mesilla")


## Colisiones del escenario (capa 1) que toca una caja; `yaw_degrees` la gira.
func _hits(location: LocationBase, center: Vector3, size: Vector3, yaw_degrees: float = 0.0) -> int:
	var box := BoxShape3D.new()
	box.size = size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), center)
	query.collision_mask = 1
	return location.get_world_3d().direct_space_state.intersect_shape(query, 16).size()


## Distancia desde `from` hasta la primera colisión (capa 1) en `direction`. La pieza dentro de la
## que empieza el rayo no cuenta.
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
