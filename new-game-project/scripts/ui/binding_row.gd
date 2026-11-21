class_name BindingRow
extends PanelContainer
## Fila de la lista de controles: la acción a la izquierda y sus teclas a la derecha, con «o»
## entre las alternativas. Recibe el foco para recorrer la lista con el teclado, el mando o el
## ratón, salvo que se cree no seleccionable (las teclas fijas de la pantalla de reasignación).

## Acciones del InputMap que representa la fila; vacío si las teclas son fijas del código.
var actions: Array[String] = []
## Si recibe el foco. Las filas sólo informativas no lo reciben y se ven atenuadas.
var selectable := true

var _label: Label
var _keys: HBoxContainer
var _groups: Array[PackedStringArray] = []


func _init(label_text: String = "", key_groups: Array[PackedStringArray] = [], row_actions: Array[String] = [], can_select: bool = true) -> void:
	actions = row_actions
	selectable = can_select
	_groups = key_groups
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = MenuStyle.make_label(label_text, 21, MenuStyle.TEXT if can_select else MenuStyle.TEXT_SECONDARY)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_label)
	_keys = HBoxContainer.new()
	_keys.add_theme_constant_override("separation", 6)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_keys)
	add_child(box)
	_fill_keys()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL if selectable else Control.FOCUS_NONE
	custom_minimum_size.y = 48.0
	_set_highlighted(false)
	if not selectable:
		return
	focus_entered.connect(_set_highlighted.bind(true))
	focus_exited.connect(_set_highlighted.bind(false))
	mouse_entered.connect(grab_focus)


func get_action_text() -> String:
	return _label.text


## Teclas que muestra cada alternativa, p. ej. [["W", "A", "S", "D"], ["↑", "←", "↓", "→"]].
func get_key_groups() -> Array[PackedStringArray]:
	return _groups


func set_key_groups(key_groups: Array[PackedStringArray]) -> void:
	_groups = key_groups
	for child in _keys.get_children():
		_keys.remove_child(child)
		child.queue_free()
	_fill_keys()


func _fill_keys() -> void:
	for index in _groups.size():
		if index > 0:
			_keys.add_child(MenuStyle.make_label("o", 18, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic()))
		for key in _groups[index]:
			_keys.add_child(KeyCap.new(key))


func _set_highlighted(highlighted: bool) -> void:
	add_theme_stylebox_override("panel", MenuStyle.row_box(highlighted))
