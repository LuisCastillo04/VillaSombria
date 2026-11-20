class_name JournalCluesSection
extends JournalSection
## Pestaña Pistas. A la izquierda, las pruebas registradas con el icono de su categoría y el grabado
## del escritorio al pie. A la derecha, la ficha de la elegida: categoría, procedencia, descripción
## completa, las deducciones en que ya se ha usado y su imagen, o un emblema de su categoría cuando
## la prueba no tiene imagen propia.

const ART := preload("res://assets/ui/expediente/escritorio.svg")


func _init() -> void:
	super._init("Pistas", "lupa")


func _build() -> void:
	super._build()
	column.art = ART


func refresh() -> void:
	var entries: Array[Dictionary] = []
	for clue in JournalInfo.clues():
		var entry := clue.duplicate()
		entry["subtitle"] = clue["category"]
		entries.append(entry)
	_show_entries(entries, "PISTAS (%d)" % entries.size(), "Las pruebas que examines aparecerán aquí.")


func _show_detail(entry: Dictionary) -> void:
	detail.set_heading(entry["icon"], entry["title"], entry["category"])
	if not String(entry["where"]).is_empty():
		detail.add_field("ubicacion", "Procedencia:", entry["where"])
	detail.add_text_box(entry["text"])
	var related := JournalInfo.related_deductions(entry["id"])
	if not related.is_empty():
		detail.add_section_title("Deducciones relacionadas")
		var rows: Array[Dictionary] = []
		for related_title in related:
			rows.append({"icon": "cerebro", "title": related_title})
		detail.add_item_rows(rows)
	var image_path: String = entry.get("image", "")
	if not image_path.is_empty() and ResourceLoader.exists(image_path):
		detail.set_photo(load(image_path), JournalPhoto.Mode.PHOTO, entry["title"])
	else:
		detail.set_photo(JournalStyle.icon(entry["icon"]), JournalPhoto.Mode.EMBLEM, entry["category"])


func _show_empty() -> void:
	var empty := detail.show_empty()
	empty.set_emblem("lupa")
	var key := JournalInfo.key_name("interact")
	if key.is_empty():
		empty.setup("Aún no hay pistas registradas.", "Examina objetos y documentos para registrarlos aquí.")
	else:
		empty.setup("Aún no hay pistas registradas.", "Examina objetos y documentos con", key, "para registrarlos aquí.")
