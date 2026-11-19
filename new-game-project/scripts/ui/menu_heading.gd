class_name MenuHeading
extends VBoxContainer
## Encabezado de los menús oscuros: el título en mayúsculas entre dos filigranas doradas y, debajo,
## un filete con un rombo.

@export var text := "":
	set(value):
		text = value
		if _title != null:
			_title.text = value
@export var font_size := 46

var _title: Label


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = MenuStyle.make_label(text, font_size, MenuStyle.TEXT, CaseFileStyle.display_serif())
	_title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.add_theme_constant_override("shadow_outline_size", 6)
	row.add_child(_flourish(false))
	row.add_child(_title)
	row.add_child(_flourish(true))
	add_child(row)
	var divider := GoldDivider.new()
	divider.custom_minimum_size = Vector2(380.0, 14.0)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	divider.color = Color(MenuStyle.GOLD, 0.7)
	add_child(divider)


func get_title() -> Label:
	return _title


func _flourish(mirrored: bool) -> TitleFlourish:
	var flourish := TitleFlourish.new()
	flourish.mirrored = mirrored
	flourish.color = Color(MenuStyle.GOLD, 0.9)
	flourish.custom_minimum_size = Vector2(96.0, 22.0)
	flourish.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return flourish
