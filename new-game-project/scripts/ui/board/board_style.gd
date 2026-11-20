class_name BoardStyle
extends RefCounted
## Estilo del tablero de deducción en un solo sitio: paleta, letras, medidas, tiempos y recuadros.
##
## Parte del estilo del expediente (`JournalStyle`), del HUD (`HudStyle`) y de las pantallas de
## guardar (`CaseFileStyle`): el tablero es el mismo cuero, el mismo pergamino y los mismos dorados,
## con un corcho para las pruebas. Las medidas están en el lienzo lógico de 1920 × 1080: el
## estiramiento `canvas_items` del proyecto las escala con la ventana.

# --- Paleta ---

const CHARCOAL := Color("101116")
## Cuero marrón oscuro del marco, algo menos rojizo que la carpeta del expediente.
const LEATHER := Color("321b16")
const LEATHER_DARK := Color("1b0e0a")
const LEATHER_SHEEN := Color("4f2d22")
const BROWN := Color("49301f")
const PARCHMENT := HudStyle.PARCHMENT
const PARCHMENT_LIGHT := JournalStyle.PARCHMENT_LIGHT
const PARCHMENT_STAIN := JournalStyle.PARCHMENT_STAIN
const PARCHMENT_EDGE := JournalStyle.PARCHMENT_EDGE
const CREAM := Color("f1deb9")
const GOLD := Color("b58b4a")
const GOLD_LIGHT := JournalStyle.GOLD_LIGHT
const GOLD_DARK := JournalStyle.GOLD_DARK
const BURGUNDY := Color("761523")
const BURGUNDY_INK := JournalStyle.BURGUNDY_INK
const BURGUNDY_DARK := JournalStyle.BURGUNDY_DARK
const INK := Color("38281d")
const INK_SOFT := JournalStyle.INK_SOFT
const FRAME := JournalStyle.FRAME
const DIM := JournalStyle.DIM
const BRASS := JournalStyle.BRASS
const BRASS_LIGHT := JournalStyle.BRASS_LIGHT
## Corcho del tablero: tostado claro, con gránulos más oscuros y motas claras.
const CORK := Color("c09f70")
const CORK_DARK := Color("86643e")
const CORK_LIGHT := Color("dcc59b")
## Hilo rojo de las relaciones registradas y su sombra.
const THREAD := Color("9b1c24")
const THREAD_DARK := Color("4a0b0f")
## Papel de cada tipo de ficha, el color de su rótulo y el de su chincheta.
const PAPERS := {"pista": Color("efe1c0"), "testimonio": Color("e3dcc8"), "deduccion": Color("ecd4bc")}
const TAGS := {"pista": BURGUNDY, "testimonio": Color("4b3826"), "deduccion": Color("6b4a1f")}
const PINS := {"pista": Color("b3262a"), "testimonio": Color("c49a3c"), "deduccion": Color("5c1119")}
## Ficha descartada: el pergamino algo gris y la tinta más clara, sin dejar de leerse.
const DISCARDED_PAPER := Color("cfc3a8")
const DISCARDED_INK := Color("6a5a49")

# --- Medidas, en el lienzo lógico de 1920 × 1080 ---

