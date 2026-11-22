class_name EvidenceTag
extends Control
## Tira de papel claro pegada al documento con un dato del investigador escrito a máquina: dónde se
## halló la prueba («Hallada en: Despacho de Julián Valdés») o una nota sobre ella. Lleva un icono
## a la izquierda y el extremo derecho rasgado. Su ancho sigue al texto hasta `max_width`; si no
## cabe, la letra se reduce.

const PADDING := Vector2(18.0, 8.0)
const GAP := 12.0
const MIN_FONT_SIZE := 17

var _icon: TextureRect
var _label: Label
var _icon_size := 26.0
var _font_size := 25


## `font_size` es el tamaño de la letra en el diseño del documento.
func _init(text: String = "", icon_name: String = "ubicacion", font_size: int = 25) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_size = font_size
	_icon_size = round(font_size * 1.05)
	_icon = HudStyle.make_icon(EvidenceStyle.icon(icon_name), _icon_size, EvidenceStyle.TYPE_INK)
	_icon.name = "Icon"
	add_child(_icon)
	_label = EvidenceStyle.make_label(text, EvidenceStyle.typewriter(), font_size, EvidenceStyle.TYPE_INK)
	_label.name = "Label"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func get_text() -> String:
	return _label.text


## Ajusta el ancho al texto sin pasar de `max_width` y devuelve el tamaño resultante.
func fit(max_width: float) -> Vector2:
	var font := EvidenceStyle.typewriter()
	var room := max_width - PADDING.x * 2.0 - _icon_size - GAP - 14.0
	var font_size := _font_size
	while font_size > MIN_FONT_SIZE and font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
		font_size -= 1
	_label.add_theme_font_size_override("font_size", font_size)
	var text_width := minf(ceilf(font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x), room)
	var height := maxf(font.get_height(font_size), _icon_size) + PADDING.y * 2.0
	size = Vector2(PADDING.x * 2.0 + _icon_size + GAP + text_width + 14.0, height)
	_icon.position = Vector2(PADDING.x, (height - _icon_size) * 0.5)
	_icon.size = Vector2(_icon_size, _icon_size)
	_label.position = Vector2(PADDING.x + _icon_size + GAP, 0.0)
	_label.size = Vector2(text_width, height)
	queue_redraw()
	return size


func _draw() -> void:
	# Tira con el extremo derecho rasgado en dientes irregulares.
	var points := PackedVector2Array([Vector2.ZERO])
	var teeth := 6
	for tooth in teeth + 1:
		var y := size.y * tooth / teeth
		var x := size.x - (0.0 if tooth % 2 == 0 else 7.0) - (3.0 if tooth == 3 else 0.0)
		points.append(Vector2(x, y))
	points.append(Vector2(0.0, size.y))
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(2.0, 3.0))
	draw_colored_polygon(shadow, Color(0.2, 0.12, 0.05, 0.22))
	draw_colored_polygon(points, EvidenceStyle.TAG_PAPER)
	draw_polyline(HudOrnaments.closed(points), EvidenceStyle.TAG_BORDER, 1.2, true)
