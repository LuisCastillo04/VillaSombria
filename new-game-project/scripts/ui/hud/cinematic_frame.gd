class_name CinematicFrame
extends Control
## Marco fino alrededor de la pantalla, como el filete de una lámina antigua: dos líneas doradas
## muy tenues, escuadras con un rombo en las cuatro esquinas y un rombo pequeño en el centro de
## los lados largos. No oscurece nada (la viñeta ya la pone el postproceso), no recibe el ratón y
## se redibuja sólo cuando cambia el tamaño de la ventana.
##
## Las pantallas que oscurecen el escenario (las conversaciones) pueden avivar el trazo con
## `emphasis` y rellenar el margen exterior con `band_color`, como el paspartú de una lámina.

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
## Banda entre el borde de la pantalla y el marco. Transparente en el HUD.
@export var band_color := Color(0.0, 0.0, 0.0, 0.0):
	set(value):
		band_color = value
		queue_redraw()
## Intensidad de los filetes y adornos: 1 es el trazo tenue del HUD; por encima de 1, más vivo.
@export var emphasis := 1.0:
	set(value):
		emphasis = value
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
	if band_color.a > 0.0:
		_draw_band(rect)
	var ornament := _stronger(ORNAMENT)
	draw_rect(rect, _stronger(LINE), false, 1.4, true)
	draw_rect(rect.grow(-INNER_GAP), _stronger(LINE_FAINT), false, 1.0, true)
	HudOrnaments.draw_corner_brackets(self, rect.grow(3.0), CORNER_LENGTH, ornament, 2.0)
	var fill := Color(HudStyle.CHARCOAL, 0.9)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		HudOrnaments.draw_diamond(self, corner, 4.5, ornament, fill)
	for y: float in [rect.position.y, rect.end.y]:
		HudOrnaments.draw_diamond(self, Vector2(rect.get_center().x, y), 3.5, ornament, fill)


func _stronger(color: Color) -> Color:
	return Color(color, minf(color.a * emphasis, 1.0))


## Rellena el margen entre el marco y el borde de la pantalla, sin pisar lo que queda dentro.
func _draw_band(rect: Rect2) -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, rect.position.y), band_color)
	draw_rect(Rect2(0.0, rect.end.y, size.x, size.y - rect.end.y), band_color)
	draw_rect(Rect2(0.0, rect.position.y, rect.position.x, rect.size.y), band_color)
	draw_rect(Rect2(rect.end.x, rect.position.y, size.x - rect.end.x, rect.size.y), band_color)
