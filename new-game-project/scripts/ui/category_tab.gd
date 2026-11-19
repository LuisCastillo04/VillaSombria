class_name CategoryTab
extends Button
## Pestaña de categoría de los menús de configuración y controles. La seleccionada se tiñe de
## burdeos. Recibir el foco con el teclado o el mando también la selecciona, así basta con
## subir y bajar para recorrer las categorías.

const HEIGHT := 54.0
const ICON_WIDTH := 28


func _ready() -> void:
	toggle_mode = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size.y = maxf(custom_minimum_size.y, HEIGHT)
	_apply_styles()
	focus_entered.connect(_on_focus_entered)


func _on_focus_entered() -> void:
	if not button_pressed:
		button_pressed = true


func _apply_styles() -> void:
	var idle := _tab_box(Color(0.0, 0.0, 0.0, 0.0), Color(MenuStyle.GOLD, 0.0))
	idle.border_width_bottom = 1
	idle.border_color = Color(MenuStyle.GOLD, 0.22)
	var hover := _tab_box(Color(MenuStyle.SELECTION, 0.22), Color(MenuStyle.GOLD, 0.3))
	var selected := _tab_box(MenuStyle.SELECTION, MenuStyle.SELECTION_LIGHT)
	selected.shadow_color = Color(MenuStyle.SELECTION, 0.45)
	selected.shadow_size = 8
	add_theme_stylebox_override("normal", idle)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", selected)
	add_theme_stylebox_override("hover_pressed", selected)
	add_theme_stylebox_override("focus", CaseFileStyle.focus_ring(5))
	add_theme_font_override("font", CaseFileStyle.serif_bold())
	add_theme_font_size_override("font_size", 24)
	for key: String in ["font_color", "font_hover_color", "font_focus_color"]:
		add_theme_color_override(key, MenuStyle.TEXT_SECONDARY)
	for key: String in ["font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(key, MenuStyle.TEXT)
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		add_theme_color_override(key, MenuStyle.TEXT_SECONDARY)
	for key: String in ["icon_pressed_color", "icon_hover_pressed_color"]:
		add_theme_color_override(key, MenuStyle.TEXT)
	add_theme_constant_override("icon_max_width", ICON_WIDTH)
	add_theme_constant_override("h_separation", 16)


static func _tab_box(background: Color, border: Color) -> StyleBoxFlat:
	var style := CaseFileStyle.box(background, border, 1, 5)
	style.content_margin_left = 16.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
