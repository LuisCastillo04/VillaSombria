class_name JournalFooter
extends HBoxContainer
## Pie del expediente, sobre el cuero: a la derecha, «J Cerrar el expediente», que también se puede
## pulsar con el ratón. La tecla sale del InputMap a través de `InputLabels`.

signal close_pressed

var _close: Button
var _close_key: KeyCap
var _close_label: Label
var _close_content: HBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spacer)
	_close = Button.new()
	_close.name = "Close"
	_close.focus_mode = Control.FOCUS_NONE
	_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		_close.add_theme_stylebox_override(state, empty)
	_close_content = HBoxContainer.new()
	_close_content.add_theme_constant_override("separation", 16)
	_close_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_close_key = KeyCap.new()
	_close_content.add_child(_close_key)
	_close_label = JournalStyle.make_label("Cerrar el expediente", JournalStyle.body_font(), JournalStyle.FOOTER_SIZE, JournalStyle.CREAM)
	_close_content.add_child(_close_label)
	_close.add_child(_close_content)
	_close.pressed.connect(func() -> void: close_pressed.emit())
	_close.mouse_entered.connect(func() -> void: _close_label.add_theme_color_override("font_color", JournalStyle.GOLD_LIGHT))
	_close.mouse_exited.connect(func() -> void: _close_label.add_theme_color_override("font_color", JournalStyle.CREAM))
	_close_content.minimum_size_changed.connect(_fit_close)
	add_child(_close)


## Vuelve a leer las teclas del InputMap: al abrir el expediente, por si se han reasignado.
func refresh_keys() -> void:
	_close_key.text = JournalInfo.key_name("open_journal")
	_close_key.visible = not _close_key.text.is_empty()
	_fit_close()


func get_close_button() -> Button:
	return _close


func get_close_text() -> String:
	return "%s %s" % [_close_key.text, _close_label.text]


## El botón no crece con sus hijos: su tamaño sigue al contenido.
func _fit_close() -> void:
	var needed := _close_content.get_combined_minimum_size()
	_close.custom_minimum_size = needed
	_close_content.position = Vector2.ZERO
	_close_content.size = needed
