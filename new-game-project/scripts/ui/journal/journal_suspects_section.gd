class_name JournalSuspectsSection
extends JournalSection
## Pestaña Sospechosos. A la izquierda, los cinco sospechosos con su retrato y el grabado del Café La
## Luna al pie. A la derecha, la ficha del elegido: relación con el caso, biografía, paradero según
## su rutina a la hora actual, la valoración y la hipótesis que el jugador anotó en el tablero, y su
## retrato en una fotografía con clip. Todo sale de los datos y del estado reales del juego.

const ART := preload("res://assets/ui/expediente/cafe_la_luna.svg")


func _init() -> void:
	super._init("Sospechosos", "antifaz")


func _banner_icon() -> String:
	return "sombrero"


func _build() -> void:
	super._build()
	column.art = ART


func refresh() -> void:
	var entries: Array[Dictionary] = []
	for suspect in JournalInfo.suspects():
		var entry := suspect.duplicate()
		entry["title"] = suspect["name"]
		entry["portrait"] = JournalSection.face_of(suspect["portrait"])
		entry["portrait_path"] = suspect["portrait"]
		entries.append(entry)
	_show_entries(entries, "SOSPECHOSOS (%d)" % entries.size(), "No hay sospechosos en el caso.")


func _show_detail(entry: Dictionary) -> void:
	detail.set_heading("persona", entry["name"], entry["role"])
	detail.add_text_box(entry["bio"])
	detail.add_field("ubicacion", "Paradero:", entry["whereabouts"])
	detail.add_field("balanza", "Valoración:", entry["status_label"])
	if not String(entry["note"]).is_empty():
		detail.add_field("nota", "Hipótesis:", entry["note"])
	var count: int = entry["testimonies"]
	if count > 0:
		detail.add_field("microfono", "Declaraciones:", "%d registrada%s" % [count, "" if count == 1 else "s"])
	var bust := JournalSection.bust_of(entry["portrait_path"])
	if bust != null:
		detail.set_photo(bust, JournalPhoto.Mode.PORTRAIT)
	else:
		detail.hide_photo()


func _show_empty() -> void:
	var empty := detail.show_empty()
	empty.set_emblem("antifaz")
	empty.setup("No hay sospechosos en el caso.", "")
