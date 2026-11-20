extends Node
## Registro del mapa del pueblo. Lee `data/map.json`, calibra las zonas exteriores y responde
## dónde está el detective en el lienzo del mapa:
##
## - En un exterior calibrado (la plaza, la estación), su posición real, convertida punto por punto.
## - En un interior (el café, el archivo, la mansión), el edificio al que pertenece: el mapa no
##   tiene plano de los interiores y no se inventa una posición dentro de ellos.
## - En un escenario que el mapa no conoce, nada: el marcador se oculta en lugar de señalar un
##   sitio falso.
##
## También decide qué lugares se muestran (existen, se conocen y tienen chincheta), qué objetivos
## pendientes se cumplen en cada uno y qué lugares ha pisado ya el detective.

signal visited_changed

const DEFAULT_CANVAS := Vector2(1600.0, 1000.0)
## Distancia, en metros, a partir de la cual una posición fuera del área transitable se considera
## corregida al llevarla al borde.
const CLAMP_TOLERANCE := 0.5

## Tamaño del lienzo del mapa: todas las posiciones del mapa están en estas unidades.
var canvas_size := DEFAULT_CANVAS

var _regions: Dictionary = {}
var _region_by_location: Dictionary = {}
var _places: Array[MapPlace] = []
var _place_by_id: Dictionary = {}
var _place_by_location: Dictionary = {}
var _problems: PackedStringArray = []
var _visited: Dictionary = {}


func _ready() -> void:
	load_data(GameData.map)
	EventBus.location_changed.connect(_on_location_changed)


# --- Datos -------------------------------------------------------------------------------

## Carga las zonas y los lugares. Lo que está mal escrito se descarta y se anota en
## `get_problems()`: un lugar sin datos válidos no aparece, nunca se coloca en un sitio inventado.
func load_data(data: Dictionary, report_problems: bool = true) -> void:
	_regions.clear()
	_region_by_location.clear()
	_places.clear()
	_place_by_id.clear()
	_place_by_location.clear()
	_problems.clear()
	var canvas: Variant = data.get("canvas")
	canvas_size = DEFAULT_CANVAS
	if canvas is Array and (canvas as Array).size() == 2 and float(canvas[0]) > 0.0 and float(canvas[1]) > 0.0:
		canvas_size = Vector2(float(canvas[0]), float(canvas[1]))
	var regions: Dictionary = data.get("regions", {})
	for region_id: String in regions:
		var region := MapRegion.from_data(region_id, regions[region_id])
		if not region.is_valid():
			_problems.append(region.error)
			continue
		_regions[region_id] = region
		_region_by_location[region.location_id] = region
	for entry: Variant in data.get("places", []):
		if not entry is Dictionary:
			_problems.append("Hay un lugar que no es un objeto: %s" % str(entry))
			continue
		_add_place(MapPlace.from_data(entry))
	if report_problems:
		for problem in _problems:
			push_error("Mapa: %s" % problem)


func _add_place(place: MapPlace) -> void:
	if not place.is_valid():
		_problems.append(place.error)
	elif not _regions.has(place.region_id):
		_problems.append("El lugar «%s» está en una zona que no existe o no está calibrada: «%s»." % [place.id, place.region_id])
	elif _place_by_id.has(place.id):
		_problems.append("El lugar «%s» está repetido." % place.id)
	else:
		_places.append(place)
		_place_by_id[place.id] = place
		for location_id in place.location_ids:
			_place_by_location[location_id] = place


func get_problems() -> PackedStringArray:
	return _problems


func get_regions() -> Array[MapRegion]:
	var regions: Array[MapRegion] = []
	regions.assign(_regions.values())
	return regions


func get_region(region_id: String) -> MapRegion:
	return _regions.get(region_id)


## Zona calibrada de un escenario exterior, o null si el escenario no se representa punto por punto.
func get_region_for_location(location_id: String) -> MapRegion:
	return _region_by_location.get(location_id)


func get_places() -> Array[MapPlace]:
	return _places


func get_place(place_id: String) -> MapPlace:
	return _place_by_id.get(place_id)


func get_place_for_location(location_id: String) -> MapPlace:
	return _place_by_location.get(location_id)


## Posición de la chincheta del lugar en el lienzo.
func get_place_point(place: MapPlace) -> Vector2:
	var region: MapRegion = _regions[place.region_id]
	return region.world_to_map(place.anchor)


func get_place_name(place: MapPlace) -> String:
	if not place.label.is_empty():
		return place.label
	for location_id in place.location_ids:
		var location_name: String = GameData.locations.get(location_id, {}).get("name", "")
		if not location_name.is_empty():
			return location_name
	return place.id


