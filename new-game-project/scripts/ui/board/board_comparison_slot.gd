class_name BoardComparisonSlot
extends VBoxContainer
## Uno de los dos huecos del panel de comparación. Vacío dice «Elemento N: sin seleccionar»; con un
## elemento muestra su tipo, su título, el texto completo (que se desplaza si es largo) y lo que el
## jugador ya sabe de él: dónde se halló, quién lo declaró, en qué deducciones se usó. Una cruz lo
## suelta sin tener que buscar su ficha en el corcho.

signal remove_requested

var index := 1
var item_id := ""

var _empty: Label
var _filled: VBoxContainer
var _tag: Label
var _title: Label
var _remove: Button
var _scroll: ScrollContainer
var _text: Label
var _facts: VBoxContainer


func _init(slot_index: int = 1) -> void:
	index = slot_index
	name = "Slot%d" % slot_index
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty = BoardStyle.make_label("Elemento %d: sin seleccionar" % index, BoardStyle.italic_font(), BoardStyle.SLOT_TEXT_SIZE, BoardStyle.INK_SOFT)
	_empty.name = "Empty"
	add_child(_empty)
	_filled = VBoxContainer.new()
	_filled.name = "Filled"
	_filled.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_filled.add_theme_constant_override("separation", 4)
	_filled.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag = BoardStyle.make_label("", BoardStyle.banner_font(), BoardStyle.SLOT_TAG_SIZE, BoardStyle.BURGUNDY_INK)
	_tag.name = "Tag"
	_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tag.clip_text = true
	top.add_child(_tag)
	_remove = Button.new()
	_remove.name = "Remove"
	_remove.text = "×"
	_remove.tooltip_text = "Quitar de la comparación"
	_remove.focus_mode = Control.FOCUS_NONE
	BoardStyle.apply_text_button(_remove, BoardStyle.heading_font(), BoardStyle.SLOT_TITLE_SIZE, BoardStyle.INK_SOFT)
	_remove.pressed.connect(func() -> void: remove_requested.emit())
	top.add_child(_remove)
	_filled.add_child(top)
	_title = BoardStyle.make_label("", BoardStyle.heading_font(), BoardStyle.SLOT_TITLE_SIZE, BoardStyle.INK, true)
	_title.name = "Title"
	_filled.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	BoardStyle.style_scroll(_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text = BoardStyle.make_label("", BoardStyle.italic_font(), BoardStyle.SLOT_TEXT_SIZE, BoardStyle.INK, true)
	_text.name = "Text"
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_text)
	_facts = VBoxContainer.new()
	_facts.name = "Facts"
	_facts.add_theme_constant_override("separation", 2)
	_facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_facts)
	_scroll.add_child(body)
	_filled.add_child(_scroll)
	add_child(_filled)
	show_item({})


## Muestra un elemento descrito por `BoardInfo.describe()`; vacío, el hueco libre.
func show_item(entry: Dictionary) -> void:
	item_id = entry.get("id", "")
	var filled := not entry.is_empty()
	_empty.visible = not filled
	_filled.visible = filled
	if not filled:
		return
	var tag: String = entry.get("kind_label", "")
	var subtitle: String = entry.get("subtitle", "")
	if not subtitle.is_empty():
		tag = "%s · %s" % [tag, subtitle.to_upper()]
	_tag.text = tag
	_title.text = entry.get("title", "")
	_text.text = entry.get("text", "")
	for child in _facts.get_children():
		_facts.remove_child(child)
		child.queue_free()
	for fact: Dictionary in entry.get("facts", []):
		_facts.add_child(_fact_row(fact))
	_scroll.scroll_vertical = 0


func is_filled() -> bool:
	return not item_id.is_empty()


func get_title() -> String:
	return _title.text if is_filled() else _empty.text


func get_text() -> String:
	return _text.text if is_filled() else ""


func get_tag() -> String:
	return _tag.text if is_filled() else ""


func get_facts_text() -> String:
	var lines := PackedStringArray()
	for row in _facts.get_children():
		if row.is_queued_for_deletion():
			continue
		var label := row.get_child(1) as Label
		lines.append(label.text)
	return "\n".join(lines)


func get_remove_button() -> Button:
	return _remove


func get_scroll() -> ScrollContainer:
	return _scroll


## Una línea de datos con su icono: «Hallada en: Bolsillo del inspector».
func _fact_row(fact: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := BoardStyle.make_icon(fact.get("icon", "lupa"), 20.0, BoardStyle.BURGUNDY_INK)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var label := BoardStyle.make_label("%s: %s" % [fact.get("label", ""), fact.get("text", "")], BoardStyle.body_font(), BoardStyle.FACT_SIZE, BoardStyle.INK_SOFT, true)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row
