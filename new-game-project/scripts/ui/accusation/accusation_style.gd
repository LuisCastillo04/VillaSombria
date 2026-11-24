class_name AccusationStyle
extends RefCounted
## Estilo de la acusación formal en un solo sitio: paleta, letras, medidas, tiempos y recuadros.
##
## Es el mismo pergamino, el mismo burdeos y los mismos dorados del expediente (`JournalStyle`) y de
## la inspección de evidencias (`EvidenceStyle`): presentar la acusación es rellenar una hoja más del
## caso. Las medidas están en el lienzo lógico de 1920 × 1080; si la ventana (o el tamaño de letra de
## Accesibilidad) deja menos sitio, la interfaz escala la hoja y el panel enteros.

# --- Paleta ---

const PAPER := JournalStyle.PARCHMENT
const PAPER_LIGHT := JournalStyle.PARCHMENT_LIGHT
const PAPER_STAIN := JournalStyle.PARCHMENT_STAIN
const PAPER_EDGE := JournalStyle.PARCHMENT_EDGE
## Tinta del texto sobre el papel y su versión apagada (textos de ayuda, campos sin rellenar).
const INK := Color("2e2017")
const INK_SOFT := JournalStyle.INK_SOFT
const BURGUNDY := EvidenceStyle.BURGUNDY
const BURGUNDY_LIGHT := EvidenceStyle.BURGUNDY_LIGHT
const BURGUNDY_DARK := EvidenceStyle.BURGUNDY_DARK
const BURGUNDY_INK := JournalStyle.BURGUNDY_INK
const GOLD := EvidenceStyle.GOLD
const GOLD_LIGHT := EvidenceStyle.GOLD_LIGHT
const GOLD_DARK := EvidenceStyle.GOLD_DARK
const CREAM := EvidenceStyle.CREAM
const CREAM_SOFT := EvidenceStyle.CREAM_SOFT
const CHARCOAL := EvidenceStyle.CHARCOAL
const CHARCOAL_LIGHT := EvidenceStyle.CHARCOAL_LIGHT
## Marco de la hoja: un burdeos muy oscuro, casi vino, con su borde más negro.
const FRAME := Color("3b0f14")
const FRAME_DARK := Color("1f0709")
const SHADOW := Color(0.0, 0.0, 0.0, 0.55)
## Velo sobre el escenario mientras la acusación está abierta.
const DIM := Color(0.02, 0.025, 0.035, 0.8)

# --- Medidas, en el lienzo lógico de 1920 × 1080 ---

## Tamaño de diseño de la hoja y del panel lateral, y el hueco entre ambos.
const SHEET_SIZE := Vector2(880.0, 1010.0)
const PANEL_SIZE := Vector2(600.0, 880.0)
const PANEL_GAP := 34.0
## Margen mínimo respecto a los bordes de la pantalla.
const SCREEN_MARGIN := Vector2(36.0, 30.0)
## Grosor del marco burdeos alrededor del papel.
const FRAME_WIDTH := 16.0
const HEADER_HEIGHT := 140.0
const MEDALLION := 46.0
const RIBBON_HEIGHT := 38.0
const SELECTOR_HEIGHT := 52.0
## Sangría del selector respecto al medallón de su campo.
const SELECTOR_INDENT := 62.0
const BUTTON_HEIGHT := 70.0
const PANEL_HEADER_HEIGHT := 92.0
const ROW_HEIGHT := 50.0
const SUSPECT_ROW_HEIGHT := 70.0
const PORTRAIT_SIZE := 52.0

# --- Tamaños de letra ---

const TITLE_SIZE := 54
const TITLE_MIN_SIZE := 34
const RIBBON_SIZE := 23
const SELECTOR_SIZE := 27
const VERDICT_SIZE := 26
const STATUS_SIZE := 20
const BUTTON_SIZE := 28
const PANEL_TITLE_SIZE := 29
const PANEL_SUBTITLE_SIZE := 20
const ROW_SIZE := 24
const GROUP_SIZE := 17
const SEARCH_SIZE := 22
const PREVIEW_TITLE_SIZE := 22
const PREVIEW_SIZE := 20
const EMPTY_SIZE := 23
const HINT_SIZE := 20
const SUSPECT_NAME_SIZE := 26
const SUSPECT_ROLE_SIZE := 19

# --- Tiempos, en segundos ---

const OPEN_SECONDS := 0.26
const CLOSE_SECONDS := 0.17
const OPEN_SCALE := 0.975
## Paso de una hoja centrada a la hoja con el panel al lado, y vuelta.
const SPLIT_SECONDS := 0.28
## Recorrido del panel al entrar desde la derecha.
const PANEL_SLIDE := 48.0
const LIST_OPEN_SECONDS := 0.16
const LIST_CLOSE_SECONDS := 0.11
const VERDICT_SECONDS := 0.3

