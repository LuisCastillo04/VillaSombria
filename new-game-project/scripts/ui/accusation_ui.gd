class_name AccusationUi
extends CanvasLayer
## Acusación final. El jugador elige culpable y presenta motivo, oportunidad y medios.
## Un error no termina la partida: Ortega explica por qué no se sostiene y se puede
## seguir investigando.

var is_open := false
var _items: Array[Dictionary] = []
var _suspect_ids: Array[String] = []

@onready var _root: Control = $Root
@onready var _suspect: OptionButton = $Root/Sheet/Box/Suspect
@onready var _motive: OptionButton = $Root/Sheet/Box/Motive
@onready var _opportunity: OptionButton = $Root/Sheet/Box/Opportunity
@onready var _means: OptionButton = $Root/Sheet/Box/Means
@onready var _verdict: RichTextLabel = $Root/Sheet/Box/Verdict
@onready var _accuse: Button = $Root/Sheet/Box/Buttons/Accuse
@onready var _cancel: Button = $Root/Sheet/Box/Buttons/Cancel
@onready var _title: Label = $Root/Sheet/Box/Title


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_title.add_theme_font_override("font", UiTheme.serif())
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", UiTheme.STAMP)
	_root.hide()
	_accuse.pressed.connect(_on_accuse_pressed)
	_cancel.pressed.connect(close)


func open() -> void:
	is_open = true
	GameState.lock_player("acusacion")
	_suspect.clear()
	_suspect_ids = GameData.get_suspects()
	for suspect_id in _suspect_ids:
		_suspect.add_item(GameData.get_character_name(suspect_id))
	_items = Investigation.get_board_items()
	for selector: OptionButton in [_motive, _opportunity, _means]:
		selector.clear()
		for item in _items:
			selector.add_item(item["title"])
	_verdict.text = "Ortega te escucha en silencio. Presenta tus pruebas."
	_root.show()


func close() -> void:
	is_open = false
	GameState.unlock_player("acusacion")
	_root.hide()


func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _on_accuse_pressed() -> void:
	GameState.accusation_attempts += 1
	var verdict := Investigation.evaluate_accusation(
		_suspect_ids[_suspect.selected],
		_items[_motive.selected]["id"],
		_items[_opportunity.selected]["id"],
		_items[_means.selected]["id"]
	)
	if verdict["ok"]:
		close()
		DialogueManager.play_scene("confrontacion")
	else:
		_verdict.text = "[b]Ortega:[/b] %s" % verdict["reason"]
