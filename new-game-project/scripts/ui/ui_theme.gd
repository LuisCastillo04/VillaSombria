class_name UiTheme
extends RefCounted
## Tema de la interfaz, inspirado en los expedientes policiales antiguos.
## Usa fuentes del sistema para no depender de archivos de terceros.

const PAPER := Color("d9cbaa")
const PAPER_LIGHT := Color("e6dabd")
const PAPER_DARK := Color("b5a482")
const INK := Color("1f1b16")
const INK_SOFT := Color("4a4237")
const STAMP := Color("8c2f2a")
const FOLDER := Color("3a2e24")
const FOLDER_DARK := Color("241c16")
const AMBER := Color("e8a33d")
const NIGHT := Color("0d1119")
const CORK := Color("6d5238")

static var _theme: Theme
static var _typewriter: SystemFont
static var _serif: SystemFont


## Libera las cachés al cerrar el juego.
static func clear() -> void:
	_theme = null
	_typewriter = null
	_serif = null


static func typewriter() -> Font:
	if _typewriter == null:
		_typewriter = SystemFont.new()
		_typewriter.font_names = PackedStringArray(["Courier New", "Liberation Mono", "DejaVu Sans Mono", "monospace"])
		_typewriter.font_weight = 600
	return _typewriter


static func serif() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Georgia", "Times New Roman", "Liberation Serif", "serif"])
		_serif.font_weight = 700
	return _serif


static func paper_box(color: Color = PAPER, border: Color = PAPER_DARK, margin: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	box.set_content_margin_all(margin)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 6
	box.shadow_offset = Vector2(2.0, 3.0)
	return box


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.default_font = typewriter()
	theme.default_font_size = 22

	theme.set_color("font_color", "Label", INK)
	theme.set_stylebox("panel", "PanelContainer", paper_box())
	theme.set_stylebox("panel", "Panel", paper_box())

	var normal := paper_box(PAPER, PAPER_DARK, 10)
	var hover := paper_box(PAPER_LIGHT, AMBER, 10)
	var pressed := paper_box(PAPER_DARK, STAMP, 10)
	var disabled := paper_box(Color("8d8370"), Color("6f6757"), 10)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", paper_box(Color(0, 0, 0, 0), STAMP, 10))
	theme.set_stylebox("disabled", "Button", disabled)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color("3f3a31"))

	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_font("normal_font", "RichTextLabel", typewriter())
	theme.set_font("bold_font", "RichTextLabel", serif())
	theme.set_font("italics_font", "RichTextLabel", typewriter())
	theme.set_font_size("bold_font_size", "RichTextLabel", 26)
	theme.set_font_size("italics_font_size", "RichTextLabel", 19)
	theme.set_font_size("normal_font_size", "RichTextLabel", 22)
	_theme = theme
	return theme
