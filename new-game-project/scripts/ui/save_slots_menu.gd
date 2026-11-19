class_name SaveSlotsMenu
extends Control
## Expediente de partidas: la pantalla de guardar y la de cargar, con las cinco ranuras.
## La usan la pausa, el menú principal y la salida del juego. Sobrescribir, eliminar o
## cargar encima de un progreso sin guardar piden confirmación, y el resultado de cada
## operación se muestra en la propia pantalla.
##
## Elegir una ranura en la lista sólo la selecciona: la ranura activa de la partida no cambia
## hasta que se guarda o se carga.

signal closed
## La carga quedó preparada: quien abrió el menú debe pasar a la escena de juego.
signal load_ready(slot_id: String)

enum Mode { SAVE, LOAD }

const ROW_SCENE := preload("res://scenes/ui/save_slot_row.tscn")
const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")
const TITLES := {Mode.SAVE: "GUARDAR PARTIDA", Mode.LOAD: "CARGAR PARTIDA"}
const SUBTITLES := {
	Mode.SAVE: "Guarda tu progreso actual en una ranura de partida.",
	Mode.LOAD: "Elige una partida guardada para continuar con la investigación.",
}
const EMPTY_NOTE := "Todavía no hay partidas guardadas. Empieza una nueva y guárdala desde la pausa (Esc)."

var mode := Mode.SAVE
## Si no está vacío, se pide confirmación con este texto antes de cargar.
var load_warning := ""
## Guardado para poder salir del juego: valen las reglas de `SaveSystem.save_for_exit`.
var for_exit := false

var _selected := ""
var _rows: Dictionary = {}
var _infos: Dictionary = {}
var _saving_slot := ""
var _loading := false
var _empty_note := ""
var _confirm_action := Callable()

@onready var _parchment: ColorRect = $Center/Sheet/Parchment
@onready var _title: Label = $Center/Sheet/Content/Box/TitleRow/Title
@onready var _subtitle: Label = $Center/Sheet/Content/Box/Subtitle
@onready var _action: Button = $Center/Sheet/Content/Box/ActionRow/Action
@onready var _list_frame: PanelContainer = $Center/Sheet/Content/Box/ListFrame
@onready var _list: VBoxContainer = $Center/Sheet/Content/Box/ListFrame/Slots
@onready var _status: Label = $Center/Sheet/Content/Box/Status
@onready var _delete: Button = $Center/Sheet/Content/Box/Buttons/Delete
@onready var _back: Button = $Center/Sheet/Content/Box/Buttons/Back
@onready var _confirm: Control = $Confirm
@onready var _confirm_title: Label = $Confirm/Center/Card/Box/Title
@onready var _confirm_text: Label = $Confirm/Center/Card/Box/Text
@onready var _accept: Button = $Confirm/Center/Card/Box/Buttons/Accept
@onready var _cancel: Button = $Confirm/Center/Card/Box/Buttons/Cancel


func _ready() -> void:
	_build_look()
	for slot_id in SaveSystem.get_slots():
		var row: SaveSlotRow = ROW_SCENE.instantiate()
		row.name = slot_id
		_list.add_child(row)
		row.slot_id = slot_id
		row.pressed.connect(_on_row_pressed.bind(slot_id))
		_rows[slot_id] = row
	_action.pressed.connect(_on_action_pressed)
	_delete.pressed.connect(_on_delete_pressed)
	_back.pressed.connect(_on_back_pressed)
	_accept.pressed.connect(_on_confirm_accepted)
	_cancel.pressed.connect(_on_confirm_cancelled)
	SaveSystem.save_finished.connect(_on_save_finished)
	SaveSystem.slots_changed.connect(_on_slots_changed)
	_confirm.hide()


func open(new_mode: Mode = Mode.SAVE) -> void:
	mode = new_mode
	_loading = false
	_title.text = TITLES[mode]
	_subtitle.text = SUBTITLES[mode]
	_action.text = "Guardar" if mode == Mode.SAVE else "Cargar"
	_action.icon = CaseFileStyle.icon("disquete" if mode == Mode.SAVE else "carpeta")
	_center_banner_content()
	_selected = ""
	_hide_confirm()
	show()
	refresh()
	_selected = _initial_selection()
	_update_selection()
	_set_status(SaveSystem.get_save_blocker(for_exit) if mode == Mode.SAVE else _empty_note, mode == Mode.SAVE)
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
		_on_row_pressed(slot_id)


