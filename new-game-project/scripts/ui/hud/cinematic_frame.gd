class_name CinematicFrame
extends Control
## Marco fino alrededor de la pantalla, como el filete de una lámina antigua: dos líneas doradas
## muy tenues, escuadras con un rombo en las cuatro esquinas y un rombo pequeño en el centro de
## los lados largos. No oscurece nada (la viñeta ya la pone el postproceso), no recibe el ratón y
## se redibuja sólo cuando cambia el tamaño de la ventana.

const INNER_GAP := 5.0
const CORNER_LENGTH := 46.0
const LINE := Color(0.71, 0.545, 0.29, 0.34)
const LINE_FAINT := Color(0.71, 0.545, 0.29, 0.14)
const ORNAMENT := Color(0.71, 0.545, 0.29, 0.72)

## Distancia del marco al borde de la pantalla.
@export var inset := HudStyle.FRAME_INSET:
	set(value):
		inset = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func get_frame_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(-inset)


func _draw() -> void:
	var rect := get_frame_rect()
	if rect.size.x <= CORNER_LENGTH * 2.0 or rect.size.y <= CORNER_LENGTH * 2.0:
		return
	draw_rect(rect, LINE, false, 1.4, true)
	draw_rect(rect.grow(-INNER_GAP), LINE_FAINT, false, 1.0, true)
	HudOrnaments.draw_corner_brackets(self, rect.grow(3.0), CORNER_LENGTH, ORNAMENT, 2.0)
	var fill := Color(HudStyle.CHARCOAL, 0.9)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		HudOrnaments.draw_diamond(self, corner, 4.5, ORNAMENT, fill)
	for y: float in [rect.position.y, rect.end.y]:
		HudOrnaments.draw_diamond(self, Vector2(rect.get_center().x, y), 3.5, ORNAMENT, fill)
