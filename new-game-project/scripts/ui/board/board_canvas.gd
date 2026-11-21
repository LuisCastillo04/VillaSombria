class_name BoardCanvas
extends Control
## Corcho del tablero, enmarcado en cuero: aquí se prenden las fichas de lo que el jugador ha
## descubierto, agrupadas en pruebas, declaraciones y deducciones, y los hilos de las relaciones ya
## establecidas. En la esquina inferior izquierda, detrás de todo, un rincón de escritorio decorativo
## (libros, tintero, pluma, cartas y una foto de la mansión) que nunca tapa una ficha.
##
## Las fichas se reparten solas en una cuadrícula que se ajusta al ancho, siempre en el mismo orden
## (el de hallazgo) y con la misma inclinación, así el tablero es estable al volver a abrirlo y no
## se desordena aunque crezca: si no cabe, se desplaza en vertical. Con menos de
## `PLACEHOLDER_MIN_CELLS` fichas, unos huecos libres con una cruz indican dónde irán las siguientes;
## sólo son un indicador: no se pulsan ni dicen cuántas faltan.

## Se pulsa una ficha: `selected` dice si el jugador la elige o la suelta.
signal item_toggled(item_id: String, selected: bool)

const CORK_SHADER := preload("res://assets/shaders/cork.gdshader")
const LEATHER_SHADER := preload("res://assets/shaders/leather.gdshader")
const DECOR_ART := preload("res://assets/ui/tablero/rincon_escritorio.svg")
const DECOR_PHOTO := preload("res://assets/ui/mansion_grabado.svg")
const PLACEHOLDER_MIN_CELLS := 3
## Ancho reservado para la barra de desplazamiento, para que el reparto no cambie al aparecer.
const SCROLLBAR_SPACE := 14.0
## Por debajo de esta altura del corcho, el rincón decorativo se retira.
const DECOR_MIN_HEIGHT := 380.0
## Estado vacío. La tecla de examinar sale del InputMap.
const EMPTY_TEXT := "Aún no hay nada en el tablero. Examina objetos y documentos con [%s] y conversa con los testigos: lo que descubras aparecerá aquí."

var _leather: ColorRect
var _cork: ColorRect
var _decor: Control
var _decor_photo: JournalPhoto
var _scroll: ScrollContainer
var _content: Control
var _connections: BoardConnections
var _rim: Control
var _empty: Label
var _cards: Dictionary = {}
## Rótulo de cada grupo con fichas, por tipo.
var _labels: Dictionary = {}
var _placeholders: Array[Rect2] = []
var _items: Array[Dictionary] = []
var _cork_rect := Rect2()


func _init() -> void:
	name = "Canvas"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leather = ColorRect.new()
	_leather.name = "Leather"
	var leather_material := ShaderMaterial.new()
	leather_material.shader = LEATHER_SHADER
	leather_material.set_shader_parameter("base_color", BoardStyle.BROWN)
	leather_material.set_shader_parameter("dark_color", BoardStyle.LEATHER_DARK)
	leather_material.set_shader_parameter("sheen_color", BoardStyle.LEATHER_SHEEN)
	leather_material.set_shader_parameter("corner_radius", 6.0)
	leather_material.set_shader_parameter("edge_width", 18.0)
	leather_material.set_shader_parameter("seed", 3.9)
	_leather.material = leather_material
	_leather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_leather)
	_cork = ColorRect.new()
	_cork.name = "Cork"
	var cork_material := ShaderMaterial.new()
	cork_material.shader = CORK_SHADER
	cork_material.set_shader_parameter("base_color", BoardStyle.CORK)
	cork_material.set_shader_parameter("dark_color", BoardStyle.CORK_DARK)
	cork_material.set_shader_parameter("light_color", BoardStyle.CORK_LIGHT)
	_cork.material = cork_material
	_cork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cork)
	_decor = Control.new()
	_decor.name = "Decor"
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.draw.connect(_draw_decor)
	add_child(_decor)
	_decor_photo = JournalPhoto.new()
	_decor_photo.name = "Photo"
	_decor_photo.tilt = 7.0
	_decor_photo.clip_side = 0
	_decor_photo.set_picture(DECOR_PHOTO, JournalPhoto.Mode.PHOTO)
	_decor.add_child(_decor_photo)
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.follow_focus = true
	BoardStyle.style_scroll(_scroll)
	add_child(_scroll)
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.draw.connect(_draw_content)
	_scroll.add_child(_content)
	_connections = BoardConnections.new()
	_connections.setup(get_pin_position, _occluders)
	_content.add_child(_connections)
	_empty = BoardStyle.make_label("", BoardStyle.italic_font(), BoardStyle.EMPTY_SIZE, BoardStyle.INK, true)
	_empty.name = "Empty"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.add_theme_stylebox_override("normal", BoardStyle.box(Color(BoardStyle.PARCHMENT_LIGHT, 0.92), Color(BoardStyle.INK, 0.4), 1, 2, Vector4(28.0, 22.0, 28.0, 22.0)))
	_empty.draw.connect(func() -> void: BoardOrnaments.draw_pin(_empty, Vector2(_empty.size.x * 0.5, 4.0), BoardStyle.PINS["pista"]))
	_empty.hide()
	_content.add_child(_empty)
	_rim = Control.new()
	_rim.name = "Rim"
	_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rim.draw.connect(_draw_rim)
	add_child(_rim)
	resized.connect(_on_resized)


