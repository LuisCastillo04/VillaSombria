class_name AccusationUi
extends CanvasLayer
## Acusación formal. El jugador elige al culpable y presenta el motivo, la oportunidad y los medios.
## Un error no termina la partida: Ortega explica por qué no se sostiene y se puede seguir
## investigando.
##
## Este nodo sólo coordina. La hoja (`AccusationSheet`) y sus campos (`AccusationField`) están en la
## escena; el sospechoso se elige en una lista desplegable propia (`AccusationSuspectList`) y cada
## prueba en el panel lateral (`AccusationEvidencePanel`), que sólo ofrece lo descubierto de su
## categoría (`EvidenceCategories`). Lo que muestran lo lee `AccusationInfo`.
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
## Campo cuya lista está abierta: el sospechoso (lista desplegable), una prueba (panel lateral) o "".
var _picker := ""
## Reparto de la pantalla: 0 con la hoja centrada, 1 con el panel lateral al lado.
var _split := 0.0
## Avance de la animación de apertura, de 0 a 1.
var _open_amount := 1.0
var _scale := 1.0
var _split_tween: Tween
var _transition: Tween
var _fields: Dictionary = {}

@onready var _root: Control = $Root
@onready var _sheet: AccusationSheet = $Root/Sheet
@onready var _header: AccusationHeader = $Root/Sheet/Content/Rows/Header
@onready var _verdict: AccusationVerdict = $Root/Sheet/Content/Rows/Verdict
@onready var _accuse: AccusationPlateButton = $Root/Sheet/Content/Rows/Buttons/Accuse
@onready var _continue: AccusationPlateButton = $Root/Sheet/Content/Rows/Buttons/Continue
@onready var _panel: AccusationEvidencePanel = $Root/Panel
@onready var _suspects: AccusationSuspectList = $Root/SuspectList
@onready var _shield: Control = $Root/Shield


func _ready() -> void:
	for field: AccusationField in $Root/Sheet/Content/Rows/Fields.get_children():
		_fields[field.field_key] = field
		field.activated.connect(open_field)
	_accuse.pressed.connect(present)
	_continue.pressed.connect(close)
	_panel.item_chosen.connect(func(item_id: String) -> void: choose(_picker, item_id))
	_panel.close_requested.connect(close_picker)
	_suspects.suspect_chosen.connect(func(suspect_id: String) -> void: choose(SUSPECT_FIELD, suspect_id))
	_suspects.closed.connect(_on_suspect_list_closed)
	_root.resized.connect(_on_root_resized)
	_shield.hide()
	_panel.hide()
	_root.hide()
	_layout()


## Abre la hoja con lo último que el jugador eligió: el borrador de la acusación.
func open() -> void:
	is_open = true
	GameState.lock_player(LOCK)
	_draft = Investigation.get_accusation_draft()
	_suspects.setup(AccusationInfo.suspects())
	_refresh_fields()
	_verdict.show_message(AccusationInfo.DEFAULT_VERDICT, false)
	_suspects.close(false)
	_picker = ""
	_set_editing("")
	_set_split(0.0)
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
	if _picker == SUSPECT_FIELD:
		_suspects.close(false)
	_picker = ""
	_set_editing("")
	is_open = false
	GameState.unlock_player(LOCK)
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null and _root.is_ancestor_of(focused):
		focused.release_focus()
	_animate_close()


## Abre la lista de un campo como si el jugador pulsara su selector: la desplegable del sospechoso
## o el panel lateral de una prueba. Volver a pulsar el campo abierto la cierra.
func open_field(field: String) -> void:
	if not is_open or not _fields.has(field):
		return
	if field == _picker:
		close_picker()
		return
	if field == SUSPECT_FIELD:
		_open_suspect_list()
	else:
		_open_panel(field)


## Cierra la lista abierta (si la hay) y devuelve el foco a su campo, sin cambiar la elección.
func close_picker(play_sound: bool = true) -> void:
	var field := _picker
	if field.is_empty():
		return
	if field == SUSPECT_FIELD:
		_suspects.close()
		return
	_picker = ""
	_set_editing("")
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null and _panel.is_ancestor_of(focused):
		focused.release_focus()
	_animate_split(0.0)
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


func is_panel_open() -> bool:
	return not _picker.is_empty() and _picker != SUSPECT_FIELD


