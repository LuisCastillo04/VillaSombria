class_name DialogueStyle
extends RefCounted
## Estilo de las conversaciones en un solo sitio: paleta, letras, medidas y tiempos.
##
## Es el mismo cuero, el mismo pergamino y los mismos dorados del tablero (`BoardStyle`), del
## expediente (`JournalStyle`) y del HUD (`HudStyle`), para que una conversación no parezca una
## aplicación aparte. Las medidas están en el lienzo lógico de 1920 × 1080: el estiramiento
## `canvas_items` del proyecto las escala con la ventana, de modo que 1280 × 720, 1366 × 768 o
## 1600 × 900 ven la misma composición a otra escala.

# --- Paleta ---

const CHARCOAL := BoardStyle.CHARCOAL
## Cuero oscuro del marco de la ventana y su versión más honda, la de los bordes gastados.
const LEATHER := BoardStyle.LEATHER
const LEATHER_DARK := BoardStyle.LEATHER_DARK
const LEATHER_SHEEN := BoardStyle.LEATHER_SHEEN
const BURGUNDY := BoardStyle.BURGUNDY
const BURGUNDY_LIGHT := Color("94232f")
const BURGUNDY_DARK := JournalStyle.BURGUNDY_DARK
const GOLD := BoardStyle.GOLD
const GOLD_LIGHT := BoardStyle.GOLD_LIGHT
const GOLD_DARK := BoardStyle.GOLD_DARK
## Pergamino de la ventana: claro en el centro, manchado y quemado hacia los bordes.
const PARCHMENT := Color("efdfbc")
const PARCHMENT_STAIN := Color("d8bd8c")
const PARCHMENT_EDGE := Color("9c7647")
const CREAM := BoardStyle.CREAM
## Tinta del texto principal: casi negra, con un punto de sepia.
const INK := Color("24170f")
const INK_SOFT := JournalStyle.INK_SOFT
## Filete de tinta del pergamino y bordes marrones de las respuestas.
const RULE := Color(0.36, 0.25, 0.15, 0.62)
const SHADOW := Color(0.0, 0.0, 0.0, 0.55)
## Velo sobre el escenario: lo oscurece sin ocultarlo, la lluvia y las farolas siguen a la vista.
const DIM := Color(0.02, 0.03, 0.05, 0.58)

# --- Medidas, en el lienzo lógico de 1920 × 1080 ---

## Distancia de la ventana a los lados y al pie de la pantalla, y ancho máximo: en una pantalla
## ultrapanorámica la ventana queda centrada en una zona 16:9, como el HUD.
const SCREEN_MARGIN := HudStyle.SCREEN_MARGIN
const BOTTOM_MARGIN := 44.0
const MAX_WIDTH := HudStyle.BAR_MAX_WIDTH
## Grosor de la banda de cuero alrededor del pergamino.
const BORDER := 14.0
## Margen del texto a izquierda y derecha, dentro del pergamino.
const TEXT_SIDE := 86.0
## Altura de la ventana mientras se lee, antes de que sepa cuánto ocupan sus líneas.
const NARRATIVE_HEIGHT := 300.0
## Líneas que caben en la ventana; un texto más largo se reparte en páginas.
const TEXT_LINES := 3
const LINE_SPACING := 6
## Del borde superior de la ventana al texto: deja sitio a la mitad inferior de la placa.
const TEXT_TOP := 50.0
## Del texto al separador, y del separador al borde inferior de la ventana.
const TEXT_TO_DIVIDER := 12.0
const DIVIDER_HEIGHT := 18.0
const DIVIDER_TO_BOTTOM := 58.0
const DIVIDER_WIDTH_RATIO := 0.52
## Placa del nombre: distancia al borde izquierdo de la ventana, alto y ancho mínimo.
const PLATE_LEFT := 30.0
const PLATE_HEIGHT := 62.0
const PLATE_MIN_WIDTH := 300.0
## Pestaña de «Continuar» en la esquina inferior derecha.
const CONTINUE_HEIGHT := 58.0
## Respuestas: distancia del borde superior de la ventana a la primera, margen lateral de la lista,
## hueco entre tarjetas y ancho máximo de una tarjeta, para que una línea larga se lea cómoda.
const CHOICES_TOP := 72.0
const CHOICES_SIDE := 40.0
const CHOICES_SCROLL_GUTTER := 22.0
const CHOICE_GAP := 14.0
const CHOICE_GAP_COMPACT := 9.0
const CHOICE_MAX_WIDTH := 1460.0
## Desde cuántas respuestas las tarjetas se compactan para que quepan más sin tapar las siluetas.
const COMPACT_CHOICES_FROM := 5
## Pie de las respuestas: hueco desde la última, alto del separador con la ayuda y margen inferior.
const CHOICES_TO_HINT := 20.0
const HINT_HEIGHT := 64.0
const HINT_BOTTOM := 30.0
## La ventana nunca pasa de esta parte del alto de la pantalla, para que las caras de las siluetas
## sigan a la vista: con muchas respuestas, la lista se desplaza.
const MAX_WINDOW_RATIO := 0.52
## Marco fino de la pantalla durante la conversación.
const SCREEN_FRAME_INSET := HudStyle.FRAME_INSET

