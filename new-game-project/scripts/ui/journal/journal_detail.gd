class_name JournalDetail
extends JournalPage
## Página derecha de una sección: la ficha del elemento elegido. Arriba, una insignia burdeos con su
## icono, el nombre y una línea en cursiva; un filete con rombo; debajo, el contenido desplazable
## (texto en un recuadro hundido, datos con icono, apartados) y, a la derecha, una fotografía
## sujeta con un clip. Cuando no hay nada que enseñar, muestra un estado vacío en su lugar.
##
## Las secciones sólo dicen qué poner: `set_heading`, `add_text_box`, `add_field`, `set_photo`…
## La composición, las letras y los márgenes son siempre los mismos.

const PHOTO_SIZE := Vector2(JournalStyle.PHOTO_WIDTH, 400.0)
const PHOTO_GAP := 34.0
## Parte del ancho útil que puede ocupar la foto, y ancho por debajo del cual no se muestra.
const PHOTO_SHARE := 0.34
const PHOTO_MIN_WIDTH := 170.0

var _layout: HBoxContainer
var _main: VBoxContainer
var _badge: PanelContainer
var _badge_icon: TextureRect
var _title: Label
var _subtitle: Label
var _scroll: ScrollContainer
var _fields: VBoxContainer
var _photo_box: VBoxContainer
var _photo: JournalPhoto
var _empty: JournalEmptyState
var _fade: Tween
var _wants_photo := false
## Ancho que la sección deja a la ficha. Se usa en lugar del tamaño propio, que una foto demasiado
## ancha podría inflar.
var _available_width := 0.0


func _init() -> void:
	super._init()
	padding = Vector4(34.0, 30.0, 34.0, 26.0)
	paper_seed = 9.3
	_layout = HBoxContainer.new()
	_layout.add_theme_constant_override("separation", int(PHOTO_GAP))
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main = VBoxContainer.new()
	_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main.add_theme_constant_override("separation", 12)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.add_child(_build_heading())
	_main.add_child(JournalStyle.make_rule())
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	JournalStyle.style_scroll(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fields = VBoxContainer.new()
	_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields.add_theme_constant_override("separation", 14)
	_fields.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_fields)
	_scroll.add_child(margin)
	_main.add_child(_scroll)
	_layout.add_child(_main)
	_photo_box = VBoxContainer.new()
	_photo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_box.add_theme_constant_override("separation", 0)
	var photo_spacer := Control.new()
	photo_spacer.custom_minimum_size.y = 30.0
	photo_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_box.add_child(photo_spacer)
	_photo = JournalPhoto.new()
	_photo.custom_minimum_size = PHOTO_SIZE
	_photo.tilt = 3.5
	_photo_box.add_child(_photo)
	_photo_box.hide()
	_layout.add_child(_photo_box)
	add_child(_layout)
	_empty = JournalEmptyState.new()
	_empty.hide()
	add_child(_empty)


func _build_heading() -> HBoxContainer:
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 22)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge = PanelContainer.new()
	_badge.add_theme_stylebox_override("panel", JournalStyle.badge_box())
	_badge.custom_minimum_size = Vector2(JournalStyle.BADGE_SIZE, JournalStyle.BADGE_SIZE)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_icon = TextureRect.new()
	_badge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge_icon.modulate = JournalStyle.CREAM
	_badge_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(_badge_icon)
	heading.add_child(_badge)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", -2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = JournalStyle.make_label("", JournalStyle.heading_font(), JournalStyle.DETAIL_TITLE_SIZE, JournalStyle.BURGUNDY_INK, true)
	texts.add_child(_title)
	_subtitle = JournalStyle.make_label("", JournalStyle.italic_font(), JournalStyle.DETAIL_SUBTITLE_SIZE, JournalStyle.INK, true)
	texts.add_child(_subtitle)
	heading.add_child(texts)
	return heading


# --- Encabezado y foto ---

func set_heading(icon_name: String, title: String, subtitle: String = "", title_size: int = JournalStyle.DETAIL_TITLE_SIZE) -> void:
	_badge_icon.texture = JournalStyle.icon(icon_name)
	_title.text = title
	_title.add_theme_font_size_override("font_size", title_size)
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.is_empty()


func set_photo(texture: Texture2D, mode: JournalPhoto.Mode, caption: String = "") -> void:
	_photo.set_picture(texture, mode)
	_photo.set_caption(caption)
	_wants_photo = true
	_fit_photo()


func hide_photo() -> void:
	_wants_photo = false
	_photo_box.hide()


## Ancho disponible para la ficha: lo fija la sección al repartir sus columnas.
func fit_to_width(width: float) -> void:
	_available_width = width
	_fit_photo()


## La foto ocupa como mucho una parte del ancho, para que el texto siempre tenga sitio; en una
## página muy estrecha se retira.
func _fit_photo() -> void:
	var inner := _available_width - padding.x - padding.z - PHOTO_GAP
	var width := minf(PHOTO_SIZE.x, floorf(inner * PHOTO_SHARE))
	_photo_box.visible = _wants_photo and width >= PHOTO_MIN_WIDTH
	if _photo_box.visible:
		_photo.custom_minimum_size = Vector2(width, floorf(width * PHOTO_SIZE.y / PHOTO_SIZE.x))


