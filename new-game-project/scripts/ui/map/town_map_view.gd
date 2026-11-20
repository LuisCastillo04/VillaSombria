class_name TownMapView
extends Control
## Mapa del pueblo a cualquier tamaño. El pergamino conserva su proporción, centrado en el espacio
## disponible, y la ilustración, las chinchetas y el marcador del detective comparten la misma
## transformación del lienzo a la pantalla: al cambiar el tamaño de la ventana se recolocan juntos
## y nunca se desalinean.
##
## Mientras está visible lee cada fotograma la posición real del detective (`target`) y el
## escenario actual (`GameState.location_id`), y se los pasa a `TownMap.locate`. Si el escenario no
## figura en el mapa, el marcador se oculta.

signal place_focused(place_id: String)
signal place_pressed(place_id: String)

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
## Cono, a cada lado del eje, en el que se busca la chincheta vecina al navegar con las flechas.
const NAVIGATION_CONE := PI * 0.36

## Detective al que sigue el marcador. Sin él, el marcador se oculta.
var target: PlayerController
## Control al que se baja desde las chinchetas de más abajo (el botón «Volver»).
var exit_control: Control

var _parchment: ColorRect
var _parchment_material: ShaderMaterial
var _art: TownMapArt
var _pins_layer: Control
var _marker: MapPlayerMarker
var _pins: Dictionary = {}
var _fit := Transform2D.IDENTITY
var _fix: Dictionary = {}
var _tracked_location := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parchment_material = ShaderMaterial.new()
	_parchment_material.shader = PARCHMENT_SHADER
	_parchment_material.set_shader_parameter("base_color", Color("ddc597"))
	_parchment_material.set_shader_parameter("stain_color", Color("b48d55"))
	_parchment_material.set_shader_parameter("edge_color", Color("4d3018"))
	_parchment_material.set_shader_parameter("corner_radius", 10.0)
	_parchment_material.set_shader_parameter("seed", 8.3)
	_parchment = ColorRect.new()
	_parchment.name = "Parchment"
	_parchment.material = _parchment_material
	_parchment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_parchment)
	_art = TownMapArt.new()
	_art.name = "Art"
	add_child(_art)
	_pins_layer = Control.new()
	_pins_layer.name = "Pins"
	_pins_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pins_layer)
	_marker = MapPlayerMarker.new()
	_marker.name = "PlayerMarker"
	_marker.hide()
	add_child(_marker)
	_build_pins()
	resized.connect(_layout)
	TownMap.visited_changed.connect(refresh_places)
	EventBus.objectives_changed.connect(refresh_places)
	refresh_places()
	_layout()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		update_tracking()


## Lee la posición real del detective y mueve el marcador. Con `snap`, sin deslizarse.
func update_tracking(snap: bool = false) -> void:
	var location := GameState.location_id
	if target == null or not is_instance_valid(target):
		_fix = TownMap.locate("", Vector3.ZERO)
	else:
		_fix = TownMap.locate(location, target.global_position, target.model.rotation.y)
	if not bool(_fix["known"]):
		_marker.hide()
		_tracked_location = ""
		return
	# Un cambio de escenario recoloca el marcador al momento: no hay recorrido que animar.
	var jump := snap or not _marker.visible or location != _tracked_location
	_tracked_location = location
	_marker.set_target(_fix["map_point"], _fix["heading"], jump)
	_marker.show()


## Último resultado de `TownMap.locate` para el detective.
func get_fix() -> Dictionary:
	return _fix


func get_marker() -> MapPlayerMarker:
	return _marker


func get_pin(place_id: String) -> MapPlacePin:
	return _pins.get(place_id)


## Chinchetas visibles, en el orden de los datos.
func get_visible_pins() -> Array[MapPlacePin]:
	var visible_pins: Array[MapPlacePin] = []
	for place_id: String in _pins:
		var pin: MapPlacePin = _pins[place_id]
		if pin.visible:
			visible_pins.append(pin)
	return visible_pins


## Lienzo del mapa → píxeles de este nodo.
func get_fit_transform() -> Transform2D:
	return _fit


func map_to_local(map_point: Vector2) -> Vector2:
	return _fit * map_point