## Margen del tablero respecto a la pantalla y ancho máximo, para pantallas ultrapanorámicas.
const FRAME_MARGIN := Vector2(64.0, 34.0)
const FRAME_MAX_WIDTH := 1800.0
const FRAME_BORDER := 12.0
## Separación del contenido respecto al borde de cuero.
const CONTENT_INSET := 26.0
const HEADER_HEIGHT := 112.0
const SEAL_SIZE := Vector2(300.0, 142.0)
const ROW_HEIGHT := 104.0
const ROW_TOP_GAP := 12.0
const BODY_TOP_GAP := 14.0
const BODY_GAP := 18.0
## La columna de comparación ocupa esta parte del ancho, entre un mínimo y un máximo.
const SIDE_RATIO := 0.27
const SIDE_MIN_WIDTH := 380.0
const SIDE_MAX_WIDTH := 500.0
const SUSPECT_CARD_MIN_WIDTH := 200.0
const SUSPECT_CARD_HEIGHT := 92.0
const SUSPECT_GAP := 14.0
const SUSPECT_PORTRAIT := Vector2(64.0, 80.0)
## Grosor del marco de cuero del corcho.
const CANVAS_BORDER := 14.0
const CANVAS_PADDING := Vector2(30.0, 26.0)
const CARD_SIZE := Vector2(250.0, 124.0)
const CARD_GAP := Vector2(30.0, 40.0)
const GROUP_LABEL_HEIGHT := 46.0
const GROUP_GAP := 18.0
## Tamaño máximo del panel de hipótesis; en pantallas pequeñas se ajusta al corcho.
const EDITOR_SIZE := Vector2(640.0, 620.0)
const PIN_RADIUS := 7.0

# --- Tamaños de letra ---

const TITLE_SIZE := 44
const TITLE_MIN_SIZE := 30
const HEADER_SIZE := 27
const HELP_SIZE := 26
const SUSPECT_NAME_SIZE := 27
const SUSPECT_STATUS_SIZE := 22
const CARD_TAG_SIZE := 15
const CARD_TITLE_SIZE := 21
const CARD_SUBTITLE_SIZE := 17
const GROUP_SIZE := 18
const PANEL_TITLE_SIZE := 32
const SLOT_TAG_SIZE := 16
const SLOT_TITLE_SIZE := 26
const SLOT_TEXT_SIZE := 22
const FACT_SIZE := 19
const BUTTON_SIZE := 28
const RESULT_TITLE_SIZE := 23
const RESULT_SIZE := 21
const EDITOR_TITLE_SIZE := 32
const OPTION_SIZE := 26
const NOTE_SIZE := 23
const SMALL_SIZE := 18
const EMPTY_SIZE := 24

# --- Tiempos, en segundos ---

const OPEN_SECONDS := 0.24
const CLOSE_SECONDS := 0.16
const OPEN_SCALE := 0.975
const EDITOR_SECONDS := 0.18
const SELECT_SECONDS := 0.14
const THREAD_SECONDS := 0.7
const PULSE_SECONDS := 0.7
const FEEDBACK_SECONDS := 0.32
const TOAST_SECONDS := 2.4

const ASSETS := "res://assets/ui/tablero/%s"


# --- Letras ---

static func title_font() -> Font:
	return JournalStyle.title_font()


static func heading_font() -> Font:
	return JournalStyle.heading_font()


static func body_font() -> Font:
	return JournalStyle.body_font()


static func italic_font() -> Font:
	return JournalStyle.italic_font()


static func banner_font() -> Font:
	return JournalStyle.banner_font()


# --- Piezas sueltas ---

static func icon(icon_name: String) -> Texture2D:
	return HudStyle.icon(icon_name)


static func asset(file_name: String) -> Texture2D:
	return load(ASSETS % file_name)


static func make_label(text: String, font: Font, font_size: int, color: Color, wrap: bool = false) -> Label:
	return JournalStyle.make_label(text, font, font_size, color, wrap)


static func make_icon(icon_name: String, icon_size: float, color: Color) -> TextureRect:
	return JournalStyle.make_icon(icon_name, icon_size, color)


static func make_rule(color: Color = Color(INK, 0.55)) -> GoldDivider:
	return JournalStyle.make_rule(color)


