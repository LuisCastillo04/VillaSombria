class_name DialogueChoices
extends ScrollContainer
## Respuestas disponibles en un momento de la conversación: una columna centrada de tarjetas
## (`DialogueChoiceItem`) que se desplaza en vertical si no caben todas.
##
## Recibe las opciones tal como las emite `DialogueManager.options_shown` y devuelve el identificador
## elegido con la señal `chosen`, sin interpretarlo: qué aparece, en qué orden, en qué parte y con qué
## estado lo decide siempre `DialogueManager` (con `ConversationLog`). Cada opción trae `id`, `label`
## y `asked`; las de un interrogatorio, además, `state`, `fresh`, `repeatable` y `section`.
##
## Las de la parte `realizadas` van tras una cabecera plegable, «Preguntas realizadas»
## (`DialogueChoiceSection`), plegada al empezar cada conversación: las preguntas nuevas son lo
## primero que se ve y lo primero que se recorre. Si no queda ninguna pregunta pendiente, un aviso
## discreto lo dice encima de la lista.
##
## Navegación: ↑ ↓ recorren lo que se puede elegir (las bloqueadas y las plegadas se saltan); las
## teclas numéricas sólo cuentan las preguntas visibles que se pueden elegir; → y ← despliegan y
## pliegan la cabecera. Cuando una pregunta cambia de sitio o desaparece, el foco nunca se queda en
## el aire: vuelve a la elegida si sigue a la vista o, si no, a la primera opción.

signal chosen(option_id: String)
## Ha cambiado lo que ocupa la lista (se desplegó o se plegó una sección): la ventana se reajusta.
signal layout_changed

## Rótulos de la placa mientras se elige. Las respuestas son frases del detective, así que la placa
## no lleva el nombre del interlocutor: en un interrogatorio son las preguntas que se le pueden
## hacer (y la de terminar); en una escena, las réplicas posibles.
const TOPICS_HEADING := "Tus preguntas"
const REPLIES_HEADING := "Tus respuestas"
## Aviso cuando el personaje no tiene preguntas pendientes.
const EMPTY_NOTICE := "No hay nuevas preguntas disponibles por el momento."

var _column: VBoxContainer
var _items: Array[DialogueChoiceItem] = []
## Tarjetas de «Preguntas realizadas», que se ocultan al plegarla.
var _asked_items: Array[DialogueChoiceItem] = []
var _section: DialogueChoiceSection
var _notice: Label
## La sección sigue como la dejó el jugador mientras dure la conversación (`reset_sections`).
var _expanded := false
var _compact := false
## Respuesta señalada (con el foco), o -1 (ninguna o la cabecera).
var _selected := -1
## Momento a partir del cual se acepta confirmar (`hold_confirmation`).
var _confirm_after_msec := 0


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	follow_focus = true
	# El foco es de las tarjetas: la lista sólo se desplaza para que la señalada quede a la vista.
	focus_mode = Control.FOCUS_NONE
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


## Sustituye las respuestas por las nuevas, en el orden en que llegan. Las de «Preguntas realizadas»
## van tras su cabecera; las demás, numeradas, delante. Si son muchas, las tarjetas se compactan.
func show_options(options: Array) -> void:
	clear_options()
	var is_topics := heading_for(options) == TOPICS_HEADING
	var main: Array[Dictionary] = []
	var asked: Array[Dictionary] = []
	var tail: Array[Dictionary] = []
	var has_pending := false
	for option: Dictionary in options:
		if String(option.get("id", "")) == DialogueManager.EXIT_OPTION:
			tail.append(option)
		elif String(option.get("section", "")) == ConversationLog.SECTION_ASKED:
			asked.append(option)
		else:
			main.append(option)
		if String(option.get("state", "")) == ConversationLog.PENDING:
			has_pending = true
	if is_topics and not has_pending:
		_notice = _make_notice(EMPTY_NOTICE)
		_notice.name = "EmptyNotice"
		_column.add_child(_notice)
	for option in main:
		_add_item(option)
	if not asked.is_empty():
		_section = DialogueChoiceSection.new()
		_section.name = "AskedSection"
		_section.setup(asked.size())
		_section.set_expanded(_expanded, false)
		_section.pressed.connect(_on_section_pressed)
		_section.focus_entered.connect(_on_section_focused)
		_column.add_child(_section)
		for option in asked:
			_asked_items.append(_add_item(option))
	for option in tail:
		_add_item(option)
	_apply_sections()
	scroll_vertical = 0
	_fit_column()


