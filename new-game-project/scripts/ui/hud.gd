class_name Hud
extends CanvasLayer
## Interfaz de exploración: fecha y hora, objetivo actual, avisos y notificaciones.

const NOTIFICATION_SECONDS := 3.6

@onready var _root: Control = $Root
@onready var _prompt_panel: PanelContainer = $Root/PromptPanel
@onready var _prompt_label: Label = $Root/PromptPanel/PromptLabel
@onready var _toast_stack: VBoxContainer = $Root/ToastStack
@onready var _date_label: Label = $Root/DatePanel/Box/Date
@onready var _place_label: Label = $Root/DatePanel/Box/Place
@onready var _objective_panel: PanelContainer = $Root/ObjectivePanel
@onready var _objective_label: Label = $Root/ObjectivePanel/Box/Objective
@onready var _objective_title: Label = $Root/ObjectivePanel/Box/Title
@onready var _keys_label: Label = $Root/Keys


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_prompt_panel.hide()
	_date_label.add_theme_font_size_override("font_size", 20)
	_place_label.add_theme_font_override("font", UiTheme.serif())
	_place_label.add_theme_font_size_override("font_size", 26)
	_place_label.add_theme_color_override("font_color", UiTheme.STAMP)
	_objective_title.add_theme_color_override("font_color", UiTheme.STAMP)
	_objective_title.add_theme_font_size_override("font_size", 17)
	_objective_label.add_theme_font_size_override("font_size", 19)
	_keys_label.add_theme_color_override("font_color", Color(0.85, 0.83, 0.76, 0.85))
	_keys_label.add_theme_font_size_override("font_size", 18)
	EventBus.interaction_focus_changed.connect(_on_focus_changed)
	EventBus.notification_requested.connect(_on_notification)
	EventBus.time_changed.connect(_on_time_changed)
	EventBus.location_changed.connect(_on_location_changed)
	EventBus.objectives_changed.connect(_refresh_objective)
	_on_time_changed(GameClock.day, GameClock.minutes)
	_refresh_objective()


func _on_focus_changed(prompt: String) -> void:
	_prompt_panel.visible = not prompt.is_empty()
	_prompt_label.text = "[E]  %s" % prompt


func _on_time_changed(_day: int, _minutes: int) -> void:
	_date_label.text = "%s  ·  %s" % [StoryDirector.get_day_title(), GameClock.format_time()]
	_refresh_objective()


func _on_location_changed(location_id: String) -> void:
	_place_label.text = GameData.locations.get(location_id, {}).get("name", "")


func _refresh_objective() -> void:
	var objectives := StoryDirector.get_objectives()
	var next: Dictionary = {}
	for objective in objectives:
		if not bool(objective["done"]):
			next = objective
			break
	_objective_panel.visible = not next.is_empty()
	if not next.is_empty():
		_objective_label.text = next["text"]


func _on_notification(title: String, body: String, kind: String) -> void:
	var toast := PanelContainer.new()
	var box := VBoxContainer.new()
	toast.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_override("font", UiTheme.serif())
	heading.add_theme_color_override("font_color", UiTheme.STAMP if kind == "pista" else UiTheme.INK)
	box.add_child(heading)
	if not body.is_empty():
		var text := Label.new()
		text.text = body
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 380.0
		text.add_theme_font_size_override("font_size", 18)
		box.add_child(text)
	_toast_stack.add_child(toast)
	toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.25)
	tween.tween_interval(NOTIFICATION_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	tween.tween_callback(toast.queue_free)