# --- Tamaños de letra ---

const TEXT_SIZE := 44
const NAME_SIZE := 34
const OPTION_SIZE := 33
const OPTION_SIZE_COMPACT := 30
const HINT_SIZE := 22
const CONTINUE_SIZE := 28
const KEY_SIZE := 21

# --- Tiempos, en segundos ---

const OPEN_SECONDS := 0.45
const CLOSE_SECONDS := 0.25
## Cambio de tinte de las siluetas al cambiar quien habla.
const TINT_SECONDS := 0.2
## Cambio del nombre de la placa: se apaga el anterior y se enciende el nuevo.
const NAME_OUT_SECONDS := 0.1
const NAME_IN_SECONDS := 0.2
## Espera antes de escribir la primera intervención, mientras la ventana termina de subir.
const FIRST_LINE_DELAY := 0.22
## Escritura progresiva: letras por segundo y pausas tras un punto o una coma.
const CHARACTERS_PER_SECOND := 48.0
const SENTENCE_PAUSE := 0.14
const CLAUSE_PAUSE := 0.05
## Latido de «Continuar» cuando el texto ya se lee entero.
const PULSE_SECONDS := 1.1
## Resaltado de la respuesta señalada y destello al confirmarla.
const SELECT_SECONDS := 0.14
const CONFIRM_SECONDS := 0.22
## Tras aparecer las respuestas, la confirmación espera este instante: una pulsación de más al
## terminar de leer no elige la primera por accidente. Las teclas numéricas no esperan.
const CONFIRM_GUARD_SECONDS := 0.3

static var _speech_font: SystemFont


# --- Letras ---

## Voz de los personajes: Palatino en negrita cursiva, grande y con buen contraste sobre el papel.
static func speech_font() -> Font:
	if _speech_font == null:
		_speech_font = SystemFont.new()
		_speech_font.font_names = PackedStringArray(CaseFileStyle.DISPLAY_FONTS)
		_speech_font.font_weight = 700
		_speech_font.font_italic = true
	return _speech_font


## Narración: la misma familia en cursiva redonda, para distinguirla de lo que dice un personaje.
static func narration_font() -> Font:
	return CaseFileStyle.display_serif_italic()


static func name_font() -> Font:
	return JournalStyle.title_font()


static func option_font() -> Font:
	return CaseFileStyle.display_serif()


static func hint_font() -> Font:
	return CaseFileStyle.display_serif_italic()


static func make_label(text: String, font: Font, font_size: int, color: Color) -> Label:
	return HudStyle.make_label(text, font, font_size, color)
