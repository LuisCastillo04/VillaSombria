class_name NoirPlate
extends PanelContainer
## Placa oscura y translúcida con filete dorado y esquinas en chaflán: la barra de teclas y el aviso
## de interacción. Con `end_caps`, remata los extremos con un rombo engastado en el borde. Como el
## pergamino, se dibuja en código, crece con su contenido y no recibe el ratón.

const CUT := 8.0
const INNER_INSET := 5.5

## Rombos engastados en los extremos izquierdo y derecho.
@export var end_caps := true:
	set(value):
		end_caps = value
		queue_redraw()
## Márgenes del contenido: izquierda, arriba, derecha y abajo.
@export var padding := Vector4(30.0, 10.0, 30.0, 10.0):
	set(value):
		padding = value
		_update_padding()
@export var fill_color := HudStyle.PLATE_FILL

var _padding_box := StyleBoxEmpty.new()
var _shadow: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _padding_box)
	_shadow = StyleBoxFlat.new()
	_shadow.draw_center = false
	_shadow.set_corner_radius_all(int(CUT))
	_shadow.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	_shadow.shadow_size = 12
	_shadow.shadow_offset = Vector2(0.0, 4.0)
	_update_padding()
	resized.connect(queue_redraw)


func _update_padding() -> void:
	_padding_box.content_margin_left = padding.x
	_padding_box.content_margin_top = padding.y
	_padding_box.content_margin_right = padding.z
	_padding_box.content_margin_bottom = padding.w
	update_minimum_size()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_shadow, rect)
	var outline := HudOrnaments.chamfered(rect.grow(-0.8), CUT)
	draw_colored_polygon(outline, fill_color)
	draw_polyline(HudOrnaments.closed(outline), Color(HudStyle.GOLD, 0.9), 1.6, true)
	var inner := HudOrnaments.chamfered(rect.grow(-INNER_INSET), CUT - 2.5)
	draw_polyline(HudOrnaments.closed(inner), Color(HudStyle.GOLD, 0.26), 1.0, true)
	if end_caps:
		var solid := Color(fill_color, 1.0)
		HudOrnaments.draw_end_cap(self, Vector2(0.0, size.y * 0.5), -1.0, HudStyle.GOLD, solid)
		HudOrnaments.draw_end_cap(self, Vector2(size.x, size.y * 0.5), 1.0, HudStyle.GOLD, solid)
