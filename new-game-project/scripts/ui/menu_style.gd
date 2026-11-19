class_name MenuStyle
extends RefCounted
## Estilo de los menús oscuros (pausa, configuración y controles): panel negro azulado, filetes
## dorados, texto crema y burdeos para lo seleccionado. Las tipografías y los iconos vienen de
## CaseFileStyle, para que todo el juego comparta la misma letra.

const PANEL := Color("101116")
const GOLD := Color("b58b4a")
const TEXT := Color("f1deb9")
const TEXT_SECONDARY := Color("c5ad82")
const TEXT_MUTED := Color(0.77, 0.68, 0.51, 0.55)
const SELECTION := Color("8a2632")
const SELECTION_LIGHT := Color("c4515c")
const DIM := Color(0.02, 0.03, 0.05, 0.5)

const GRABBER := preload("res://assets/ui/deslizador.svg")
const GRABBER_ACTIVE := preload("res://assets/ui/deslizador_activo.svg")
const SWITCH_ON := preload("res://assets/ui/interruptor_si.svg")
const SWITCH_OFF := preload("res://assets/ui/interruptor_no.svg")


static func style_label(label: Label, font_size: int, color: Color = TEXT, font: Font = null) -> void:
	CaseFileStyle.style_label(label, font if font != null else CaseFileStyle.serif(), font_size, color)


static func make_label(text: String, font_size: int, color: Color = TEXT, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	style_label(label, font_size, color, font)
	return label


static func make_icon(icon_name: String, icon_size: float, color: Color = TEXT_SECONDARY) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = CaseFileStyle.icon(icon_name)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## Barra de volumen: carril oscuro, tramo recorrido en burdeos y perilla de marfil.
static func style_slider(slider: HSlider) -> void:
	var track := CaseFileStyle.box(Color(0.0, 0.0, 0.0, 0.45), Color(GOLD, 0.35), 1, 4)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var filled := CaseFileStyle.box(SELECTION, Color(SELECTION_LIGHT, 0.6), 1, 4)
	var filled_lit := CaseFileStyle.box(SELECTION.lightened(0.15), SELECTION_LIGHT, 1, 4)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled_lit)
	slider.add_theme_icon_override("grabber", GRABBER)
	slider.add_theme_icon_override("grabber_highlight", GRABBER_ACTIVE)
	slider.add_theme_stylebox_override("focus", CaseFileStyle.focus_ring(6))
	slider.custom_minimum_size.y = 32.0


## Interruptor de sí o no: el texto a la izquierda y la palanca a la derecha.
static func style_switch(button: CheckButton) -> void:
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 4.0
	empty.content_margin_right = 4.0
	for state: String in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_stylebox_override("focus", CaseFileStyle.focus_ring(6))
	for state: String in ["checked", "checked_disabled"]:
		button.add_theme_icon_override(state, SWITCH_ON)
	for state: String in ["unchecked", "unchecked_disabled"]:
		button.add_theme_icon_override(state, SWITCH_OFF)
	button.add_theme_font_override("font", CaseFileStyle.serif_bold())
	button.add_theme_font_size_override("font_size", 22)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, TEXT)
	button.add_theme_color_override("font_disabled_color", TEXT_MUTED)


## Barra de desplazamiento fina y dorada, para las páginas que no caben.
static func style_scroll_bar(bar: ScrollBar) -> void:
	var track := CaseFileStyle.box(Color(0.0, 0.0, 0.0, 0.35), Color(GOLD, 0.2), 1, 3)
	track.content_margin_left = 3.0
	track.content_margin_right = 3.0
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", CaseFileStyle.box(Color(GOLD, 0.65), Color(GOLD, 0.0), 0, 3))
	bar.add_theme_stylebox_override("grabber_highlight", CaseFileStyle.box(GOLD, Color(GOLD, 0.0), 0, 3))
	bar.add_theme_stylebox_override("grabber_pressed", CaseFileStyle.box(CaseFileStyle.GOLD_LIGHT, Color(GOLD, 0.0), 0, 3))


## Recuadro de una tecla: fondo oscuro, filete dorado y letra crema.
static func keycap_box() -> StyleBoxFlat:
	var style := CaseFileStyle.box(Color("17181e"), GOLD, 1, 5)
	style.border_width_bottom = 3
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 2.0
	return style


## Fila de una lista (controles, opciones pendientes): apenas un filete que la separa.
static func row_box(highlighted: bool = false) -> StyleBoxFlat:
	var style := CaseFileStyle.box(Color(0.0, 0.0, 0.0, 0.28), Color(GOLD, 0.2), 1, 4)
	if highlighted:
		style.bg_color = Color(SELECTION, 0.22)
		style.border_color = Color(GOLD, 0.85)
	style.content_margin_left = 16.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


## Etiqueta discreta de una función que todavía no existe.
static func make_soon_badge() -> Label:
	var badge := make_label("PRÓXIMAMENTE", 14, TEXT_SECONDARY, CaseFileStyle.serif_bold())
	var style := CaseFileStyle.box(Color(0.0, 0.0, 0.0, 0.0), Color(GOLD, 0.45), 1, 3)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	badge.add_theme_stylebox_override("normal", style)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return badge
