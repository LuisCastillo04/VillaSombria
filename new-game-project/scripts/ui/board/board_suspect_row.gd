class_name BoardSuspectRow
extends ScrollContainer
## Fila de sospechosos del tablero. Las fichas salen de los sospechosos del caso (`BoardInfo`), no de
## una lista fija: con más sospechosos de los que caben, la fila se desplaza en horizontal (también
## al recorrerla con el teclado); con menos, las fichas se reparten el ancho.

signal suspect_pressed(suspect_id: String)

var _box: HBoxContainer
var _cards: Dictionary = {}
var _selected := ""


func _init() -> void:
	name = "Suspects"
	follow_focus = true
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	BoardStyle.style_hscroll(self)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sitio para el brillo de la ficha elegida, que la fila recortaría.
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 8)
	for side: String in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 5)
	_box = HBoxContainer.new()
	_box.name = "Cards"
	_box.add_theme_constant_override("separation", int(BoardStyle.SUSPECT_GAP))
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_box)
	add_child(margin)


## Vuelve a leer los sospechosos y sus valoraciones. Las fichas se conservan si los sospechosos son
## los mismos; `drafts` dice cuáles tienen una hipótesis a medias.
func refresh(drafts: Array = []) -> void:
	var entries := BoardInfo.suspects()
	var ids := entries.map(func(entry: Dictionary) -> String: return entry["id"])
	if ids != _cards.keys():
		for card: BoardSuspectCard in _cards.values():
			_box.remove_child(card)
			card.queue_free()
		_cards.clear()
		for entry in entries:
			var card := BoardSuspectCard.new()
			card.pressed.connect(func() -> void: suspect_pressed.emit(card.suspect_id))
			_box.add_child(card)
			_cards[entry["id"]] = card
	for entry in entries:
		var card: BoardSuspectCard = _cards[entry["id"]]
		card.setup(entry)
		card.set_draft(drafts.has(entry["id"]))
		card.set_selected(entry["id"] == _selected, false)


## Ilumina la ficha cuya hipótesis se anota; vacío, ninguna.
func set_selected(suspect_id: String, animate: bool = true) -> void:
	_selected = suspect_id
	for id: String in _cards:
		var card: BoardSuspectCard = _cards[id]
		if card.selected != (id == suspect_id):
			card.set_selected(id == suspect_id, animate)


func get_selected() -> String:
	return _selected


func get_card(suspect_id: String) -> BoardSuspectCard:
	return _cards.get(suspect_id)


func get_cards() -> Array[BoardSuspectCard]:
	var cards: Array[BoardSuspectCard] = []
	for card: BoardSuspectCard in _cards.values():
		cards.append(card)
	return cards


func get_suspect_ids() -> PackedStringArray:
	return PackedStringArray(_cards.keys())
