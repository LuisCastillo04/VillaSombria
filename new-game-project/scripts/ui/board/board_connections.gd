class_name BoardConnections
extends Control
## Hilos rojos del corcho. Cada relación registrada (una deducción que el jugador ya estableció) une
## con hilo las chinchetas de sus dos fichas. Se dibuja por debajo de las fichas, así el hilo nunca
## tapa un texto ni recibe el ratón, y se vuelve a dibujar cuando una ficha se mueve.
##
## Sólo pinta lo que le dan: qué relaciones existen lo decide `BoardInfo.relations()`, que nunca
## incluye deducciones sin descubrir.

const WIDTH := 2.6

## Relaciones registradas: {id, from, to, kind}.
var _relations: Array[Dictionary] = []
## Devuelve la chincheta de una ficha por su identificador (o `Vector2.INF` si no está).
var _pin_of: Callable


func _init() -> void:
	name = "Connections"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(pin_of: Callable) -> void:
	_pin_of = pin_of


func set_relations(relations: Array[Dictionary]) -> void:
	_relations = relations
	queue_redraw()


func get_relations() -> Array[Dictionary]:
	return _relations


func _draw() -> void:
	if not _pin_of.is_valid():
		return
	for relation in _relations:
		var from: Vector2 = _pin_of.call(relation["from"])
		var to: Vector2 = _pin_of.call(relation["to"])
		if from == Vector2.INF or to == Vector2.INF:
			continue
		BoardOrnaments.draw_thread(self, from, to, BoardStyle.THREAD, WIDTH)
