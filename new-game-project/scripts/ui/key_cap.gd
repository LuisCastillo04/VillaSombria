class_name KeyCap
extends Label
## Tecla dibujada como un botón físico: recuadro oscuro, filete dorado y letra crema.

const HEIGHT := 34.0


func _init(key_text: String = "") -> void:
	text = key_text


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(HEIGHT, HEIGHT)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("normal", MenuStyle.keycap_box())
	MenuStyle.style_label(self, 18, MenuStyle.TEXT, CaseFileStyle.serif_bold())
