class_name CaseClosedUi
extends CanvasLayer
## Pantalla de cierre del caso, con el balance de la investigación.

const MAIN_MENU := "res://scenes/main/main_menu.tscn"

var is_open := false

@onready var _root: Control = $Root
@onready var _sheet: PanelContainer = $Root/Center/Sheet
@onready var _title: Label = $Root/Center/Sheet/Box/Title
@onready var _stamp: Label = $Root/Center/Sheet/Box/Stamp
@onready var _summary: RichTextLabel = $Root/Center/Sheet/Box/Summary
@onready var _teaser: Label = $Root/Center/Sheet/Box/Teaser
@onready var _menu: Button = $Root/Center/Sheet/Box/Menu


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_title.add_theme_font_override("font", UiTheme.serif())
	_title.add_theme_font_size_override("font_size", 36)
	_stamp.add_theme_font_override("font", UiTheme.serif())
	_stamp.add_theme_font_size_override("font_size", 64)
	_stamp.add_theme_color_override("font_color", UiTheme.STAMP)
	_teaser.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	_root.hide()
	_menu.pressed.connect(_on_menu_pressed)


func open() -> void:
	is_open = true
	GameState.lock_player("cierre")
	_summary.text = build_summary()
	_root.show()
	_root.modulate.a = 0.0
	_stamp.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.6)
	tween.tween_interval(0.3)
	tween.tween_property(_stamp, "modulate:a", 1.0, 0.25)
	_menu.grab_focus()


## Resumen del caso según lo que el jugador haya descubierto realmente.
func build_summary() -> String:
	var attempts := GameState.accusation_attempts
	var culprit: Dictionary = GameData.characters[GameData.story["accusation"]["culprit"]]
	var lines := PackedStringArray()
	lines.append("[b]Culpable:[/b] %s, %s." % [culprit["name"], (culprit["role"] as String).to_lower()])
	lines.append("[b]Inductor:[/b] desconocido. Firma como «el Relojero».")
	lines.append("")
	lines.append("Pistas halladas: %d de %d" % [GameState.clues.size(), GameData.clues.size()])
	lines.append("Testimonios registrados: %d de %d" % [GameState.testimonies.size(), GameData.testimonies.size()])
	lines.append("Deducciones establecidas: %d de %d" % [GameState.deductions.size(), GameData.deductions.size()])
	lines.append("Intentos de acusación: %d" % attempts)
	lines.append("Caso resuelto el día %d a las %s" % [GameClock.day, GameClock.format_time()])
	return "\n".join(lines)


func _on_menu_pressed() -> void:
	AudioManager.play("click")
	GameState.clear_player_locks()
	SaveSystem.delete_save()
	get_tree().change_scene_to_file(MAIN_MENU)
