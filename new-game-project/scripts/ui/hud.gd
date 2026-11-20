class_name Hud
extends CanvasLayer
## Interfaz de exploración: el lugar con la fecha y la hora, el objetivo actual, las teclas, el
## aviso de interacción y las notificaciones.
##
## El HUD sólo presenta: lo que muestra lo lee `HudInfo` de los sistemas del juego, y se pone al
## día con las señales de `EventBus`. Lo que sólo tiene sentido explorando cuelga de
## `Exploration`; las notificaciones van aparte, en `Toasts`.

const NOTIFICATION_SECONDS := 3.6

@onready var _root: Control = $Root
@onready var _place_label: Label = $Root/Exploration/LocationPanel/Box/Place
@onready var _date_label: Label = $Root/Exploration/LocationPanel/Box/Date
@onready var _objective_panel: PanelContainer = $Root/Exploration/ObjectivePanel
@onready var _objective_title: Label = $Root/Exploration/ObjectivePanel/Box/Title
@onready var _objective_label: Label = $Root/Exploration/ObjectivePanel/Box/Objective
@onready var _controls_bar: Label = $Root/Exploration/ControlsBar
@onready var _prompt: PanelContainer = $Root/Exploration/Prompt
@onready var _prompt_label: Label = $Root/Exploration/Prompt/PromptLabel
@onready var _toasts: VBoxContainer = $Root/Toasts


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_style_labels()
	_prompt.hide()
	_refresh_controls()
	EventBus.interaction_focus_changed.connect(_on_focus_changed)
	EventBus.notification_requested.connect(_on_notification)
	EventBus.time_changed.connect(_on_time_changed)
	EventBus.location_changed.connect(_on_location_changed)
	EventBus.objectives_changed.connect(_refresh_objective)
	_on_time_changed(GameClock.day, GameClock.minutes)


## Vuelve a leer las teclas del InputMap, por si cambió alguna asignación.
func refresh_controls() -> void:
	_refresh_controls()


func _style_labels() -> void:
	_date_label.add_theme_font_size_override("font_size", 20)
	_place_label.add_theme_font_override("font", UiTheme.serif())
	_place_label.add_theme_font_size_override("font_size", 26)
	_place_label.add_theme_color_override("font_color", UiTheme.STAMP)
	_objective_title.add_theme_color_override("font_color", UiTheme.STAMP)
	_objective_title.add_theme_font_size_override("font_size", 17)
	_objective_label.add_theme_font_size_override("font_size", 19)
	_controls_bar.add_theme_color_override("font_color", Color(0.85, 0.83, 0.76, 0.85))
	_controls_bar.add_theme_font_size_override("font_size", 18)


# --- Lugar, fecha y objetivo ---

func _on_location_changed(location_id: String) -> void:
	_place_label.text = HudInfo.location_name(location_id)


func _on_time_changed(_day: int, _minutes: int) -> void:
	_date_label.text = HudInfo.date_text()
	_refresh_objective()


func _refresh_objective() -> void:
	var objective := HudInfo.current_objective()
	_objective_panel.visible = not objective.is_empty()
	if not objective.is_empty():
		_objective_label.text = objective


# --- Teclas y aviso de interacción ---

func _refresh_controls() -> void:
	var parts := PackedStringArray()
	for hint: Dictionary in HudInfo.CONTROL_HINTS:
		var keys := HudInfo.hint_keys(hint)
		if not keys.is_empty():
			parts.append("[%s] %s" % ["".join(keys), hint["label"]])
	_controls_bar.text = "   ".join(parts)


func _on_focus_changed(prompt: String) -> void:
	_prompt.visible = not prompt.is_empty()
	_prompt_label.text = "[%s]  %s" % [HudInfo.action_key("interact"), prompt]


# --- Notificaciones ---

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
	_toasts.add_child(toast)
	toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.25)
	tween.tween_interval(NOTIFICATION_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	tween.tween_callback(toast.queue_free)
