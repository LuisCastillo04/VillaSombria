class_name EvidenceCategories
extends RefCounted
## Clasificación deductiva de lo que el detective puede presentar en la acusación: qué pruebas,
## testimonios y deducciones sirven para explicar el motivo, la oportunidad o los medios.
##
## Vive en `data/evidence_categories.json`, aparte de los textos (que siguen en `clues.json`,
## `testimonies.json` y `deductions.json`) y de las reglas que validan la acusación (el bloque
## `accusation` de `story.json`). Clasificar no dice qué respuesta es la buena: sólo a qué pregunta
## intenta responder cada elemento, así que cada categoría reúne respuestas correctas y otras que
## parecen razonables pero no se sostienen.
##
## Un elemento pertenece a varias categorías sólo cuando su contenido lo justifica: un pagaré habla
## de una deuda (motivo) y además sitúa a quien lo firmó a una hora concreta (oportunidad). Cada
## pista declara también su clase (documento, carta, registro…) para que la interfaz la distinga
## con un icono; los testimonios y las deducciones la llevan implícita.

enum Category { MOTIVE, OPPORTUNITY, MEANS }

## Claves de cada categoría en los datos y en las reglas de `story.json`, en el orden del enum.
const KEYS: Array[String] = ["motive", "opportunity", "means"]
## Clases de información que la interfaz distingue con un icono.
const TYPES: Array[String] = ["documento", "carta", "fotografia", "objeto", "registro", "informe", "testimonio", "deduccion"]
## Clase de una pista que no declara ninguna válida.
const DEFAULT_TYPE := "documento"


static func key_of(category: Category) -> String:
	return KEYS[category]


static func is_category(key: String) -> bool:
	return KEYS.has(key)


## Categorías de un elemento, en el orden de `KEYS`, sin repetir. Vacío si no está clasificado.
static func categories_of(item_id: String) -> Array[String]:
	var declared: Variant = _entry(item_id).get("categories", [])
	var result: Array[String] = []
	if not declared is Array:
		return result
	for key in KEYS:
		if (declared as Array).has(key):
			result.append(key)
	return result


static func belongs(item_id: String, category_key: String) -> bool:
	return categories_of(item_id).has(category_key)


## Si los datos clasifican el elemento (aunque sea en ninguna categoría).
static func is_classified(item_id: String) -> bool:
	return _items().has(item_id)


## Clase de información de un elemento: la declarada por la pista, «testimonio» o «deduccion».
static func type_of(item_id: String) -> String:
	if GameData.testimonies.has(item_id):
		return "testimonio"
	if GameData.deductions.has(item_id):
		return "deduccion"
	var declared := str(_entry(item_id).get("type", ""))
	return declared if TYPES.has(declared) else DEFAULT_TYPE


static func _items() -> Dictionary:
	var items: Variant = GameData.evidence_categories.get("items", {})
	return items if items is Dictionary else {}


static func _entry(item_id: String) -> Dictionary:
	var entry: Variant = _items().get(item_id, {})
	return entry if entry is Dictionary else {}
