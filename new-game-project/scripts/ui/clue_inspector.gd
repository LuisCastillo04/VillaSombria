class_name ClueInspector
extends CanvasLayer
## Muestra una pista como una hoja del expediente. Examinarla la registra si es nueva.

const CATEGORY_LABELS := {
	"documentos": "DOCUMENTO",
	"fotografias": "FOTOGRAFÍA",
	"relojes": "RELOJ",
	"cartas": "CARTA",
	"objetos": "OBJETO PERSONAL",
	"huellas": "HUELLA",
}

var is_open := false

@onready var _root: Control = $Root
@onready var _sheet: PanelContainer = $Root/Sheet
@onready var _category: Label = $Root/Sheet/Margin/Box/Category
@onready var _title: Label = $Root/Sheet/Margin/Box/Title
@onready var _where: Label = $Root/Sheet/Margin/Box/Where
@onready var _body: RichTextLabel = $Root/Sheet/Margin/Box/Body
@onready var _stamp: Label = $Root/Sheet/Stamp
@onready var _hint: Label = $Root/Sheet/Margin/Box/Hint


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_title.add_theme_font_override("font", UiTheme.serif())
	_title.add_theme_font_size_override("font_size", 38)
	_category.add_theme_color_override("font_color", UiTheme.STAMP)
	_category.add_theme_font_size_override("font_size", 20)
	_where.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	_where.add_theme_font_size_override("font_size", 19)
	_hint.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	_hint.add_theme_font_size_override("font_size", 18)
	_stamp.add_theme_font_override("font", UiTheme.serif())
	_stamp.add_theme_font_size_override("font_size", 40)
	_stamp.add_theme_color_override("font_color", Color(UiTheme.STAMP, 0.75))
	_root.hide()
	EventBus.clue_inspection_requested.connect(open)


func open(clue_id: String) -> void:
	var clue: Dictionary = GameData.clues[clue_id]
	var is_new := Investigation.discover_clue(clue_id)
	if is_new:
		GameClock.advance(Investigation.CLUE_MINUTES)
	_category.text = CATEGORY_LABELS.get(clue["category"], "PRUEBA")
	_title.text = clue["name"]
	_where.text = "Hallada en: %s" % clue["where"]
	_body.text = clue["description"]
	_stamp.visible = is_new
	is_open = true
	GameState.lock_player("inspeccion")
	_root.show()
	_root.modulate.a = 0.0
	_sheet.scale = Vector2(0.96, 0.96)
	_sheet.pivot_offset = _sheet.size * 0.5
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_root, "modulate:a", 1.0, 0.2)
	tween.tween_property(_sheet, "scale", Vector2.ONE, 0.25)


func close() -> void:
	if not is_open:
		return
	is_open = false
	GameState.unlock_player("inspeccion")
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.15)
	tween.tween_callback(_root.hide)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
