class_name BoardUi
extends CanvasLayer
## Tablero de deducción. El jugador compara dos elementos del expediente y el sistema
## comprueba si existe una relación real; las relaciones halladas se unen con hilo rojo.
##
## Este nodo coordina: abre y cierra el tablero, lleva la selección de los dos elementos que se
## comparan y pide la relación a `Investigation.try_link`, y anota las hipótesis con
## `Investigation.set_hypothesis`. Los datos que muestra los lee `BoardInfo`.

## Minutos que lleva establecer una relación nueva. El expediente los cita en sus reglas del tiempo.
const LINK_MINUTES := 15

var is_open := false
var _selection: Array[String] = []
## Hipótesis que el jugador dejó a medias, por sospechoso: {status, note}. Duran mientras dure la
## partida en curso; nunca se guardan en el archivo, que sólo recoge lo que se guarda a propósito.
var _drafts: Dictionary = {}
var _suspect_row: BoardSuspectRow
var _canvas: BoardCanvas
var _comparison: BoardComparisonPanel
var _editor: BoardHypothesisEditor
var _toast: HudToast
var _toast_tween: Tween
var _refresh_pending := false

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _board: BoardFrame = $Root/Board
@onready var _shield: Control = $Root/Shield


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_dim.color = BoardStyle.DIM
	_suspect_row = BoardSuspectRow.new()
	_suspect_row.suspect_pressed.connect(open_hypothesis)
	_canvas = BoardCanvas.new()
	_canvas.item_toggled.connect(select_item)
	_comparison = BoardComparisonPanel.new()
	_comparison.link_pressed.connect(link_selected)
	_comparison.remove_requested.connect(_on_remove_requested)
	_editor = BoardHypothesisEditor.new()
	_editor.save_requested.connect(func(_status: String, _note: String) -> void: save_hypothesis())
	_editor.close_requested.connect(close_hypothesis)
	_editor.discard_requested.connect(_on_discard_requested)
	_board.set_parts(_suspect_row, _canvas, _comparison, _editor)
	_board.header.close_pressed.connect(close)
	_root.resized.connect(_layout)
	# Si la investigación cambia con el tablero abierto, el tablero se pone al día solo.
	EventBus.clue_discovered.connect(_on_items_changed.unbind(1))
	EventBus.testimony_recorded.connect(_on_items_changed.unbind(1))
	EventBus.deduction_made.connect(_on_items_changed.unbind(1))
	EventBus.hypothesis_changed.connect(_on_hypothesis_changed)
	_shield.hide()
	_root.hide()
	_layout()


func open() -> void:
	is_open = true
	GameState.lock_player("tablero")
	_selection.clear()
	_board.header.refresh_keys()
	_root.show()
	close_hypothesis()
	_layout()
	_rebuild()


func close() -> void:
	close_hypothesis(false)
	is_open = false
	GameState.unlock_player("tablero")
	_root.hide()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if is_editing():
			close_hypothesis()
		else:
			close()
	elif _is_save_shortcut(event) and is_editing():
		get_viewport().set_input_as_handled()
		save_hypothesis()
	elif event.is_action_pressed("open_board") and not is_editing():
		# Con el panel de hipótesis abierto, la B se escribe en la nota.
		get_viewport().set_input_as_handled()
		close()


## Ctrl + Intro guarda la hipótesis sin soltar el teclado.
static func _is_save_shortcut(event: InputEvent) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.ctrl_pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)


func get_board() -> BoardFrame:
	return _board


func get_suspect_row() -> BoardSuspectRow:
	return _suspect_row


func get_investigation_canvas() -> BoardCanvas:
	return _canvas


func get_comparison() -> BoardComparisonPanel:
	return _comparison


func get_editor() -> BoardHypothesisEditor:
	return _editor


## El tablero ocupa la pantalla con un margen y sin pasar de un ancho máximo, centrado.
func _layout() -> void:
	var screen := _root.size
	var width := minf(screen.x - BoardStyle.FRAME_MARGIN.x * 2.0, BoardStyle.FRAME_MAX_WIDTH)
	var height := screen.y - BoardStyle.FRAME_MARGIN.y * 2.0
	_board.position = Vector2((screen.x - width) * 0.5, BoardStyle.FRAME_MARGIN.y)
	_board.size = Vector2(width, height)
	_board.pivot_offset = _board.size * 0.5
	_board.relayout()


# --- Selección y relaciones ---

## Elementos elegidos para comparar, del más antiguo al más reciente.
func get_selection() -> Array[String]:
	return _selection.duplicate()


## Elige o suelta un elemento. Sólo se comparan dos: un tercero sustituye al más antiguo.
func select_item(item_id: String, selected: bool = true) -> void:
	if selected:
		if not _selection.has(item_id) and Investigation.has_item(item_id):
			if _selection.size() >= 2:
				_selection.pop_front()
			_selection.append(item_id)
	else:
		_selection.erase(item_id)
	_canvas.set_selection(_selection)
	_refresh_slots()


func can_link() -> bool:
	return BoardInfo.can_link(_selection)


