class_name JournalTestimoniesSection
extends JournalSection
## Pestaña Testimonios. A la izquierda, las declaraciones oídas, agrupadas por personaje, con su
## retrato y el grabado de la mesa de interrogatorio al pie. A la derecha, la declaración elegida:
## quién la hizo, sobre qué, el texto completo y las deducciones en que ya ha servido. La fecha y el
## lugar sólo aparecen si `testimonies.json` los trae (campos `day` y `where`): nunca se inventan.

const ART := preload("res://assets/ui/expediente/interrogatorio.svg")


func _init() -> void:
	super._init("Testimonios", "testigos")


func _build() -> void:
	super._build()
	column.art = ART


func refresh() -> void:
	var entries: Array[Dictionary] = []
	for testimony in JournalInfo.testimonies():
		var entry := testimony.duplicate()
		entry["title"] = testimony["topic"]
		entry["subtitle"] = testimony["name"]
		entry["portrait"] = JournalSection.face_of(testimony["portrait"])
		entry["portrait_path"] = testimony["portrait"]
		entries.append(entry)
	_show_entries(entries, "TESTIMONIOS (%d)" % entries.size(), "")


func _show_detail(entry: Dictionary) -> void:
	detail.set_heading("microfono", entry["name"], entry["role"])
	detail.add_field("testigos", "Tema:", entry["topic"])
	if not String(entry.get("day", "")).is_empty():
		detail.add_field("calendario", "Fecha:", entry["day"])
	if not String(entry.get("where", "")).is_empty():
		detail.add_field("ubicacion", "Lugar:", entry["where"])
	detail.add_text_box("«%s»" % entry["text"])
	var related: PackedStringArray = entry.get("related", PackedStringArray())
	if not related.is_empty():
		detail.add_section_title("Deducciones relacionadas")
		var rows: Array[Dictionary] = []
		for related_title in related:
			rows.append({"icon": "cerebro", "title": related_title})
		detail.add_item_rows(rows)
	var bust := JournalSection.bust_of(entry["portrait_path"])
	if bust != null:
		detail.set_photo(bust, JournalPhoto.Mode.PORTRAIT, entry["name"])
	else:
		detail.hide_photo()


func _show_empty() -> void:
	var empty := detail.show_empty()
	empty.set_emblem("microfono")
	empty.setup("Aún no hay declaraciones registradas.", "Las declaraciones de testigos y personajes aparecerán aquí conforme avances en la investigación.")