func is_confirming() -> bool:
	return _confirm.visible


func get_status_text() -> String:
	return _status.text


## Aviso que se muestra cuando no hay ninguna partida que cargar.
func get_hint_text() -> String:
	return _empty_note


func show_message(text: String, is_error: bool = false) -> void:
	_set_status(text, is_error)


func get_row(slot_id: String) -> SaveSlotRow:
	return _rows.get(slot_id)


func get_action_button() -> Button:
	return _action


func get_delete_button() -> Button:
	return _delete


func get_back_button() -> Button:
	return _back


func get_confirm_accept() -> Button:
	return _accept


func get_confirm_cancel() -> Button:
	return _cancel


## Vuelve a leer las ranuras y actualiza las filas, que no se recrean: el foco y la
## selección se conservan.
func refresh() -> void:
	var has_saves := false
	for info in SaveSystem.list_slots():
		var slot_id: String = info["id"]
		_infos[slot_id] = info
		has_saves = has_saves or info["status"] != SaveFormat.Status.EMPTY
		var preview: Texture2D = SaveSystem.get_slot_preview(slot_id) if info["status"] == SaveFormat.Status.OK else null
		var row: SaveSlotRow = _rows[slot_id]
		row.set_info(info, preview)
		row.set_busy(slot_id == _saving_slot)
	_empty_note = EMPTY_NOTE if mode == Mode.LOAD and not has_saves else ""
	_update_buttons()


## Nombre de la ranura con su artículo, como «la ranura 2».
static func slot_name(slot_id: String) -> String:
	return "la ranura %d" % SaveSystem.get_slot_number(slot_id)


static func format_clock(minutes: int) -> String:
	return SaveSlotRow.format_clock(minutes)


func _build_look() -> void:
	var material := ShaderMaterial.new()
	material.shader = PARCHMENT_SHADER
	_parchment.material = material
	_parchment.resized.connect(func() -> void: material.set_shader_parameter("rect_size", _parchment.size))
	for paper: Panel in [$Center/Sheet/PaperBack, $Center/Sheet/PaperMiddle]:
		var style := CaseFileStyle.box(CaseFileStyle.PARCHMENT_SHADE.darkened(0.08), Color("6e5235"), 2, 18)
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 14
		paper.add_theme_stylebox_override("panel", style)
	CaseFileStyle.style_label(_title, CaseFileStyle.serif_bold(), 62, Color("3a1c13"))
	CaseFileStyle.style_label(_subtitle, CaseFileStyle.serif_italic(), 25, CaseFileStyle.INK_SOFT)
	CaseFileStyle.style_label(_status, CaseFileStyle.serif_italic(), 22, CaseFileStyle.INK)
	CaseFileStyle.apply_banner_button(_action)
	CaseFileStyle.apply_wood_button(_delete)
	CaseFileStyle.apply_wood_button(_back)
	_delete.icon = CaseFileStyle.icon("papelera")
	_back.icon = CaseFileStyle.icon("volver")
	var list_style := CaseFileStyle.box(Color(CaseFileStyle.PARCHMENT_SHADE, 0.22), Color(CaseFileStyle.SEPIA, 0.35), 1, 12, 14.0)
	list_style.content_margin_right = 30.0
	_list_frame.add_theme_stylebox_override("panel", list_style)
	var card := CaseFileStyle.box(CaseFileStyle.PARCHMENT_LIGHT, CaseFileStyle.BURGUNDY, 3, 10, 34.0)
	card.shadow_color = Color(0, 0, 0, 0.55)
	card.shadow_size = 18
	($Confirm/Center/Card as PanelContainer).add_theme_stylebox_override("panel", card)
	CaseFileStyle.style_label(_confirm_title, CaseFileStyle.serif_bold(), 32, CaseFileStyle.BURGUNDY)
	CaseFileStyle.style_label(_confirm_text, CaseFileStyle.serif(), 24, CaseFileStyle.INK)
	CaseFileStyle.apply_wood_button(_accept, 26)
	CaseFileStyle.apply_wood_button(_cancel, 26)


