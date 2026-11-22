class_name LocationNavigation
extends NavigationRegion3D
## Navegación de un escenario para los NPC. La malla se hornea al construir el escenario a partir
## de sus colisiones reales (las mismas que detienen al detective), limitada a su área
## transitable, y vive en un mapa propio: dos escenarios cargados a la vez no se mezclan.
## El servidor tarda unos fotogramas en integrarla; hasta entonces `is_map_ready()` es falso.

const CELL_SIZE := 0.15
const AGENT_RADIUS := 0.3
const AGENT_HEIGHT := 1.8
const AGENT_MAX_CLIMB := 0.3
## Lo que queda por encima no estorba a quien camina: así no se hornean tejados ni techos.
const BAKE_CEILING := 2.2

## Milisegundos que tardó el horneado, para vigilar el coste de cargar un escenario.
var bake_milliseconds := 0.0

var _map := RID()
var _map_ready := false
var _probe := Vector3.ZERO


## Hornea la malla con las colisiones de `source` dentro de `area` (sin área, todo).
func bake(source: StaticBody3D, area: Rect2) -> void:
	var started := Time.get_ticks_usec()
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(_map, CELL_SIZE)
	NavigationServer3D.map_set_active(_map, true)
	set_navigation_map(_map)
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = CELL_SIZE
	mesh.cell_height = CELL_SIZE
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = AGENT_HEIGHT
	mesh.agent_max_climb = AGENT_MAX_CLIMB
	if area.has_area():
		mesh.filter_baking_aabb = AABB(
			Vector3(area.position.x, LocationBase.FLOOR_HEIGHT - 1.0, area.position.y),
			Vector3(area.size.x, 1.0 + BAKE_CEILING, area.size.y)
		)
		_probe = Vector3(area.get_center().x, LocationBase.FLOOR_HEIGHT, area.get_center().y)
	var geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, geometry, source)
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	navigation_mesh = mesh
	bake_milliseconds = float(Time.get_ticks_usec() - started) / 1000.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _map.is_valid():
		NavigationServer3D.free_rid(_map)


func get_map() -> RID:
	return _map


## Indica si el mapa ya responde con la malla de este escenario.
func is_map_ready() -> bool:
	if not _map_ready and _map.is_valid() and NavigationServer3D.map_get_iteration_id(_map) > 0:
		_map_ready = NavigationServer3D.map_get_closest_point_owner(_map, _probe) == get_rid()
	return _map_ready


## Punto de la malla más cercano. Ojo: la malla flota unos centímetros sobre el suelo.
func closest_point(point: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_map, point)


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(_map, from, to, true)


## Indica si `point` está sobre el suelo transitable (no en otra isla, como el tablero de una
## mesa) y a menos de `tolerance` metros en planta de la malla.
func is_on_floor_mesh(point: Vector3, tolerance: float = 0.35) -> bool:
	var snapped := closest_point(point)
	var flat := Vector2(snapped.x - point.x, snapped.z - point.z).length()
	return flat <= tolerance and absf(snapped.y - LocationBase.FLOOR_HEIGHT) <= AGENT_MAX_CLIMB


static func path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


## Indica si el recorrido pasa a menos de `distance` metros (en planta) de `point`.
static func passes_near(path: PackedVector3Array, point: Vector3, distance: float) -> bool:
	var target := Vector2(point.x, point.z)
	for index in range(1, path.size()):
		var a := Vector2(path[index - 1].x, path[index - 1].z)
		var b := Vector2(path[index].x, path[index].z)
		if Geometry2D.get_closest_point_to_segment(target, a, b).distance_to(target) < distance:
			return true
	return path.size() == 1 and Vector2(path[0].x, path[0].z).distance_to(target) < distance
