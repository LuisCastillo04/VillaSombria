class_name HudControlsBar
extends NoirPlate
## Barra inferior del HUD: un sombrero de detective y, separadas por filetes dorados, las teclas de
## `HudInfo.CONTROL_HINTS` con las asignaciones reales del InputMap. Las entradas se reparten a
## partes iguales por todo el ancho.
##
## Es contextual sin inventar nada: la tecla de interactuar se enciende cuando hay algo al alcance
## y la de esperar se apaga cuando el reloj ya no puede avanzar. Si el ancho no alcanza, la barra
## pasa a una versión compacta y, si aun así no cabe, oculta primero las entradas de menor
## prioridad; las imprescindibles (prioridad 0) nunca se ocultan. Una acción sin tecla no aparece.

const SEPARATOR_HEIGHT := 30.0
const GAP := 14
const GAP_COMPACT := 8

var _row: HBoxContainer
var _hat: TextureRect
var _hints: Array[HudKeyHint] = []
## Teclas leídas la última vez, para no reconstruir la barra si nada cambió.
var _signature := ""
var _fitted_width := -1.0
var _compact := false
var _interaction_available := false
var _wait_available := true


func _init() -> void:
	padding = Vector4(24.0, 8.0, 28.0, 8.0)
	custom_minimum_size.y = HudStyle.BAR_HEIGHT
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hat = HudStyle.make_icon(HudStyle.icon("sombrero"), HudStyle.BAR_ICON, HudStyle.GOLD)
	_row.add_child(_hat)
	add_child(_row)
	refresh()


## Vuelve a leer las teclas del InputMap. Devuelve si algo cambió y hubo que reconstruir la barra.
func refresh() -> bool:
	var signature := _read_signature()
	if signature == _signature:
		return false
	_signature = signature
	_build()
	return true


func get_hints() -> Array[HudKeyHint]:
	return _hints


func get_hint(hint_id: String) -> HudKeyHint:
	for hint in _hints:
		if hint.hint_id == hint_id:
			return hint
	return null


## Identificadores de las entradas que se ven ahora, en orden.
func get_visible_hint_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for hint in _hints:
		if _slot_of(hint).visible:
			ids.append(hint.hint_id)
	return ids


func is_compact() -> bool:
	return _compact


## Enciende la tecla de interactuar mientras haya algo al alcance.
func set_interaction_available(available: bool) -> void:
	_interaction_available = available
	var hint := get_hint("interact")
	if hint != null:
		hint.set_lit(available)


## Apaga la tecla de esperar cuando el reloj ya no puede avanzar.
func set_wait_available(available: bool) -> void:
	_wait_available = available
	var hint := get_hint("wait")
	if hint != null:
		hint.set_dimmed(not available)


## Ajusta la barra a `width`: con las medidas normales si caben; si no, en compacto; y si aun así
## no cabe, oculta las entradas de menor prioridad, empezando por la última.
func fit_width(width: float) -> void:
	if is_equal_approx(width, _fitted_width):
		return
	_fitted_width = width
	for compact: bool in [false, true]:
		_set_compact(compact)
		_show_all()
		if _natural_width() <= width:
			return
	for hint in _hide_order():
		_set_hint_shown(hint, false)
		if _natural_width() <= width:
			return


## Ancho que ocupan las entradas visibles sin repartir el espacio sobrante.
func _natural_width() -> float:
	return get_combined_minimum_size().x


func _build() -> void:
	for child in _row.get_children():
		if child != _hat:
			_row.remove_child(child)
			child.queue_free()
	_hints.clear()
	for definition: Dictionary in HudInfo.CONTROL_HINTS:
		var keys := HudInfo.hint_keys(definition)
		if keys.is_empty():
			continue
		var separator := HudStyle.make_separator(Color(HudStyle.GOLD, 0.55), SEPARATOR_HEIGHT)
		_row.add_child(separator)
		var slot := CenterContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hint := HudKeyHint.new(keys, definition["label"])
		hint.hint_id = definition["id"]
		hint.set_meta("priority", int(definition.get("priority", 0)))
		hint.set_meta("separator", separator)
		hint.set_compact(_compact)
		slot.add_child(hint)
		_row.add_child(slot)
		_hints.append(hint)
	set_interaction_available(_interaction_available)
	set_wait_available(_wait_available)
	_fitted_width = -1.0


func _read_signature() -> String:
	var parts := PackedStringArray()
	for definition: Dictionary in HudInfo.CONTROL_HINTS:
		parts.append("%s=%s" % [definition["id"], ",".join(HudInfo.hint_keys(definition))])
	return ";".join(parts)


func _set_compact(compact: bool) -> void:
	_compact = compact
	_row.add_theme_constant_override("separation", GAP_COMPACT if compact else GAP)
	for hint in _hints:
		hint.set_compact(compact)


func _show_all() -> void:
	for hint in _hints:
		_set_hint_shown(hint, true)


func _set_hint_shown(hint: HudKeyHint, shown: bool) -> void:
	_slot_of(hint).visible = shown
	(hint.get_meta("separator") as Control).visible = shown


func _slot_of(hint: HudKeyHint) -> Control:
	return hint.get_parent() as Control


## Entradas que se pueden ocultar, de la menos importante a la más: prioridad más alta primero y,
## a igual prioridad, la que va más a la derecha.
func _hide_order() -> Array[HudKeyHint]:
	var order: Array[HudKeyHint] = []
	for hint in _hints:
		if int(hint.get_meta("priority")) > 0:
			order.append(hint)
	order.sort_custom(_hides_before)
	return order


func _hides_before(a: HudKeyHint, b: HudKeyHint) -> bool:
	var priority_a := int(a.get_meta("priority"))
	var priority_b := int(b.get_meta("priority"))
	if priority_a != priority_b:
		return priority_a > priority_b
	return _hints.find(a) > _hints.find(b)
