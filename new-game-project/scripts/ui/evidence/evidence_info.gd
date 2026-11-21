class_name EvidenceInfo
extends RefCounted
## Qué se muestra al examinar una prueba y con qué plantilla. Lee `data/clues.json` a través de
## `GameData`; no guarda nada ni cambia ningún estado.
##
## Cada prueba puede traer un bloque opcional `presentation` con la plantilla (`template`) y los
## textos propios de esa plantilla (el cuerpo de una carta, la cabecera de un periódico...). Sin
## bloque, la prueba se presenta en la ficha de investigación, que sólo necesita los campos de
## siempre: nombre, categoría, procedencia, descripción e imagen (`image`, la misma que usa el
## expediente). Así no hay una segunda base de datos de pistas: todo sigue en `clues.json`.

## Plantillas disponibles: el rótulo y el icono de su placa, y la clase que la dibuja.
const TEMPLATES := {
	"carta": {"header": "Carta personal", "icon": "carta"},
	"ficha": {"header": "Evidencia / Objeto", "icon": "engranaje"},
}
const DEFAULT_TEMPLATE := "ficha"
## La ficha sirve para cualquier prueba sin plantilla propia; su placa nombra el tipo de prueba.
## Las categorías que no aparecen aquí (objetos y relojes) usan «Evidencia / Objeto».
const RECORD_HEADERS := {
	"documentos": {"header": "Evidencia / Documento", "icon": "documento"},
	"fotografias": {"header": "Evidencia / Fotografía", "icon": "fotografia"},
	"cartas": {"header": "Evidencia / Carta", "icon": "carta"},
	"huellas": {"header": "Evidencia / Huella", "icon": "huella"},
}
## Rótulo rojo de la ficha según la categoría de la prueba.
const CATEGORY_TAGS := {
	"documentos": "DOCUMENTO",
	"fotografias": "FOTOGRAFÍA",
	"relojes": "RELOJ",
	"cartas": "CARTA",
	"objetos": "OBJETO PERSONAL",
	"huellas": "HUELLA",
}
## Icono grande de la ficha cuando la prueba no tiene ilustración propia.
const CATEGORY_ICONS := {
	"documentos": "documento",
	"fotografias": "fotografia",
	"relojes": "reloj",
	"cartas": "carta",
	"objetos": "lupa",
	"huellas": "huella",
}


## Datos de una prueba listos para su plantilla: `id`, `template`, `header`, `icon`, `tag`,
## `category`, `title`, `where`, `description`, `image` y `presentation` (el bloque de
## `clues.json`, vacío si no lo trae). Vacío si la prueba no existe.
static func describe(clue_id: String) -> Dictionary:
	if not GameData.clues.has(clue_id):
		return {}
	var clue: Dictionary = GameData.clues[clue_id]
	var presentation: Dictionary = clue.get("presentation", {})
	var template := template_of(clue)
	var category := str(clue.get("category", ""))
	var plate: Dictionary = TEMPLATES[template]
	if template == DEFAULT_TEMPLATE and RECORD_HEADERS.has(category):
		plate = RECORD_HEADERS[category]
	return {
		"id": clue_id,
		"template": template,
		"header": str(presentation.get("header", plate["header"])),
		"icon": str(presentation.get("icon", plate["icon"])),
		"category": category,
		"tag": CATEGORY_TAGS.get(category, "PRUEBA"),
		"title": str(clue.get("name", "")),
		"where": str(clue.get("where", "")),
		"description": str(clue.get("description", "")),
		"image": str(clue.get("image", "")),
		"presentation": presentation,
	}


## Plantilla de una prueba: la de su `presentation` si existe, o la ficha.
static func template_of(clue: Dictionary) -> String:
	var presentation: Dictionary = clue.get("presentation", {})
	var template := str(presentation.get("template", DEFAULT_TEMPLATE))
	if not TEMPLATES.has(template):
		push_warning("Plantilla de evidencia desconocida: «%s». Se usa la ficha." % template)
		return DEFAULT_TEMPLATE
	return template


## Crea la plantilla que dibuja una prueba.
static func create_document(template: String) -> EvidenceDocument:
	match template:
		"carta":
			return EvidenceLetter.new()
	return EvidenceRecordCard.new()
