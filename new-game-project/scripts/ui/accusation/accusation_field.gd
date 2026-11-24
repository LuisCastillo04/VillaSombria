class_name AccusationField
extends VBoxContainer
## Un campo del formulario de acusación: su encabezado (medallón y cinta con la pregunta) y, debajo
## y con sangría, el selector con la elección. Los datos del campo (clave, rótulos e icono) se
## ajustan en la escena; este nodo sólo los pinta y avisa con `activated` cuando el jugador quiere
## cambiar la elección.

signal activated(field_key: String)

## Clave del campo en el borrador: "suspect", "motive", "opportunity" o "means".
@export var field_key := "suspect"
@export var label_text := "Acuso a:"
@export var prompt_text := ""
@export var icon_name := "persona"
## Signo en lugar de icono (el «?» del motivo).
@export var glyph := ""
@export var placeholder := "Seleccionar evidencia o testimonio"
## Si abre una lista debajo (el sospechoso) o el panel lateral (las pruebas).
@export var opens_side_panel := true

var heading: AccusationFieldHeading
var selector: AccusationSelector


func _init() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	heading = AccusationFieldHeading.new()
	heading.name = "Heading"
	heading.label_text = label_text
	heading.prompt_text = prompt_text
	heading.glyph = glyph
	if glyph.is_empty():
		heading.icon = AccusationStyle.icon(icon_name)
	add_child(heading)
	var indent := MarginContainer.new()
	indent.name = "Indent"
	indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indent.add_theme_constant_override("margin_left", int(AccusationStyle.SELECTOR_INDENT))
	indent.add_theme_constant_override("margin_right", 0)
	selector = AccusationSelector.new()
	selector.name = "Selector"
	selector.placeholder = placeholder
	selector.arrow = AccusationSelector.Arrow.SIDE if opens_side_panel else AccusationSelector.Arrow.DOWN
	selector.pressed.connect(func() -> void: activated.emit(field_key))
	indent.add_child(selector)
	add_child(indent)


## Muestra la elección del campo; `text` vacío lo deja pendiente.
func set_value(text: String, type_icon: Texture2D = null) -> void:
	selector.set_value(text, type_icon)
	heading.completed = not text.is_empty()


## Marca el campo que se está editando: su lista o el panel lateral están abiertos.
func set_editing(editing: bool) -> void:
	selector.active = editing
	heading.editing = editing


func is_filled() -> bool:
	return selector.is_filled()
