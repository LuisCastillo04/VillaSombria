class_name AccusationVerdict
extends PanelContainer
## Línea de Ortega bajo los campos: lo que dice mientras escucha y, tras una acusación que no se
## sostiene, por qué. Es una franja de tinta muy tenue con el texto centrado en cursiva; al cambiar,
## el texto nuevo aparece con un fundido breve.

const MIN_HEIGHT := 70.0

var _text: RichTextLabel
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = MIN_HEIGHT
	var band := AccusationStyle.box(Color(AccusationStyle.INK, 0.06), Color(AccusationStyle.INK, 0.0), 0, 6, Vector4(26.0, 12.0, 26.0, 12.0))
	band.shadow_color = Color(1.0, 0.98, 0.9, 0.3)
	band.shadow_size = 1
	band.shadow_offset = Vector2(0.0, 1.0)
	add_theme_stylebox_override("panel", band)
	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_text.add_theme_font_override("normal_font", AccusationStyle.italic_font())
	_text.add_theme_font_override("italics_font", AccusationStyle.italic_font())
	_text.add_theme_font_override("bold_font", AccusationStyle.heading_font())
	_text.add_theme_font_size_override("normal_font_size", AccusationStyle.VERDICT_SIZE)
	_text.add_theme_font_size_override("italics_font_size", AccusationStyle.VERDICT_SIZE)
	_text.add_theme_font_size_override("bold_font_size", AccusationStyle.VERDICT_SIZE)
	_text.add_theme_color_override("default_color", AccusationStyle.INK)
	_text.add_theme_constant_override("line_separation", 4)
	add_child(_text)


## Muestra `bbcode` centrado. Con `animate`, el texto nuevo aparece con un fundido.
func show_message(bbcode: String, animate: bool = true) -> void:
	_text.text = "[center]%s[/center]" % bbcode
	if _tween != null:
		_tween.kill()
	if animate and is_inside_tree():
		_text.modulate.a = 0.0
		_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_text, "modulate:a", 1.0, AccusationStyle.VERDICT_SECONDS)
	else:
		_text.modulate.a = 1.0


## Texto tal como se lee, sin etiquetas.
func get_text() -> String:
	return _text.get_parsed_text()
