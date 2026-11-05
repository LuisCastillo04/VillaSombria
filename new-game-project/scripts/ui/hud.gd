class_name Hud
extends CanvasLayer
## Interfaz de exploración: aviso de interacción y notificaciones.

const NOTIFICATION_SECONDS := 3.6

@onready var _root: Control = $Root
@onready var _prompt_panel: PanelContainer = $Root/PromptPanel
@onready var _prompt_label: Label = $Root/PromptPanel/PromptLabel
@onready var _toast_stack: VBoxContainer = $Root/ToastStack


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_prompt_panel.hide()
	EventBus.interaction_focus_changed.connect(_on_focus_changed)
	EventBus.notification_requested.connect(_on_notification)


func _on_focus_changed(prompt: String) -> void:
	_prompt_panel.visible = not prompt.is_empty()
	_prompt_label.text = "[E]  %s" % prompt


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