## El icono y el texto de la pestaña van juntos en el centro, como en una etiqueta impresa.
func _center_banner_content() -> void:
	var font := _action.get_theme_font("font")
	var font_size := _action.get_theme_font_size("font_size")
	var text_width := font.get_string_size(_action.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon_width := float(_action.get_theme_constant("icon_max_width"))
	var group := icon_width + _action.get_theme_constant("h_separation") + text_width
	var side := maxf((_action.custom_minimum_size.x - group) * 0.5, 16.0)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := _action.get_theme_stylebox(state)
		style.content_margin_left = side
		style.content_margin_right = side
	_action.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _initial_selection() -> String:
	var active := SaveSystem.get_active_slot()
	if _rows.has(active):
		return active
	for slot_id: String in _rows:
		var occupied: bool = _infos[slot_id]["status"] != SaveFormat.Status.EMPTY
		if (mode == Mode.LOAD and occupied) or (mode == Mode.SAVE and not occupied):
			return slot_id
	return SaveSystem.get_slots()[0]


func _update_selection() -> void:
	for slot_id: String in _rows:
		(_rows[slot_id] as SaveSlotRow).set_selected(slot_id == _selected)
	_update_buttons()


func _update_buttons() -> void:
	var info: Dictionary = _infos.get(_selected, {})
	var status: int = info.get("status", SaveFormat.Status.EMPTY)
	var locked := _confirm.visible or not _saving_slot.is_empty() or _loading
	if mode == Mode.SAVE:
		_action.disabled = info.is_empty() or locked or not SaveSystem.get_save_blocker(for_exit).is_empty()
	else:
		_action.disabled = info.is_empty() or locked or status != SaveFormat.Status.OK
	_delete.disabled = info.is_empty() or status == SaveFormat.Status.EMPTY or locked or SaveSystem.is_busy()
	_back.disabled = _confirm.visible or _loading
	for slot_id: String in _rows:
		(_rows[slot_id] as SaveSlotRow).disabled = locked


func _focus_default() -> void:
	if _rows.has(_selected):
		(_rows[_selected] as Control).grab_focus()
	else:
		_back.grab_focus()


func _set_status(text: String, is_error: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", CaseFileStyle.BURGUNDY if is_error else CaseFileStyle.INK)


func _on_row_pressed(slot_id: String) -> void:
	_selected = slot_id
	_update_selection()
	_set_status(SaveSystem.get_save_blocker(for_exit) if mode == Mode.SAVE else _empty_note, mode == Mode.SAVE)


func _on_action_pressed() -> void:
	AudioManager.play("click")
	var info: Dictionary = _infos.get(_selected, {})
	if info.is_empty():
		return
	if mode == Mode.LOAD:
		if load_warning.is_empty():
			_load_selected()
		else:
			_ask("CARGAR PARTIDA", load_warning, "Cargar", _load_selected)
		return
	if info["status"] == SaveFormat.Status.EMPTY:
		_save_selected()
		return
	var name_text := slot_name(_selected)
	name_text = name_text.left(1).to_upper() + name_text.substr(1)
	var detail := ""
	if info["status"] == SaveFormat.Status.OK:
		var summary: Dictionary = info["summary"]
		detail = " (%s, día %d)" % [summary["location_name"], int(summary["day"])]
	_ask("SOBRESCRIBIR", "%s ya contiene una partida%s. ¿Quieres sustituirla por la actual?" % [name_text, detail], "Sobrescribir", _save_selected)


func _on_delete_pressed() -> void:
	AudioManager.play("click")
	if not _infos.has(_selected):
		return
	_ask("ELIMINAR PARTIDA", "¿Eliminar %s? La partida no se podrá recuperar." % slot_name(_selected), "Eliminar", _delete_selected)


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


func _ask(title: String, text: String, accept_label: String, action: Callable) -> void:
	_confirm_title.text = title
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
