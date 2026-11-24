class_name JournalInterrogationsSection
extends JournalSection
## Pestaña Preguntas: el historial de declaraciones de los interrogatorios. A la izquierda, cada
## pregunta que el jugador ha hecho y cuya respuesta oyó entera, agrupadas por personaje en el orden
## en que se hicieron. A la derecha, la conversación elegida: a quién se le preguntó, la pregunta, lo que se
## respondió (palabra por palabra, como se oyó) y lo que aportó a la investigación.
##
## Sale de `ConversationLog.history()`: leerla no reproduce la conversación ni aplica ninguno de sus
## efectos. Es la forma de repasar lo dicho en la modalidad de diálogo único, donde una pregunta no
## se puede repetir. La fecha sólo aparece si se anotó al completarla (las partidas anteriores al
## registro no la tenían y no se inventa).

const ART := preload("res://assets/ui/expediente/interrogatorio.svg")


func _init() -> void:
	super._init("Preguntas", "microfono")


func _banner_icon() -> String:
	return "testigos"


func _build() -> void:
	super._build()
	column.art = ART


func refresh() -> void:
	var entries: Array[Dictionary] = []
	for statement in JournalInfo.statements():
		var entry := statement.duplicate()
		entry["title"] = statement["question"]
		entry["subtitle"] = statement["name"]
		entry["portrait"] = JournalSection.face_of(statement["portrait"])
		entry["portrait_path"] = statement["portrait"]
		entries.append(entry)
	_show_entries(entries, "PREGUNTAS (%d)" % entries.size(), "")


func _show_detail(entry: Dictionary) -> void:
	detail.set_heading("microfono", entry["name"], entry["role"])
	detail.add_field("testigos", "Pregunta:", "«%s»" % entry["question"])
	if not String(entry["when"]).is_empty():
		detail.add_field("calendario", "Fecha:", entry["when"])
	var count: int = entry["count"]
	if count > 1:
		detail.add_field("reloj", "Veces:", "Preguntada %d veces" % count)
	detail.add_section_title("Respuesta")
	detail.add_text_box(entry["transcript"])
	detail.add_section_title("Información obtenida")
	var rows: Array[Dictionary] = entry["gained"]
	if rows.is_empty():
		detail.add_paragraph("Ninguna prueba ni declaración nueva para el expediente.")
	else:
		detail.add_item_rows(rows)
	var bust := JournalSection.bust_of(entry["portrait_path"])
	if bust != null:
		detail.set_photo(bust, JournalPhoto.Mode.PORTRAIT, entry["name"])
	else:
		detail.hide_photo()


func _show_empty() -> void:
	var empty := detail.show_empty()
	empty.set_emblem("microfono")
	empty.setup("Aún no has interrogado a nadie.", "Cada pregunta que hagas, con su respuesta completa, quedará anotada aquí para releerla sin repetir el interrogatorio.")
