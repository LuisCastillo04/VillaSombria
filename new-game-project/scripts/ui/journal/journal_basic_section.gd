class_name JournalBasicSection
extends JournalSection
## Sección provisional del expediente: muestra con las piezas nuevas la misma información que el
## expediente anterior (título, datos y texto) mientras su sección propia no está rediseñada. Se
## retira cuando las cinco secciones tienen la suya.

enum Kind { CLUES, TESTIMONIES, SUSPECTS, DEDUCTIONS }

var kind := Kind.CLUES


func _init(section_title: String = "", section_icon: String = "", section_kind: Kind = Kind.CLUES) -> void:
	kind = section_kind
	super._init(section_title, section_icon)


func refresh() -> void:
	var entries: Array[Dictionary] = []
	match kind:
		Kind.CLUES:
			for clue in JournalInfo.clues():
				entries.append({"id": clue["id"], "title": clue["title"], "subtitle": clue["category"], "icon": clue["icon"], "data": clue})
		Kind.TESTIMONIES:
			for testimony in JournalInfo.testimonies():
				entries.append({"id": testimony["id"], "title": testimony["topic"], "subtitle": testimony["name"], "icon": "testigos", "data": testimony})
		Kind.SUSPECTS:
			for suspect in JournalInfo.suspects():
				entries.append({"id": suspect["id"], "title": suspect["name"], "icon": "antifaz", "data": suspect})
		Kind.DEDUCTIONS:
			for deduction in JournalInfo.deductions():
				entries.append({"id": deduction["id"], "title": deduction["title"], "subtitle": deduction["kind_label"], "icon": deduction["icon"], "data": deduction})
	_show_entries(entries, "%s (%d)" % [title.to_upper(), entries.size()], "")


func _show_detail(entry: Dictionary) -> void:
	var data: Dictionary = entry["data"]
	detail.hide_photo()
	match kind:
		Kind.CLUES:
			detail.set_heading(data["icon"], data["title"], data["category"])
			detail.add_field("ubicacion", "Hallada en:", data["where"])
			detail.add_text_box(data["text"])
		Kind.TESTIMONIES:
			detail.set_heading("testigos", data["name"], data["topic"])
			detail.add_text_box("«%s»" % data["text"])
		Kind.SUSPECTS:
			detail.set_heading("persona", data["name"], data["role"])
			detail.add_text_box(data["bio"])
			detail.add_field("ubicacion", "Paradero:", data["whereabouts"])
			detail.add_field("balanza", "Valoración:", data["status_label"])
			if not String(data["note"]).is_empty():
				detail.add_field("nota", "Hipótesis:", data["note"])
		Kind.DEDUCTIONS:
			detail.set_heading(data["icon"], data["title"], data["kind_label"])
			detail.add_text_box(data["text"])


func _show_empty() -> void:
	var empty := detail.show_empty()
	match kind:
		Kind.CLUES:
			empty.setup("Aún no hay pistas registradas.", "")
		Kind.TESTIMONIES:
			empty.setup("Aún no hay declaraciones registradas.", "")
		Kind.SUSPECTS:
			empty.setup("No hay sospechosos en el caso.", "")
		Kind.DEDUCTIONS:
			empty.setup("Aún no hay deducciones.", "Relaciona pruebas y testimonios en el tablero", JournalInfo.key_name("open_board"), ".")