func clear_options() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_items.clear()
	_asked_items.clear()
	_section = null
	_notice = null
	_selected = -1


## Cada conversación empieza con «Preguntas realizadas» plegada.
func reset_sections() -> void:
	_expanded = false


## Las tarjetas aparecen una tras otra, con un fundido y una subida corta.
func play_entrance() -> void:
	var index := 0
	for child in _visible_children():
		_play_child_entrance(child, index * DialogueStyle.CHOICE_STAGGER)
		index += 1


## Da el foco a la primera opción que se puede elegir, para manejar la lista con el teclado desde el
## principio: la primera pregunta pendiente si la hay.
func focus_first() -> void:
	var targets := _navigable()
	if not targets.is_empty():
		targets[0].grab_focus()


## Señala la respuesta con ese identificador o, si ya no está a la vista (se hizo y pasó a
## «Preguntas realizadas», o desapareció), la primera.
func focus_option(option_id: String) -> void:
	var index := get_option_ids().find(option_id)
	if index >= 0 and _can_focus(_items[index]):
		_items[index].grab_focus()
	else:
		focus_first()


## Señala una respuesta (le da el foco); la lista se desplaza hasta ella si hace falta. Las bloqueadas
## y las plegadas no se pueden señalar.
func select_index(index: int) -> void:
	if index >= 0 and index < _items.size() and _can_focus(_items[index]):
		_items[index].grab_focus()


## Señala la siguiente (`step` 1) o la anterior (-1) de lo que se puede elegir, cabecera incluida.
## Desde la última se vuelve a la primera.
func move_selection(step: int) -> void:
	var targets := _navigable()
	if targets.is_empty():
		return
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var start := targets.find(focus_owner)
	if start < 0:
		start = -1 if step > 0 else 0
	targets[posmod(start + step, targets.size())].grab_focus()


func get_selected_index() -> int:
	return _selected


func get_selected_id() -> String:
	return _items[_selected].option_id if _selected >= 0 and _selected < _items.size() else ""


## Si la cabecera de «Preguntas realizadas» tiene el foco.
func is_section_focused() -> bool:
	return _section != null and _section.has_focus()


## Si el foco está en una de las preguntas de «Preguntas realizadas».
func is_asked_focused() -> bool:
	return _selected >= 0 and _selected < _items.size() and _asked_items.has(_items[_selected]) and _items[_selected].has_focus()


## Durante `seconds` no se acepta confirmar con una tecla ni con un clic.
func hold_confirmation(seconds: float) -> void:
	_confirm_after_msec = Time.get_ticks_msec() + int(seconds * 1000.0)


func can_confirm() -> bool:
	return Time.get_ticks_msec() >= _confirm_after_msec


## Elige la respuesta señalada, si ya se puede; con la cabecera señalada, la despliega o la pliega.
## Devuelve si hizo algo.
func confirm_selected() -> bool:
	if not can_confirm():
		return false
	if is_section_focused():
		toggle_section()
		return true
	if _selected < 0:
		return false
	return _choose_item(_items[_selected])


## Elige la respuesta de una tecla numérica (0 para la primera). Sólo cuentan las que se ven y se
## pueden elegir, en el orden en que aparecen. Devuelve si había una respuesta con ese número.
func choose_index(index: int) -> bool:
	var numbered := _numbered()
	if index < 0 or index >= numbered.size():
		return false
	return _choose_item(numbered[index])


