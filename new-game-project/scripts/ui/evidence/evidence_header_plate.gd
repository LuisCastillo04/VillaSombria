class_name EvidenceHeaderPlate
extends Control
## Placa burdeos del encabezado, montada sobre la esquina superior izquierda del marco: el icono
## de la evidencia y su tipo («Carta personal», «Periódico / Crónica», «Evidencia / Objeto») en
## crema, entre filetes dorados. Su ancho sigue al texto.

const CUT := 9.0
const PADDING := 26.0
const GAP := 16.0

var _icon: TextureRect
var _label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = HudStyle.make_icon(null, EvidenceStyle.HEADER_ICON, EvidenceStyle.GOLD_LIGHT)
	_icon.name = "Icon"
	add_child(_icon)
	_label = EvidenceStyle.make_label("", EvidenceStyle.plate_font(), EvidenceStyle.HEADER_SIZE, EvidenceStyle.CREAM)
	_label.name = "Label"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func set_content(text: String, icon_texture: Texture2D) -> void:
	_label.text = text
	_icon.texture = icon_texture
	_icon.visible = icon_texture != null
	_fit()


func get_text() -> String:
	return _label.text


func get_icon() -> Texture2D:
	return _icon.texture


func _fit() -> void:
	var text_width := ceilf(EvidenceStyle.plate_font().get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, EvidenceStyle.HEADER_SIZE).x)
	var icon_width := EvidenceStyle.HEADER_ICON + GAP if _icon.visible else 0.0
	var plate_size := Vector2(PADDING * 2.0 + icon_width + text_width, EvidenceStyle.HEADER_HEIGHT)
	custom_minimum_size = plate_size
	size = plate_size
	var center_y := plate_size.y * 0.5
	_icon.position = Vector2(PADDING, center_y - EvidenceStyle.HEADER_ICON * 0.5)
	_icon.size = Vector2(EvidenceStyle.HEADER_ICON, EvidenceStyle.HEADER_ICON)
	_label.position = Vector2(PADDING + icon_width, 0.0)
	_label.size = Vector2(text_width, plate_size.y)
	queue_redraw()


func _draw() -> void:
	EvidenceOrnaments.draw_plate(self, Rect2(Vector2.ZERO, size), CUT, EvidenceStyle.BURGUNDY_LIGHT, EvidenceStyle.BURGUNDY_DARK, EvidenceStyle.GOLD, Color(EvidenceStyle.GOLD_LIGHT, 0.4))
