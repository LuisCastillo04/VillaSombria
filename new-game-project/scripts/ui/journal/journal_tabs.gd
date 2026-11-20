class_name JournalTabs
extends HBoxContainer
## Fila de pestañas del expediente. Crea una `JournalTab` por sección, las agrupa para que sólo una
## esté elegida y avisa con `tab_changed`. Si el ancho no alcanza, pasa a pestañas compactas.

signal tab_changed(index: int)

const MAX_TAB_WIDTH := 268.0

var _group := ButtonGroup.new()
var _tabs: Array[JournalTab] = []
var _selected := -1


func _init() -> void:
	add_theme_constant_override("separation", int(JournalStyle.TAB_GAP))
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Crea las pestañas a partir de `{title, icon}`.
func setup(definitions: Array[Dictionary]) -> void:
	for tab in _tabs:
		remove_child(tab)
		tab.queue_free()
	_tabs.clear()
	for index in definitions.size():
		var definition: Dictionary = definitions[index]
		var tab := JournalTab.new(definition["title"], definition["icon"])
		tab.name = "Tab%d" % index
		tab.button_group = _group
		tab.toggled.connect(_on_tab_toggled.bind(index))
		add_child(tab)
		_tabs.append(tab)


## Elige una pestaña sin avisar (quien la elige ya sabe qué sección mostrar).
func select(index: int) -> void:
	if index < 0 or index >= _tabs.size():
		return
	_selected = index
	_tabs[index].set_pressed_no_signal(true)
	# `set_pressed_no_signal` no suelta a las demás del grupo.
	for other in _tabs.size():
		if other != index:
			_tabs[other].set_pressed_no_signal(false)


func get_selected() -> int:
	return _selected


func get_tab(index: int) -> JournalTab:
	return _tabs[index]


func get_tab_count() -> int:
	return _tabs.size()


func is_compact() -> bool:
	return not _tabs.is_empty() and _tabs[0].is_compact()


## Ajusta las pestañas al ancho disponible: todas iguales, hasta `MAX_TAB_WIDTH`, y compactas si
## alguna no cabe en su parte.
func fit_width(width: float) -> void:
	if _tabs.is_empty():
		return
	var each := floorf(minf((width - JournalStyle.TAB_GAP * (_tabs.size() - 1)) / _tabs.size(), MAX_TAB_WIDTH))
	var compact := false
	for tab in _tabs:
		tab.set_compact(false)
		if tab.get_content_width() > each:
			compact = true
	for tab in _tabs:
		tab.set_compact(compact)
		tab.fit(each)


## Si las pestañas caben en `width`, aunque sea en su versión compacta.
func fits(width: float) -> bool:
	var each := (width - JournalStyle.TAB_GAP * (_tabs.size() - 1)) / maxf(_tabs.size(), 1)
	for tab in _tabs:
		var was_compact := tab.is_compact()
		tab.set_compact(true)
		var needed := tab.get_content_width()
		tab.set_compact(was_compact)
		if needed > each:
			return false
	return true


func _on_tab_toggled(pressed: bool, index: int) -> void:
	if pressed and index != _selected:
		_selected = index
		tab_changed.emit(index)