## Vuelve a leer lo que ha descubierto el jugador y prende sus fichas. Con `keep_scroll`, conserva
## el desplazamiento (al registrar una deducción); si no, vuelve arriba (al abrir el tablero).
func refresh(keep_scroll: bool = true) -> void:
	var scroll_value := _scroll.scroll_vertical if keep_scroll else 0
	_items = BoardInfo.items()
	_empty.text = EMPTY_TEXT % BoardInfo.key_name("interact")
	for card: BoardEvidenceCard in _cards.values():
		_content.remove_child(card)
		card.queue_free()
	_cards.clear()
	for label: Label in _labels.values():
		_content.remove_child(label)
		label.queue_free()
	_labels.clear()
	for group in BoardInfo.GROUPS:
		var count := _items.filter(func(entry: Dictionary) -> bool: return entry["kind"] == group["kind"]).size()
		if count > 0:
			_labels[group["kind"]] = _group_label("%s · %d" % [group["title"], count])
	for entry in _items:
		var card := BoardEvidenceCard.new()
		card.setup(entry)
		card.toggled.connect(func(pressed: bool) -> void: item_toggled.emit(card.item_id, pressed))
		card.moved.connect(_connections.queue_redraw)
		_content.add_child(card)
		_cards[entry["id"]] = card
	# Los hilos, por encima de las fichas: ellos mismos se ocultan donde pasarían por detrás del papel.
	_content.move_child(_connections, -1)
	_arrange()
	_connections.set_relations(BoardInfo.relations(_cards.keys()))
	_restore_scroll.call_deferred(scroll_value)


## Marca las fichas elegidas para comparar, en orden: la primera es el elemento 1. Las fichas que ya
## tienen una relación registrada con una elegida avivan su chincheta.
func set_selection(ids: Array[String], animate: bool = true) -> void:
	var related := {}
	for relation in _connections.get_relations():
		if ids.has(relation["from"]):
			related[relation["to"]] = true
		if ids.has(relation["to"]):
			related[relation["from"]] = true
	for id: String in _cards:
		var card: BoardEvidenceCard = _cards[id]
		card.set_slot(ids.find(id) + 1, animate)
		card.related = related.has(id)
	_connections.set_focus(ids)


## Una relación recién registrada: su hilo se tiende poco a poco y la ficha de la deducción nueva
## destella, a la vista.
func animate_relation(deduction_id: String) -> void:
	_connections.animate_relation(deduction_id)
	var card: BoardEvidenceCard = _cards.get(deduction_id)
	if card != null:
		card.pulse()
		reveal.call_deferred(deduction_id)


func get_card(item_id: String) -> BoardEvidenceCard:
	return _cards.get(item_id)


func get_cards() -> Array[BoardEvidenceCard]:
	var cards: Array[BoardEvidenceCard] = []
	for card: BoardEvidenceCard in _cards.values():
		cards.append(card)
	return cards


func get_item_ids() -> PackedStringArray:
	return PackedStringArray(_cards.keys())


func get_group_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for group in BoardInfo.GROUPS:
		if _labels.has(group["kind"]):
			titles.append((_labels[group["kind"]] as Label).text)
	return titles


func get_placeholders() -> Array[Rect2]:
	return _placeholders.duplicate()


## Fichas y rótulos: los hilos pasan por detrás de ellos.
func _occluders() -> Array:
	var items: Array = _cards.values()
	items.append_array(_labels.values())
	return items


func get_connections() -> BoardConnections:
	return _connections


func get_scroll() -> ScrollContainer:
	return _scroll


func get_cork_rect() -> Rect2:
	return _cork_rect


func is_empty_shown() -> bool:
	return _empty.visible


func is_decor_shown() -> bool:
	return _decor.visible


## Chincheta de una ficha, en las coordenadas del contenido; `Vector2.INF` si no está en el tablero.
func get_pin_position(item_id: String) -> Vector2:
	var card: BoardEvidenceCard = _cards.get(item_id)
	return card.get_pin_position() if card != null else Vector2.INF


