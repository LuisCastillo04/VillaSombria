class_name RebindMenu
extends CategoryMenu
## Pantalla «Reasignar teclas»: las acciones que el jugador puede cambiar, en las mismas categorías
## que la lista de controles, cada una con su tecla principal y su alternativa (`RebindRow`). Al pie
## de cada categoría, las teclas fijas que no se pueden cambiar.
##
## Cambiar una tecla:
## 1. Se elige un hueco con Intro, el botón de aceptar del mando o un clic. La pulsación que lo elige
##    nunca se toma como la tecla nueva: la espera empieza con la pulsación siguiente.
## 2. «Presiona una tecla para asignarla a…»: la siguiente tecla pulsada (sin contar las repeticiones
##    de una tecla mantenida) es la nueva. Esc, un clic o el botón de cancelar del mando cancelan.
##    Mayús y Ctrl solas se toman al soltarlas, para no confundirlas con el principio de una
##    combinación; las combinaciones con Alt o con la tecla de Windows (Alt + F4, Alt + Tab) son del
##    sistema y no se toman.
## 3. `Controls.check` decide: si la tecla está libre, se asigna; si está reservada (Esc, 1–9, las del
##    sistema, las de moverse por una pantalla para una acción que funciona dentro de ella), se dice
##    por qué y se sigue esperando; si la usa otra acción, `ConfirmDialog` pregunta si se intercambian.
##    Un intercambio que dejaría a la otra acción sin tecla no se ofrece.
##
## Supr, Retroceso o el clic derecho quitan la alternativa. Todo cambio se aplica al InputMap y se
## guarda en el acto (`Controls`).

## Teclas fijas que se enseñan al pie de cada categoría, sin poder cambiarlas: así se ve por qué no se
## aceptan. Mismo formato que las filas de `ControlsMenu.CATEGORIES`.
const FIXED_ROWS := {
	"Interacción": [
		{"label": "Elegir una pregunta", "fixed": [["1–9"]]},
	],
	"Menús": [
		{"label": "Pausar el juego y volver atrás", "actions": ["pause", "ui_cancel"]},
		{"label": "Moverse por los menús", "together": ["ui_up", "ui_left", "ui_down", "ui_right"]},
		{"label": "Confirmar en los menús", "actions": ["ui_accept"]},
	],
	"Otros": [
		{"label": "Cerrar el juego guardando", "fixed": [["Alt", "F4"]]},
	],
}
const HINT := "Intro o clic: cambiar una tecla  ·  Supr o clic derecho: quitar la alternativa  ·  Esc: volver"
const STATUS_SIZE := 18
## Teclas que quitan la alternativa del hueco señalado.
const CLEAR_KEYS: Array[Key] = [KEY_DELETE, KEY_BACKSPACE]

enum Tone { HINT, WAITING, DONE, WARNING }

var _rows: Array[RebindRow] = []
var _status: Label
## Hueco que espera la tecla nueva, o null.
var _capture: KeySlotButton
## Fotograma en que empezó la espera: nada de ese mismo fotograma cuenta como tecla.
var _capture_frame := -1
## Mayús o Ctrl pulsadas durante la espera: se asignan si se sueltan sin pulsar otra tecla.
var _pending_modifier: Key = KEY_NONE
## Hay una pregunta de intercambio en pantalla.
var _asking := false


