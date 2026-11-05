class_name BoardUi
extends CanvasLayer
## Tablero de deducción. El jugador compara dos elementos del expediente y el sistema
## comprueba si existe una relación real; las relaciones halladas se unen con hilo rojo.

const CARD_SIZE := Vector2(230.0, 112.0)
const KIND_COLORS := {
	"pista": Color("e0d3b3"),
	"testimonio": Color("c9d3da"),
	"deduccion": Color("e2bcb0"),
}
const KIND_LABELS := {"pista": "PRUEBA", "testimonio": "DECLARACIÓN", "deduccion": "DEDUCCIÓN"}
const STATUS_ORDER: Array[String] = ["", "sospechoso", "principal", "descartado"]

var is_open := false
var _selection: Array[String] = []
var _cards: Dictionary = {}
var _hypothesis_suspect := ""

@onready var _root: Control = $Root
@onready var _suspects: HBoxContainer = $Root/Layout/Suspects
@onready var _scroll: ScrollContainer = $Root/Layout/Body/CardArea/CardScroll
@onready var _grid: GridContainer = $Root/Layout/Body/CardArea/CardScroll/Cards
@onready var _strings: Control = $Root/Layout/Body/CardArea/Strings
@onready var _slot_a: RichTextLabel = $Root/Layout/Body/Side/Box/SlotA
@onready var _slot_b: RichTextLabel = $Root/Layout/Body/Side/Box/SlotB
@onready var _link_button: Button = $Root/Layout/Body/Side/Box/Link
@onready var _result: RichTextLabel = $Root/Layout/Body/Side/Box/Result
@onready var _note_panel: PanelContainer = $Root/NotePanel
@onready var _note_title: Label = $Root/NotePanel/Box/Title
@onready var _note_status: OptionButton = $Root/NotePanel/Box/Status
@onready var _note_text: TextEdit = $Root/NotePanel/Box/Text
@onready var _note_save: Button = $Root/NotePanel/Box/Save


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_root.hide()
	_note_panel.hide()
	_link_button.pressed.connect(_on_link_pressed)
	_note_save.pressed.connect(_save_hypothesis)
	for status in STATUS_ORDER:
		_note_status.add_item(JournalUi.STATUS_LABELS[status])
	_strings.draw.connect(_draw_strings)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _strings.queue_redraw())


func open() -> void:
	is_open = true
	GameState.lock_player("tablero")
	_selection.clear()
	_result.text = "Selecciona dos elementos y comprueba si guardan relación."
	_root.show()
	_note_panel.hide()
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
		if _note_panel.visible:
			_note_panel.hide()
		else:
			close()
	elif event.is_action_pressed("open_board") and not _note_panel.visible:
		get_viewport().set_input_as_handled()
		close()


func _rebuild() -> void:
	_build_suspects()
	_build_cards()
	_refresh_slots()
	await get_tree().process_frame
	_strings.queue_redraw()


func _build_suspects() -> void:
	for child in _suspects.get_children():
		_suspects.remove_child(child)
		child.queue_free()
	for suspect_id in GameData.get_suspects():
		var card := Button.new()
		var hypothesis: Dictionary = GameState.hypotheses.get(suspect_id, {})
		var status: String = hypothesis.get("status", "")
		card.text = "%s\n%s" % [GameData.characters[suspect_id]["short"], JournalUi.STATUS_LABELS[status]]
		card.icon = load(GameData.characters[suspect_id]["portrait"])
		card.expand_icon = true
		card.custom_minimum_size = Vector2(290.0, 104.0)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 18)
		if status == "descartado":
			card.modulate = Color(0.72, 0.72, 0.72)
		elif status == "principal":
			card.add_theme_color_override("font_color", UiTheme.STAMP)
		card.pressed.connect(_open_hypothesis.bind(suspect_id))
		_suspects.add_child(card)


