class_name BoardUi
extends CanvasLayer
## Tablero de deducción. El jugador compara dos elementos del expediente y el sistema
## comprueba si existe una relación real; las relaciones halladas se unen con hilo rojo.
##
## Este nodo coordina: abre y cierra el tablero, lleva la selección de los dos elementos que se
## comparan y pide la relación a `Investigation.try_link`, y anota las hipótesis con
## `Investigation.set_hypothesis`. Los datos que muestra los lee `BoardInfo`.

const CARD_SIZE := Vector2(230.0, 112.0)
const KIND_COLORS := {
	"pista": Color("e0d3b3"),
	"testimonio": Color("c9d3da"),
	"deduccion": Color("e2bcb0"),
}
## Minutos que lleva establecer una relación nueva. El expediente los cita en sus reglas del tiempo.
const LINK_MINUTES := 15
const HINT := "Selecciona dos elementos y comprueba si guardan relación."

var is_open := false
var _selection: Array[String] = []
var _cards: Dictionary = {}
var _hypothesis_suspect := ""
var _suspect_row: BoardSuspectRow

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _board: BoardFrame = $Root/Board
@onready var _shield: Control = $Root/Shield
@onready var _scroll: ScrollContainer = $Root/Board/CardArea/CardScroll
@onready var _grid: GridContainer = $Root/Board/CardArea/CardScroll/Cards
@onready var _strings: Control = $Root/Board/CardArea/Strings
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
	_board.set_parts(_suspect_row, $Root/Board/CardArea, $Root/Board/Side, _note_panel)
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
	_strings.draw.connect(_draw_strings)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _strings.queue_redraw())


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
		if _selection.has(item_id) or not Investigation.has_item(item_id):
			return
		if _selection.size() >= 2:
			var oldest: String = _selection.pop_front()
			if _cards.has(oldest):
				(_cards[oldest] as Button).set_pressed_no_signal(false)
		_selection.append(item_id)
	else:
		_selection.erase(item_id)
	if _cards.has(item_id):
		(_cards[item_id] as Button).set_pressed_no_signal(selected)
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
	_build_cards()
	_refresh_slots()
	await get_tree().process_frame
	_strings.queue_redraw()


func _build_suspects() -> void:
	_suspect_row.refresh()


func _build_cards() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cards.clear()
	for item in BoardInfo.items():
		var card := Button.new()
		card.custom_minimum_size = CARD_SIZE
		card.toggle_mode = true
		card.text = "%s\n%s" % [item["kind_label"], item["title"]]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.clip_text = true
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 16)
		_style_card(card, item["kind"])
		card.toggled.connect(func(pressed: bool) -> void: select_item(item["id"], pressed))
		_grid.add_child(card)
		_cards[item["id"]] = card


func _style_card(card: Button, kind: String) -> void:
	var color: Color = KIND_COLORS[kind]
	card.add_theme_stylebox_override("normal", UiTheme.paper_box(color, color.darkened(0.25), 8))
	card.add_theme_stylebox_override("hover", UiTheme.paper_box(color.lightened(0.15), UiTheme.AMBER, 8))
	card.add_theme_stylebox_override("pressed", UiTheme.paper_box(color.lightened(0.1), UiTheme.STAMP, 8))
	card.add_theme_stylebox_override("hover_pressed", UiTheme.paper_box(color.lightened(0.1), UiTheme.STAMP, 8))
	card.add_theme_color_override("font_pressed_color", UiTheme.STAMP)
	card.add_theme_color_override("font_hover_pressed_color", UiTheme.STAMP)


func _refresh_slots() -> void:
	_slot_a.text = _describe_slot(0)
	_slot_b.text = _describe_slot(1)
	_link_button.disabled = not can_link()


func _describe_slot(index: int) -> String:
	if index >= _selection.size():
		return "[i]Elemento %d: sin seleccionar[/i]" % (index + 1)
	var item := BoardInfo.describe(_selection[index])
	return "[b]%s[/b]\n%s" % [item["title"], item["text"]]


## Une con hilo rojo las tarjetas de cada deducción, de chincheta a chincheta. Las
## chinchetas van en el borde superior para que el hilo no tape el texto.
func _draw_strings() -> void:
	for relation in BoardInfo.relations(_cards.keys()):
		var from_point := _pin_position(_cards[relation["from"]])
		var to_point := _pin_position(_cards[relation["to"]])
		_strings.draw_line(from_point, to_point, Color(0.62, 0.1, 0.09, 0.6), 2.0, true)
		_strings.draw_circle(from_point, 5.0, UiTheme.STAMP)
		_strings.draw_circle(to_point, 5.0, UiTheme.STAMP)


func _pin_position(card: Button) -> Vector2:
	var rect := card.get_global_rect()
	return rect.position + Vector2(rect.size.x * 0.5, 7.0) - _strings.get_global_rect().position


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
