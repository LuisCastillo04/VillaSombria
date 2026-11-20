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
const HINT := "Selecciona dos elementos y comprueba si guardan relación."

var is_open := false
var _selection: Array[String] = []
var _hypothesis_suspect := ""
var _suspect_row: BoardSuspectRow
var _canvas: BoardCanvas

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _board: BoardFrame = $Root/Board
@onready var _shield: Control = $Root/Shield
@onready var _slot_a: RichTextLabel = $Root/Board/Side/Box/SlotA
@onready var _slot_b: RichTextLabel = $Root/Board/Side/Box/SlotB
@onready var _link_button: Button = $Root/Board/Side/Box/Link
@onready var _result: RichTextLabel = $Root/Board/Side/Box/Result
@onready var _note_panel: PanelContainer = $Root/Board/NotePanel
@onready var _note_title: Label = $Root/Board/NotePanel/Box/Title
@onready var _note_status: OptionButton = $Root/Board/NotePanel/Box/Status
@onready var _note_text: TextEdit = $Root/Board/NotePanel/Box/Text
@onready var _note_save: Button = $Root/Board/NotePanel/Box/Save


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_dim.color = BoardStyle.DIM
	_suspect_row = BoardSuspectRow.new()
	_suspect_row.suspect_pressed.connect(open_hypothesis)
	_canvas = BoardCanvas.new()
	_canvas.item_toggled.connect(select_item)
	_board.set_parts(_suspect_row, _canvas, $Root/Board/Side, _note_panel)
	_board.header.close_pressed.connect(close)
	_root.resized.connect(_layout)
	_shield.hide()
	_root.hide()
	_note_panel.hide()
	_layout()
	_link_button.pressed.connect(link_selected)
	_note_save.pressed.connect(save_hypothesis)
	for label in BoardInfo.status_labels():
		_note_status.add_item(label)


func open() -> void:
	is_open = true
	GameState.lock_player("tablero")
	_selection.clear()
	_result.text = HINT
	_board.header.refresh_keys()
	_root.show()
	close_hypothesis()
	_layout()
	_rebuild()


func close() -> void:
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
	elif event.is_action_pressed("open_board") and not is_editing():
		get_viewport().set_input_as_handled()
		close()


func get_board() -> BoardFrame:
	return _board


func get_suspect_row() -> BoardSuspectRow:
	return _suspect_row


func get_investigation_canvas() -> BoardCanvas:
	return _canvas


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


## Pide a la investigación si los dos elementos elegidos guardan relación y muestra el resultado.
func link_selected() -> Dictionary:
	if not can_link():
		return {"result": Investigation.LinkResult.MISSING_ITEM, "deduction": ""}
	var outcome := Investigation.try_link(_selection[0], _selection[1])
	match outcome["result"]:
		Investigation.LinkResult.NEW:
			var deduction: Dictionary = GameData.deductions[outcome["deduction"]]
			_result.text = "[b]%s[/b]\n%s" % [deduction["title"], deduction["text"]]
			GameClock.advance(LINK_MINUTES)
			_selection.clear()
			_rebuild()
		Investigation.LinkResult.ALREADY_KNOWN:
			var known: Dictionary = GameData.deductions[outcome["deduction"]]
			_result.text = "Ya estableciste esta relación: [b]%s[/b]." % known["title"]
		Investigation.LinkResult.MISSING_ITEM:
			_result.text = "Uno de los elementos ya no está en el expediente."
		_:
			_result.text = "No encuentro ninguna relación concluyente entre estos dos elementos."
	return outcome


func _rebuild() -> void:
	_build_suspects()
	_canvas.refresh()
	_canvas.set_selection(_selection, false)
	_refresh_slots()


func _build_suspects() -> void:
	_suspect_row.refresh()


func _refresh_slots() -> void:
	_slot_a.text = _describe_slot(0)
	_slot_b.text = _describe_slot(1)
	_link_button.disabled = not can_link()


func _describe_slot(index: int) -> String:
	if index >= _selection.size():
		return "[i]Elemento %d: sin seleccionar[/i]" % (index + 1)
	var item := BoardInfo.describe(_selection[index])
	return "[b]%s[/b]\n%s" % [item["title"], item["text"]]


# --- Hipótesis ---

func is_editing() -> bool:
	return _note_panel.visible


func get_editing_suspect() -> String:
	return _hypothesis_suspect if is_editing() else ""


## Abre la hipótesis de un sospechoso con lo que el jugador anotó.
func open_hypothesis(suspect_id: String) -> void:
	_hypothesis_suspect = suspect_id
	var hypothesis := Investigation.get_hypothesis(suspect_id)
	_note_title.text = "Hipótesis sobre %s" % GameData.get_character_name(suspect_id)
	_note_status.select(Investigation.HYPOTHESIS_STATUSES.find(hypothesis["status"]))
	_note_text.text = hypothesis["note"]
	_note_panel.show()
	_suspect_row.set_selected(suspect_id)


func close_hypothesis() -> void:
	_note_panel.hide()
	_suspect_row.set_selected("")


func save_hypothesis() -> void:
	var status := Investigation.HYPOTHESIS_STATUSES[_note_status.selected]
	if Investigation.set_hypothesis(_hypothesis_suspect, status, _note_text.text):
		close_hypothesis()
		_build_suspects()
		_suspect_row.get_card(_hypothesis_suspect).pulse()