## Icono de cada clase de información (`EvidenceCategories.TYPES`) y su nombre.
const TYPE_ICONS := {
	"documento": "documento",
	"carta": "carta",
	"fotografia": "fotografia",
	"objeto": "etiqueta",
	"registro": "libro",
	"informe": "carpeta",
	"testimonio": "testigos",
	"deduccion": "cerebro",
}
const TYPE_NAMES := {
	"documento": "Documento",
	"carta": "Carta",
	"fotografia": "Fotografía",
	"objeto": "Objeto",
	"registro": "Registro",
	"informe": "Informe",
	"testimonio": "Testimonio",
	"deduccion": "Deducción",
}

static var _title_font: FontVariation
static var _ribbon_font: FontVariation


# --- Letras ---

## Rótulo «ACUSACIÓN FORMAL»: la Palatino en negrita de los demás rótulos, algo espaciada.
static func title_font() -> Font:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = CaseFileStyle.display_serif()
		_title_font.spacing_glyph = 1
	return _title_font


static func heading_font() -> Font:
	return CaseFileStyle.display_serif()


static func body_font() -> Font:
	return CaseFileStyle.display_serif_regular()


static func italic_font() -> Font:
	return CaseFileStyle.display_serif_italic()


## Letra de las cintas de cada campo, algo espaciada.
static func ribbon_font() -> Font:
	if _ribbon_font == null:
		_ribbon_font = FontVariation.new()
		_ribbon_font.base_font = CaseFileStyle.display_serif_regular()
		_ribbon_font.spacing_glyph = 1
	return _ribbon_font


# --- Piezas sueltas ---

static func icon(icon_name: String) -> Texture2D:
	return HudStyle.icon(icon_name)


static func type_icon_name(type_id: String) -> String:
	return TYPE_ICONS.get(type_id, "documento")


static func type_icon(type_id: String) -> Texture2D:
	return icon(type_icon_name(type_id))


static func type_label(type_id: String) -> String:
	return TYPE_NAMES.get(type_id, "Prueba")


static func make_label(text: String, font: Font, font_size: int, color: Color, wrapped: bool = false) -> Label:
	return JournalStyle.make_label(text, font, font_size, color, wrapped)


static func make_icon(icon_name: String, icon_size: float, color: Color) -> TextureRect:
	return HudStyle.make_icon(icon(icon_name), icon_size, color)


static func box(background: Color, border: Color, border_width: int, radius: int, margin: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
	return JournalStyle.box(background, border, border_width, radius, margin)


static func focus_ring(radius: int = 4) -> StyleBoxFlat:
	return CaseFileStyle.focus_ring(radius)


## Filete de tinta con un rombo en el centro.
static func make_rule(color: Color = Color(BURGUNDY_INK, 0.6)) -> GoldDivider:
	return JournalStyle.make_rule(color)


# --- Selectores del formulario ---

## Recuadro de un selector. `state` es "empty" (pendiente), "filled" (con una elección), "hover" o
## "active" (su lista está abierta). Lo pendiente es más claro y de filete fino; lo elegido, papel
## claro con filete dorado. Ninguno dice si la elección es buena.
static func selector_box(state: String) -> StyleBoxFlat:
	var style := box(Color(PAPER_LIGHT, 0.42), Color(INK, 0.34), 1, 4, Vector4(18.0, 6.0, 52.0, 6.0))
	style.shadow_color = Color(0.25, 0.15, 0.08, 0.16)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0.0, 2.0)
	match state:
		"filled":
			style.bg_color = Color(PAPER_LIGHT, 0.9)
			style.border_color = GOLD_DARK
			style.set_border_width_all(2)
			style.shadow_color = Color(0.25, 0.15, 0.08, 0.28)
			style.shadow_size = 4
		"hover":
			style.bg_color = Color("f8eed4")
			style.border_color = GOLD
			style.set_border_width_all(2)
			style.shadow_color = Color(GOLD_LIGHT, 0.6)
			style.shadow_size = 6
			style.shadow_offset = Vector2.ZERO
		"active":
			style.bg_color = Color("f8eed4")
			style.border_color = BURGUNDY
			style.set_border_width_all(3)
			style.shadow_color = Color(BURGUNDY, 0.4)
			style.shadow_size = 9
			style.shadow_offset = Vector2.ZERO
	return style


# --- Botones ---