func _build_cards() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cards.clear()
	for item in Investigation.get_board_items():
		var card := Button.new()
		card.custom_minimum_size = CARD_SIZE
		card.toggle_mode = true
		card.text = "%s\n%s" % [KIND_LABELS[item["kind"]], item["title"]]
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.clip_text = true
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 16)
		_style_card(card, item["kind"])
		card.toggled.connect(_on_card_toggled.bind(item["id"]))
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


func _on_card_toggled(pressed: bool, item_id: String) -> void:
	if pressed:
		if _selection.size() >= 2:
			var oldest: String = _selection.pop_front()
			(_cards[oldest] as Button).set_pressed_no_signal(false)
		_selection.append(item_id)
	else:
		_selection.erase(item_id)
	_refresh_slots()


func _refresh_slots() -> void:
	_slot_a.text = _describe_slot(0)
	_slot_b.text = _describe_slot(1)
	_link_button.disabled = _selection.size() < 2


func _describe_slot(index: int) -> String:
	if index >= _selection.size():
		return "[i]Elemento %d: sin seleccionar[/i]" % (index + 1)
	var item := Investigation.get_item(_selection[index])
	return "[b]%s[/b]\n%s" % [item["title"], item["text"]]


func _on_link_pressed() -> void:
	var outcome := Investigation.try_link(_selection[0], _selection[1])
	match outcome["result"]:
		Investigation.LinkResult.NEW:
			var deduction: Dictionary = GameData.deductions[outcome["deduction"]]
			_result.text = "[b]%s[/b]\n%s" % [deduction["title"], deduction["text"]]
			GameClock.advance(15)
			_selection.clear()
			_rebuild()
		Investigation.LinkResult.ALREADY_KNOWN:
			var known: Dictionary = GameData.deductions[outcome["deduction"]]
			_result.text = "Ya estableciste esta relación: [b]%s[/b]." % known["title"]
		_:
			_result.text = "No encuentro ninguna relación concluyente entre estos dos elementos."


## Une con hilo rojo las tarjetas de cada deducción, de chincheta a chincheta. Las
## chinchetas van en el borde superior para que el hilo no tape el texto.
func _draw_strings() -> void:
	for deduction_id in GameState.deductions:
		var pair := _visible_pair(deduction_id)
		if pair.is_empty():
			continue
		var from_point := _pin_position(_cards[pair[0]])
		var to_point := _pin_position(_cards[pair[1]])
		_strings.draw_line(from_point, to_point, Color(0.62, 0.1, 0.09, 0.6), 2.0, true)
		_strings.draw_circle(from_point, 5.0, UiTheme.STAMP)
		_strings.draw_circle(to_point, 5.0, UiTheme.STAMP)


## Primera combinación de una deducción cuyas dos tarjetas están en el tablero.
func _visible_pair(deduction_id: String) -> Array:
	for pair: Array in GameData.deductions[deduction_id]["pairs"]:
		if _cards.has(pair[0]) and _cards.has(pair[1]):
			return pair
	return []


func _pin_position(card: Button) -> Vector2:
	var rect := card.get_global_rect()
	return rect.position + Vector2(rect.size.x * 0.5, 7.0) - _strings.get_global_rect().position


func _open_hypothesis(suspect_id: String) -> void:
	_hypothesis_suspect = suspect_id
	var hypothesis: Dictionary = GameState.hypotheses.get(suspect_id, {})
	_note_title.text = "Hipótesis sobre %s" % GameData.get_character_name(suspect_id)
	_note_status.select(STATUS_ORDER.find(hypothesis.get("status", "")))
	_note_text.text = hypothesis.get("note", "")
	_note_panel.show()


func _save_hypothesis() -> void:
	GameState.hypotheses[_hypothesis_suspect] = {
		"status": STATUS_ORDER[_note_status.selected],
		"note": _note_text.text,
	}
	_note_panel.hide()
	_build_suspects()
