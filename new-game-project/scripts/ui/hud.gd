class_name Hud
extends CanvasLayer
## Interfaz de exploración: el lugar con la fecha y la hora, el objetivo actual, las teclas, el
## aviso de interacción y las notificaciones.
##
## El HUD sólo presenta: lo que muestra lo lee `HudInfo` de los sistemas del juego, y se pone al
## día con las señales de `EventBus`. Lo que sólo tiene sentido explorando cuelga de
## `Exploration`; las notificaciones van aparte, en `Toasts`. Las piezas se colocan en `_layout`
## a partir del tamaño real de la pantalla, sin posiciones fijas.

const NOTIFICATION_SECONDS := 3.6

var _layout_queued := false

@onready var _root: Control = $Root
@onready var _location: HudLocationPanel = $Root/Exploration/LocationPanel
@onready var _objective: HudObjectivePanel = $Root/Exploration/ObjectivePanel
@onready var _controls: HudControlsBar = $Root/Exploration/ControlsBar
@onready var _prompt: HudPrompt = $Root/Exploration/Prompt
@onready var _toasts: VBoxContainer = $Root/Toasts


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	# El aviso de guardado sube para no tapar la barra de teclas.
	SaveIndicator.set_bottom_margin(HudStyle.BOTTOM_MARGIN + HudStyle.BAR_HEIGHT + HudStyle.PANEL_GAP)
	EventBus.interaction_focus_changed.connect(_on_focus_changed)
	EventBus.notification_requested.connect(_on_notification)
	EventBus.time_changed.connect(_on_time_changed)
	EventBus.location_changed.connect(_on_location_changed)
	EventBus.objectives_changed.connect(_refresh_objective.bind(true))
	_root.resized.connect(_queue_layout)
	for panel: Control in [_location, _objective, _controls, _prompt]:
		panel.minimum_size_changed.connect(_queue_layout)
	_refresh_location(GameState.location_id, false)
	_refresh_date(false)
	_refresh_objective(false)
	_controls.set_wait_available(HudInfo.can_wait())
	_layout()


func _exit_tree() -> void:
	SaveIndicator.set_bottom_margin(SaveIndicator.DEFAULT_MARGIN)


## Vuelve a leer las teclas del InputMap, por si cambió alguna asignación.
func refresh_controls() -> void:
	if _controls.refresh():
		_queue_layout()


func get_location_panel() -> HudLocationPanel:
	return _location


func get_objective_panel() -> HudObjectivePanel:
	return _objective


func get_controls_bar() -> HudControlsBar:
	return _controls


func get_prompt() -> HudPrompt:
	return _prompt


# --- Colocación ---

## Agrupa las peticiones de un mismo fotograma en una sola colocación.
func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	_layout.call_deferred()


## Coloca las piezas según el tamaño de la pantalla: el lugar arriba a la izquierda, el objetivo
## arriba a la derecha con las notificaciones debajo, la barra de teclas centrada al pie y el aviso
## de interacción sobre ella. El objetivo cede ancho antes de pisar el panel del lugar, y la barra
## se compacta o prescinde de teclas secundarias antes de salirse de la pantalla.
func _layout() -> void:
	_layout_queued = false
	var view := _root.size
	var location_size := _location.get_combined_minimum_size()
	_location.position = Vector2(HudStyle.SCREEN_MARGIN, HudStyle.TOP_MARGIN)
	_location.size = location_size
	var free_width := view.x - HudStyle.SCREEN_MARGIN * 2.0 - location_size.x - HudStyle.PANEL_GAP * 2.0
	_objective.set_panel_width(clampf(free_width, HudStyle.OBJECTIVE_MIN_WIDTH, HudStyle.OBJECTIVE_WIDTH))
	var objective_size := _objective.get_combined_minimum_size()
	_objective.size = objective_size
	_objective.position = Vector2(view.x - HudStyle.SCREEN_MARGIN - objective_size.x, HudStyle.TOP_MARGIN)
	var toasts_top := HudStyle.TOP_MARGIN
	if _objective.visible:
		toasts_top = _objective.position.y + objective_size.y + HudStyle.PANEL_GAP
	_toasts.position = Vector2(view.x - HudStyle.SCREEN_MARGIN - HudStyle.TOAST_WIDTH, toasts_top)
	_toasts.size = Vector2(HudStyle.TOAST_WIDTH, 0.0)
	var bar_width := minf(view.x - HudStyle.SCREEN_MARGIN * 2.0, HudStyle.BAR_MAX_WIDTH)
	_controls.fit_width(bar_width)
	_controls.size = Vector2(bar_width, _controls.get_combined_minimum_size().y)
	_controls.position = Vector2((view.x - bar_width) * 0.5, view.y - HudStyle.BOTTOM_MARGIN - _controls.size.y)
	var prompt_size := _prompt.get_combined_minimum_size()
	_prompt.size = prompt_size
	_prompt.position = Vector2((view.x - prompt_size.x) * 0.5, _controls.position.y - HudStyle.PANEL_GAP - prompt_size.y)


# --- Lugar, fecha y objetivo ---

func _on_location_changed(location_id: String) -> void:
	_refresh_location(location_id, true)


func _refresh_location(location_id: String, animate: bool) -> void:
	_location.set_location(HudInfo.location_name(location_id), HudInfo.location_icon(location_id), animate)


func _on_time_changed(_day: int, _minutes: int) -> void:
	_refresh_date(true)
	_refresh_objective(true)
	_controls.set_wait_available(HudInfo.can_wait())


func _refresh_date(animate: bool) -> void:
	_location.set_date(HudInfo.date_text(), animate)


## Muestra el primer objetivo pendiente. Sin ninguno, el panel se oculta y las notificaciones suben.
func _refresh_objective(animate: bool) -> void:
	var objective := HudInfo.current_objective()
	var had_objective := _objective.visible
	_objective.visible = not objective.is_empty()
	if objective.is_empty():
		if had_objective:
			_queue_layout()
		return
	_objective.set_objective(objective, animate and had_objective)
	if not had_objective:
		_queue_layout()


# --- Teclas y aviso de interacción ---

## Con algo al alcance aparece el aviso y la tecla de interactuar de la barra se enciende.
func _on_focus_changed(prompt: String) -> void:
	_controls.set_interaction_available(not prompt.is_empty())
	if prompt.is_empty():
		_prompt.hide_prompt()
	else:
		_prompt.show_prompt(prompt, HudInfo.action_key("interact"))


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
