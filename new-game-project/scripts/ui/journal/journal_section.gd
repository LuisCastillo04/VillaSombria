class_name JournalSection
extends HBoxContainer
## Una sección del expediente: la página izquierda con su lista (`JournalListColumn`) y la derecha con
## la ficha del elemento elegido (`JournalDetail`). Las cinco secciones heredan de aquí la
## composición, el reparto de anchos, la selección y el desplazamiento; cada una sólo dice de dónde
## salen sus datos (`JournalInfo`) y cómo se pinta su ficha.
##
## Las secciones se construyen una vez y se conservan: `refresh()` vuelve a leer los datos y la lista
## sólo rehace sus fichas si han cambiado, así cambiar de pestaña no reconstruye nada.

## Rótulo de la pestaña y de la cinta, e icono.
var title := ""
var icon_name := ""
var column: JournalListColumn
var detail: JournalDetail
var list: JournalList
## Columna derecha: la ficha y, debajo, el hueco del pie del expediente.
var side: VBoxContainer

## Entradas que pinta la lista, por identificador.
var _entries: Dictionary = {}


func _init(section_title: String = "", section_icon: String = "") -> void:
	title = section_title
	icon_name = section_icon
	name = section_title.validate_node_name()
	add_theme_constant_override("separation", int(JournalStyle.COLUMN_GAP))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	column = JournalListColumn.new(section_title.to_upper(), _banner_icon())
	column.name = "Column"
	add_child(column)
	side = VBoxContainer.new()
	side.name = "Side"
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 0)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail = JournalDetail.new()
	detail.name = "Detail"
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(detail)
	# La ficha deja libre la franja del pie; la página de la lista llega hasta abajo.
	var footer_space := Control.new()
	footer_space.name = "FooterSpace"
	footer_space.custom_minimum_size.y = JournalStyle.FOOTER_HEIGHT + 8.0
	footer_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(footer_space)
	add_child(side)
	_build()
	resized.connect(_fit_columns)


## Icono de la cinta; por defecto, el de la pestaña.
func _banner_icon() -> String:
	return icon_name


## Las subclases crean aquí su contenido. Por defecto, una lista elegible.
func _build() -> void:
	list = JournalList.new()
	list.name = "List"
	column.content.add_child(list)
	list.selection_changed.connect(_on_selection_changed)


## Vuelve a leer los datos y pinta la sección. Las subclases lo amplían.
func refresh() -> void:
	pass


## Pone las fichas en la lista y pinta la elegida (o el estado vacío).
func _show_entries(entries: Array[Dictionary], banner_title: String, empty_text: String) -> void:
	_entries.clear()
	for entry in entries:
		_entries[entry["id"]] = entry
	column.set_title(banner_title)
	list.set_entries(entries)
	column.set_empty_text(empty_text if entries.is_empty() else "")
	_show_selected()


func _show_selected() -> void:
	var selected := list.get_selected_id() if list != null else ""
	if selected.is_empty() or not _entries.has(selected):
		_show_empty()
	else:
		detail.clear()
		_show_detail(_entries[selected])


## Pinta la ficha de una entrada. Lo implementa cada sección.
func _show_detail(_entry: Dictionary) -> void:
	pass


## Pinta el estado vacío de la ficha. Lo implementa cada sección.
func _show_empty() -> void:
	detail.show_empty()


func _on_selection_changed(_entry_id: String) -> void:
	_show_selected()


# --- Navegación ---

func get_list() -> JournalList:
	return list


## Lleva el foco a la ficha elegida. Devuelve si había dónde ponerlo.
func focus_content() -> bool:
	return list != null and list.focus_selected()


## Elige la ficha anterior o siguiente.
func step_selection(direction: int) -> void:
	if list != null:
		list.step(direction)


func scroll_detail(pixels: float) -> void:
	detail.scroll_by(pixels)


## La primera ficha sube a la pestaña de su sección.
func link_focus(tab: Control) -> void:
	if list != null:
		list.link_focus(tab)


## Dónde puede empezar el pie del expediente, medido desde la izquierda de la sección: bajo la ficha.
func get_footer_left() -> float:
	return side.position.x


## Ancho de la columna de la lista: una parte fija del total, entre un mínimo y un máximo.
func get_column_width() -> float:
	return clampf(size.x * JournalStyle.LIST_RATIO, JournalStyle.LIST_MIN_WIDTH, JournalStyle.LIST_MAX_WIDTH)


func _fit_columns() -> void:
	var column_width := get_column_width()
	column.custom_minimum_size.x = column_width
	var taken := column_width + JournalStyle.COLUMN_GAP if column.visible else 0.0
	detail.fit_to_width(size.x - taken)


# --- Ayudas para las secciones ---

## Retrato recortado de una silueta, para las miniaturas.
static func face_of(portrait_path: String) -> Texture2D:
	return JournalInfo.portrait(portrait_path, JournalInfo.PORTRAIT_FACE)


static func bust_of(portrait_path: String) -> Texture2D:
	return JournalInfo.portrait(portrait_path, JournalInfo.PORTRAIT_BUST)
