extends CanvasLayer
## Ventana de confirmación común a todo el juego: una pregunta, un botón para confirmar y otro para
## cancelar, con la misma ficha de pergamino que las preguntas de salida y de las ranuras.
##
## `ask` muestra la pregunta y devuelve, al contestarla, si se confirmó:
##
##     if await ConfirmDialog.ask("ESPERAR", "¿Quieres dejar pasar una hora?"):
##         ...
##
## Con `timeout`, la pregunta se contesta sola como «cancelar» al agotarse el tiempo y muestra la
## cuenta atrás (se usa al cambiar la pantalla: si el jugador no ve nada, se restaura lo anterior).
##
## Hay dos clases de pregunta:
## - **Opcionales** (`ask_optional`): acciones que el jugador puede querer hacer sin más, como dejar
##   pasar una hora. Se hacen sólo si tiene activadas las confirmaciones en Configuración
##   (`jugabilidad/confirmaciones`); si no, la respuesta es «sí» en el acto.
## - **Críticas** (`ask`): se hacen siempre, porque se pierde algo o el jugador podría quedarse sin ver
##   la pantalla: mantener un cambio de pantalla. Las de eliminar o sobrescribir una partida y la de
##   salir sin guardar tienen su propia ventana (`SaveSlotsMenu`, `ExitManager`) y tampoco dependen
##   de la preferencia.
##
## Funciona con el ratón, el teclado y el mando: el foco no sale de los dos botones, izquierda y
## derecha pasan de uno a otro, aceptar pulsa el señalado y Escape (o el botón de cancelar del
## mando) cancela. También con el árbol en pausa.

signal answered(accepted: bool)

## Tiempo que se tarda en aparecer, en segundos.
const APPEAR_SECONDS := 0.18
const CARD_WIDTH := 820.0

var _open := false
var _remaining := 0.0
var _timeout_text := ""
var _focus_before: Control
var _tween: Tween

var _root: Control
var _dim: ColorRect
var _card: PanelContainer
var _title: Label
var _message: Label
var _countdown: Label
var _confirm: Button
var _cancel: Button


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	set_process(false)


## Hace una pregunta y espera la respuesta. Opciones:
## - `confirm_text` y `cancel_text`: rótulos de los botones («Confirmar» y «Cancelar»).
## - `focus`: botón señalado al abrir, `"confirm"` o `"cancel"` (por defecto, cancelar).
## - `timeout`: segundos hasta contestar «cancelar» solo; 0 espera indefinidamente.
## - `timeout_text`: aviso de la cuenta atrás, con `%d` para los segundos que quedan.
## Si ya hay una pregunta en pantalla, la nueva se contesta «cancelar» sin mostrarse.
func ask(title: String, message: String, options: Dictionary = {}) -> bool:
	if _open:
		return false
	_open = true
	_focus_before = get_viewport().gui_get_focus_owner()
	_title.text = title
	_message.text = message
	_confirm.text = String(options.get("confirm_text", "Confirmar"))
	_cancel.text = String(options.get("cancel_text", "Cancelar"))
	_remaining = float(options.get("timeout", 0.0))
	_timeout_text = String(options.get("timeout_text", "Se cancelará sola en %d s."))
	_countdown.visible = _remaining > 0.0
	_update_countdown()
	set_process(_remaining > 0.0)
	_show()
	if String(options.get("focus", "cancel")) == "confirm":
		_confirm.grab_focus()
	else:
		_cancel.grab_focus()
	var accepted: bool = await answered
	return accepted


func is_open() -> bool:
	return _open


## Pregunta sólo si el jugador tiene activadas las confirmaciones en Configuración; si no, contesta
## «sí» en el acto sin mostrar nada. Para las acciones que no destruyen nada.
func ask_optional(title: String, message: String, options: Dictionary = {}) -> bool:
	if not confirmations_enabled():
		return true
	return await ask(title, message, options)


## Si el jugador quiere que se le pregunte antes de las acciones que se pueden confirmar.
func confirmations_enabled() -> bool:
	return bool(Settings.get_value("jugabilidad/confirmaciones"))


## Confirma o cancela la pregunta en pantalla, como los botones.
func confirm() -> void:
	_finish(true)


