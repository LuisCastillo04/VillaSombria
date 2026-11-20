class_name JournalDeductionsSection
extends JournalSection
## Pestaña Deducciones: el registro de las conclusiones halladas en el tablero. El expediente sólo las
## consulta; la combinación de pruebas sigue siendo cosa del tablero (`Investigation.try_link`).
##
## Sin deducciones, la sección es una sola página grande con el grabado del tablero, el aviso y la
## tecla real del tablero, y libros y una lupa en la esquina. Con deducciones, la lista a la izquierda
## y, a la derecha, la conclusión elegida, su tipo y las pruebas y declaraciones que la sostienen.

const BOARD_ART := preload("res://assets/ui/expediente/tablero.svg")
const CORNER_ART := preload("res://assets/ui/expediente/libros_lupa.svg")


func _init() -> void:
	super._init("Deducciones", "cerebro")


func _build() -> void:
	super._build()
	column.art = CORNER_ART


func refresh() -> void:
	var entries: Array[Dictionary] = []
	for deduction in JournalInfo.deductions():
		var entry := deduction.duplicate()
		entry["subtitle"] = deduction["kind_label"]
		entries.append(entry)
	# Sin deducciones, la ficha ocupa todo el ancho: no hay lista que enseñar.
	column.visible = not entries.is_empty()
	detail.art = CORNER_ART if entries.is_empty() else null
	detail.art_corner = JournalPage.ArtCorner.BOTTOM_LEFT
	detail.art_size = Vector2(400.0, 240.0)
	detail.art_alpha = 0.6
	_fit_columns()
	_show_entries(entries, "DEDUCCIONES (%d)" % entries.size(), "")


func get_footer_left() -> float:
	return side.position.x if column.visible else 0.0


func _show_detail(entry: Dictionary) -> void:
	detail.hide_photo()
	detail.set_heading(entry["icon"], entry["title"], entry["kind_label"])
	detail.add_text_box(entry["text"])
	var evidence: Array[Dictionary] = []
	evidence.assign(entry["evidence"])
	if not evidence.is_empty():
		detail.add_section_title("Pruebas y declaraciones")
		detail.add_item_rows(evidence)
	detail.add_field("cerebro", "Estado:", "Establecida en el tablero")


func _show_empty() -> void:
	detail.hide_photo()
	var empty := detail.show_empty()
	empty.set_art(BOARD_ART, Vector2(520.0, 352.0))
	var key := JournalInfo.key_name("open_board")
	if key.is_empty():
		empty.setup("Aún no hay deducciones.", "Relaciona pruebas y testimonios en el tablero.")
	else:
		empty.setup("Aún no hay deducciones.", "Relaciona pruebas y testimonios en el tablero", key, ".")
