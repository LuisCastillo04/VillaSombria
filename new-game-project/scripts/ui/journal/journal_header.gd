class_name JournalHeader
extends HBoxContainer
## Encabezado de la carpeta: la pila de fotos con su clip y el rótulo «EXPEDIENTE 1948/17 · CASO
## VALDÉS» en burdeos, subrayado con un filete que termina en un rombo. El sello va aparte: lo coloca
## la carpeta en la esquina, a caballo entre el encabezado y las pestañas.

const TITLE_MIN_SIZE := 28

var _stack: JournalPhotoStack
var _title: Label
var _rule: Control


func _init() -> void:
	add_theme_constant_override("separation", 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack = JournalPhotoStack.new()
	add_child(_stack)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", 2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = JournalStyle.make_label(JournalInfo.CASE_TITLE, JournalStyle.title_font(), JournalStyle.TITLE_SIZE, JournalStyle.BURGUNDY_INK)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_color_override("font_shadow_color", Color(1.0, 0.97, 0.88, 0.45))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 1)
	texts.add_child(_title)
	_rule = Control.new()
	_rule.custom_minimum_size = Vector2(0.0, 14.0)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.draw.connect(_draw_rule)
	texts.add_child(_rule)
	add_child(texts)
	resized.connect(_fit_title)


func get_title() -> String:
	return _title.text


func get_title_font_size() -> int:
	return _title.get_theme_font_size("font_size")


## Si el rótulo no cabe, la letra se reduce hasta `TITLE_MIN_SIZE`.
func _fit_title() -> void:
	var available := size.x - _stack.size.x - get_theme_constant("separation") - 8.0
	var font := JournalStyle.title_font()
	var font_size := JournalStyle.TITLE_SIZE
	while font_size > TITLE_MIN_SIZE and font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available:
		font_size -= 2
	_title.add_theme_font_size_override("font_size", font_size)
	_rule.queue_redraw()


## Filete fino bajo el rótulo, con un rombo en el extremo izquierdo, que se apaga hacia la derecha.
func _draw_rule() -> void:
	var font := JournalStyle.title_font()
	var width := minf(font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_title_font_size()).x * 0.92, _rule.size.x)
	var y := _rule.size.y * 0.5
	var color := Color(JournalStyle.BURGUNDY_INK, 0.8)
	_rule.draw_polyline_colors(PackedVector2Array([Vector2(8.0, y), Vector2(width * 0.7, y), Vector2(width, y)]), PackedColorArray([color, color, Color(color, 0.0)]), 1.4, true)
	HudOrnaments.draw_diamond(_rule, Vector2(5.0, y), 4.0, color)
