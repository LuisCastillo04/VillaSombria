class_name VisualFilters
extends RefCounted
## Filtros de color de Configuración → Filtros: Modo noir, Sepia, Frío nocturno y Colores originales.
##
## Sólo hay un filtro activo: la preferencia `filtros/activo` de `Settings`, que guarda su
## identificador estable (`noir`, `sepia`, `cold_night` u `original`), nunca el texto visible. Cada
## filtro es un juego de parámetros de la corrección de color de `noir_post.gdshader`, el
## postproceso que ya dibuja la niebla, la viñeta y el grano del mundo (`PostFx`). Toda la interfaz
## se dibuja en capas superiores a la suya, así que el filtro cambia los colores del escenario, los
## personajes, las luces y la lluvia, pero nunca los de los menús, el HUD o los diálogos.
##
## Aplicar un filtro sólo cambia los parámetros del material que ya existe: no crea materiales ni
## pasadas, no toca texturas, luces ni entornos, y repetir el filtro vigente no escribe nada.
##
## Para añadir un filtro: añade su identificador a `IDS`, su nombre y su descripción a `FILTERS` y los
## parámetros que cambia respecto a `NEUTRAL`. La preferencia, la página de Configuración y el
## postproceso lo recogen sin más cambios.

## Preferencia de `Settings` con el filtro activo.
const SETTING_KEY := "filtros/activo"
const ORIGINAL := "original"
## Identificadores, en el orden en que se ofrecen en Configuración.
const IDS: Array[String] = ["noir", "sepia", "cold_night", "original"]
## Grupo de los postprocesos que muestran el filtro activo.
const GROUP := &"filtros_visuales"
## Filtro que tienen aplicado los parámetros de un material.
const APPLIED_META := &"filtro_visual"

## Parámetros de la corrección de color que dejan la imagen tal cual (`noir_post.gdshader` explica
## cada uno). Todo filtro parte de ellos, así que al pasar de uno a otro no queda ningún resto del
## anterior. Con `grade_amount` a 0 el shader ni siquiera calcula la corrección.
const NEUTRAL := {
	"grade_amount": 0.0,
	"grade_saturation": 1.0,
	"grade_contrast": 1.0,
	"grade_pivot": 0.5,
	"grade_lift": 0.0,
	"grade_gain": 1.0,
	"grade_shadow_tint": Vector3(1.0, 1.0, 1.0),
	"grade_highlight_tint": Vector3(1.0, 1.0, 1.0),
}

## Nombre, descripción y parámetros de cada filtro (sólo los que cambian respecto a `NEUTRAL`). Los
## tintes multiplican la luminancia y su propia luminancia es casi 1: tiñen sin aclarar ni oscurecer.
## El pivote del contraste es bajo porque Villa Sombría es de noche: la mayor parte de la imagen está
## por debajo del gris medio, y un pivote de 0,5 la hundiría entera en el negro.
const FILTERS := {
	"noir": {
		"label": "Modo noir",
		"description": "Blanco y negro con alto contraste para una atmósfera detectivesca.",
		# Sin color, con una curva en S marcada: sombras profundas pero no negras del todo, y las
		# farolas y la lluvia iluminada siguen destacando en blanco.
		"grade": {
			"grade_amount": 1.0,
			"grade_saturation": 0.0,
			"grade_contrast": 1.5,
			"grade_pivot": 0.3,
			"grade_lift": 0.012,
		},
	},
	"sepia": {
		"label": "Sepia",
		"description": "Tonos cálidos y envejecidos, con un estilo clásico.",
		# Marrón en las sombras y crema dorado en las luces, con un poco del color original para que
		# los materiales no se confundan; el negro algo levantado y el blanco algo apagado, como en
		# una fotografía antigua.
		"grade": {
			"grade_amount": 1.0,
			"grade_saturation": 0.14,
			"grade_contrast": 1.12,
			"grade_pivot": 0.32,
			"grade_lift": 0.035,
			"grade_gain": 0.96,
			"grade_shadow_tint": Vector3(1.28, 0.95, 0.62),
			"grade_highlight_tint": Vector3(1.12, 1.0, 0.78),
		},
	},
	"cold_night": {
		"label": "Frío nocturno",
		"description": "Tonos azulados y desaturados que refuerzan el ambiente nocturno.",
		# Sombras azules y luces casi neutras: conserva algo más de la mitad del color, así que la
		# luz cálida de las farolas sigue distinguiéndose del ambiente.
		"grade": {
			"grade_amount": 1.0,
			"grade_saturation": 0.55,
			"grade_contrast": 1.08,
			"grade_pivot": 0.3,
			"grade_lift": 0.012,
			"grade_gain": 0.98,
			"grade_shadow_tint": Vector3(0.8, 1.0, 1.5),
			"grade_highlight_tint": Vector3(0.96, 1.0, 1.1),
		},
	},
	"original": {
		"label": "Colores originales",
		"description": "La paleta de colores estándar del juego, sin filtros.",
		"grade": {},
	},
}


static func ids() -> Array[String]:
	return IDS.duplicate()


static func is_valid(value: Variant) -> bool:
	return (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME) and IDS.has(String(value))


## El identificador si existe; si no (un archivo antiguo, dañado o editado a mano), Colores originales.
static func sanitize(value: Variant) -> String:
	return String(value) if is_valid(value) else ORIGINAL


## Filtro activo según `Settings`.
static func current() -> String:
	return sanitize(Settings.get_value(SETTING_KEY))


static func label_of(id: String) -> String:
	return String((FILTERS[sanitize(id)] as Dictionary)["label"])


static func description_of(id: String) -> String:
	return String((FILTERS[sanitize(id)] as Dictionary)["description"])


## Todos los parámetros de la corrección de color de un filtro: los neutros con los suyos encima.
static func parameters(id: String) -> Dictionary:
	var values := NEUTRAL.duplicate()
	values.merge((FILTERS[sanitize(id)] as Dictionary)["grade"], true)
	return values


## Escribe en el material los parámetros del filtro. Si ya los tiene, no toca nada y devuelve false.
static func apply_to_material(material: ShaderMaterial, id: String) -> bool:
	if material == null:
		return false
	id = sanitize(id)
	if applied_to(material) == id:
		return false
	var values := parameters(id)
	for parameter: String in values:
		material.set_shader_parameter(parameter, values[parameter])
	material.set_meta(APPLIED_META, id)
	return true


## Filtro cuyos parámetros tiene el material. Uno sin tocar está en Colores originales.
static func applied_to(material: ShaderMaterial) -> String:
	if material == null:
		return ORIGINAL
	return sanitize(material.get_meta(APPLIED_META, ORIGINAL))
