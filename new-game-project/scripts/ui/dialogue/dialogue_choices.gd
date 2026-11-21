class_name DialogueChoices
extends ScrollContainer
## Respuestas disponibles en un momento de la conversación: una columna centrada de tarjetas
## (`DialogueChoiceItem`) que se desplaza en vertical si no caben todas.
##
## Recibe las opciones tal como las emite `DialogueManager.options_shown` (`id`, `label`, `asked`) y
## devuelve el identificador elegido con la señal `chosen`, sin interpretarlo: qué aparece, en qué
## orden y qué consecuencia tiene lo decide siempre `DialogueManager`.

signal chosen(option_id: String)

## Rótulos de la placa mientras se elige. Las respuestas son frases del detective, así que la placa
## no lleva el nombre del interlocutor: en un interrogatorio son las preguntas que se le pueden
## hacer (y la de terminar); en una escena, las réplicas posibles.
const TOPICS_HEADING := "Tus preguntas"
const REPLIES_HEADING := "Tus respuestas"

var _column: VBoxContainer
var _items: Array[DialogueChoiceItem] = []
var _compact := false


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	follow_focus = true
	# La columna ocupa todo el ancho y centra las tarjetas: el contenedor con desplazamiento no
	# centra a su hijo por sí mismo.
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", int(DialogueStyle.CHOICE_GAP))
	add_child(_column)


func _ready() -> void:
	JournalStyle.style_scroll(self)
	resized.connect(_fit_column)


## Rótulo de la placa para estas opciones: el menú de preguntas de un interrogatorio siempre
## termina con la de salir; las réplicas de una escena, no.
static func heading_for(options: Array) -> String:
	for option: Dictionary in options:
		if String(option.get("id", "")) == DialogueManager.EXIT_OPTION:
			return TOPICS_HEADING
	return REPLIES_HEADING


## Sustituye las respuestas por las nuevas, numeradas en el orden en que llegan. Si son muchas, las
## tarjetas se compactan.
func show_options(options: Array) -> void:
	clear_options()
	_compact = options.size() >= DialogueStyle.COMPACT_CHOICES_FROM
	_column.add_theme_constant_override("separation", int(_gap()))
	var number := 1
	for option: Dictionary in options:
		var item := DialogueChoiceItem.new()
		item.name = "Option%d" % number
		item.set_compact(_compact)
		item.setup(String(option["id"]), number, String(option["label"]), not bool(option.get("asked", false)))
		item.pressed.connect(_on_item_pressed.bind(item))
		_column.add_child(item)
		_items.append(item)
		number += 1
	scroll_vertical = 0
	_fit_column()


func clear_options() -> void:
	for item in _items:
		_column.remove_child(item)
		item.queue_free()
	_items.clear()


## Da el foco a la primera respuesta, para manejar la lista con el teclado desde el principio.
func focus_first() -> void:
	if not _items.is_empty():
		_items[0].grab_focus()


## Elige la respuesta de una posición (0 para la primera), como al pulsar su tecla numérica.
## Devuelve si había una respuesta en esa posición.
func choose_index(index: int) -> bool:
	if index < 0 or index >= _items.size():
		return false
	_items[index].flash()
	chosen.emit(_items[index].option_id)
	return true


func get_option_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in _items:
		ids.append(item.option_id)
	return ids


func get_count() -> int:
	return _items.size()


func is_compact() -> bool:
	return _compact


func get_items() -> Array[DialogueChoiceItem]:
	return _items.duplicate()


## Ancho de las tarjetas: el de la ventana, sin pasar de una línea de lectura cómoda.
func get_column_width() -> float:
	return minf(maxf(size.x - DialogueStyle.CHOICES_SCROLL_GUTTER * 2.0, 0.0), DialogueStyle.CHOICE_MAX_WIDTH)


## Alto de todas las tarjetas con el ancho `width` (o el actual): la ventana se mide con él.
func get_content_height(width: float = -1.0) -> float:
	var column := get_column_width() if width < 0.0 else width
	var total := 0.0
	for item in _items:
		total += item.get_height_for_width(column)
	if _items.size() > 1:
		total += _gap() * (_items.size() - 1)
	return total


## Alto mínimo de la lista: una tarjeta.
func get_min_height() -> float:
	return DialogueChoiceItem.MIN_HEIGHT_COMPACT if _compact else DialogueChoiceItem.MIN_HEIGHT


func _gap() -> float:
	return DialogueStyle.CHOICE_GAP_COMPACT if _compact else DialogueStyle.CHOICE_GAP


func _fit_column() -> void:
	var width := get_column_width()
	for item in _items:
		item.custom_minimum_size = Vector2(width, item.get_height_for_width(width))


func _on_item_pressed(item: DialogueChoiceItem) -> void:
	var index := _items.find(item)
	if index >= 0:
		choose_index(index)