## Pide a la investigación si los dos elementos elegidos guardan relación y muestra el resultado. Una
## deducción nueva lleva su tiempo, se convierte en una ficha más y su hilo aparece en el corcho.
func link_selected() -> Dictionary:
	if not can_link():
		return {"result": Investigation.LinkResult.MISSING_ITEM, "deduction": ""}
	var outcome := Investigation.try_link(_selection[0], _selection[1])
	if outcome["result"] == Investigation.LinkResult.NEW:
		GameClock.advance(LINK_MINUTES)
		_selection.clear()
		_rebuild()
		_canvas.animate_relation(outcome["deduction"])
	_comparison.show_outcome(outcome)
	return outcome


## Algo nuevo en la investigación: las fichas se rehacen (una vez por fotograma) sólo si cambia lo que
## hay que prender en el corcho.
func _on_items_changed() -> void:
	if not is_open or _refresh_pending:
		return
	_refresh_pending = true
	_refresh_items.call_deferred()


func _refresh_items() -> void:
	_refresh_pending = false
	if not is_open:
		return
	var ids := PackedStringArray(BoardInfo.items().map(func(item: Dictionary) -> String: return item["id"]))
	if ids == _canvas.get_item_ids():
		return
	_selection.assign(_selection.filter(func(item_id: String) -> bool: return Investigation.has_item(item_id)))
	_canvas.refresh()
	_canvas.set_selection(_selection, false)
	_refresh_slots()


func _on_hypothesis_changed(_suspect_id: String) -> void:
	if is_open:
		_build_suspects()


func _on_remove_requested(index: int) -> void:
	if index >= 1 and index <= _selection.size():
		select_item(_selection[index - 1], false)


func _rebuild() -> void:
	_build_suspects()
	_canvas.refresh()
	_canvas.set_selection(_selection, false)
	_refresh_slots()


func _build_suspects() -> void:
	_suspect_row.refresh(_drafts.keys())


func _refresh_slots() -> void:
	var entries: Array[Dictionary] = []
	for item_id in _selection:
		entries.append(BoardInfo.describe(item_id))
	_comparison.show_selection(entries, can_link())


# --- Hipótesis ---

func is_editing() -> bool:
	return _editor.is_open


func get_editing_suspect() -> String:
	return _editor.suspect_id if is_editing() else ""


func has_draft(suspect_id: String) -> bool:
	return _drafts.has(suspect_id)


## Abre la hipótesis de un sospechoso con lo que el jugador anotó, o con su borrador si dejó uno a
## medias. Si ya estaba anotando otra, la deja como borrador.
func open_hypothesis(suspect_id: String) -> void:
	if is_editing():
		if _editor.suspect_id == suspect_id:
			return
		_keep_draft()
	var entry: Dictionary = {}
	for suspect in BoardInfo.suspects():
		if suspect["id"] == suspect_id:
			entry = suspect
	if entry.is_empty():
		return
	_editor.open_for(entry, Investigation.get_hypothesis(suspect_id), _drafts.get(suspect_id, {}))
	_suspect_row.set_selected(suspect_id)


## Cierra el panel de hipótesis sin cerrar el tablero. Lo que no se haya guardado queda como borrador.
func close_hypothesis(animate: bool = true) -> void:
	if not is_editing():
		return
	_keep_draft()
	_editor.close(animate)
	_suspect_row.set_selected("")
	_refresh_drafts()


## Anota la valoración y la nota del panel en la partida, pone al día la ficha del sospechoso y lo
## confirma con un destello y un aviso breve.
func save_hypothesis() -> void:
	if not is_editing():
		return
	var suspect_id := _editor.suspect_id
	var values := _editor.get_values()
	if not Investigation.set_hypothesis(suspect_id, values["status"], values["note"]):
		return
	_drafts.erase(suspect_id)
	_editor.close()
	_suspect_row.set_selected("")
	_build_suspects()
	var card := _suspect_row.get_card(suspect_id)
	if card != null:
		card.pulse()
	_show_toast("Hipótesis guardada", "%s · %s" % [GameData.get_character_name(suspect_id), BoardInfo.status_label(values["status"])])


func _keep_draft() -> void:
	if _editor.is_dirty():
		_drafts[_editor.suspect_id] = _editor.get_values()
	else:
		_drafts.erase(_editor.suspect_id)


func _on_discard_requested() -> void:
	_drafts.erase(_editor.suspect_id)
	_refresh_drafts()


func _refresh_drafts() -> void:
	for card in _suspect_row.get_cards():
		card.set_draft(_drafts.has(card.suspect_id))


## Aviso breve sobre el corcho, en el pergamino de los avisos del HUD.
func _show_toast(title: String, body: String) -> void:
	if _toast != null:
		_toast.queue_free()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast = HudToast.new(title, body, "historia")
	_toast.name = "Toast"
	_board.add_child(_toast)
	var canvas := _board.get_canvas_rect()
	_toast.reset_size()
	_toast.position = Vector2(canvas.get_center().x - _toast.size.x * 0.5, canvas.position.y + 26.0)
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(BoardStyle.TOAST_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(_toast.queue_free)


func get_toast() -> HudToast:
	return _toast if is_instance_valid(_toast) else null
