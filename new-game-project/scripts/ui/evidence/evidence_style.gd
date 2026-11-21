class_name EvidenceStyle
extends RefCounted
## Estilo de la inspección de evidencias en un solo sitio: paleta, letras, medidas y tiempos.
##
## Comparte los burdeos, los dorados y el crema del HUD, del expediente y de las conversaciones, para
## que examinar una prueba no parezca una aplicación aparte. Las medidas del marco, las placas y el
## aviso están en el lienzo lógico de 1920 × 1080 (el estiramiento `canvas_items` las escala con la
## ventana y con el tamaño de letra de Accesibilidad); las de cada documento, en su propio tamaño de
## diseño (`EvidenceDocument.get_design_size`), que se escala entero para caber en pantalla.
##
## Las letras son del sistema, como en el resto del juego. Cada familia lleva detrás otras parecidas
## y una genérica: si el equipo no tiene la primera, Godot usa la siguiente que encuentre.

# --- Paleta ---

const BURGUNDY := Color("6e1a22")
const BURGUNDY_LIGHT := Color("8a2430")
const BURGUNDY_DARK := Color("3f0d12")
const GOLD := Color("b58b4a")
const GOLD_LIGHT := Color("e2c584")
const GOLD_DARK := Color("7d5c2c")
const CREAM := Color("f1deb9")
const CREAM_SOFT := Color("c5ad82")
const CHARCOAL := Color("17140f")
const CHARCOAL_LIGHT := Color("2a241c")
const SHADOW := Color(0.0, 0.0, 0.0, 0.5)
## Velo sobre el escenario, que además se desenfoca (`evidence_backdrop.gdshader`).
const DIM := Color(0.02, 0.025, 0.035, 0.64)

## Papel de los documentos: claro en el centro, tostado y quemado hacia los bordes.
const PAPER := Color("dfc69b")
const PAPER_LIGHT := Color("f3e5c4")
const PAPER_STAIN := Color("b78a52")
const PAPER_EDGE := Color("5a3418")
## Tinta de pluma de la carta, el rojo de su encabezado y el gris de las anotaciones.
const PEN_INK := Color("241812")
const PEN_RED := Color("7a1f17")
const PEN_SOFT := Color("4a3426")
## Tinta de imprenta del periódico y de la máquina de escribir de las fichas.
const PRINT_INK := Color("1e1712")
const TYPE_INK := Color("2a1f17")
const TYPE_RED := Color("962b22")
## Etiqueta de papel claro con la procedencia de la prueba.
const TAG_PAPER := Color("ead7b0")
const TAG_BORDER := Color(0.36, 0.25, 0.15, 0.55)

# --- Medidas del marco, en el lienzo lógico de 1920 × 1080 ---

## Separación mínima del marco respecto a los lados de la pantalla.
const SIDE_MARGIN := 40.0
## Hueco entre el filete del marco y el papel.
const FRAME_PADDING := Vector2(34.0, 30.0)
## Aviso «Evidencia obtenida»: distancia al borde superior, alto y hueco hasta el marco. El marco
## siempre deja este sitio libre, así que el aviso nunca mueve ni encoge el documento.
const NOTICE_TOP := 14.0
const NOTICE_HEIGHT := 62.0
const NOTICE_GAP := 16.0
## Largo de los filetes que salen a los lados del aviso.
const NOTICE_FLOURISH := 130.0
## Placa del encabezado sobre la esquina superior izquierda del marco.
const HEADER_HEIGHT := 58.0
const HEADER_INSET := 34.0
## Botón «Cerrar» montado sobre el filete inferior y su distancia mínima al pie de la pantalla.
const CLOSE_SIZE := Vector2(270.0, 62.0)
const BOTTOM_MARGIN := 14.0
## Un documento no crece más de esto sobre su tamaño de diseño (pantallas 4:3 o 5:4 muy altas).
const MAX_DOCUMENT_SCALE := 1.2

# --- Tamaños de letra del marco ---

const HEADER_SIZE := 32
const HEADER_ICON := 34.0
const NOTICE_SIZE := 36
const NOTICE_ICON := 34.0
const CLOSE_SIZE_TEXT := 28

# --- Tiempos, en segundos ---

const OPEN_SECONDS := 0.3
const CLOSE_SECONDS := 0.18
## El documento aparece desde este tamaño relativo y unos píxeles más abajo.
const OPEN_SCALE := 0.965
const OPEN_RISE := 16.0
## Aviso «Evidencia obtenida»: espera tras abrir, entrada, tiempo a la vista y salida. El tiempo a
## la vista se puede cambiar en el nodo (`ClueInspector.notice_seconds`).
const NOTICE_DELAY := 0.12
const NOTICE_IN := 0.45
const NOTICE_HOLD := 2.5
const NOTICE_OUT := 0.6
const NOTICE_SLIDE := 14.0