# --- Contenido ---

## Vacía el contenido y vuelve a la ficha (por si se mostraba el estado vacío).
func clear() -> void:
	for child in _fields.get_children():
		_fields.remove_child(child)
		child.queue_free()
	_empty.hide()
	_layout.show()
	_scroll.scroll_vertical = 0


## Texto principal en un recuadro hundido: la biografía, la declaración, la descripción.
func add_text_box(text: String, italic: bool = true) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", JournalStyle.inset_box())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := JournalStyle.italic_font() if italic else JournalStyle.body_font()
	var label := JournalStyle.make_label(text, font, JournalStyle.BODY_SIZE, JournalStyle.INK, true)
	label.add_theme_constant_override("line_spacing", 4)
	panel.add_child(label)
	_fields.add_child(panel)
	return label


## Dato con icono: «Paradero: Bebiendo junto a la chimenea».
func add_field(icon_name: String, label: String, value: String) -> HBoxContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", JournalStyle.field_box())
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.name = "Field_%s" % label.validate_node_name()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", JournalStyle.field_icon_box())
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(JournalStyle.make_icon(icon_name, 34.0, JournalStyle.BURGUNDY_INK))
	box.add_child(cell)
	var name_label := JournalStyle.make_label(label, JournalStyle.heading_font(), JournalStyle.FIELD_SIZE, JournalStyle.BURGUNDY_INK)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(name_label)
	var value_label := JournalStyle.make_label(value, JournalStyle.body_font(), JournalStyle.BODY_SIZE, JournalStyle.INK, true)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label.name = "Value"
	box.add_child(value_label)
	row.add_child(box)
	_fields.add_child(row)
	return box


## Rótulo de un apartado, en versalitas burdeos con un filete.
func add_section_title(text: String) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := JournalStyle.make_label(text.to_upper(), JournalStyle.banner_font(), JournalStyle.SECTION_SIZE, JournalStyle.BURGUNDY_INK, true)
	box.add_child(label)
	var rule := GoldDivider.new()
	rule.diamond = false
	rule.color = Color(JournalStyle.BURGUNDY_INK, 0.45)
	rule.custom_minimum_size = Vector2(0.0, 8.0)
	box.add_child(rule)
	_fields.add_child(box)
	return label


## Elementos relacionados (pruebas, declaraciones), uno por línea con su icono.
func add_item_rows(items: Array[Dictionary]) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in items:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(JournalStyle.make_icon(item.get("icon", "lupa"), 28.0, JournalStyle.INK_SOFT))
		var title := JournalStyle.make_label(item.get("title", ""), JournalStyle.body_font(), JournalStyle.NOTE_SIZE + 1, JournalStyle.INK, true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		list.add_child(row)
	_fields.add_child(list)
	return list


## Párrafo suelto, sin recuadro.
func add_paragraph(text: String, color: Color = JournalStyle.INK_SOFT) -> Label:
	var label := JournalStyle.make_label(text, JournalStyle.italic_font(), JournalStyle.NOTE_SIZE, color, true)
	_fields.add_child(label)
	return label


## Cualquier otro control, como las tarjetas de recuento de Objetivos.
func add_custom(control: Control) -> void:
	_fields.add_child(control)


# --- Estado vacío ---

## Sustituye la ficha por un estado vacío y devuelve el componente para rellenarlo.
func show_empty() -> JournalEmptyState:
	clear()
	_layout.hide()
	_empty.show()
	return _empty


func is_empty_shown() -> bool:
	return _empty.visible


func get_empty_state() -> JournalEmptyState:
	return _empty


# --- Consultas y desplazamiento ---

func get_title() -> String:
	return _title.text


func get_subtitle() -> String:
	return _subtitle.text if _subtitle.visible else ""


func get_photo() -> JournalPhoto:
	return _photo


func is_photo_shown() -> bool:
	return _photo_box.visible and _layout.visible


## Si la ficha lleva foto, aunque una página muy estrecha la retire.
func has_photo() -> bool:
	return _wants_photo


func get_fields() -> VBoxContainer:
	return _fields


func get_scroll() -> ScrollContainer:
	return _scroll


## Texto de todos los rótulos del contenido, para las pruebas y la accesibilidad.
func get_field_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	_collect_texts(_fields, texts)
	return texts


func scroll_by(pixels: float) -> void:
	_scroll.scroll_vertical = int(_scroll.scroll_vertical + pixels)


## Aparición suave del contenido nuevo al cambiar de ficha.
func fade_in() -> void:
	if _fade != null:
		_fade.kill()
	_layout.modulate.a = 0.35
	_empty.modulate.a = 0.35
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_fade.tween_property(_layout, "modulate:a", 1.0, JournalStyle.DETAIL_SECONDS)
	_fade.tween_property(_empty, "modulate:a", 1.0, JournalStyle.DETAIL_SECONDS)


static func _collect_texts(node: Node, texts: PackedStringArray) -> void:
	for child in node.get_children():
		if child is Label and not child.is_queued_for_deletion():
			texts.append((child as Label).text)
		_collect_texts(child, texts)