## Si un lugar es exterior: su propio escenario está calibrado en el mapa.
func is_exterior(place: MapPlace) -> bool:
	for location_id in place.location_ids:
		if _region_by_location.has(location_id):
			return true
	return false


# --- Reglas de visibilidad ---------------------------------------------------------------

## Todos sus escenarios existen en `locations.json` y tienen escena. Un lugar que todavía no se
## puede visitar no aparece en el mapa.
func is_place_implemented(place: MapPlace) -> bool:
	for location_id in place.location_ids:
		var scene: String = GameData.locations.get(location_id, {}).get("scene", "")
		if scene.is_empty() or not ResourceLoader.exists(scene):
			return false
	return true


## Conocido: cumple su condición de descubrimiento (por defecto, ninguna) o ya se ha visitado.
func is_place_discovered(place: MapPlace) -> bool:
	return is_visited(place.id) or Conditions.check(place.discovered_if)


## Abierto según su condición de disponibilidad (por defecto, siempre).
func is_place_available(place: MapPlace) -> bool:
	return Conditions.check(place.available_if)


func is_place_shown(place: MapPlace) -> bool:
	return place.interest and is_place_implemented(place) and is_place_discovered(place)


func get_shown_places() -> Array[MapPlace]:
	var shown: Array[MapPlace] = []
	for place in _places:
		if is_place_shown(place):
			shown.append(place)
	return shown


# --- Posición del detective --------------------------------------------------------------

## Sitúa en el mapa una posición de un escenario. Devuelve:
## - `known`: si el mapa representa ese escenario. Si es falso, no hay que mostrar marcador.
## - `precise`: si `map_point` es la posición real (exteriores) o el edificio (interiores).
## - `place_id`, `region_id`, `location_id`, `map_point` (unidades del lienzo).
## - `heading`: hacia dónde mira, como dirección del lienzo, o cero si no se conoce.
## - `clamped`: si la posición estaba fuera del área transitable y se llevó a su borde.
func locate(location_id: String, world_position: Vector3, facing_yaw: float = NAN) -> Dictionary:
	var fix := {
		"known": false, "precise": false, "location_id": location_id, "place_id": "",
		"region_id": "", "map_point": Vector2.ZERO, "heading": Vector2.ZERO, "clamped": false,
	}
	var place: MapPlace = _place_by_location.get(location_id)
	if place != null:
		fix["place_id"] = place.id
	var region: MapRegion = _region_by_location.get(location_id)
	if region != null:
		var ground := Vector2(world_position.x, world_position.z)
		if not ground.is_finite():
			return fix
		var inside := region.clamp_to_bounds(ground)
		fix["known"] = true
		fix["precise"] = true
		fix["region_id"] = region.id
		fix["map_point"] = region.world_to_map(inside)
		fix["clamped"] = inside.distance_to(ground) > CLAMP_TOLERANCE
		if is_finite(facing_yaw):
			# El detective mira hacia -Z girado `facing_yaw` (ver PlayerController).
			fix["heading"] = region.map_direction(Vector2(-sin(facing_yaw), -cos(facing_yaw)))
		return fix
	if place != null:
		fix["known"] = true
		fix["map_point"] = get_place_point(place)
	return fix


# --- Objetivos ---------------------------------------------------------------------------

## Objetivos pendientes de hoy, en el orden de StoryDirector, cada uno con los lugares del mapa
## (que se muestran) donde se cumple, en `places`.
func get_pending_objectives() -> Array[Dictionary]:
	var pending: Array[Dictionary] = []
	for objective in StoryDirector.get_objectives():
		if bool(objective["done"]):
			continue
		var entry := objective.duplicate()
		var places := PackedStringArray()
		for place in _places:
			if place.objective_ids.has(str(objective.get("id", ""))) and is_place_shown(place):
				places.append(place.id)
		entry["places"] = places
		pending.append(entry)
	return pending


## Lugares relacionados con algún objetivo pendiente.
func get_objective_place_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for objective in get_pending_objectives():
		for place_id: String in objective["places"]:
			if not ids.has(place_id):
				ids.append(place_id)
	return ids


# --- Lugares visitados ------------------------------------------------------------------

func is_visited(place_id: String) -> bool:
	return _visited.has(place_id)


func get_visited_ids() -> PackedStringArray:
	var ids := PackedStringArray(_visited.keys())
	ids.sort()
	return ids


## Partida nueva: el detective todavía no ha pisado ningún lugar.
func reset() -> void:
	if _visited.is_empty():
		return
	_visited.clear()
	visited_changed.emit()


func _on_location_changed(location_id: String) -> void:
	var place: MapPlace = _place_by_location.get(location_id)
	if place == null or _visited.has(place.id):
		return
	_visited[place.id] = true
	visited_changed.emit()