const HANDWRITING_FONTS: Array[String] = ["Vladimir Script", "French Script MT", "Edwardian Script ITC", "Lucida Handwriting", "Segoe Script", "cursive"]
const FLOURISH_FONTS: Array[String] = ["Edwardian Script ITC", "Vladimir Script", "French Script MT", "Lucida Handwriting", "Segoe Script", "cursive"]
## Century Schoolbook era la letra de muchos diarios de la época; Georgia viene con Windows.
const NEWSPAPER_FONTS: Array[String] = ["Century Schoolbook", "Georgia", "Times New Roman", "Liberation Serif", "serif"]
const RECORD_TITLE_FONTS: Array[String] = ["Century Schoolbook", "Bookman Old Style", "Georgia", "Liberation Serif", "serif"]

static var _fonts: Dictionary = {}


# --- Letras ---

## Letra manuscrita del cuerpo de una carta.
static func handwriting() -> Font:
	return _system("handwriting", HANDWRITING_FONTS, 400, false)


## Manuscrita con más floreo, para el encabezado y la firma de una carta.
static func flourish() -> Font:
	return _system("flourish", FLOURISH_FONTS, 400, false)


## Cabecera del periódico: serif negrita estrechada, como la de un diario de la época.
static func masthead() -> Font:
	return _condensed("masthead", NEWSPAPER_FONTS, 700, false, 0.86)


## Titulares: la misma familia en negrita, algo estrechada.
static func headline() -> Font:
	return _condensed("headline", NEWSPAPER_FONTS, 800, false, 0.9)


static func newspaper_body() -> Font:
	return _system("newspaper_body", NEWSPAPER_FONTS, 400, false)


static func newspaper_bold() -> Font:
	return _system("newspaper_bold", NEWSPAPER_FONTS, 700, false)


static func newspaper_italic() -> Font:
	return _system("newspaper_italic", NEWSPAPER_FONTS, 700, true)


## Máquina de escribir de las fichas: la del expediente.
static func typewriter() -> Font:
	return UiTheme.typewriter()


## La misma máquina con las letras separadas, para los rótulos en mayúsculas («RELOJ»).
static func typewriter_spaced() -> Font:
	if not _fonts.has("typewriter_spaced"):
		var variation := FontVariation.new()
		variation.base_font = typewriter()
		variation.spacing_glyph = 4
		_fonts["typewriter_spaced"] = variation
	return _fonts["typewriter_spaced"]


static func record_title() -> Font:
	return _system("record_title", RECORD_TITLE_FONTS, 700, false)


## Letra de las placas, el aviso y el botón: la de los rótulos del resto del juego.
static func plate_font() -> Font:
	return CaseFileStyle.display_serif_regular()


static func notice_font() -> Font:
	return CaseFileStyle.display_serif_italic()


static func _system(key: String, names: Array[String], weight: int, italic: bool) -> Font:
	if not _fonts.has(key):
		var font := SystemFont.new()
		font.font_names = PackedStringArray(names)
		font.font_weight = weight
		font.font_italic = italic
		_fonts[key] = font
	return _fonts[key]


## Una familia del sistema estrechada horizontalmente: con pocas familias condensadas instaladas
## en un equipo cualquiera, es la forma segura de lograr el aspecto de una cabecera de diario.
static func _condensed(key: String, names: Array[String], weight: int, italic: bool, width: float) -> Font:
	if not _fonts.has(key):
		var variation := FontVariation.new()
		variation.base_font = _system(key + "_base", names, weight, italic)
		variation.variation_transform = Transform2D(Vector2(width, 0.0), Vector2(0.0, 1.0), Vector2.ZERO)
		_fonts[key] = variation
	return _fonts[key]


# --- Utilidades ---

## Etiqueta que no recibe el ratón, con su letra, tamaño y color.
static func make_label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CaseFileStyle.style_label(label, font, font_size, color)
	return label


## Icono de `assets/ui/iconos/` con el de reserva de `HudStyle` si no existe.
static func icon(icon_name: String) -> Texture2D:
	return HudStyle.icon(icon_name)


## Mayor tamaño de letra (entre `max_size` y `min_size`) con el que `text` cabe en `box` al
## partirse en líneas, contando `line_spacing` píxeles extra por línea.
static func fit_font_size(text: String, font: Font, max_size: int, min_size: int, box: Vector2, line_spacing: float = 0.0) -> int:
	var font_size := max_size
	while font_size > min_size:
		if text_height(text, font, font_size, box.x, line_spacing) <= box.y:
			return font_size
		font_size -= 1
	return min_size


## Alto que ocupa `text` partido en líneas de `width` píxeles.
static func text_height(text: String, font: Font, font_size: int, width: float, line_spacing: float = 0.0) -> float:
	var line_height := font.get_height(font_size)
	var measured := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var lines := maxi(roundi(measured.y / line_height), 1)
	return lines * line_height + (lines - 1) * line_spacing