## Placa con las esquinas en chaflán: la de «Presentar la acusación» (`primary`, burdeos) o la de
## «Seguir investigando» (carbón). Desactivada, es una placa gastada que no llama la atención.
static func apply_plate_button(button: Button, primary: bool) -> void:
	var fill := BURGUNDY if primary else CHARCOAL_LIGHT
	var normal := box(fill, GOLD, 2, 12, Vector4(30.0, 8.0, 30.0, 10.0))
	normal.corner_detail = 1
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	normal.shadow_size = 7
	normal.shadow_offset = Vector2(0.0, 4.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = BURGUNDY_LIGHT if primary else Color("3a3127")
	hover.border_color = GOLD_LIGHT
	hover.shadow_color = Color(BURGUNDY if primary else GOLD_DARK, 0.55)
	hover.shadow_size = 12
	hover.shadow_offset = Vector2.ZERO
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = BURGUNDY_DARK if primary else CHARCOAL
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0.0, 1.0)
	var disabled := box(Color("8f7f68"), Color("6d604d"), 2, 12, Vector4(30.0, 8.0, 30.0, 10.0))
	disabled.corner_detail = 1
	disabled.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	disabled.shadow_size = 3
	disabled.shadow_offset = Vector2(0.0, 2.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus_ring(12))
	button.add_theme_font_override("font", body_font())
	button.add_theme_font_size_override("font_size", BUTTON_SIZE)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, CREAM)
	button.add_theme_color_override("font_disabled_color", Color("d8cbb2"))
	button.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.4))
	button.add_theme_constant_override("shadow_offset_y", 1)
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(key, CREAM)
	button.add_theme_color_override("icon_disabled_color", Color("d8cbb2"))
	button.add_theme_constant_override("h_separation", 18)
	button.add_theme_constant_override("icon_max_width", 40)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# --- Listas ---

## Fila de una lista (pruebas o sospechosos). `state` es "normal", "hover" o "selected"; la elegida va
## en burdeos con filete dorado, como en el resto de menús del juego.
static func row_box(state: String) -> StyleBoxFlat:
	var style := box(Color(PAPER_LIGHT, 0.0), Color(0, 0, 0, 0), 0, 4, Vector4(12.0, 4.0, 36.0, 4.0))
	match state:
		"hover":
			style.bg_color = Color(PAPER_LIGHT, 0.85)
			style.border_color = Color(GOLD_DARK, 0.8)
			style.set_border_width_all(1)
		"selected":
			style.bg_color = BURGUNDY
			style.border_color = GOLD
			style.set_border_width_all(2)
			style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
			style.shadow_size = 4
			style.shadow_offset = Vector2(0.0, 2.0)
		"selected_hover":
			style.bg_color = BURGUNDY_LIGHT
			style.border_color = GOLD_LIGHT
			style.set_border_width_all(2)
			style.shadow_color = Color(BURGUNDY, 0.5)
			style.shadow_size = 7
	return style


## Barra de desplazamiento burdeos sobre un carril de tinta, con flechas en los extremos.
static func style_scroll(scroll: ScrollContainer) -> void:
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar := scroll.get_v_scroll_bar()
	var track := box(Color(INK, 0.1), Color(INK, 0.22), 1, 4, Vector4(4.0, 2.0, 4.0, 2.0))
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", box(BURGUNDY, Color(GOLD_DARK, 0.9), 1, 4))
	bar.add_theme_stylebox_override("grabber_highlight", box(BURGUNDY_LIGHT, GOLD, 1, 4))
	bar.add_theme_stylebox_override("grabber_pressed", box(BURGUNDY_DARK, GOLD, 1, 4))
	var arrow_up := load("res://assets/ui/acusacion/flecha_arriba.svg") as Texture2D
	var arrow_down := load("res://assets/ui/acusacion/flecha_abajo.svg") as Texture2D
	for key: String in ["decrement", "decrement_highlight", "decrement_pressed"]:
		bar.add_theme_icon_override(key, arrow_up)
	for key: String in ["increment", "increment_highlight", "increment_pressed"]:
		bar.add_theme_icon_override(key, arrow_down)
	bar.custom_minimum_size.x = 16.0


## Campo de búsqueda del panel: papel claro hundido con un filete de tinta; dorado con el foco.
static func apply_search(line: LineEdit) -> void:
	var normal := box(Color(PAPER_LIGHT, 0.7), Color(INK, 0.35), 1, 4, Vector4(46.0, 6.0, 14.0, 6.0))
	normal.shadow_color = Color(1.0, 0.98, 0.9, 0.4)
	normal.shadow_size = 1
	normal.shadow_offset = Vector2(0.0, 1.0)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	focus.bg_color = Color("f8eed4")
	line.add_theme_stylebox_override("normal", normal)
	line.add_theme_stylebox_override("focus", focus)
	line.add_theme_font_override("font", italic_font())
	line.add_theme_font_size_override("font_size", SEARCH_SIZE)
	line.add_theme_color_override("font_color", INK)
	line.add_theme_color_override("font_placeholder_color", Color(INK_SOFT, 0.75))
	line.add_theme_color_override("caret_color", BURGUNDY)
	line.add_theme_color_override("selection_color", Color(BURGUNDY, 0.35))
	line.add_theme_color_override("clear_button_color", INK_SOFT)
	line.add_theme_color_override("clear_button_color_pressed", BURGUNDY)