# --- «Preguntas realizadas» ---

func has_section() -> bool:
	return _section != null


func get_section() -> DialogueChoiceSection:
	return _section


func is_section_expanded() -> bool:
	return _expanded


func toggle_section() -> void:
	set_section_expanded(not _expanded)


## Despliega o pliega «Preguntas realizadas». El foco se queda en la cabecera (o vuelve a ella si
## estaba en una pregunta que se pliega) y la ventana se reajusta con una transición corta.
func set_section_expanded(value: bool) -> void:
	if _section == null or value == _expanded:
		return
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var was_inside := focus_owner != null and focus_owner is DialogueChoiceItem and _asked_items.has(focus_owner)
	_expanded = value
	_section.set_expanded(value)
	AudioManager.play("click")
	_apply_sections()
	_fit_column()
	if value:
		var index := 0
		for item in _asked_items:
			item.play_entrance(index * DialogueStyle.CHOICE_STAGGER)
			index += 1
	elif was_inside:
		_section.grab_focus()
	layout_changed.emit()


func _on_section_pressed() -> void:
	if can_confirm():
		toggle_section()


func _on_section_focused() -> void:
	_selected = -1


# --- Datos para las pruebas y para la ventana ---

## Identificadores de todas las respuestas, en el orden en que llegaron (también las plegadas).
func get_option_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in _items:
		ids.append(item.option_id)
	return ids


## Identificadores de las respuestas que se ven ahora.
func get_visible_option_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in _items:
		if item.visible:
			ids.append(item.option_id)
	return ids


func get_item(option_id: String) -> DialogueChoiceItem:
	var index := get_option_ids().find(option_id)
	return _items[index] if index >= 0 else null


## Texto del aviso de «no hay preguntas nuevas», o vacío si no se muestra.
func get_notice_text() -> String:
	return _notice.text if _notice != null else ""


## Si alguna pregunta está bloqueada (diálogo único): el pie recuerda dónde releer lo respondido.
static func has_locked(options: Array) -> bool:
	return options.any(func(option: Dictionary) -> bool: return option.get("state", "") == ConversationLog.LOCKED)


func get_count() -> int:
	return _items.size()


func is_compact() -> bool:
	return _compact


func get_items() -> Array[DialogueChoiceItem]:
	return _items.duplicate()


## Ancho de las tarjetas: el de la ventana, sin pasar de una línea de lectura cómoda.
func get_column_width() -> float:
	return minf(maxf(size.x - DialogueStyle.CHOICES_SCROLL_GUTTER * 2.0, 0.0), DialogueStyle.CHOICE_MAX_WIDTH)


## Alto de lo que se ve con el ancho `width` (o el actual): la ventana se mide con él.
func get_content_height(width: float = -1.0) -> float:
	var column := get_column_width() if width < 0.0 else width
	var total := 0.0
	var shown := _visible_children()
	for child in shown:
		total += _height_of(child, column)
	if shown.size() > 1:
		total += _gap() * (shown.size() - 1)
	return total


## Alto mínimo de la lista: una tarjeta.
func get_min_height() -> float:
	return DialogueChoiceItem.MIN_HEIGHT_COMPACT if _compact else DialogueChoiceItem.MIN_HEIGHT


# --- Interno ---

func _add_item(option: Dictionary) -> DialogueChoiceItem:
	var item := DialogueChoiceItem.new()
	item.name = "Option%d" % (_items.size() + 1)
	item.setup(String(option["id"]), 0, String(option["label"]), not bool(option.get("asked", false)))
	if option.has("state"):
		var item_state := String(option["state"])
		if not [ConversationLog.PENDING, ConversationLog.DONE, ConversationLog.LOCKED].has(item_state):
			item_state = DialogueChoiceItem.NEUTRAL
		item.set_state(item_state, bool(option.get("fresh", false)), bool(option.get("repeatable", false)) or item_state == ConversationLog.DONE)
	item.pressed.connect(_on_item_pressed.bind(item))
	item.focus_entered.connect(_on_item_focused.bind(item))
	_column.add_child(item)
	_items.append(item)
	return item


