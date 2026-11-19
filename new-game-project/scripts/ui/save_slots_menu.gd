class_name SaveSlotsMenu
extends PanelContainer
## Lista de ranuras compartida por la pausa y el menú principal. Para guardar muestra las
## cinco ranuras manuales; para cargar, también las automáticas. Sobrescribir, eliminar o
## cargar encima de un progreso sin guardar piden confirmación, y el resultado de cada
## operación se muestra en la propia lista.

signal closed
## La carga quedó preparada: quien abrió el menú debe pasar a la escena de juego.
signal load_ready(slot_id: String)

enum Mode { SAVE, LOAD }

const ROW_HEIGHT := 100.0
const REASON_LABELS := {
	"lugar": "cambio de lugar",
	"nuevo_dia": "nuevo día",
	"pista": "pista nueva",
	"deduccion": "deducción",
	"escena": "escena",
	"interrogatorio": "interrogatorio",
	"evento": "evento",
	"salida": "al salir",
	"importada": "importada",
}
const TAG_COLORS := {
	"manual": UiTheme.INK_SOFT,
	"auto": UiTheme.CORK,
	"empty": UiTheme.INK_SOFT,
	"error": UiTheme.STAMP,
	"busy": UiTheme.STAMP,
}

## Altura mínima de la lista de ranuras.
@export var list_height := 440.0

var mode := Mode.SAVE
## Guardado para poder salir del juego: valen las reglas de `SaveSystem.save_for_exit`.
var for_exit := false
## Si no está vacío, se pide confirmación con este texto antes de cargar.
var load_warning := ""

var _selected := ""
var _loading := false
var _infos: Dictionary = {}
var _rows: Dictionary = {}
var _saving_slot := ""
var _confirm_action := Callable()

@onready var _title: Label = $Box/Title
@onready var _hint: Label = $Box/Hint
@onready var _scroll: ScrollContainer = $Box/Scroll
@onready var _slots: VBoxContainer = $Box/Scroll/Slots
@onready var _confirm: PanelContainer = $Box/Confirm
@onready var _confirm_text: Label = $Box/Confirm/Box/Text
@onready var _accept: Button = $Box/Confirm/Box/Buttons/Accept
@onready var _cancel: Button = $Box/Confirm/Box/Buttons/Cancel
@onready var _status: Label = $Box/Status
@onready var _action: Button = $Box/Buttons/Action
@onready var _delete: Button = $Box/Buttons/Delete
@onready var _back: Button = $Box/Buttons/Back


func _ready() -> void:
	_scroll.custom_minimum_size.y = list_height
	_title.add_theme_font_override("font", UiTheme.serif())
	_title.add_theme_font_size_override("font_size", 30)
	_hint.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	_hint.add_theme_font_size_override("font_size", 19)
	_confirm.add_theme_stylebox_override("panel", UiTheme.paper_box(UiTheme.PAPER_LIGHT, UiTheme.STAMP, 12))
	_action.pressed.connect(_on_action_pressed)
	_delete.pressed.connect(_on_delete_pressed)
	_back.pressed.connect(_on_back_pressed)
	_accept.pressed.connect(_on_confirm_accepted)
	_cancel.pressed.connect(_on_confirm_cancelled)
	SaveSystem.save_finished.connect(_on_save_finished)
	SaveSystem.slots_changed.connect(_on_slots_changed)


func open(new_mode: Mode = Mode.SAVE) -> void:
	mode = new_mode
	_loading = false
	_title.text = "GUARDAR PARTIDA" if mode == Mode.SAVE else "CARGAR PARTIDA"
	_selected = ""
	_hide_confirm()
	show()
	refresh()
	_set_status(SaveSystem.get_save_blocker(for_exit) if mode == Mode.SAVE else "", true)
	_focus_default()


func close() -> void:
	_hide_confirm()
	hide()
	closed.emit()


## Escape: primero cierra la confirmación y después el menú.
func cancel() -> void:
	if _confirm.visible:
		_on_confirm_cancelled()
	else:
		close()


func get_selected_slot() -> String:
	return _selected


func select_slot(slot_id: String) -> void:
	if _rows.has(slot_id):
		(_rows[slot_id] as Button).button_pressed = true
		_on_row_pressed(slot_id)


func is_confirming() -> bool:
	return _confirm.visible


func get_status_text() -> String:
	return _status.text


func get_hint_text() -> String:
	return _hint.text


func show_message(text: String, is_error: bool = false) -> void:
	_set_status(text, is_error)


