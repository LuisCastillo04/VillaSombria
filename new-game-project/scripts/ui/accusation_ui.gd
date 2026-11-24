class_name AccusationUi
extends CanvasLayer
## Acusación formal. El jugador elige al culpable y presenta el motivo, la oportunidad y los medios.
## Un error no termina la partida: Ortega explica por qué no se sostiene y se puede seguir
## investigando.
##
## Este nodo sólo coordina. La hoja (`AccusationSheet`) y sus campos (`AccusationField`) están en la
## escena. De momento, cada campo se elige en el menú desplegable de Godot, que en las pruebas sólo
## ofrece lo descubierto de su categoría (`EvidenceCategories`). Lo que muestran lo lee
## `AccusationInfo`.
##
## Cada elección se anota enseguida en el borrador de `Investigation`, que vive en `GameState` y se
## guarda con la partida: «Seguir investigando» sólo cierra la hoja, y al volver todo sigue igual.
## Las reglas que deciden si la acusación se sostiene no cambian (`Investigation.evaluate_accusation`).

const LOCK := "acusacion"
## Campo del sospechoso (`Investigation.SUSPECT_FIELD`); los otros tres son las categorías de prueba.
const SUSPECT_FIELD := "suspect"
const CONFRONTATION_SCENE := "confrontacion"

var is_open := false

var _draft: Dictionary = {}
## Campo cuyo menú está abierto, o "".
var _picker := ""
## Avance de la animación de apertura, de 0 a 1.
var _open_amount := 1.0
var _scale := 1.0
var _transition: Tween
var _fields: Dictionary = {}
## Menú desplegable de Godot con las opciones del campo que se edita, y sus identificadores.
var _popup: PopupMenu
var _popup_ids: Array[String] = []

@onready var _root: Control = $Root
@onready var _sheet: AccusationSheet = $Root/Sheet
@onready var _header: AccusationHeader = $Root/Sheet/Content/Rows/Header
@onready var _verdict: AccusationVerdict = $Root/Sheet/Content/Rows/Verdict
@onready var _accuse: AccusationPlateButton = $Root/Sheet/Content/Rows/Buttons/Accuse
@onready var _continue: AccusationPlateButton = $Root/Sheet/Content/Rows/Buttons/Continue
@onready var _shield: Control = $Root/Shield


func _ready() -> void:
	for field: AccusationField in $Root/Sheet/Content/Rows/Fields.get_children():
		_fields[field.field_key] = field
		field.activated.connect(open_field)
	_accuse.pressed.connect(present)
	_continue.pressed.connect(close)
	_root.resized.connect(_on_root_resized)
	_shield.hide()
	_root.hide()
	_layout()


## Abre la hoja con lo último que el jugador eligió: el borrador de la acusación.
func open() -> void:
	is_open = true
	GameState.lock_player(LOCK)
	_draft = Investigation.get_accusation_draft()
	_refresh_fields()
	_verdict.show_message(AccusationInfo.DEFAULT_VERDICT, false)
	close_picker(false)
	_root.show()
	_shield.hide()
	_layout()
	_animate_open()
	(_fields[SUSPECT_FIELD] as AccusationField).selector.grab_focus()


## «Seguir investigando»: cierra la hoja sin presentar nada ni contar un intento. Lo elegido ya
## está en el borrador.
func close() -> void:
	if not is_open:
		return
	close_picker(false)
	is_open = false
	GameState.unlock_player(LOCK)
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null and _root.is_ancestor_of(focused):
		focused.release_focus()
	_animate_close()


## Abre el menú de un campo como si el jugador pulsara su selector. Volver a pulsar el campo
## abierto lo cierra.
func open_field(field: String) -> void:
	if not is_open or not _fields.has(field):
		return
	if field == _picker:
		close_picker()
		return
	_open_popup(field)


## Cierra la lista abierta (si la hay) y devuelve el foco a su campo, sin cambiar la elección.
func close_picker(play_sound: bool = true) -> void:
	var field := _picker
	if field.is_empty():
		return
	_picker = ""
	_set_editing("")
	if _popup != null and _popup.visible:
		_popup.hide()
	if play_sound:
		AudioManager.play("ui_cerrar")
	(_fields[field] as AccusationField).selector.grab_focus()


## Elige `value` en un campo, como al pulsar su fila: se anota en el borrador, se actualiza sólo
## ese campo y se cierra su lista. Devuelve si la elección valía.
func choose(field: String, value: String) -> bool:
	if not is_open or not Investigation.set_accusation_choice(field, value):
		return false
	_draft = Investigation.get_accusation_draft()
	_refresh_fields()
	AudioManager.play("click")
	if _picker == field:
		close_picker(false)
	return true


## «Presentar la acusación». Sólo con los cuatro campos; cuenta un intento y la valora con las
## reglas de siempre. Devuelve el veredicto ({"ok", "reason"}), o vacío si no se presentó.
func present() -> Dictionary:
	if not is_open or not can_present():
		return {}
	if not _picker.is_empty():
		close_picker(false)
	GameState.accusation_attempts += 1
	var verdict := Investigation.evaluate_accusation(_draft["suspect"], _draft["motive"], _draft["opportunity"], _draft["means"])
	if verdict["ok"]:
		close()
		DialogueManager.play_scene(CONFRONTATION_SCENE)
	else:
		AudioManager.play("acusacion_fallida")
		_verdict.show_message("[b]Ortega:[/b] %s" % verdict["reason"])
	return verdict


func can_present() -> bool:
	return Investigation.is_accusation_complete(_draft)


# --- Consultas (pruebas y capturas) ---

func get_field(field: String) -> AccusationField:
	return _fields.get(field)


