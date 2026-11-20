class_name JournalTab
extends Button
## Pestaña de la carpeta del expediente: placa oscura con filete dorado y las esquinas cortadas; la
## elegida, burdeos con un brillo cálido. Recibir el foco con el teclado o el mando también la elige,
## así basta con ir a izquierda y derecha para recorrer las secciones.

const MIN_INSET := 12.0

var _compact := false
## Margen a cada lado que centra el icono y el texto juntos en el ancho de la pestaña.
var _inset := -1.0


func _init(label: String = "", icon_name: String = "") -> void:
	text = label
	if not icon_name.is_empty():
		icon = JournalStyle.icon(icon_name)
	toggle_mode = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size.y = JournalStyle.TAB_HEIGHT
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(_on_focus_entered)
	_apply_styles()


## Versión estrecha para pantallas de poco ancho: letra y márgenes menores.
func set_compact(compact: bool) -> void:
	if compact == _compact:
		return
	_compact = compact
	_inset = -1.0
	_apply_styles()


func is_compact() -> bool:
	return _compact


## Fija el ancho de la pestaña y centra en él el icono y el texto como un solo grupo.
func fit(width: float) -> void:
	var natural := _natural_width()
	_inset = maxf(floorf((width - natural) * 0.5), MIN_INSET)
	_apply_styles()
	custom_minimum_size.x = width


## Ancho que necesitan el icono y el texto, con un margen mínimo a cada lado.
func get_content_width() -> float:
	return _natural_width() + MIN_INSET * 2.0


## Ancho del icono y el texto tal como los mide el propio botón, sin márgenes ni mínimo impuesto.
func _natural_width() -> float:
	var saved_inset := _inset
	var saved_minimum := custom_minimum_size.x
	_inset = 0.0
	_apply_styles()
	custom_minimum_size.x = 0.0
	var natural := get_combined_minimum_size().x
	custom_minimum_size.x = saved_minimum
	_inset = saved_inset
	_apply_styles()
	return natural


func _on_focus_entered() -> void:
	if not button_pressed:
		button_pressed = true


func _apply_styles() -> void:
	for pair: Array in [["normal", "normal"], ["hover", "hover"], ["pressed", "selected"], ["hover_pressed", "selected"]]:
		var style := JournalStyle.tab_box(pair[1], _compact)
		if _inset >= 0.0:
			style.content_margin_left = _inset
			style.content_margin_right = _inset
		add_theme_stylebox_override(pair[0], style)
	var focus := JournalStyle.focus_ring(10)
	focus.corner_detail = 1
	add_theme_stylebox_override("focus", focus)
	add_theme_font_override("font", JournalStyle.body_font())
	add_theme_font_size_override("font_size", JournalStyle.TAB_SIZE_COMPACT if _compact else JournalStyle.TAB_SIZE)
	for key: String in ["font_color", "font_focus_color"]:
		add_theme_color_override(key, JournalStyle.CREAM_SOFT)
	add_theme_color_override("font_hover_color", JournalStyle.CREAM)
	for key: String in ["font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(key, JournalStyle.CREAM)
	for key: String in ["icon_normal_color", "icon_focus_color"]:
		add_theme_color_override(key, JournalStyle.CREAM_SOFT)
	add_theme_color_override("icon_hover_color", JournalStyle.CREAM)
	for key: String in ["icon_pressed_color", "icon_hover_pressed_color"]:
		add_theme_color_override(key, Color("fff3dc"))
	add_theme_constant_override("icon_max_width", JournalStyle.TAB_ICON - (6 if _compact else 0))
	add_theme_constant_override("h_separation", 10 if _compact else 14)
