class_name CaseFileStyle
extends RefCounted
## Estilo de «expediente del caso» de las pantallas de guardar y cargar: pergamino envejecido,
## marco de madera con filetes dorados, burdeos para lo seleccionado y tinta sepia. Todo se
## genera aquí, sin texturas externas, para que las pantallas y sus diálogos compartan aspecto.

const PARCHMENT := Color("e9d7b3")
const PARCHMENT_LIGHT := Color("f2e4c6")
const PARCHMENT_SHADE := Color("d4bb8c")
const SEPIA := Color("6b4b2f")
const INK := Color("2a1910")
const INK_SOFT := Color("5c4430")
const BURGUNDY := Color("7a1d21")
const BURGUNDY_DARK := Color("4f1014")
const ROSE := Color("ecd0bd")
const GOLD := Color("b8924f")
const GOLD_LIGHT := Color("e2c584")
const WOOD := Color("2b1d15")
const WOOD_LIGHT := Color("3d2a1e")
const CREAM := Color("f3e5c5")
const DISABLED_TEXT := Color("8d7c68")

const ICONS := "res://assets/ui/iconos/%s.svg"

const DISPLAY_FONTS: Array[String] = ["Palatino Linotype", "Book Antiqua", "Palatino", "Georgia", "Times New Roman", "Liberation Serif", "serif"]

static var _serif_regular: SystemFont
static var _serif_italic: SystemFont
static var _display: SystemFont
static var _display_regular: SystemFont
static var _display_italic: SystemFont


static func serif_bold() -> Font:
	return UiTheme.serif()


static func serif() -> Font:
	if _serif_regular == null:
		_serif_regular = SystemFont.new()
		_serif_regular.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "serif"])
		_serif_regular.font_weight = 400
	return _serif_regular


static func serif_italic() -> Font:
	if _serif_italic == null:
		_serif_italic = SystemFont.new()
		_serif_italic.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "serif"])
		_serif_italic.font_weight = 400
		_serif_italic.font_italic = true
	return _serif_italic


## Serif de los rótulos grandes, como el título del menú principal. Palatino se diseñó a finales
## de los años cuarenta y encaja con la época; si el sistema no la tiene, se usa Georgia.
static func display_serif() -> Font:
	if _display == null:
		_display = _display_font(700, false)
	return _display


## La misma familia en redonda, para textos corridos que acompañan a los rótulos (el HUD).
static func display_serif_regular() -> Font:
	if _display_regular == null:
		_display_regular = _display_font(400, false)
	return _display_regular


## La misma familia en cursiva, para fechas y notas al pie de un rótulo.
static func display_serif_italic() -> Font:
	if _display_italic == null:
		_display_italic = _display_font(400, true)
	return _display_italic


static func _display_font(weight: int, italic: bool) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(DISPLAY_FONTS)
	font.font_weight = weight
	font.font_italic = italic
	return font


static func icon(icon_name: String) -> Texture2D:
	return load(ICONS % icon_name)


static func box(background: Color, border: Color, border_width: int, radius: int, margin: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	style.anti_aliasing = true
	return style


## Contorno dorado que marca el control enfocado, por fuera de su propio borde.
static func focus_ring(radius: int) -> StyleBoxFlat:
	var style := box(Color(0, 0, 0, 0), GOLD_LIGHT, 3, radius + 3)
	style.draw_center = false
	style.set_expand_margin_all(4.0)
	return style


## Botones de madera oscura con filete dorado: «Eliminar», «Volver» y los de los diálogos.
static func apply_wood_button(button: Button, font_size: int = 30) -> void:
	var normal := box(WOOD, GOLD, 2, 7, 14.0)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	var hover := box(WOOD_LIGHT, GOLD_LIGHT, 2, 7, 14.0)
	hover.shadow_color = normal.shadow_color
	hover.shadow_size = 8
	hover.shadow_offset = normal.shadow_offset
	var pressed := box(Color("1d130e"), GOLD, 2, 7, 14.0)
	var disabled := box(Color("4a3f36"), Color("6d5d4b"), 2, 7, 14.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus_ring(7))
	_apply_button_text(button, CREAM, font_size)


## Pestaña burdeos de la acción principal: «Cargar» o «Guardar».
static func apply_banner_button(button: Button, font_size: int = 36) -> void:
	var normal := box(BURGUNDY, GOLD, 3, 6, 16.0)
	normal.shadow_color = Color(0, 0, 0, 0.35)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	var hover := box(Color("8e2429"), GOLD_LIGHT, 3, 6, 16.0)
	hover.shadow_color = normal.shadow_color
	hover.shadow_size = 9
	hover.shadow_offset = normal.shadow_offset
	var pressed := box(BURGUNDY_DARK, GOLD, 3, 6, 16.0)
	var disabled := box(Color("6c4d48"), Color("9a8466"), 3, 6, 16.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus_ring(6))
	_apply_button_text(button, CREAM, font_size)


static func _apply_button_text(button: Button, color: Color, font_size: int) -> void:
	button.add_theme_font_override("font", serif_bold())
	button.add_theme_font_size_override("font_size", font_size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, color)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(key, color)
	button.add_theme_color_override("icon_disabled_color", DISABLED_TEXT)
	button.add_theme_constant_override("h_separation", 14)
	button.add_theme_constant_override("icon_max_width", 38)


static func style_label(label: Label, font: Font, font_size: int, color: Color) -> void:
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