## Vuelve a leer las ranuras y reconstruye la lista conservando la selección.
func refresh() -> void:
	var focused_slot := _focused_slot()
	for child in _slots.get_children():
		_slots.remove_child(child)
		child.queue_free()
	_rows.clear()
	_infos.clear()
	var group := ButtonGroup.new()
	var has_saves := false
	for info in SaveSystem.list_slots():
		var slot_id: String = info["id"]
		_infos[slot_id] = info
		has_saves = has_saves or info["status"] != SaveFormat.Status.EMPTY
		var row := _make_row(info, group)
		_slots.add_child(row)
		_rows[slot_id] = row
	_hint.text = _hint_text(has_saves)
	if _rows.has(_selected):
		(_rows[_selected] as Button).set_pressed_no_signal(true)
	else:
		_selected = ""
	_update_buttons()
	if _rows.has(focused_slot) and (_rows[focused_slot] as Button).focus_mode != Control.FOCUS_NONE:
		(_rows[focused_slot] as Button).grab_focus()


## Textos de una ranura para la lista. Sólo usa lo que el archivo registró.
static func describe_slot(info: Dictionary) -> Dictionary:
	var auto: bool = info["kind"] == "auto"
	var title := "Ranura %d" % int(info["number"])
	match info["status"]:
		SaveFormat.Status.EMPTY:
			return {"title": title, "tag": "VACÍA", "detail": "Sin partida guardada.", "extra": "", "tone": "empty"}
		SaveFormat.Status.INCOMPATIBLE:
			return {"title": title, "tag": "INCOMPATIBLE", "detail": info["error"], "extra": "Puedes eliminarla para liberar la ranura.", "tone": "error"}
		SaveFormat.Status.CORRUPT:
			return {"title": title, "tag": "DAÑADA", "detail": info["error"], "extra": "Puedes eliminarla para liberar la ranura.", "tone": "error"}
	var summary: Dictionary = info["summary"]
	var tag := "AUTOGUARDADO" if auto else "MANUAL"
	var reason: String = REASON_LABELS.get(summary["reason"], "")
	if not reason.is_empty():
		tag += " · " + reason.to_upper()
	var detail := "%s · Día %d, %s" % [summary["location_name"], int(summary["day"]), format_clock(int(summary["minutes"]))]
	var extra := "Guardada el %s · %s · %d %s" % [
		format_saved_at(float(summary["saved_at"])),
		format_play_time(float(summary["play_seconds"])),
		int(summary["clues"]),
		"pista" if int(summary["clues"]) == 1 else "pistas",
	]
	return {"title": title, "tag": tag, "detail": detail, "extra": extra, "tone": "auto" if auto else "manual"}


## Nombre de la ranura con su artículo, como «la ranura 2».
static func slot_name(slot_id: String) -> String:
	return "la ranura %d" % SaveSystem.get_slot_number(slot_id)


static func format_clock(minutes: int) -> String:
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## Fecha y hora locales del guardado; el archivo la registra en UTC.
static func format_saved_at(unix_time: float) -> String:
	var bias_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var local := Time.get_datetime_dict_from_unix_time(int(unix_time) + bias_minutes * 60)
	return "%02d/%02d/%04d %02d:%02d" % [local["day"], local["month"], local["year"], local["hour"], local["minute"]]


static func format_play_time(seconds: float) -> String:
	if seconds < 0.0:
		return "tiempo de juego sin registrar"
	var total_minutes := int(seconds) / 60
	if total_minutes < 1:
		return "menos de 1 min de juego"
	if total_minutes < 60:
		return "%d min de juego" % total_minutes
	return "%d h %02d min de juego" % [total_minutes / 60, total_minutes % 60]


func _make_row(info: Dictionary, group: ButtonGroup) -> Button:
	var slot_id: String = info["id"]
	var text := describe_slot(info)
	var tone: String = text["tone"]
	if slot_id == _saving_slot:
		text["tag"] = "GUARDANDO…"
		tone = "busy"
	var row := Button.new()
	row.name = slot_id
	# Al cargar, una ranura vacía no ofrece nada: se muestra, pero no se puede elegir.
	var selectable: bool = mode == Mode.SAVE or info["status"] != SaveFormat.Status.EMPTY
	row.set_meta("selectable", selectable)
	if not selectable:
		row.focus_mode = Control.FOCUS_NONE
	row.toggle_mode = true
	row.button_group = group
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.pressed.connect(_on_row_pressed.bind(slot_id))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	row.add_child(box)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 14.0
	box.offset_top = 8.0
	box.offset_right = -14.0
	box.offset_bottom = -8.0
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	var title := _make_label(text["title"], 23, UiTheme.INK)
	title.add_theme_font_override("font", UiTheme.serif())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var tag := _make_label(text["tag"], 17, TAG_COLORS[tone])
	# La etiqueta nunca se recorta: es la que distingue manual, automática, vacía o dañada.
	tag.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	header.add_child(tag)
	box.add_child(_make_label(text["detail"], 19, UiTheme.STAMP if tone == "error" else UiTheme.INK))
	box.add_child(_make_label(text["extra"], 17, UiTheme.INK_SOFT))
	return row


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _update_buttons() -> void:
	var info: Dictionary = _infos.get(_selected, {})
	var occupied: bool = not info.is_empty() and info["status"] != SaveFormat.Status.EMPTY
	var locked := _confirm.visible or not _saving_slot.is_empty() or _loading
	if mode == Mode.SAVE:
		_action.text = "Sobrescribir" if occupied else "Guardar aquí"
		_action.disabled = info.is_empty() or locked or not SaveSystem.get_save_blocker(for_exit).is_empty()
	else:
		_action.text = "Cargar"
		_action.disabled = info.is_empty() or locked or info["status"] != SaveFormat.Status.OK
	_delete.disabled = not occupied or locked or SaveSystem.is_busy()
	_back.disabled = _confirm.visible or _loading
	for slot_id: String in _rows:
		var row: Button = _rows[slot_id]
		row.disabled = locked or not row.get_meta("selectable", true)