func cancel() -> void:
	_finish(false)


func get_title_text() -> String:
	return _title.text


func get_message_text() -> String:
	return _message.text


func get_countdown_text() -> String:
	return _countdown.text if _countdown.visible else ""


func get_confirm_button() -> Button:
	return _confirm


func get_cancel_button() -> Button:
	return _cancel


func _process(delta: float) -> void:
	if not _open or _remaining <= 0.0:
		set_process(false)
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_finish(false)
		return
	_update_countdown()


## Escape (o cancelar en el mando) contesta «cancelar»; izquierda y derecha pasan de un botón a
## otro sin que el foco salga de la ventana. Aceptar lo atiende el botón señalado.
func _input(event: InputEvent) -> void:
	# La pregunta de salida (X o Alt + F4) va por encima: mientras está, el teclado es suyo.
	if not _open or ExitManager.is_dialog_open():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_focus_prev"):
		get_viewport().set_input_as_handled()
		_confirm.grab_focus()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_focus_next"):
		get_viewport().set_input_as_handled()
		_cancel.grab_focus()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()


func _finish(accepted: bool) -> void:
	if not _open:
		return
	_open = false
	set_process(false)
	AudioManager.play("click")
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and _root.is_ancestor_of(focused):
		focused.release_focus()
	_root.hide()
	if is_instance_valid(_focus_before) and _focus_before.is_visible_in_tree() and _focus_before.focus_mode != Control.FOCUS_NONE:
		_focus_before.grab_focus()
	_focus_before = null
	answered.emit(accepted)


func _update_countdown() -> void:
	if _remaining > 0.0:
		_countdown.text = _timeout_text % ceili(_remaining) if _timeout_text.contains("%d") else _timeout_text


func _show() -> void:
	_root.show()
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2.ONE if UiAccessibility.reduced_motion() else Vector2(0.96, 0.96)
	_card.modulate.a = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_card, "modulate:a", 1.0, APPEAR_SECONDS)
	_tween.tween_property(_card, "scale", Vector2.ONE, APPEAR_SECONDS + 0.04)


## Velo, ficha de pergamino con filete burdeos, título, texto, cuenta atrás y los dos botones de
## madera: el mismo aspecto que la pregunta de salida (`ExitManager`) y las de las ranuras.
func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.02, 0.03, 0.05, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.custom_minimum_size.x = CARD_WIDTH
	var card_style := CaseFileStyle.box(CaseFileStyle.PARCHMENT_LIGHT, CaseFileStyle.BURGUNDY, 3, 10, 34.0)
	card_style.shadow_color = Color(0, 0, 0, 0.55)
	card_style.shadow_size = 18
	_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	_card.add_child(box)
	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CaseFileStyle.style_label(_title, CaseFileStyle.serif_bold(), 32, CaseFileStyle.BURGUNDY)
	box.add_child(_title)
	_message = Label.new()
	_message.name = "Message"
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = CARD_WIDTH - 80.0
	CaseFileStyle.style_label(_message, CaseFileStyle.serif(), 25, CaseFileStyle.INK)
	box.add_child(_message)
	_countdown = Label.new()
	_countdown.name = "Countdown"
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CaseFileStyle.style_label(_countdown, CaseFileStyle.serif_italic(), 21, CaseFileStyle.INK_SOFT)
	box.add_child(_countdown)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 28)
	box.add_child(buttons)
	_confirm = _make_button("Confirm", buttons)
	_cancel = _make_button("Cancel", buttons)
	_confirm.pressed.connect(confirm)
	_cancel.pressed.connect(cancel)
	# El foco nunca sale de la ventana: arriba y abajo se quedan, los lados van al otro botón.
	for button: Button in [_confirm, _cancel]:
		var other := _cancel if button == _confirm else _confirm
		button.focus_neighbor_top = NodePath(".")
		button.focus_neighbor_bottom = NodePath(".")
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.get_path_to(other)
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)


func _make_button(button_name: String, parent: Control) -> Button:
	var button := Button.new()
	button.name = button_name
	button.custom_minimum_size = Vector2(250.0, 64.0)
	CaseFileStyle.apply_wood_button(button, 24)
	parent.add_child(button)
	return button
