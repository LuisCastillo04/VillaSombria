class_name DialogueChoiceHint
extends VBoxContainer
## Pie de las respuestas: un separador con un rombo y, debajo, centrada, la ayuda con un icono de
## ratón («Elige con el ratón o con las teclas numéricas»). El texto lo decide `DialogueControls`
## según las respuestas que haya, para no anunciar nada que no funcione.

const ICON := "raton"
const ICON_SIZE := 26.0

var _divider: GoldDivider
var _icon: TextureRect
var _label: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	_divider = GoldDivider.new()
	_divider.name = "Divider"
	_divider.color = Color(DialogueStyle.INK_SOFT, 0.75)
	_divider.custom_minimum_size = Vector2(0.0, DialogueStyle.DIVIDER_HEIGHT)
	_divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_divider)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_icon = HudStyle.make_icon(HudStyle.icon(ICON), ICON_SIZE, DialogueStyle.INK_SOFT)
	row.add_child(_icon)
	_label = DialogueStyle.make_label("", DialogueStyle.hint_font(), DialogueStyle.HINT_SIZE, DialogueStyle.INK_SOFT)
	row.add_child(_label)
	resized.connect(_fit_divider)


func set_text(value: String) -> void:
	_label.text = value


func get_text() -> String:
	return _label.text


## El separador ocupa la parte central del pie, como el del diálogo.
func _fit_divider() -> void:
	_divider.custom_minimum_size.x = size.x * DialogueStyle.DIVIDER_WIDTH_RATIO
