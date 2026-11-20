class_name JournalList
extends VBoxContainer
## Lista de fichas elegibles del expediente (pistas, testimonios, sospechosos, deducciones). Sólo una
## está elegida a la vez; se elige con el ratón, con el teclado o el mando (arriba y abajo) y avisa
## con `selection_changed`. Conserva las fichas mientras los datos no cambian y recuerda la elegida
## aunque se cierre el expediente o lleguen fichas nuevas.

signal selection_changed(entry_id: String)

var _group := ButtonGroup.new()
var _items: Array[JournalListItem] = []
var _selected := ""
var _signature := ""


func _init() -> void:
	add_theme_constant_override("separation", int(JournalStyle.ROW_GAP))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pone las fichas `{id, title, subtitle, portrait | icon}`. Si son las mismas que ya había, no
## rehace nada. Devuelve si la elegida ha cambiado.
func set_entries(entries: Array[Dictionary]) -> bool:
	var signature := _signature_of(entries)
	if signature != _signature:
		_signature = signature
		_rebuild(entries)
	var previous := _selected
	if not _has(_selected):
		_selected = _items[0].entry_id if not _items.is_empty() else ""
	_mark_selected()
	return _selected != previous


func select(entry_id: String, notify: bool = true) -> void:
	if not _has(entry_id) or entry_id == _selected:
		return
	_selected = entry_id
	_mark_selected()
	if notify:
		selection_changed.emit(entry_id)


func get_selected_id() -> String:
	return _selected


func get_selected_item() -> JournalListItem:
	return get_item(_selected)


func get_item(entry_id: String) -> JournalListItem:
	for item in _items:
		if item.entry_id == entry_id:
			return item
	return null


func get_items() -> Array[JournalListItem]:
	return _items


func get_entry_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for item in _items:
		ids.append(item.entry_id)
	return ids


func is_empty() -> bool:
	return _items.is_empty()


## Lleva el foco a la ficha elegida. Devuelve si había alguna.
func focus_selected() -> bool:
	var item := get_selected_item()
	if item == null:
		return false
	item.grab_focus()
	return true


## Elige la ficha anterior o siguiente (dirección -1 o 1), sin salir de la lista.
func step(direction: int) -> void:
	var index := get_entry_ids().find(_selected)
	if index < 0:
		return
	var target := clampi(index + direction, 0, _items.size() - 1)
	select(_items[target].entry_id)


## Cada ficha lleva arriba a `top` (la pestaña de su sección) y abajo se queda en la última.
func link_focus(top: Control) -> void:
	for index in _items.size():
		var item := _items[index]
		if index == 0 and top != null:
			item.focus_neighbor_top = item.get_path_to(top)
		if index == _items.size() - 1:
			item.focus_neighbor_bottom = NodePath(".")
		# Izquierda y derecha cambian de sección: las atiende el expediente.
		item.focus_neighbor_left = NodePath(".")
		item.focus_neighbor_right = NodePath(".")


func _rebuild(entries: Array[Dictionary]) -> void:
	for item in _items:
		remove_child(item)
		item.queue_free()
	_items.clear()
	for entry in entries:
		var item := JournalListItem.new()
		item.button_group = _group
		item.setup(entry)
		item.toggled.connect(_on_item_toggled.bind(item))
		add_child(item)
		_items.append(item)


func _mark_selected() -> void:
	for item in _items:
		item.set_pressed_no_signal(item.entry_id == _selected)
		item.queue_redraw()


func _has(entry_id: String) -> bool:
	return not entry_id.is_empty() and get_item(entry_id) != null


func _on_item_toggled(pressed: bool, item: JournalListItem) -> void:
	if pressed:
		select(item.entry_id)


static func _signature_of(entries: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for entry in entries:
		parts.append("%s|%s|%s" % [entry.get("id", ""), entry.get("title", ""), entry.get("subtitle", "")])
	return "\n".join(parts)
