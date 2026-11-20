class_name JournalStyle
extends RefCounted
## Estilo del expediente en un solo sitio: paleta, letras, medidas, tiempos y recuadros.
##
## Parte de la paleta de los menús (`MenuStyle`), del HUD (`HudStyle`) y de las pantallas de
## guardar (`CaseFileStyle`), para que el expediente sea la misma carpeta de cuero y pergamino que
## el resto del juego. Las medidas están en el lienzo lógico de 1920 × 1080: el estiramiento
## `canvas_items` del proyecto las escala con la ventana.

# --- Paleta ---

## Cuero rojizo de la carpeta y su versión más oscura, la del hueco donde van las páginas.
const LEATHER := Color("4b1f17")
const LEATHER_DARK := Color("2c130e")
const LEATHER_DEEP := Color("1b0b08")
## Pergamino de las páginas: más tostado que el del HUD, como papel guardado años en una carpeta.
const PARCHMENT := Color("e5cea2")
const PARCHMENT_LIGHT := Color("f3e7c9")
const PARCHMENT_STAIN := Color("c9a46f")
const PARCHMENT_EDGE := Color("8a6034")
const INK := HudStyle.INK
const INK_SOFT := Color("5c4430")
## Burdeos de los rótulos sobre pergamino: un punto más oscuro que el de las cintas para leerse bien.
const BURGUNDY_INK := Color("6e1a1e")
const BURGUNDY := HudStyle.BURGUNDY
const BURGUNDY_DARK := Color("561219")
const GOLD := HudStyle.GOLD
const GOLD_LIGHT := HudStyle.GOLD_LIGHT
const GOLD_DARK := Color("7d5c2c")
const CREAM := HudStyle.CREAM
const CREAM_SOFT := HudStyle.CREAM_SOFT
## Pestañas inactivas: casi negro con un punto de marrón.
const TAB_FILL := Color("1d1411")
const TAB_HOVER := Color("33221b")
const FRAME := HudStyle.FRAME
const SHADOW := Color(0.0, 0.0, 0.0, 0.5)
const DIM := Color(0.02, 0.025, 0.035, 0.8)
## Latón del clip de las fotografías.
const BRASS := Color("b07a3c")
const BRASS_LIGHT := Color("e9b977")

# --- Medidas, en el lienzo lógico de 1920 × 1080 ---

## Margen de la carpeta respecto a la pantalla y ancho máximo, para pantallas ultrapanorámicas.
const FOLDER_MARGIN := Vector2(86.0, 46.0)
const FOLDER_MAX_WIDTH := 1760.0
## Grosor de la banda de cuero alrededor de todo.
const FOLDER_BORDER := 12.0
const HEADER_HEIGHT := 138.0
const TAB_HEIGHT := 62.0
const TAB_GAP := 8.0
const TAB_ICON := 34
## Separación entre la columna de la lista y la de los detalles.
const COLUMN_GAP := 18.0
const LIST_RATIO := 0.31
const LIST_MIN_WIDTH := 400.0
const LIST_MAX_WIDTH := 540.0
const BANNER_HEIGHT := 54.0
const ROW_HEIGHT := 62.0
const ROW_GAP := 10.0
const THUMB_SIZE := 48.0
const BADGE_SIZE := 78.0
const PHOTO_WIDTH := 312.0
## Una ilustración decorativa sólo aparece si le queda al menos esta altura libre.
const ART_MIN_HEIGHT := 120.0
const FOOTER_HEIGHT := 46.0

# --- Tamaños de letra ---

const TITLE_SIZE := 46
const TAB_SIZE := 27
const TAB_SIZE_COMPACT := 21
const BANNER_SIZE := 25
const ROW_SIZE := 25
const ROW_SUBTITLE_SIZE := 19
const DETAIL_TITLE_SIZE := 44
const DETAIL_SUBTITLE_SIZE := 26
const BODY_SIZE := 26
const FIELD_SIZE := 27
const SECTION_SIZE := 21
const NOTE_SIZE := 22
const EMPTY_TITLE_SIZE := 36
const EMPTY_TEXT_SIZE := 25
const FOOTER_SIZE := 25
const STAT_SIZE := 34

# --- Tiempos, en segundos ---

const OPEN_SECONDS := 0.24
const CLOSE_SECONDS := 0.16
const PAGE_SECONDS := 0.16
const DETAIL_SECONDS := 0.18
## Escala de la carpeta al empezar a abrirse.
const OPEN_SCALE := 0.975

static var _banner_font: FontVariation
static var _title_font: FontVariation


# --- Letras ---

## Rótulo del expediente: Palatino en negrita, algo espaciada.
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


## Versalitas espaciadas de las cintas («SOSPECHOSOS (5)»).
static func banner_font() -> Font:
	if _banner_font == null:
		_banner_font = FontVariation.new()
		_banner_font.base_font = CaseFileStyle.display_serif_regular()
		_banner_font.spacing_glyph = 2
	return _banner_font


# --- Piezas sueltas ---

static func icon(icon_name: String) -> Texture2D:
	return HudStyle.icon(icon_name)