func _focus_default() -> void:
	if _rows.has(_selected):
		(_rows[_selected] as Button).grab_focus()
		return
	for slot_id: String in _rows:
		if (_rows[slot_id] as Button).get_meta("selectable", true):
			(_rows[slot_id] as Button).grab_focus()
			return
	_back.grab_focus()


func _hint_text(has_saves: bool) -> String:
	if mode == Mode.SAVE:
		return "Elige una ranura: pasará a ser la de esta partida y los autoguardados seguirán en ella."
	if has_saves:
		return "Elige la partida que quieres retomar: sus autoguardados seguirán en la misma ranura."
	return "Todavía no hay partidas guardadas. Empieza una nueva y guárdala desde la pausa."


func _focused_slot() -> String:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for slot_id: String in _rows:
		if _rows[slot_id] == focused:
			return slot_id
	return ""


func _set_status(text: String, is_error: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiTheme.STAMP if is_error else UiTheme.INK)


func _on_row_pressed(slot_id: String) -> void:
	_selected = slot_id
	_set_status(SaveSystem.get_save_blocker(for_exit) if mode == Mode.SAVE else "", true)
	_update_buttons()
	if not _action.disabled:
		_action.grab_focus()


func _on_action_pressed() -> void:
	AudioManager.play("click")
	var info: Dictionary = _infos.get(_selected, {})
	if info.is_empty():
		return
	if mode == Mode.LOAD:
		if load_warning.is_empty():
			_load_selected()
		else:
			_ask(load_warning, "Cargar", _load_selected)
		return
	if info["status"] == SaveFormat.Status.EMPTY:
		_save_selected()
		return
	var detail: String = describe_slot(info)["detail"]
	var name_text := slot_name(_selected)
	name_text = name_text.left(1).to_upper() + name_text.substr(1)
	_ask("%s ya contiene una partida (%s). ¿Quieres sobrescribirla?" % [name_text, detail], "Sobrescribir", _save_selected)


func _on_delete_pressed() -> void:
	AudioManager.play("click")
	if not _infos.has(_selected):
		return
	_ask("¿Eliminar %s? La partida no se podrá recuperar." % slot_name(_selected), "Eliminar", _delete_selected)


func _on_back_pressed() -> void:
	AudioManager.play("click")
	close()


func _save_selected() -> void:
	var slot_id := _selected
	var result := SaveSystem.save_to_slot(slot_id, for_exit)
	if not result["ok"]:
		_set_status(result["error"], true)
		return
	_saving_slot = slot_id
	_set_status("Guardando en %s…" % slot_name(slot_id))
	refresh()


func _load_selected() -> void:
	var result := SaveSystem.request_load(_selected)
	if not result["ok"]:
		_set_status("No se pudo cargar %s: %s" % [slot_name(_selected), result["error"]], true)
		refresh()
		return
	_loading = true
	_set_status("Cargando la partida…")
	_update_buttons()
	load_ready.emit(_selected)


func _delete_selected() -> void:
	var result := SaveSystem.delete_slot(_selected)
	if result["ok"]:
		_set_status("Partida eliminada.")
	else:
		_set_status(result["error"], true)


func _ask(text: String, accept_label: String, action: Callable) -> void:
	_confirm_text.text = text
	_accept.text = accept_label
	_confirm_action = action
	_confirm.show()
	_update_buttons()
	_cancel.grab_focus()


func _on_confirm_accepted() -> void:
	AudioManager.play("click")
	var action := _confirm_action
	_hide_confirm()
	if action.is_valid():
		action.call()


func _on_confirm_cancelled() -> void:
	AudioManager.play("click")
	_hide_confirm()
	_focus_default()


func _hide_confirm() -> void:
	_confirm.hide()
	_confirm_action = Callable()
	_update_buttons()


func _on_save_finished(slot_id: String, ok: bool, message: String) -> void:
	if slot_id != _saving_slot:
		return
	_saving_slot = ""
	if ok:
		_set_status("Partida guardada en %s." % slot_name(slot_id))
	else:
		_set_status("No se pudo guardar: %s" % message, true)


func _on_slots_changed() -> void:
	if visible:
		refresh()
		if _focused_slot().is_empty() and get_viewport().gui_get_focus_owner() == null:
			_focus_default()
