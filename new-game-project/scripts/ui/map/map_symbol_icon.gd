class_name MapSymbolIcon
extends Control
## Un símbolo del mapa suelto, para la leyenda y la lista de objetivos. Se dibuja con las mismas
## funciones que el mapa; el del detective late igual que su marcador.

@export var kind := MapSymbols.Kind.PLACE:
	set(value):
		kind = value
		set_process(kind == MapSymbols.Kind.PLAYER)
		queue_redraw()

var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(kind == MapSymbols.Kind.PLAYER)
	resized.connect(queue_redraw)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse = fmod(_pulse + delta / MapPlayerMarker.PULSE_SECONDS, 1.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var unit := minf(size.x, size.y)
	match kind:
		MapSymbols.Kind.PLACE:
			var head := unit * 0.21
			MapSymbols.draw_pin(self, center + Vector2(0.0, head * MapSymbols.PIN_REACH * 0.5), head)
		MapSymbols.Kind.OBJECTIVE:
			MapSymbols.draw_diamond(self, center, unit * 0.3, 0.5)
		MapSymbols.Kind.PLAYER:
			MapSymbols.draw_player(self, center, unit * 0.2, _pulse)
