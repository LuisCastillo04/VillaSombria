class_name HudStyle
extends RefCounted
## Estilo del HUD de exploración en un solo sitio: paleta, letras, medidas y tiempos.
##
## La paleta parte de la de los menús oscuros (`MenuStyle`) y del expediente (`CaseFileStyle`), y
## las letras son las de `CaseFileStyle`, para que el HUD hable el mismo idioma que el resto del
## juego. Las medidas están en píxeles del lienzo lógico de 1920 × 1080: el estiramiento
## `canvas_items` del proyecto las escala con la ventana, de modo que 1280 × 720 o 1600 × 900 ven
## exactamente la misma composición, más pequeña.

# --- Paleta ---

## Negro carbón de la barra de teclas y los avisos oscuros.
const CHARCOAL := MenuStyle.PANEL
const GOLD := MenuStyle.GOLD
const GOLD_LIGHT := CaseFileStyle.GOLD_LIGHT
const CREAM := MenuStyle.TEXT
const CREAM_SOFT := MenuStyle.TEXT_SECONDARY
const BURGUNDY := MenuStyle.SELECTION
const BURGUNDY_DARK := CaseFileStyle.BURGUNDY_DARK
## Pergamino de los paneles: un poco más claro en el centro, manchado y quemado en los bordes.
const PARCHMENT := Color("e6d5ae")
const PARCHMENT_STAIN := Color("c9ad7f")
const PARCHMENT_EDGE := Color("94714a")
## Tinta marrón oscura del texto sobre pergamino.
const INK := Color("38281d")
const INK_SOFT := CaseFileStyle.INK_SOFT
## Borde exterior de los pergaminos, casi negro, que los separa del escenario.
const FRAME := Color("1d140d")
const SHADOW := Color(0.0, 0.0, 0.0, 0.55)
## Relleno translúcido de la barra de teclas: deja intuir el empedrado mojado detrás.
const PLATE_FILL := Color(0.063, 0.067, 0.086, 0.84)

# --- Medidas, en el lienzo lógico de 1920 × 1080 ---

## Distancia de los paneles y la barra a los bordes de la pantalla.
const SCREEN_MARGIN := 56.0
const TOP_MARGIN := 40.0
const BOTTOM_MARGIN := 38.0
const PANEL_GAP := 16.0
## El panel del lugar no baja de este ancho, para que no cambie de tamaño con cada nombre corto.
const LOCATION_MIN_WIDTH := 500.0
## Ancho máximo del nombre del lugar; si no cabe, la letra se reduce hasta `TITLE_MIN_SIZE`.
const LOCATION_TEXT_MAX := 470.0
const LOCATION_ICON := 70.0
const OBJECTIVE_WIDTH := 520.0
const OBJECTIVE_MIN_WIDTH := 380.0
const OBJECTIVE_ICON := 44.0
const BANNER_HEIGHT := 34.0
const BAR_HEIGHT := 62.0
const BAR_MAX_WIDTH := 1808.0
const BAR_ICON := 52.0
const TOAST_WIDTH := 440.0
const TOAST_LIMIT := 4
## Capa de los avisos mientras hay una conversación: justo por encima de ella (capa 6), para que una
## pista o un testimonio conseguidos hablando se lean, y por debajo de las pantallas completas, que
## no pueden abrirse a la vez que una conversación.
const NOTICES_OVER_DIALOGUE_LAYER := 7
## Marco fino de la pantalla, separado del borde.
const FRAME_INSET := 14.0

# --- Tamaños de letra ---

const TITLE_SIZE := 40
const TITLE_MIN_SIZE := 28
const DATE_SIZE := 23
const BANNER_SIZE := 17
const OBJECTIVE_SIZE := 23
const HINT_SIZE := 22
const HINT_SIZE_COMPACT := 19
const KEY_SIZE := 18
const KEY_SIZE_COMPACT := 16
const PROMPT_SIZE := 24
const TOAST_TITLE_SIZE := 22
const TOAST_BODY_SIZE := 19

# --- Tiempos, en segundos ---

## Aparición y desaparición del HUD completo (conversaciones, transiciones, pantallas).
const FADE_IN := 0.45
const FADE_OUT := 0.22
## Cambio de un texto: se desvanece el anterior y aparece el nuevo.
const SWAP_OUT := 0.16
const SWAP_IN := 0.38
## Recorrido del deslizamiento al aparecer.
const SLIDE := 14.0
## Destello del encabezado cuando llega un objetivo nuevo.
const FLASH := 1.4

const FALLBACK_ICON := "mapa"

static var _banner_font: FontVariation


static func title_font() -> Font:
	return CaseFileStyle.display_serif()


static func date_font() -> Font:
	return CaseFileStyle.display_serif_italic()


static func body_font() -> Font:
	return CaseFileStyle.display_serif_regular()


static func key_font() -> Font:
	return CaseFileStyle.serif_bold()


## Versalitas espaciadas de los rótulos cortos, como «OBJETIVO».
static func banner_font() -> Font:
	if _banner_font == null:
		_banner_font = FontVariation.new()
		_banner_font.base_font = CaseFileStyle.display_serif()
		_banner_font.spacing_glyph = 3
	return _banner_font


## Icono de `assets/ui/iconos/`, o el de reserva si no existe, para que un dato mal escrito no
## deje el panel sin icono ni llene la consola de errores.
static func icon(icon_name: String) -> Texture2D:
	var path := CaseFileStyle.ICONS % icon_name
	if icon_name.is_empty() or not ResourceLoader.exists(path):
		path = CaseFileStyle.ICONS % FALLBACK_ICON
	return load(path)


static func make_label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CaseFileStyle.style_label(label, font, font_size, color)
	return label


static func make_icon(texture: Texture2D, icon_size: float, color: Color) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(icon_size, icon_size)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.modulate = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Filete vertical entre un icono y su texto.
static func make_separator(color: Color, height: float) -> GoldDivider:
	var divider := GoldDivider.new()
	divider.vertical = true
	divider.diamond = false
	divider.color = color
	divider.custom_minimum_size = Vector2(14.0, height)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return divider


## Recuadro de tecla de la barra: el de los menús, y en burdeos cuando la tecla se puede usar ahora.
static func keycap_box(lit: bool) -> StyleBoxFlat:
	var style := MenuStyle.keycap_box()
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	if lit:
		style.bg_color = BURGUNDY
		style.border_color = GOLD_LIGHT
		style.shadow_color = Color(BURGUNDY, 0.55)
		style.shadow_size = 8
	return style