func _ready() -> void:
	super._ready()
	_status = MenuStyle.make_label(HINT, STATUS_SIZE, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Dos líneas reservadas: los avisos no hacen saltar el panel.
	_status.custom_minimum_size.y = 50.0
	var box := _back.get_parent()
	box.add_child(_status)
	box.move_child(_status, _back.get_index())
	Controls.bindings_changed.connect(_on_bindings_changed)


## Al abrir se leen las teclas vigentes y se olvida cualquier espera anterior.
func open() -> void:
	_end_capture()
	refresh()
	_set_status(HINT, Tone.HINT)
	super.open()


func close() -> void:
	_end_capture()
	super.close()


func refresh() -> void:
	for row in _rows:
		row.refresh()


func get_rows() -> Array[RebindRow]:
	return _rows


func get_row(action: String) -> RebindRow:
	for row in _rows:
		if row.action == action:
			return row
	return null


func get_status_text() -> String:
	return _status.text


func is_capturing() -> bool:
	return _capture != null


## Hueco que espera una tecla, o null.
func get_capturing_slot() -> KeySlotButton:
	return _capture


# --- Construcción ---

func _build_categories() -> void:
	for category in InputBindings.CATEGORIES:
		var page := add_category(category, _icon_of(category))
		page.add_theme_constant_override("separation", 8)
		page.add_child(MenuStyle.make_label(category, 26, MenuStyle.TEXT, CaseFileStyle.serif_bold()))
		page.add_child(_column_header())
		for action in InputBindings.actions_in(category):
			var row := RebindRow.new(action, InputBindings.label_of(action))
			for slot in row.get_slots():
				slot.pressed.connect(_begin_capture.bind(slot))
				slot.clear_requested.connect(_clear.bind(slot))
			_rows.append(row)
			page.add_child(row)
		var fixed: Array = FIXED_ROWS.get(category, [])
		if fixed.is_empty():
			continue
		var divider := GoldDivider.new()
		divider.custom_minimum_size = Vector2(0.0, 16.0)
		divider.color = Color(MenuStyle.GOLD, 0.45)
		page.add_child(divider)
		page.add_child(MenuStyle.make_label("Teclas fijas: siempre sirven para navegar, elegir y volver.", 17, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic()))
		for definition: Dictionary in fixed:
			var row := BindingRow.new(definition["label"], ControlsMenu.groups_for(definition), [], false)
			row.set_meta("fixed", true)
			page.add_child(row)
	refresh()


## «Principal» y «Alternativa» sobre las columnas de los huecos.
func _column_header() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 12)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	for text: String in ["Principal", "Alternativa"]:
		var label := MenuStyle.make_label(text, 16, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
		label.custom_minimum_size.x = KeySlotButton.WIDTH
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(label)
	margin.add_child(header)
	return margin


static func _icon_of(category: String) -> String:
	for definition: Dictionary in ControlsMenu.CATEGORIES:
		if definition["title"] == category:
			return definition["icon"]
	return "puntos"


## Además del enlace de `CategoryMenu` (izquierda desde la página vuelve a la pestaña), los huecos de
## cada fila se enlazan entre sí y por columnas: arriba y abajo nunca cambian de columna.
func _link_focus() -> void:
	super._link_focus()
	var by_page := {}
	for row in _rows:
		var page := row.get_parent()
		if not by_page.has(page):
			by_page[page] = []
		(by_page[page] as Array).append(row)
	for page: Node in by_page:
		var rows: Array = by_page[page]
		for index in rows.size():
			var row: RebindRow = rows[index]
			var primary := row.get_slot(0)
			var alternative := row.get_slot(1)
			primary.focus_neighbor_right = primary.get_path_to(alternative)
			alternative.focus_neighbor_left = alternative.get_path_to(primary)
			alternative.focus_neighbor_right = NodePath(".")
			for column in InputBindings.SLOTS:
				var slot := row.get_slot(column)
				slot.focus_neighbor_top = slot.get_path_to((rows[index - 1] as RebindRow).get_slot(column)) if index > 0 else NodePath(".")
				slot.focus_neighbor_bottom = slot.get_path_to((rows[index + 1] as RebindRow).get_slot(column)) if index + 1 < rows.size() else slot.get_path_to(_back)


# --- Espera de la tecla nueva ---

func _input(event: InputEvent) -> void:
	if _capture != null:
		# La pregunta de salida (X o Alt + F4) va por encima: si aparece, la espera termina y el
		# teclado vuelve a ser suyo.
		if not is_open() or ExitManager.is_dialog_open():
			_end_capture()
			return
		get_viewport().set_input_as_handled()
		_capture_input(event)
		return
	if is_open() and not _asking and not ExitManager.is_dialog_open() and not ConfirmDialog.is_open() and _is_clear_key(event):
		var slot := get_viewport().gui_get_focus_owner() as KeySlotButton
		if slot != null and is_ancestor_of(slot):
			get_viewport().set_input_as_handled()
			_clear(slot)
			return
	super._input(event)


func _begin_capture(slot: KeySlotButton) -> void:
	if _asking or _capture != null or not is_open():
		return
	AudioManager.play("click")
	_capture = slot
	_capture_frame = Engine.get_process_frames()
	_pending_modifier = KEY_NONE
	slot.set_waiting(true)
	_set_status("Presiona una tecla para asignarla a «%s»%s. Esc cancela." % [
		InputBindings.label_of(slot.action), " como alternativa" if slot.slot > 0 else ""], Tone.WAITING)


func _end_capture() -> void:
	if _capture != null and is_instance_valid(_capture):
		_capture.set_waiting(false)
	_capture = null
	_pending_modifier = KEY_NONE


func _capture_input(event: InputEvent) -> void:
	# La pulsación que empezó la espera (y lo que llegue en su mismo fotograma) no cuenta.
	if Engine.get_process_frames() == _capture_frame:
		return
	if event is InputEventKey:
		_capture_key(event as InputEventKey)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		_cancel_capture()
		return
	var button := event as InputEventJoypadButton
	if button != null and button.pressed:
		if button.is_action("ui_cancel"):
			_cancel_capture()
		else:
			_set_status("Los botones del mando tienen su propio esquema: pulsa una tecla del teclado o cancela.", Tone.WARNING)


func _capture_key(key: InputEventKey) -> void:
	if key.echo:
		return
	var code := InputBindings.code_of(key)
	if not key.pressed:
		# Una modificadora sola se toma al soltarla, si no se pulsó otra tecla mientras tanto.
		if code != KEY_NONE and code == _pending_modifier:
			_pending_modifier = KEY_NONE
			_offer(code)
		return
	if key.is_action("ui_cancel") or key.is_action("pause"):
		_cancel_capture()
		return
	if InputBindings.is_modifier(code):
		_pending_modifier = code
		return
	if key.alt_pressed or key.meta_pressed:
		# Alt + F4, Alt + Tab o los atajos de Windows: son del sistema y siguen funcionando.
		_pending_modifier = KEY_NONE
		_set_status("Las combinaciones con Alt o con la tecla de Windows son del sistema. Pulsa una sola tecla.", Tone.WARNING)
		return
	_pending_modifier = KEY_NONE
	_offer(code)


func _cancel_capture() -> void:
	_end_capture()
	_set_status("Cambio cancelado. " + HINT, Tone.HINT)


## Decide qué hacer con la tecla pulsada para el hueco que espera.
func _offer(code: Key) -> void:
	var slot := _capture
	var action := slot.action
	var label := InputBindings.label_of(action)
	var key_text := InputLabels.code_name(code)
	var outcome := Controls.check(action, slot.slot, code)
	match String(outcome["result"]):
		"ok", "reorder":
			_end_capture()
			Controls.assign(action, slot.slot, code)
			_set_status("«%s» usa ahora %s." % [label, key_text], Tone.DONE)
		"unchanged":
			_end_capture()
			if Controls.get_key(action, slot.slot) == code:
				_set_status("«%s» ya usa %s." % [label, key_text], Tone.HINT)
			else:
				_set_status("%s ya es la tecla principal de «%s»." % [key_text, label], Tone.HINT)
		"blocked":
			_set_status(_blocked_text(key_text, outcome) + " Pulsa otra tecla o Esc.", Tone.WARNING)
		"conflict":
			if outcome["swap_ok"]:
				_end_capture()
				_ask_swap(slot, code, outcome)
			else:
				_set_status(_no_swap_text(key_text, outcome) + " Pulsa otra tecla o Esc.", Tone.WARNING)


static func _blocked_text(key_text: String, outcome: Dictionary) -> String:
	match String(outcome.get("reason", "")):
		"sistema":
			return "%s es del sistema operativo y no se puede asignar." % key_text
		"reservada":
			return "%s está reservada para %s." % [key_text, outcome["use"]]
		"menu":
			return "Esta acción también funciona dentro de su pantalla, donde %s sirve para %s." % [key_text, outcome["use"]]
	return "%s no se puede asignar a esta acción." % key_text


static func _no_swap_text(key_text: String, outcome: Dictionary) -> String:
	var other := InputBindings.label_of(outcome["action"])
	var given: Key = outcome["gives"]
	if given == KEY_NONE:
		return "%s es la única tecla de «%s», que se quedaría sin ninguna." % [key_text, other]
	return "%s es de «%s», que no puede recibir %s a cambio." % [key_text, other, InputLabels.code_name(given)]


## La tecla la usa otra acción: se pregunta si se intercambian. Cancelar no cambia nada.
func _ask_swap(slot: KeySlotButton, code: Key, outcome: Dictionary) -> void:
	_asking = true
	var key_text := InputLabels.code_name(code)
	var label := InputBindings.label_of(slot.action)
	var other := InputBindings.label_of(outcome["action"])
	var given: Key = outcome["gives"]
	var after := "«%s» pasará a usar %s." % [other, InputLabels.code_name(given)]
	if given == KEY_NONE:
		after = "«%s» se quedará sin esa tecla y conservará la otra." % other
	_set_status("La tecla %s ya está asignada a «%s»." % [key_text, other], Tone.WARNING)
	var accepted: bool = await ConfirmDialog.ask("TECLA EN USO",
		"La tecla %s ya está asignada a «%s».\n¿Quieres intercambiar las asignaciones?\n%s" % [key_text, other, after],
		{"confirm_text": "Intercambiar", "cancel_text": "Cancelar", "focus": "cancel"})
	_asking = false
	if not is_inside_tree():
		return
	if accepted and Controls.swap(slot.action, slot.slot, code):
		if given == KEY_NONE:
			_set_status("«%s» usa ahora %s; «%s» conserva su otra tecla." % [label, key_text, other], Tone.DONE)
		else:
			_set_status("Intercambiadas: «%s» usa %s y «%s» usa %s." % [label, key_text, other, InputLabels.code_name(given)], Tone.DONE)
	else:
		_set_status("Sin cambios: %s sigue en «%s»." % [key_text, other], Tone.HINT)
	if slot.is_visible_in_tree():
		slot.grab_focus()


# --- Quitar la alternativa ---

func _is_clear_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and InputBindings.code_of(key) in CLEAR_KEYS


func _clear(slot: KeySlotButton) -> void:
	if _capture != null or _asking:
		return
	var label := InputBindings.label_of(slot.action)
	if slot.slot == 0:
		_set_status("La tecla principal no se puede quitar: «%s» se quedaría sin tecla. Elige otra en su lugar." % label, Tone.WARNING)
		return
	if slot.get_key() == KEY_NONE:
		_set_status("«%s» no tiene tecla alternativa." % label, Tone.HINT)
		return
	var key_text := slot.get_key_text()
	if Controls.clear_slot(slot.action, slot.slot):
		AudioManager.play("click")
		_set_status("Se quitó %s de «%s»." % [key_text, label], Tone.DONE)


# --- Estado ---

func _set_status(text: String, tone: Tone) -> void:
	if _status == null:
		return
	_status.text = text
	var color := MenuStyle.TEXT_SECONDARY
	match tone:
		Tone.WAITING:
			color = CaseFileStyle.GOLD_LIGHT
		Tone.DONE:
			color = MenuStyle.TEXT
		Tone.WARNING:
			color = MenuStyle.SELECTION_LIGHT
	_status.add_theme_color_override("font_color", color)


func _on_bindings_changed(_actions: PackedStringArray) -> void:
	refresh()