static func box(background: Color, border: Color, border_width: int, radius: int, margin: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
	return JournalStyle.box(background, border, border_width, radius, margin)


static func focus_ring(radius: int = 4) -> StyleBoxFlat:
	return JournalStyle.focus_ring(radius)


## Barra de desplazamiento fina en tinta, la de las listas del expediente.
static func style_scroll(scroll: ScrollContainer) -> void:
	JournalStyle.style_scroll(scroll)


## La misma barra, en horizontal y en dorado sobre el cuero: la fila de sospechosos.
static func style_hscroll(scroll: ScrollContainer) -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar := scroll.get_h_scroll_bar()
	var track := box(Color(0.0, 0.0, 0.0, 0.3), Color(GOLD, 0.3), 1, 3, Vector4(0.0, 3.0, 0.0, 3.0))
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", box(Color(GOLD, 0.7), Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_highlight", box(GOLD_LIGHT, Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_pressed", box(BURGUNDY, Color(0, 0, 0, 0), 0, 3))


# --- Botones ---

## Botón de la acción principal: placa burdeos con filete dorado («Relacionar», «Guardar hipótesis»).
## Desactivado, es una placa de pergamino gastado que no llama la atención.
static func apply_primary_button(button: Button, font_size: int = BUTTON_SIZE) -> void:
	var normal := box(BURGUNDY, GOLD, 2, 4, Vector4(24.0, 10.0, 24.0, 12.0))
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0.0, 3.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("8e2129")
	hover.border_color = GOLD_LIGHT
	hover.shadow_color = Color(BURGUNDY, 0.55)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2.ZERO
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = BURGUNDY_DARK
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0.0, 1.0)
	var disabled := box(Color("b5a88c"), Color("8c7c60"), 2, 4, Vector4(24.0, 10.0, 24.0, 12.0))
	disabled.shadow_color = Color(0.0, 0.0, 0.0, 0.2)
	disabled.shadow_size = 3
	disabled.shadow_offset = Vector2(0.0, 2.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus_ring(4))
	button.add_theme_font_override("font", heading_font())
	button.add_theme_font_size_override("font_size", font_size)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, CREAM)
	button.add_theme_color_override("font_disabled_color", Color("6d604d"))
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.35))
	button.add_theme_constant_override("shadow_offset_y", 1)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Botón de texto sin recuadro, en tinta y burdeos al señalarlo: «[B] Cerrar», «Descartar cambios».
static func apply_text_button(button: Button, font: Font, font_size: int, color: Color = INK) -> void:
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, empty)
	button.add_theme_stylebox_override("focus", focus_ring(3))
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_hover_color", BURGUNDY)
	button.add_theme_color_override("font_pressed_color", BURGUNDY_DARK)
	button.add_theme_color_override("font_hover_pressed_color", BURGUNDY_DARK)
	button.add_theme_color_override("icon_normal_color", color)
	button.add_theme_color_override("icon_hover_color", BURGUNDY)
	button.add_theme_color_override("icon_pressed_color", BURGUNDY_DARK)
	button.add_theme_color_override("icon_focus_color", color)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# --- Selector de valoración ---