## Desplaza el corcho hasta una ficha.
func reveal(item_id: String) -> void:
	var card: BoardEvidenceCard = _cards.get(item_id)
	if card != null:
		_scroll.ensure_control_visible(card)


func _on_resized() -> void:
	var border := BoardStyle.CANVAS_BORDER
	_cork_rect = Rect2(Vector2(border, border), size - Vector2(border, border) * 2.0)
	_leather.position = Vector2.ZERO
	_leather.size = size
	(_leather.material as ShaderMaterial).set_shader_parameter("rect_size", size)
	_cork.position = _cork_rect.position
	_cork.size = _cork_rect.size
	(_cork.material as ShaderMaterial).set_shader_parameter("rect_size", _cork_rect.size)
	_scroll.position = _cork_rect.position
	_scroll.size = _cork_rect.size
	_rim.position = Vector2.ZERO
	_rim.size = size
	_decor.position = _cork_rect.position
	_decor.size = _cork_rect.size
	_place_decor()
	_arrange()
	_rim.queue_redraw()


func _restore_scroll(value: int) -> void:
	_scroll.scroll_vertical = value


# --- Reparto de las fichas ---

## Coloca las fichas por grupos, en una cuadrícula centrada que se ajusta al ancho del corcho.
func _arrange() -> void:
	if _cork_rect.size.x <= 0.0:
		return
	var padding := BoardStyle.CANVAS_PADDING
	var card_size := BoardStyle.CARD_SIZE
	var gap := BoardStyle.CARD_GAP
	var inner_width := _cork_rect.size.x - padding.x * 2.0 - SCROLLBAR_SPACE
	var columns := maxi(1, int(floorf((inner_width + gap.x) / (card_size.x + gap.x))))
	var row_width := columns * card_size.x + (columns - 1) * gap.x
	var left := padding.x + maxf((inner_width - row_width) * 0.5, 0.0)
	var y := padding.y
	var placed := 0
	var last_column := 0
	var last_row_top := y
	for group in BoardInfo.GROUPS:
		var ids: Array[String] = []
		for entry in _items:
			if entry["kind"] == group["kind"]:
				ids.append(entry["id"])
		if ids.is_empty():
			continue
		var label: Label = _labels[group["kind"]]
		label.position = Vector2(left - 4.0, y)
		y += BoardStyle.GROUP_LABEL_HEIGHT
		for index in ids.size():
			var column := index % columns
			var row := index / columns
			var card: BoardEvidenceCard = _cards[ids[index]]
			card.position = Vector2(left + column * (card_size.x + gap.x), y + row * (card_size.y + gap.y)) + _jitter(ids[index])
			last_column = column
			last_row_top = y + row * (card_size.y + gap.y)
		var rows := int(ceilf(float(ids.size()) / columns))
		y += rows * (card_size.y + gap.y) - gap.y + BoardStyle.GROUP_GAP + BoardStyle.GROUP_LABEL_HEIGHT * 0.3
		placed += ids.size()
	_placeholders.clear()
	if placed < PLACEHOLDER_MIN_CELLS:
		# Huecos libres a continuación de la última ficha (o, sin fichas, en la primera fila).
		var column := last_column + 1 if placed > 0 else 0
		var top := last_row_top if placed > 0 else padding.y + BoardStyle.GROUP_LABEL_HEIGHT
		for index in PLACEHOLDER_MIN_CELLS - placed:
			if column >= columns:
				column = 0
				top += card_size.y + gap.y
			_placeholders.append(Rect2(Vector2(left + column * (card_size.x + gap.x), top), card_size))
			column += 1
		y = maxf(y, top + card_size.y + padding.y)
	var decorative: Array[PackedVector2Array] = []
	for index in range(1, _placeholders.size()):
		decorative.append(PackedVector2Array([_placeholder_pin(_placeholders[index - 1]), _placeholder_pin(_placeholders[index])]))
	_connections.set_decorative(decorative)
	_empty.visible = _items.is_empty()
	if _empty.visible:
		var width := minf(inner_width * 0.8, 620.0)
		_empty.custom_minimum_size = Vector2(width, 0.0)
		_fit_empty()
		_fit_empty.call_deferred()
		var bottom := _placeholders[-1].end.y if not _placeholders.is_empty() else y
		_empty.position = Vector2(padding.x + (inner_width - width) * 0.5, bottom + 34.0)
		y = maxf(y, _empty.position.y + _empty.get_combined_minimum_size().y + padding.y)
	_content.custom_minimum_size = Vector2(0.0, y + padding.y * 0.5)
	_connections.position = Vector2.ZERO
	_connections.size = Vector2(_cork_rect.size.x, maxf(y, _cork_rect.size.y))
	_content.queue_redraw()
	_connections.queue_redraw()


