class_name DialogueChoices
extends ScrollContainer
## Respuestas disponibles en un momento de la conversación, en una lista que se desplaza si no cabe.
##
## Recibe las opciones tal como las emite `DialogueManager.options_shown` (`id`, `label`, `asked`) y
## devuelve el identificador elegido con la señal `chosen`, sin interpretarlo: la consecuencia
## narrativa la decide siempre `DialogueManager.choose`.

signal chosen(option_id: String)

## Marca de las preguntas que el jugador aún no ha hecho.
const NEW_MARK := "●  "

var _list: VBoxContainer
var _ids: Array[String] = []


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	follow_focus = true
	_list = VBoxContainer.new()
	_list.name = "Options"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)


## Sustituye las respuestas por las nuevas.
func show_options(options: Array) -> void:
	clear_options()
	var number := 1
	for option: Dictionary in options:
		var button := Button.new()
		var mark := "" if bool(option.get("asked", false)) else NEW_MARK
		button.text = "%d. %s%s" % [number, mark, option["label"]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_pressed.bind(String(option["id"])))
		_list.add_child(button)
		_ids.append(String(option["id"]))
		number += 1


func clear_options() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_ids.clear()


## Da el foco a la primera respuesta, para manejar la lista con el teclado desde el principio.
func focus_first() -> void:
	if _list.get_child_count() > 0:
		(_list.get_child(0) as Control).grab_focus()


## Elige la respuesta de una posición (0 para la primera), como al pulsar su tecla numérica.
## Devuelve si había una respuesta en esa posición.
func choose_index(index: int) -> bool:
	if index < 0 or index >= _ids.size():
		return false
	chosen.emit(_ids[index])
	return true


func get_option_ids() -> Array[String]:
	return _ids.duplicate()


func get_count() -> int:
	return _ids.size()


func _on_pressed(option_id: String) -> void:
	chosen.emit(option_id)
