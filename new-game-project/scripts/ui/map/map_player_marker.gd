class_name MapPlayerMarker
extends Control
## Marcador del detective en el mapa: un círculo dorado con el centro encendido, un resplandor
## ámbar y una onda que late. Se coloca por su centro (el nodo mide cero) y se desliza con
## suavidad hacia la posición real; al cambiar de escenario o al abrir el mapa salta sin animar
## recorridos que el detective no ha hecho. Funciona con el juego en pausa.

const PULSE_SECONDS := 1.6
## Rapidez con la que alcanza la posición real: en un cuarto de segundo recorre el 95 %.
const FOLLOW_RATE := 12.0

## Radio del anillo, en píxeles.
@export var radius := 11.0

## Posición real en el lienzo del mapa y la que se está mostrando, que la persigue.
var target_point := Vector2.ZERO
var shown_point := Vector2.ZERO
## Dirección hacia la que mira, en el lienzo; cero si no se conoce (interiores).
var heading := Vector2.ZERO
## Lienzo → píxeles del padre; lo pone TownMapView.
var view_transform := Transform2D.IDENTITY

var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ZERO


## Nueva posición real. Con `snap`, se muestra ya, sin deslizarse.
func set_target(point: Vector2, facing: Vector2, snap: bool) -> void:
	target_point = point
	heading = facing
	if snap:
		shown_point = point
	_place()


func _process(delta: float) -> void:
	# La pausa procesa siempre a sus hijos: con el mapa cerrado no hay nada que animar.
	if not is_visible_in_tree():
		return
	_pulse = fmod(_pulse + delta / PULSE_SECONDS, 1.0)
	if not shown_point.is_equal_approx(target_point):
		shown_point = shown_point.lerp(target_point, 1.0 - exp(-FOLLOW_RATE * delta))
		if shown_point.distance_to(target_point) < 0.05:
			shown_point = target_point
		_place()
	queue_redraw()


func _place() -> void:
	position = view_transform * shown_point


## Posición en píxeles del padre donde está dibujado ahora mismo.
func get_shown_position() -> Vector2:
	return position


func _draw() -> void:
	MapSymbols.draw_player(self, Vector2.ZERO, radius, _pulse, heading)
