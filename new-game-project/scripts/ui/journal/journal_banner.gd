class_name JournalBanner
extends Control
## Cinta burdeos que encabeza una página: un icono a la izquierda y el rótulo en versalitas, con
## los extremos en punta, filete dorado y una sombra. Ocupa todo el ancho de la página.

const NOTCH := 14.0
const ICON_GAP := 18.0

var text := "":
	set(value):
		text = value
		queue_redraw()
var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()


func _init(banner_text: String = "", banner_icon: Texture2D = null) -> void:
	text = banner_text
	icon = banner_icon
	custom_minimum_size = Vector2(0.0, JournalStyle.BANNER_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2(0.0, 3.0), Vector2(size.x, size.y - 6.0))
	var shape := HudOrnaments.ribbon(rect, NOTCH)
	var shadow := PackedVector2Array()
	for point in shape:
		shadow.append(point + Vector2(0.0, 4.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.3))
	draw_colored_polygon(shape, JournalStyle.BURGUNDY)
	# Luz suave en la mitad superior, como un lazo de raso.
	draw_rect(Rect2(rect.position + Vector2(NOTCH, 2.0), Vector2(rect.size.x - NOTCH * 2.0, rect.size.y * 0.42)), Color(1.0, 0.85, 0.75, 0.07))
	draw_polyline(HudOrnaments.closed(shape), JournalStyle.GOLD, 1.8, true)
	var inner := HudOrnaments.ribbon(rect.grow(-4.5), NOTCH - 1.5)
	draw_polyline(HudOrnaments.closed(inner), Color(JournalStyle.GOLD, 0.45), 1.0, true)
	var font := JournalStyle.banner_font()
	var font_size := JournalStyle.BANNER_SIZE
	var cursor := NOTCH + 22.0
	if icon != null:
		var icon_size := rect.size.y * 0.62
		var icon_rect := Rect2(Vector2(cursor, rect.get_center().y - icon_size * 0.5), Vector2(icon_size, icon_size))
		draw_texture_rect(icon, icon_rect, false, JournalStyle.CREAM)
		cursor += icon_size + ICON_GAP
	var baseline := rect.position.y + (rect.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	var available := size.x - cursor - NOTCH - 16.0
	draw_string(font, Vector2(cursor, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, available, font_size, JournalStyle.CREAM)