## Lo que se lee en el selector de un campo: la elección o el texto de ayuda.
func get_field_text(field: String) -> String:
	var node: AccusationField = _fields.get(field)
	return node.selector.get_display_text() if node != null else ""


## Campo cuya lista está abierta, o "".
func get_active_picker() -> String:
	return _picker


func get_sheet() -> AccusationSheet:
	return _sheet


func get_header() -> AccusationHeader:
	return _header


func get_accuse_button() -> Button:
	return _accuse


func get_continue_button() -> Button:
	return _continue


func get_verdict_text() -> String:
	return _verdict.get_text()


func get_layout_scale() -> float:
	return _scale


## Rectángulos de la hoja y del panel en pantalla, ya escalados, para comprobar que caben.
func get_sheet_rect() -> Rect2:
	return Rect2(_sheet.position, _sheet.size * _sheet.scale)


# --- Listas ---

## Despliega el menú de Godot con los sospechosos o con lo que se puede presentar en un campo.
func _open_popup(field: String) -> void:
	if _popup == null:
		_popup = PopupMenu.new()
		_popup.name = "Popup"
		_popup.add_theme_font_override("font", AccusationStyle.body_font())
		_popup.add_theme_font_size_override("font_size", AccusationStyle.ROW_SIZE)
		_popup.id_pressed.connect(func(index: int) -> void: choose(_picker, _popup_ids[index]))
		_popup.popup_hide.connect(_on_popup_hidden)
		add_child(_popup)
	_popup.clear()
	_popup_ids.clear()
	var options := AccusationInfo.suspects() if field == SUSPECT_FIELD else AccusationInfo.options(field)
	for option in options:
		_popup.add_item(option["title"], _popup_ids.size())
		_popup_ids.append(option["id"])
	if _popup_ids.is_empty():
		_popup.add_item(AccusationInfo.EMPTY_TEXTS.get(field, ""), 0)
		_popup.set_item_disabled(0, true)
	_picker = field
	_set_editing(field)
	# Bajo el selector, en píxeles de la ventana: con la escala de la hoja y la del estiramiento.
	var selector := (_fields[field] as AccusationField).selector
	var screen_scale := selector.get_viewport().get_final_transform().get_scale() * selector.get_global_transform_with_canvas().get_scale()
	var origin := selector.get_screen_position() + Vector2(0.0, selector.size.y * screen_scale.y)
	_popup.popup(Rect2i(Vector2i(origin), Vector2i(int(selector.size.x * screen_scale.x), 0)))
	AudioManager.play("ui_abrir")


## El menú se cerró sin elegir (Esc o un clic fuera).
func _on_popup_hidden() -> void:
	if _picker.is_empty():
		return
	var field := _picker
	_picker = ""
	_set_editing("")
	(_fields[field] as AccusationField).selector.grab_focus()


func _set_editing(field: String) -> void:
	for key: String in _fields:
		(_fields[key] as AccusationField).set_editing(key == field)


# --- Formulario ---

func _refresh_fields() -> void:
	var suspect_id: String = _draft.get(SUSPECT_FIELD, "")
	(_fields[SUSPECT_FIELD] as AccusationField).set_value(AccusationInfo.suspect_name(suspect_id) if not suspect_id.is_empty() else "")
	for field in EvidenceCategories.KEYS:
		var item_id: String = _draft.get(field, "")
		var node: AccusationField = _fields[field]
		if item_id.is_empty():
			node.set_value("")
		else:
			var info := AccusationInfo.describe(item_id)
			node.set_value(info.get("title", ""), AccusationStyle.type_icon(info.get("type", "")))


# --- Entrada ---

func _input(event: InputEvent) -> void:
	if not is_open or ExitManager.is_dialog_open() or ConfirmDialog.is_open():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _picker.is_empty():
			close_picker()
		else:
			close()


func _on_root_resized() -> void:
	_layout()


# --- Composición y animaciones ---

## La hoja tiene un tamaño de diseño; si la pantalla (o el tamaño de letra de Accesibilidad) no da
## para ella, se escala entera, así nunca se sale de la pantalla.
func _layout() -> void:
	if _root == null:
		return
	var available := _root.size - AccusationStyle.SCREEN_MARGIN * 2.0
	_scale = clampf(minf(available.y / AccusationStyle.SHEET_SIZE.y, available.x / AccusationStyle.SHEET_SIZE.x), 0.25, 1.0)
	_sheet.size = AccusationStyle.SHEET_SIZE
	_place()


func _place() -> void:
	var area := _root.size
	var sheet_size := AccusationStyle.SHEET_SIZE * _scale
	var pop := lerpf(AccusationStyle.OPEN_SCALE, 1.0, _open_amount)
	var sheet_position := (area - sheet_size) * 0.5
	_sheet.scale = Vector2.ONE * _scale * pop
	_sheet.position = sheet_position + sheet_size * (1.0 - pop) * 0.5


func _animate_open() -> void:
	if _transition != null:
		_transition.kill()
	_root.modulate.a = 0.0
	_open_amount = 0.0
	_place()
	_transition = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(_root, "modulate:a", 1.0, AccusationStyle.OPEN_SECONDS)
	_transition.tween_method(func(value: float) -> void:
		_open_amount = value
		_place()
	, 0.0, 1.0, AccusationStyle.OPEN_SECONDS)


## Se desvanece y después se oculta. Mientras tanto, una capa transparente recoge los clics para que
## nada responda ya cerrado.
func _animate_close() -> void:
	if _transition != null:
		_transition.kill()
	_shield.show()
	_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_transition.tween_property(_root, "modulate:a", 0.0, AccusationStyle.CLOSE_SECONDS)
	_transition.tween_callback(_finish_close)


func _finish_close() -> void:
	if is_open:
		return
	_root.hide()
	_shield.hide()
	_root.modulate.a = 1.0