static func make_label(text: String, font: Font, font_size: int, color: Color, wrap: bool = false) -> Label:
	var label := HudStyle.make_label(text, font, font_size, color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


static func make_icon(icon_name: String, icon_size: float, color: Color) -> TextureRect:
	return HudStyle.make_icon(icon(icon_name), icon_size, color)


## Filete de tinta con un rombo en el centro, entre el encabezado de una ficha y su contenido.
static func make_rule(color: Color = Color(INK, 0.55)) -> GoldDivider:
	var rule := GoldDivider.new()
	rule.color = color
	rule.custom_minimum_size = Vector2(0.0, 18.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


static func box(background: Color, border: Color, border_width: int, radius: int, margin: Vector4 = Vector4.ZERO) -> StyleBoxFlat:
	var style := CaseFileStyle.box(background, border, border_width, radius)
	style.content_margin_left = margin.x
	style.content_margin_top = margin.y
	style.content_margin_right = margin.z
	style.content_margin_bottom = margin.w
	return style


## Contorno dorado del control enfocado con el teclado o el mando.
static func focus_ring(radius: int = 4) -> StyleBoxFlat:
	return CaseFileStyle.focus_ring(radius)


## Pestaña de la carpeta: placa con las esquinas cortadas en chaflán, oscura o burdeos si es la
## elegida. `state` es "normal", "hover" o "selected".
static func tab_box(state: String, compact: bool = false) -> StyleBoxFlat:
	var padding := Vector4(18.0, 6.0, 20.0, 8.0) if not compact else Vector4(12.0, 6.0, 12.0, 8.0)
	var style := box(TAB_FILL, GOLD, 2, 12, padding)
	style.corner_detail = 1
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0.0, 3.0)
	match state:
		"hover":
			style.bg_color = TAB_HOVER
			style.border_color = GOLD_LIGHT
		"selected":
			style.bg_color = BURGUNDY
			style.border_color = GOLD_LIGHT
			style.set_border_width_all(3)
			style.shadow_color = Color(BURGUNDY, 0.55)
			style.shadow_size = 10
			style.shadow_offset = Vector2.ZERO
	return style


## Ficha de una lista: pergamino algo más claro que la página, con un filete de tinta. La elegida
## se ilumina con un borde dorado.
static func row_box(state: String) -> StyleBoxFlat:
	var style := box(Color(PARCHMENT_LIGHT, 0.5), Color(INK, 0.32), 1, 4, Vector4(10.0, 6.0, 14.0, 6.0))
	style.shadow_color = Color(0.25, 0.15, 0.08, 0.18)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 2.0)
	match state:
		"hover":
			style.bg_color = Color(PARCHMENT_LIGHT, 0.78)
			style.border_color = Color(GOLD_DARK, 0.85)
		"selected":
			style.bg_color = Color("f8eed4")
			style.border_color = GOLD
			style.set_border_width_all(2)
			style.shadow_color = Color(GOLD_LIGHT, 0.75)
			style.shadow_size = 7
			style.shadow_offset = Vector2.ZERO
	return style


## Recuadro de una ficha que no se elige (un objetivo): como la fila, sin estados.
static func card_box() -> StyleBoxFlat:
	var style := row_box("normal")
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


## Recuadro hundido del texto principal de una ficha (la biografía, la declaración).
static func inset_box() -> StyleBoxFlat:
	var style := box(Color(INK, 0.055), Color(INK, 0.24), 1, 3, Vector4(24.0, 16.0, 24.0, 18.0))
	style.shadow_color = Color(1.0, 0.98, 0.9, 0.35)
	style.shadow_size = 1
	style.shadow_offset = Vector2(0.0, 1.0)
	return style


## Franja de un dato de la ficha («Paradero:»): un velo de tinta muy tenue.
static func field_box() -> StyleBoxFlat:
	return box(Color(INK, 0.07), Color(INK, 0.0), 0, 3, Vector4(0.0, 4.0, 18.0, 4.0))


## Celda del icono de un dato, algo más oscura que su franja.
static func field_icon_box() -> StyleBoxFlat:
	return box(Color(INK, 0.1), Color(INK, 0.0), 0, 3, Vector4(14.0, 4.0, 14.0, 4.0))


## Insignia burdeos del icono de una ficha.
static func badge_box() -> StyleBoxFlat:
	var style := box(BURGUNDY_DARK, GOLD_DARK, 2, 3, Vector4(10.0, 10.0, 10.0, 10.0))
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


## Barra de desplazamiento fina en tinta, para las listas y fichas largas sobre pergamino.
static func style_scroll(scroll: ScrollContainer) -> void:
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bar := scroll.get_v_scroll_bar()
	var track := box(Color(INK, 0.08), Color(INK, 0.18), 1, 3, Vector4(3.0, 0.0, 3.0, 0.0))
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", box(Color(GOLD_DARK, 0.75), Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_highlight", box(GOLD_DARK, Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("grabber_pressed", box(BURGUNDY, Color(0, 0, 0, 0), 0, 3))