## La nota del estado vacío sólo ocupa el alto de su texto: con ajuste de línea, una etiqueta mide su
## alto con el ancho que tenía y no encoge sola.
func _fit_empty() -> void:
	_empty.size = Vector2(_empty.custom_minimum_size.x, 0.0)
	_empty.size = Vector2(_empty.custom_minimum_size.x, _empty.get_combined_minimum_size().y)


## Pequeño desplazamiento propio de cada ficha, como papeles prendidos a mano.
static func _jitter(item_id: String) -> Vector2:
	var value := absi(hash(item_id + "#"))
	return Vector2(float(value % 9) - 4.0, float((value / 9) % 7) - 3.0)


## Rótulo de un grupo: una tira de papel prendida con una chincheta («PRUEBAS · 4»).
func _group_label(text: String) -> Label:
	var label := BoardStyle.make_label(text, BoardStyle.banner_font(), BoardStyle.GROUP_SIZE, BoardStyle.INK)
	label.name = "Group_%d" % _labels.size()
	var strip := BoardStyle.box(Color(BoardStyle.PARCHMENT_LIGHT, 0.95), Color(BoardStyle.INK, 0.35), 1, 1, Vector4(30.0, 4.0, 16.0, 5.0))
	strip.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	strip.shadow_size = 3
	strip.shadow_offset = Vector2(1.0, 2.0)
	label.add_theme_stylebox_override("normal", strip)
	label.rotation_degrees = -1.0
	label.draw.connect(func() -> void: BoardOrnaments.draw_pin(label, Vector2(14.0, label.size.y * 0.5), BoardStyle.BRASS, 6.0))
	_content.add_child(label)
	return label


# --- Dibujo ---

func _draw_content() -> void:
	for rect in _placeholders:
		BoardOrnaments.draw_placeholder(_content, rect)
		BoardOrnaments.draw_pin(_content, _placeholder_pin(rect), BoardStyle.BRASS, 5.0)


static func _placeholder_pin(rect: Rect2) -> Vector2:
	return Vector2(rect.get_center().x, rect.position.y + 1.0)


func _place_decor() -> void:
	_decor.visible = _cork_rect.size.y >= DECOR_MIN_HEIGHT
	var art := _decor_art_rect()
	var photo_size := Vector2(art.size.x * 0.4, art.size.x * 0.3)
	_decor_photo.size = photo_size
	_decor_photo.position = Vector2(art.position.x + art.size.x * 0.44, art.end.y - art.size.y * 0.24 - photo_size.y)
	_decor.queue_redraw()


## Dónde va el grabado del rincón, dentro del corcho: abajo a la izquierda, a escala del corcho.
func _decor_art_rect() -> Rect2:
	var width := clampf(_cork_rect.size.x * 0.36, 260.0, 430.0)
	var art_size := Vector2(width, width * DECOR_ART.get_height() / DECOR_ART.get_width())
	return Rect2(Vector2(-6.0, _cork_rect.size.y - art_size.y + 6.0), art_size)


func _draw_decor() -> void:
	var art := _decor_art_rect()
	_decor.draw_texture_rect(DECOR_ART, art, false, Color(1.0, 1.0, 1.0, 0.92))
	var stain := Color(0.36, 0.22, 0.1, 0.22)
	BoardOrnaments.draw_coffee_ring(_decor, Vector2(art.end.x + 70.0, _cork_rect.size.y - 70.0), 34.0, stain)
	BoardOrnaments.draw_coffee_ring(_decor, Vector2(_cork_rect.size.x - 90.0, 80.0), 28.0, Color(stain, 0.14))


## Marco del corcho: un filete oscuro, otro dorado y escuadras en las esquinas, por encima de todo.
func _draw_rim() -> void:
	var cork := _cork_rect
	_rim.draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), Color(BoardStyle.FRAME, 0.9), false, 2.0, true)
	_rim.draw_rect(Rect2(Vector2.ZERO, size).grow(-5.0), Color(BoardStyle.GOLD, 0.55), false, 1.2, true)
	_rim.draw_rect(cork.grow(1.0), Color(BoardStyle.LEATHER_DARK, 0.95), false, 2.5, true)
	_rim.draw_rect(cork.grow(3.5), Color(BoardStyle.GOLD_DARK, 0.7), false, 1.0, true)
	HudOrnaments.draw_corner_brackets(_rim, cork.grow(-8.0), 18.0, Color(BoardStyle.GOLD_DARK, 0.6))