func is_suspect_list_open() -> bool:
	return _picker == SUSPECT_FIELD


func get_panel() -> AccusationEvidencePanel:
	return _panel


func get_suspect_list() -> AccusationSuspectList:
	return _suspects


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


func get_panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size * _panel.scale)


# --- Listas ---

func _open_suspect_list() -> void:
	if is_panel_open():
		close_picker(false)
	_picker = SUSPECT_FIELD
	_set_editing(SUSPECT_FIELD)
	var selector := (_fields[SUSPECT_FIELD] as AccusationField).selector
	_suspects.open_at(selector, _draft[SUSPECT_FIELD])
	AudioManager.play("ui_abrir")


func _on_suspect_list_closed() -> void:
	if _picker != SUSPECT_FIELD:
		return
	_picker = ""
	_set_editing("")
	if is_open:
		AudioManager.play("ui_cerrar")
		(_fields[SUSPECT_FIELD] as AccusationField).selector.grab_focus()


## Abre el panel lateral para un campo de prueba. Si ya estaba abierto para otro, sólo cambia
## de contenido.
func _open_panel(field: String) -> void:
	var switching := is_panel_open()
	if _picker == SUSPECT_FIELD:
		_suspects.close(false)
	_picker = field
	_set_editing(field)
	_panel.show()
	_panel.open_for(field, _draft[field])
	_panel.refresh_keys()
	_animate_split(1.0)
	AudioManager.play("ui_mover" if switching else "ui_abrir")
	_panel.focus_list()


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
	if _picker == SUSPECT_FIELD:
		_suspects.close(false)
	_layout()


# --- Composición y animaciones ---

## La hoja y el panel tienen un tamaño de diseño; si la pantalla (o el tamaño de letra de
## Accesibilidad) no da para los dos juntos, se escalan a la vez, así nunca se salen de la pantalla
## ni cambian de tamaño al abrir el panel.
func _layout() -> void:
	if _root == null:
		return
	var available := _root.size - AccusationStyle.SCREEN_MARGIN * 2.0
	var both := AccusationStyle.SHEET_SIZE.x + AccusationStyle.PANEL_GAP + AccusationStyle.PANEL_SIZE.x
	_scale = clampf(minf(available.y / AccusationStyle.SHEET_SIZE.y, available.x / both), 0.25, 1.0)
	_sheet.size = AccusationStyle.SHEET_SIZE
	_panel.size = AccusationStyle.PANEL_SIZE
	_place()


func _place() -> void:
	var area := _root.size
	var sheet_size := AccusationStyle.SHEET_SIZE * _scale
	var panel_size := AccusationStyle.PANEL_SIZE * _scale
	var both := (AccusationStyle.SHEET_SIZE.x + AccusationStyle.PANEL_GAP + AccusationStyle.PANEL_SIZE.x) * _scale
	var centered_x := (area.x - sheet_size.x) * 0.5
	var split_x := (area.x - both) * 0.5
	var top := (area.y - sheet_size.y) * 0.5
	var pop := lerpf(AccusationStyle.OPEN_SCALE, 1.0, _open_amount)
	var sheet_position := Vector2(lerpf(centered_x, split_x, _split), top)
	_sheet.scale = Vector2.ONE * _scale * pop
	_sheet.position = sheet_position + sheet_size * (1.0 - pop) * 0.5
	var panel_x := split_x + (AccusationStyle.SHEET_SIZE.x + AccusationStyle.PANEL_GAP) * _scale
	_panel.scale = Vector2.ONE * _scale
	_panel.position = Vector2(panel_x + AccusationStyle.PANEL_SLIDE * _scale * (1.0 - _split), top + (sheet_size.y - panel_size.y) * 0.5)
	_panel.modulate.a = _split
	_panel.visible = is_panel_open() or _split > 0.001


func _set_split(value: float) -> void:
	if _split_tween != null:
		_split_tween.kill()
	_split = value
	_place()


## Paso suave entre la hoja centrada y la hoja con el panel al lado.
func _animate_split(target: float) -> void:
	if _split_tween != null:
		_split_tween.kill()
	_split_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if target > _split else Tween.EASE_IN_OUT)
	_split_tween.tween_method(func(value: float) -> void:
		_split = value
		_place()
	, _split, target, AccusationStyle.SPLIT_SECONDS)


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
	_set_split(0.0)