## Rectángulo que ocupa el pergamino, en píxeles de este nodo.
func get_parchment_rect() -> Rect2:
	return Rect2(_parchment.position, _parchment.size)


## Vuelve a decidir qué lugares se ven, cuáles tienen objetivo y si están abiertos.
func refresh_places() -> void:
	var objective_places := TownMap.get_objective_place_ids()
	for place_id: String in _pins:
		var pin: MapPlacePin = _pins[place_id]
		var place := TownMap.get_place(place_id)
		var shown := TownMap.is_place_shown(place)
		pin.visible = shown
		pin.focus_mode = Control.FOCUS_ALL if shown else Control.FOCUS_NONE
		pin.objective = shown and objective_places.has(place_id)
		pin.available = TownMap.is_place_available(place)
	_link_focus()


func _build_pins() -> void:
	for place in TownMap.get_places():
		var pin := MapPlacePin.new()
		pin.name = "Pin_%s" % place.id
		pin.place_id = place.id
		pin.title = TownMap.get_place_name(place)
		pin.label_side = place.label_side
		pin.focus_entered.connect(func() -> void: place_focused.emit(place.id))
		pin.pressed.connect(func() -> void: place_pressed.emit(place.id))
		_pins_layer.add_child(pin)
		_pins[place.id] = pin


func _layout() -> void:
	var canvas := TownMap.canvas_size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale := minf(size.x / canvas.x, size.y / canvas.y)
	var offset := ((size - canvas * scale) * 0.5).round()
	_fit = Transform2D(0.0, Vector2(scale, scale), 0.0, offset)
	_parchment.position = offset
	_parchment.size = canvas * scale
	_parchment_material.set_shader_parameter("rect_size", _parchment.size)
	_parchment_material.set_shader_parameter("edge_width", 46.0 * scale)
	_art.position = offset
	_art.size = canvas * scale
	_art.view_transform = Transform2D(0.0, Vector2(scale, scale), 0.0, Vector2.ZERO)
	_pins_layer.size = size
	for place_id: String in _pins:
		(_pins[place_id] as MapPlacePin).place_at(_fit * TownMap.get_place_point(TownMap.get_place(place_id)))
	_marker.view_transform = _fit
	_marker.set_target(_marker.target_point, _marker.heading, true)
	_link_focus()


## Vecinas de cada chincheta para las flechas: la más cercana en esa dirección. Desde las de más
## abajo se baja a «Volver». Así la navegación no depende de cómo resuelva Godot la geometría.
func _link_focus() -> void:
	var pins := get_visible_pins()
	var directions := {
		"focus_neighbor_top": Vector2.UP, "focus_neighbor_bottom": Vector2.DOWN,
		"focus_neighbor_left": Vector2.LEFT, "focus_neighbor_right": Vector2.RIGHT,
	}
	for pin in pins:
		var from := pin.position + pin.get_tip_offset()
		for property: String in directions:
			var best := _nearest_in_direction(pin, from, directions[property], pins)
			if best != null:
				pin.set(property, pin.get_path_to(best))
			elif property == "focus_neighbor_bottom" and exit_control != null:
				pin.set(property, pin.get_path_to(exit_control))
			else:
				pin.set(property, NodePath("."))


func _nearest_in_direction(origin: MapPlacePin, from: Vector2, direction: Vector2, pins: Array[MapPlacePin]) -> MapPlacePin:
	var best: MapPlacePin = null
	var best_score := INF
	for other in pins:
		if other == origin:
			continue
		var offset := other.position + other.get_tip_offset() - from
		var distance := offset.length()
		if distance < 1.0:
			continue
		var angle := absf(direction.angle_to(offset))
		if angle > NAVIGATION_CONE:
			continue
		var score := distance * (1.0 + angle * 1.5)
		if score < best_score:
			best_score = score
			best = other
	return best


## Chincheta más cercana a un punto del lienzo, para volver a ella desde «Volver».
func nearest_pin_to(map_point: Vector2) -> MapPlacePin:
	var best: MapPlacePin = null
	var best_distance := INF
	for pin in get_visible_pins():
		var distance := (pin.position + pin.get_tip_offset()).distance_to(_fit * map_point)
		if distance < best_distance:
			best_distance = distance
			best = pin
	return best