func _make_notice(text: String) -> Label:
	var label := DialogueStyle.make_label(text, DialogueStyle.hint_font(), DialogueStyle.NOTICE_SIZE, DialogueStyle.INK_MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return label


## Muestra u oculta lo plegable, numera lo que se puede elegir y decide si hace falta compactar.
func _apply_sections() -> void:
	for item in _asked_items:
		item.visible = _expanded
	var shown := 0
	for child in _visible_children():
		if child is DialogueChoiceItem or child is DialogueChoiceSection:
			shown += 1
	_compact = shown >= DialogueStyle.COMPACT_CHOICES_FROM
	_column.add_theme_constant_override("separation", int(_gap()))
	for item in _items:
		item.set_compact(_compact)
		item.set_number(0)
	if _section != null:
		_section.set_compact(_compact)
	var number := 1
	for item in _numbered():
		item.set_number(number)
		number += 1
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focus_owner is DialogueChoiceItem and not _can_focus(focus_owner):
		focus_owner.release_focus()


## Preguntas que se pueden elegir con un número: visibles y no bloqueadas, en su orden.
func _numbered() -> Array[DialogueChoiceItem]:
	var result: Array[DialogueChoiceItem] = []
	for item in _items:
		if _can_focus(item):
			result.append(item)
	return result


## Lo que se recorre con las flechas, en el orden en que se ve: tarjetas elegibles y la cabecera.
func _navigable() -> Array[Control]:
	var result: Array[Control] = []
	for child in _visible_children():
		if child is DialogueChoiceItem and _can_focus(child):
			result.append(child)
		elif child is DialogueChoiceSection:
			result.append(child)
	return result


func _visible_children() -> Array[Control]:
	var result: Array[Control] = []
	for child in _column.get_children():
		if child is Control and (child as Control).visible and not child.is_queued_for_deletion():
			result.append(child)
	return result


static func _can_focus(item: DialogueChoiceItem) -> bool:
	return item.visible and not item.is_locked()


func _choose_item(item: DialogueChoiceItem) -> bool:
	if item.is_locked() or not item.visible:
		return false
	item.flash()
	chosen.emit(item.option_id)
	return true


func _play_child_entrance(child: Control, delay: float) -> void:
	if child is DialogueChoiceItem:
		(child as DialogueChoiceItem).play_entrance(delay)
		return
	child.modulate.a = 0.0
	var tween := child.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(child, "modulate:a", 1.0, DialogueStyle.CHOICE_ENTER_SECONDS).set_delay(delay)


func _gap() -> float:
	return DialogueStyle.CHOICE_GAP_COMPACT if _compact else DialogueStyle.CHOICE_GAP


func _height_of(child: Control, width: float) -> float:
	if child is DialogueChoiceItem:
		return (child as DialogueChoiceItem).get_height_for_width(width)
	if child is DialogueChoiceSection:
		return (child as DialogueChoiceSection).get_height()
	return child.get_combined_minimum_size().y


func _fit_column() -> void:
	var width := get_column_width()
	for child in _column.get_children():
		if child is DialogueChoiceItem:
			child.custom_minimum_size = Vector2(width, (child as DialogueChoiceItem).get_height_for_width(width))
		elif child is DialogueChoiceSection:
			child.custom_minimum_size = Vector2(width, (child as DialogueChoiceSection).get_height())


## Un clic (o la tecla de aceptar recibida por la propia tarjeta) elige, salvo justo al aparecer.
func _on_item_pressed(item: DialogueChoiceItem) -> void:
	if can_confirm():
		_choose_item(item)


func _on_item_focused(item: DialogueChoiceItem) -> void:
	_selected = _items.find(item)
