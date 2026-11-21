class_name RebindRow
extends PanelContainer
## Fila de una acción en la pantalla de reasignación: su nombre a la izquierda y sus dos huecos a la
## derecha, la tecla principal y la alternativa (`KeySlotButton`). Tiene el aspecto de las filas de
## la lista de controles y se resalta cuando uno de sus huecos tiene el foco. Una acción con teclas
## distintas de las de fábrica lo indica bajo su nombre.

const CUSTOM_TEXT := "Personalizada"

## Acción reasignable que representa.
var action := ""

var _label: Label
var _note: Label
var _slots: Array[KeySlotButton] = []


func _init(row_action: String = "", label_text: String = "") -> void:
	action = row_action
	name = "Fila_" + row_action
	mouse_filter = Control.MOUSE_FILTER_PASS
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", -2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = MenuStyle.make_label(label_text, 21)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_label)
	_note = MenuStyle.make_label(CUSTOM_TEXT, 16, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	_note.hide()
	texts.add_child(_note)
	box.add_child(texts)
	for index in InputBindings.SLOTS:
		var slot := KeySlotButton.new(row_action, index)
		_slots.append(slot)
		box.add_child(slot)
	add_child(box)


func _ready() -> void:
	custom_minimum_size.y = 52.0
	for slot in _slots:
		slot.focus_entered.connect(_refresh_highlight)
		slot.focus_exited.connect(_refresh_highlight)
	_refresh_highlight()


## Vuelve a leer las teclas vigentes de la acción.
func refresh() -> void:
	for slot in _slots:
		slot.set_key(Controls.get_key(action, slot.slot))
	_note.visible = Controls.is_customized(action)


func get_slot(index: int) -> KeySlotButton:
	return _slots[index]


func get_slots() -> Array[KeySlotButton]:
	return _slots


func get_action_text() -> String:
	return _label.text


func is_marked_custom() -> bool:
	return _note.visible


func _refresh_highlight() -> void:
	var highlighted := false
	for slot in _slots:
		highlighted = highlighted or slot.has_focus()
	add_theme_stylebox_override("panel", MenuStyle.row_box(highlighted))
