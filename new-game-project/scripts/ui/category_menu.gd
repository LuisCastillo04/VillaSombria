class_name CategoryMenu
extends MenuScreen
## Menú por categorías: pestañas a la izquierda, el contenido de la elegida a la derecha y
## «Volver» al pie. Las subclases crean sus categorías en `_build_categories()` con
## `add_category()`; el encabezado, la navegación, el desplazamiento y los fundidos son comunes.
## Una categoría nueva sólo necesita otra llamada a `add_category()`.

const PAGE_FADE_SECONDS := 0.14

@export var title := ""
## Nombre del icono de `assets/ui/iconos/` para el medallón.
@export var emblem_icon := ""
@export var panel_size := Vector2(1000.0, 640.0)

var _tab_group := ButtonGroup.new()
var _tabs: Array[CategoryTab] = []
var _pages: Array[VBoxContainer] = []
var _scrolls: Array[ScrollContainer] = []
var _selected := -1
var _page_tween: Tween

@onready var _frame: MenuFrame = %Frame
@onready var _heading: MenuHeading = %Heading
@onready var _tab_list: VBoxContainer = %Tabs
@onready var _page_stack: MarginContainer = %Pages
@onready var _back: MenuOptionButton = %Back


func _ready() -> void:
	if not emblem_icon.is_empty():
		_frame.emblem = CaseFileStyle.icon(emblem_icon)
	_frame.custom_minimum_size = panel_size
	_heading.text = title
	_back.pressed.connect(_on_back_pressed)
	_build_categories()
	_link_focus()
	if not _tabs.is_empty():
		select_category(0)


## Crea una categoría y devuelve la columna donde van sus filas.
func add_category(label: String, icon_name: String) -> VBoxContainer:
	var index := _tabs.size()
	var tab := CategoryTab.new()
	tab.name = "Tab%d" % index
	tab.text = label
	tab.icon = CaseFileStyle.icon(icon_name)
	tab.button_group = _tab_group
	tab.toggled.connect(_on_tab_toggled.bind(index))
	_tab_list.add_child(tab)
	# Cada página se desplaza sola si sus filas no caben, para poder añadir opciones sin rediseñar.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	MenuStyle.style_scroll_bar(scroll.get_v_scroll_bar())
	scroll.hide()
	var page := VBoxContainer.new()
	page.name = "Page%d" % index
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 12)
	scroll.add_child(page)
	_page_stack.add_child(scroll)
	_tabs.append(tab)
	_pages.append(page)
	_scrolls.append(scroll)
	return page


## Selecciona una categoría. Si el foco estaba en las pestañas, pasa a la nueva.
func select_category(index: int) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_in_tabs := focused != null and _tab_list.is_ancestor_of(focused)
	_tabs[index].button_pressed = true
	_show_page(index)
	if focus_in_tabs:
		_tabs[index].grab_focus()


func get_selected_category() -> int:
	return _selected


func get_category_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for tab in _tabs:
		titles.append(tab.text)
	return titles


func get_tab(index: int) -> CategoryTab:
	return _tabs[index]


func get_page(index: int) -> VBoxContainer:
	return _pages[index]


func get_back_button() -> MenuOptionButton:
	return _back


## Las subclases añaden aquí sus categorías.
func _build_categories() -> void:
	pass


## Filete dorado con rombo que separa dos bloques de una página.
func add_divider(page: VBoxContainer) -> GoldDivider:
	var divider := GoldDivider.new()
	divider.custom_minimum_size = Vector2(0.0, 16.0)
	divider.color = Color(MenuStyle.GOLD, 0.45)
	page.add_child(divider)
	return divider


## Filete y, debajo, las funciones previstas que todavía no existen.
func add_planned_section(page: VBoxContainer, planned_options: Array[Dictionary]) -> void:
	add_divider(page)
	for planned: Dictionary in planned_options:
		page.add_child(planned_row(planned))


## Fila de una función prevista: atenuada, sin foco ni controles, con «Próximamente». Se marca
## con el metadato `planned` para distinguirla de las filas reales.
static func planned_row(planned: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", MenuStyle.row_box())
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_meta("planned", true)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.add_child(MenuStyle.make_label(planned["label"], 20, MenuStyle.TEXT_MUTED, CaseFileStyle.serif_bold()))
	if planned.has("detail"):
		texts.add_child(MenuStyle.make_label(planned["detail"], 17, MenuStyle.TEXT_MUTED, CaseFileStyle.serif_italic()))
	box.add_child(texts)
	box.add_child(MenuStyle.make_soon_badge())
	row.add_child(box)
	return row


func _focus_default() -> void:
	if _selected >= 0:
		_tabs[_selected].grab_focus()
	else:
		_back.grab_focus()


func _on_tab_toggled(pressed: bool, index: int) -> void:
	if pressed:
		_show_page(index)


func _show_page(index: int) -> void:
	if index == _selected:
		return
	_selected = index
	for page_index in _scrolls.size():
		_scrolls[page_index].visible = page_index == index
	var scroll := _scrolls[index]
	scroll.modulate.a = 0.0
	if _page_tween != null:
		_page_tween.kill()
	_page_tween = create_tween()
	_page_tween.tween_property(scroll, "modulate:a", 1.0, PAGE_FADE_SECONDS)


## Las pestañas se enlazan entre sí y la última con «Volver», sin depender de la geometría. Cada
## pestaña lleva a la derecha al primer control de su página, y desde la página la izquierda vuelve
## a esa pestaña: recorrer el contenido nunca cambia de categoría sin querer.
func _link_focus() -> void:
	for index in _tabs.size():
		var tab := _tabs[index]
		tab.focus_neighbor_top = tab.get_path_to(_tabs[index - 1]) if index > 0 else NodePath(".")
		tab.focus_neighbor_bottom = tab.get_path_to(_tabs[index + 1] if index + 1 < _tabs.size() else _back)
		var focusables := _focusables(_pages[index])
		tab.focus_neighbor_right = tab.get_path_to(focusables[0]) if not focusables.is_empty() else NodePath(".")
		for control in focusables:
			control.focus_neighbor_left = control.get_path_to(tab)


func _focusables(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child in root.get_children():
		var control := child as Control
		if control != null and control.focus_mode == Control.FOCUS_ALL:
			found.append(control)
		found.append_array(_focusables(child))
	return found


func _on_back_pressed() -> void:
	AudioManager.play("click")
	close()