## Selector desplegable en pergamino claro con filete dorado, flecha burdeos y una lista oscura con
## la opción señalada en burdeos y marcas redondas, como el resto de menús del juego.
static func apply_option_button(option: OptionButton) -> void:
	var normal := box(PARCHMENT_LIGHT, GOLD, 2, 4, Vector4(18.0, 8.0, 14.0, 8.0))
	normal.shadow_color = Color(0.25, 0.15, 0.08, 0.25)
	normal.shadow_size = 3
	normal.shadow_offset = Vector2(0.0, 2.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("f8eed4")
	hover.border_color = GOLD_LIGHT
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.border_color = BURGUNDY
	for state: String in ["normal", "normal_mirrored"]:
		option.add_theme_stylebox_override(state, normal)
	for state: String in ["hover", "hover_mirrored"]:
		option.add_theme_stylebox_override(state, hover)
	for state: String in ["pressed", "pressed_mirrored"]:
		option.add_theme_stylebox_override(state, pressed)
	option.add_theme_stylebox_override("focus", focus_ring(4))
	option.add_theme_font_override("font", heading_font())
	option.add_theme_font_size_override("font_size", OPTION_SIZE)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		option.add_theme_color_override(key, INK)
	option.add_theme_icon_override("arrow", asset("desplegable.svg"))
	option.add_theme_constant_override("arrow_margin", 14)
	option.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var popup := option.get_popup()
	var panel := box(Color("1d1411", 0.98), GOLD_DARK, 2, 3, Vector4(4.0, 6.0, 4.0, 6.0))
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel.shadow_size = 10
	panel.shadow_offset = Vector2(0.0, 4.0)
	popup.add_theme_stylebox_override("panel", panel)
	popup.add_theme_stylebox_override("hover", box(BURGUNDY, Color(GOLD_LIGHT, 0.6), 1, 2))
	popup.add_theme_font_override("font", body_font())
	popup.add_theme_font_size_override("font_size", OPTION_SIZE - 2)
	popup.add_theme_color_override("font_color", CREAM)
	popup.add_theme_color_override("font_hover_color", CREAM)
	popup.add_theme_icon_override("radio_checked", asset("radio_si.svg"))
	popup.add_theme_icon_override("radio_unchecked", asset("radio_no.svg"))
	popup.add_theme_constant_override("v_separation", 12)
	popup.add_theme_constant_override("h_separation", 14)
	popup.add_theme_constant_override("item_start_padding", 14)
	popup.add_theme_constant_override("item_end_padding", 18)


# --- Campo de escritura ---

## Recuadro hundido y oscuro donde se escribe la hipótesis: tinta clara sobre sepia, como un
## cuaderno de notas, con filete dorado cuando tiene el foco.
static func apply_text_edit(text_edit: TextEdit) -> void:
	var normal := box(Color(0.2, 0.145, 0.1, 0.68), Color(INK, 0.6), 1, 3, Vector4(16.0, 12.0, 16.0, 12.0))
	normal.shadow_color = Color(1.0, 0.97, 0.88, 0.3)
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(0.0, 1.0)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	text_edit.add_theme_stylebox_override("normal", normal)
	text_edit.add_theme_stylebox_override("focus", focus)
	text_edit.add_theme_stylebox_override("read_only", normal)
	# En cursiva, como una nota escrita a mano en el cuaderno.
	text_edit.add_theme_font_override("font", italic_font())
	text_edit.add_theme_font_size_override("font_size", NOTE_SIZE)
	text_edit.add_theme_color_override("font_color", CREAM)
	text_edit.add_theme_color_override("font_placeholder_color", Color(CREAM, 0.55))
	text_edit.add_theme_color_override("caret_color", GOLD_LIGHT)
	text_edit.add_theme_color_override("selection_color", Color(BURGUNDY, 0.7))
	text_edit.add_theme_color_override("font_selected_color", CREAM)
	text_edit.add_theme_constant_override("line_spacing", 6)
	var bar := text_edit.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", box(Color(0.0, 0.0, 0.0, 0.15), Color(0, 0, 0, 0), 0, 3, Vector4(3.0, 0.0, 3.0, 0.0)))
	bar.add_theme_stylebox_override("grabber", box(Color(GOLD, 0.75), Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_highlight", box(GOLD_LIGHT, Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_pressed", box(BURGUNDY, Color(0, 0, 0, 0), 0, 3))


# --- Fichas ---

## Rótulo del tipo de una ficha («PRUEBA»): una cinta del color del tipo con letra crema.
static func tag_box(kind: String) -> StyleBoxFlat:
	var style := box(TAGS.get(kind, BURGUNDY), Color(GOLD, 0.65), 1, 2, Vector4(10.0, 2.0, 10.0, 3.0))
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 1.0)
	return style


static func paper_color(kind: String) -> Color:
	return PAPERS.get(kind, PARCHMENT)


static func pin_color(kind: String) -> Color:
	return PINS.get(kind, PINS["pista"])
