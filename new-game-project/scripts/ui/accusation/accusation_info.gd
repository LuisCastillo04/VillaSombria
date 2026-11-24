class_name AccusationInfo
extends RefCounted
## Todo lo que muestra la acusación, leído de los sistemas del juego: sospechosos de `GameData`,
## opciones de cada campo de `Investigation` (que ya las filtra con `EvidenceCategories`) y el
## borrador del formulario. Sólo consulta y da forma a los datos para la interfaz: no cambia nada.

const DEFAULT_VERDICT := "Ortega te escucha en silencio. Presenta tus pruebas."
const SUSPECT_PLACEHOLDER := "Seleccionar sospechoso"
const EVIDENCE_PLACEHOLDER := "Seleccionar evidencia o testimonio"

const PANEL_TITLES := {
	"motive": "Seleccionar prueba del motivo",
	"opportunity": "Seleccionar prueba de la oportunidad",
	"means": "Seleccionar prueba de los medios",
}
## La pregunta que responde cada campo, como en su cinta del formulario.
const QUESTIONS := {
	"suspect": "Acuso a:",
	"motive": "Motivo: por qué lo hizo",
	"opportunity": "Oportunidad: cómo pudo estar allí a la hora real",
	"means": "Medios: cómo lo hizo",
}
## Icono (o signo) del medallón de cada campo.
const FIELD_ICONS := {"suspect": "persona", "motive": "", "opportunity": "reloj", "means": "lupa"}
const FIELD_GLYPHS := {"motive": "?"}
const FIELD_NAMES := {"suspect": "sospechoso", "motive": "motivo", "opportunity": "oportunidad", "means": "medios"}
## Cuando una categoría todavía no tiene nada descubierto. No adelanta qué hay que buscar.
const EMPTY_TEXTS := {
	"motive": "Todavía no has reunido pruebas ni testimonios que expliquen por qué alguien querría matarlo.",
	"opportunity": "Todavía no has reunido pruebas ni testimonios sobre dónde estaba cada cual a la hora de la muerte.",
	"means": "Todavía no has reunido pruebas ni testimonios sobre cómo se cometió el crimen.",
}
const EMPTY_HINT := "Sigue investigando: examina los lugares e interroga a los sospechosos."
const GROUPS: Array[String] = ["pista", "testimonio", "deduccion"]
const GROUP_TITLES := {"pista": "Pruebas", "testimonio": "Testimonios", "deduccion": "Deducciones"}


## Sospechosos del caso para la lista desplegable: `{id, title, subtitle, portrait}`.
static func suspects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for suspect_id in GameData.get_suspects():
		var character: Dictionary = GameData.characters[suspect_id]
		result.append({
			"id": suspect_id,
			"title": character.get("name", suspect_id),
			"subtitle": character.get("role", ""),
			"portrait": JournalInfo.portrait(character.get("portrait", ""), JournalInfo.PORTRAIT_FACE),
		})
	return result


## Lo que se puede presentar en un campo, agrupado (pruebas, testimonios y deducciones) y, dentro de
## cada grupo, en el orden en que se descubrió. Cada opción trae lo que pinta su fila y la vista
## previa: `{id, title, text, group, type, icon, type_label, tooltip}`.
static func options(field: String) -> Array[Dictionary]:
	var items := Investigation.get_accusation_options(field)
	var result: Array[Dictionary] = []
	for group in GROUPS:
		for item in items:
			if item.get("kind", "") == group:
				result.append(describe(item["id"]))
	return result


## Cómo se presenta un elemento del expediente en la acusación. Los testimonios se titulan con el
## nombre corto de quien habla («Ortega: La escena del crimen») para caber en una fila; la vista
## previa usa el título completo (`full_title`).
static func describe(item_id: String) -> Dictionary:
	var item := Investigation.get_item(item_id)
	if item.is_empty():
		return {}
	var type_id := EvidenceCategories.type_of(item_id)
	var title: String = item.get("title", "")
	if item.get("kind", "") == "testimonio":
		var testimony: Dictionary = GameData.testimonies[item_id]
		var speaker: Dictionary = GameData.characters.get(testimony.get("speaker", ""), {})
		title = "%s: %s" % [speaker.get("short", speaker.get("name", "")), testimony.get("topic", "")]
	return {
		"id": item_id,
		"title": title,
		"full_title": item.get("title", ""),
		"text": item.get("text", ""),
		"group": item.get("kind", "pista"),
		"type": type_id,
		"icon": AccusationStyle.type_icon_name(type_id),
		"type_label": AccusationStyle.type_label(type_id),
		"tooltip": item.get("text", ""),
	}


static func suspect_name(suspect_id: String) -> String:
	return GameData.get_character_name(suspect_id)
