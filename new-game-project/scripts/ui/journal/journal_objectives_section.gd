class_name JournalObjectivesSection
extends JournalSection
## Pestaña Objetivos. A la izquierda, la fecha del día y los objetivos visibles, cada uno con su
## estado (en curso, pendiente o cumplido) y el grabado de la mansión al pie. A la derecha, el estado
## general del caso: la fecha y la hora, el recuento de pistas, testimonios y deducciones, una
## fotografía del lugar donde está el detective y las reglas del tiempo del juego.

const ART := preload("res://assets/ui/mansion_grabado.svg")

var _date: Label
var _cards: VBoxContainer
var _cards_signature := ""
## Foto del lugar, hecha al abrir el expediente; si no se pudo hacer, el emblema del lugar.
var _photo_texture: Texture2D
var _photo_location := ""


func _init() -> void:
	super._init("Objetivos", "objetivo")


func _build() -> void:
	column.art = ART
	var date_row := HBoxContainer.new()
	date_row.alignment = BoxContainer.ALIGNMENT_CENTER
	date_row.add_theme_constant_override("separation", 10)
	date_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_row.add_child(JournalStyle.make_icon("calendario", 24.0, JournalStyle.BURGUNDY_INK))
	_date = JournalStyle.make_label("", JournalStyle.italic_font(), JournalStyle.ROW_SUBTITLE_SIZE + 3, JournalStyle.INK)
	date_row.add_child(_date)
	column.header.add_child(date_row)
	column.header.add_child(JournalStyle.make_rule(Color(JournalStyle.INK, 0.4)))
	column.header.show()
	_cards = VBoxContainer.new()
	_cards.name = "Cards"
	_cards.add_theme_constant_override("separation", int(JournalStyle.ROW_GAP))
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.content.add_child(_cards)


func refresh() -> void:
	var objectives := JournalInfo.objectives()
	column.set_title("OBJETIVOS")
	_date.text = JournalInfo.day_title()
	_fill_cards(objectives)
	column.set_empty_text("No hay objetivos a la vista." if objectives.is_empty() else "")
	_show_summary()


## Foto del lugar actual. La pone el expediente al abrirse; `location_id` evita repetirla.
func set_location_photo(texture: Texture2D, location_id: String) -> void:
	_photo_texture = texture
	_photo_location = location_id
	_show_summary()


func get_photo_location() -> String:
	return _photo_location


func get_cards() -> Array[JournalObjectiveCard]:
	var cards: Array[JournalObjectiveCard] = []
	for child in _cards.get_children():
		if child is JournalObjectiveCard and not child.is_queued_for_deletion():
			cards.append(child)
	return cards


func get_date_text() -> String:
	return _date.text


func focus_content() -> bool:
	return false


func scroll_detail(pixels: float) -> void:
	column.scroll.scroll_vertical = int(column.scroll.scroll_vertical + pixels)
	detail.scroll_by(pixels)


func _fill_cards(objectives: Array[Dictionary]) -> void:
	var parts := PackedStringArray()
	for objective in objectives:
		parts.append("%s|%d" % [objective["text"], objective["state"]])
	var signature := "\n".join(parts)
	if signature == _cards_signature:
		return
	_cards_signature = signature
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for objective in objectives:
		var card := JournalObjectiveCard.new()
		card.setup(objective)
		_cards.add_child(card)


func _show_summary() -> void:
	detail.clear()
	var location_id := GameState.location_id
	var place: String = GameData.locations.get(location_id, {}).get("name", "")
	var subtitle := "Son las %s" % JournalInfo.time_text()
	if not place.is_empty():
		subtitle += " · %s" % place
	detail.set_heading("calendario", JournalInfo.day_title(), subtitle, JournalStyle.DETAIL_TITLE_SIZE - 6)
	detail.add_custom(_stats_row(JournalInfo.stats()))
	detail.add_section_title("El tiempo en Villa Sombría")
	for rule in JournalInfo.time_rules():
		detail.add_custom(_rule_row(rule))
	if _photo_texture != null and _photo_location == location_id:
		detail.set_photo(_photo_texture, JournalPhoto.Mode.PHOTO, place)
	else:
		detail.set_photo(JournalStyle.icon(HudInfo.location_icon(location_id)), JournalPhoto.Mode.EMBLEM, place)


func _stats_row(stats: Dictionary) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.name = "Stats"
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_stat_card("lupa", "%d / %d" % [stats["clues"], stats["clues_total"]], "Pistas encontradas"))
	row.add_child(_stat_card("testigos", str(stats["testimonies"]), "Testimonios registrados"))
	row.add_child(_stat_card("cerebro", "%d / %d" % [stats["deductions"], stats["deductions_total"]], "Deducciones realizadas"))
	return row


func _stat_card(icon: String, value: String, caption: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = caption.validate_node_name()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.x = 190.0
	card.add_theme_stylebox_override("panel", JournalStyle.inset_box())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(JournalStyle.make_icon(icon, 30.0, JournalStyle.BURGUNDY_INK))
	var number := JournalStyle.make_label(value, JournalStyle.heading_font(), JournalStyle.STAT_SIZE, JournalStyle.BURGUNDY_INK)
	number.name = "Value"
	top.add_child(number)
	box.add_child(top)
	box.add_child(JournalStyle.make_label(caption, JournalStyle.italic_font(), JournalStyle.ROW_SUBTITLE_SIZE, JournalStyle.INK, true))
	card.add_child(box)
	return card


func _rule_row(rule: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := JournalStyle.make_icon(rule["icon"], 28.0, JournalStyle.INK_SOFT)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var key: String = rule.get("key", "")
	if not key.is_empty():
		var cap := KeyCap.new(key)
		cap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(cap)
	var text := JournalStyle.make_label(rule["text"], JournalStyle.body_font(), JournalStyle.NOTE_SIZE, JournalStyle.INK, true)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	return row
