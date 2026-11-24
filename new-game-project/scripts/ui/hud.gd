class_name Hud
extends CanvasLayer
## Interfaz de exploración: el lugar con la fecha y la hora, el objetivo actual, la barra de teclas,
## el aviso de interacción, las notificaciones y el marco fino de la pantalla.
##
## El HUD sólo presenta: lo que muestra lo lee `HudInfo` de los sistemas del juego y se pone al día
## con las señales de `EventBus`. Las piezas se colocan en `_layout` a partir del tamaño real de la
## pantalla, sin posiciones fijas.
##
## Lo que sólo tiene sentido explorando cuelga de `Exploration` y se desvanece mientras el control
## del jugador está bloqueado: conversación, inspección, transición, expediente, tablero, acusación,
## pausa y las pantallas que se abren sobre ella (el mapa, la configuración...), que así nunca
## quedan con paneles asomando por detrás. Las notificaciones y el marco quedan fuera de ese grupo:
## una pista hallada en una conversación se sigue anunciando. Las notificaciones tienen su propia
## capa (`Notices`): durante una conversación sube por encima de ella y las centra arriba, entre las
## dos siluetas, para que se lean sin tapar a nadie. Todas las animaciones son `Tween`
## que no dejan trabajo pendiente fotograma a fotograma, y se detienen con la pausa salvo el propio
## fundido del HUD, que tiene que poder terminar cuando la pausa empieza.

const NOTIFICATION_SECONDS := 3.6
const TOAST_FADE_IN := 0.25
const TOAST_FADE_OUT := 0.4
## Espera antes de la primera aparición: el fundido de entrada termina antes, y si entonces empieza
## una escena (la introducción, o la de un lugar al cargar), el HUD ni siquiera asoma.
const FIRST_REVEAL_DELAY := 0.55

var _layout_queued := false
var _visibility_queued := false
## La primera aparición ya ocurrió (o está en marcha): desde entonces se siguen los bloqueos.
var _started := false
## Si el grupo de exploración debe verse; `_reveal` es su progreso animado, de 0 a 1.
var _shown := false
var _reveal := 0.0
var _reveal_tween: Tween
## Llegó un objetivo nuevo con el HUD oculto: la cinta destellará al volver.
var _flash_pending := false
## Posiciones de reposo calculadas en `_layout`; el deslizamiento se suma encima.
var _rest_positions: Dictionary = {}

@onready var _root: Control = $Root
@onready var _exploration: Control = $Root/Exploration
@onready var _location: HudLocationPanel = $Root/Exploration/LocationPanel
@onready var _objective: HudObjectivePanel = $Root/Exploration/ObjectivePanel
@onready var _controls: HudControlsBar = $Root/Exploration/ControlsBar
@onready var _prompt: HudPrompt = $Root/Exploration/Prompt
@onready var _notices: CanvasLayer = $Notices
@onready var _toasts: VBoxContainer = $Notices/Toasts


func _ready() -> void:
	# El aviso de guardado sube para no tapar la barra de teclas.
	SaveIndicator.set_bottom_margin(HudStyle.BOTTOM_MARGIN + HudStyle.BAR_HEIGHT + HudStyle.PANEL_GAP)
	EventBus.interaction_focus_changed.connect(_on_focus_changed)
	EventBus.interaction_status_changed.connect(_prompt.set_status)
	EventBus.notification_requested.connect(_on_notification)
	EventBus.time_changed.connect(_on_time_changed)
	EventBus.location_changed.connect(_on_location_changed)
	EventBus.objectives_changed.connect(_refresh_objective.bind(true))
	EventBus.player_locks_changed.connect(_queue_visibility)
	# Al pasar del teclado al mando (o al revés), las teclas y el aviso cambian de rótulo.
	Controls.input_device_changed.connect(_on_input_device_changed.unbind(1))
	DialogueManager.opened.connect(_on_conversation_changed.unbind(1))
	DialogueManager.closed.connect(_on_conversation_changed.unbind(1))
	_root.resized.connect(_queue_layout)
	for panel: Control in [_location, _objective, _controls, _prompt]:
		panel.minimum_size_changed.connect(_queue_layout)
	_refresh_location(GameState.location_id, false)
	_refresh_date(false)
	_refresh_objective(false)
	_controls.set_wait_available(HudInfo.can_wait())
	_exploration.modulate.a = 0.0
	_exploration.hide()
	_layout()
	var first := create_tween()
	first.tween_interval(FIRST_REVEAL_DELAY)
	first.tween_callback(_start)


func _exit_tree() -> void:
	SaveIndicator.set_bottom_margin(SaveIndicator.DEFAULT_MARGIN)


## Vuelve a leer las teclas del InputMap, por si cambió alguna asignación.
func refresh_controls() -> void:
	if _controls.refresh():
		_queue_layout()


## Si el lugar, el objetivo y las teclas deben estar a la vista (aunque aún se estén fundiendo).
func is_exploration_shown() -> bool:
	return _shown


## Si el HUD de exploración debe verse ahora: sólo mientras el jugador tiene el control.
static func should_show_exploration() -> bool:
	return not GameState.is_player_locked()


func get_location_panel() -> HudLocationPanel:
	return _location


func get_objective_panel() -> HudObjectivePanel:
	return _objective


func get_controls_bar() -> HudControlsBar:
	return _controls


func get_prompt() -> HudPrompt:
	return _prompt


## Capa en la que se dibujan ahora las notificaciones.
func get_notices_layer() -> int:
	return _notices.layer


func get_toasts_container() -> Control:
	return _toasts


func get_toasts() -> Array[HudToast]:
	var toasts: Array[HudToast] = []
	for toast in _toasts.get_children():
		if not toast.is_queued_for_deletion():
			toasts.append(toast as HudToast)
	return toasts


# --- Aparición y desaparición ---

func _start() -> void:
	_started = true
	_update_visibility()


## Agrupa los cambios de bloqueo de un mismo fotograma: al terminar una transición se libera el
## control y, en el mismo instante, puede empezar la escena del lugar; el HUD no debe parpadear.
func _queue_visibility() -> void:
	if _visibility_queued:
		return
	_visibility_queued = true
	_update_visibility.call_deferred()


func _update_visibility() -> void:
	_visibility_queued = false
	if _started:
		_set_shown(should_show_exploration())


func _set_shown(shown: bool) -> void:
	if shown == _shown:
		return
	_shown = shown
	if _reveal_tween != null:
		_reveal_tween.kill()
	if shown:
		# Las teclas pudieron cambiar en la configuración mientras el HUD no se veía, y oculto
		# ningún panel avisa de que su contenido cambió de tamaño: se recoloca todo antes de volver.
		_controls.refresh()
		_exploration.show()
		_layout()
	# Avanza aunque el árbol esté en pausa: el HUD se retira mientras aparece el menú de pausa.
	_reveal_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_reveal_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if shown else Tween.EASE_IN)
	_reveal_tween.tween_method(_apply_reveal, _reveal, 1.0 if shown else 0.0, HudStyle.FADE_IN if shown else HudStyle.FADE_OUT)
	_reveal_tween.tween_callback(_after_reveal if shown else _exploration.hide)


func _apply_reveal(value: float) -> void:
	_reveal = value
	_exploration.modulate.a = value
	_apply_slide()


func _after_reveal() -> void:
	if _flash_pending and _objective.visible:
		_objective.flash()
	_flash_pending = false


# --- Colocación ---

## Agrupa las peticiones de un mismo fotograma en una sola colocación.
func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	_layout.call_deferred()


## Zona que ocupa el HUD: toda la pantalla menos los márgenes, sin pasar del ancho de una pantalla
## 16:9. En una ultrapanorámica el HUD queda centrado y no obliga a mirar a las esquinas.
func _content_rect() -> Rect2:
	var view := _root.size
	var width := minf(view.x - HudStyle.SCREEN_MARGIN * 2.0, HudStyle.BAR_MAX_WIDTH)
	return Rect2((view.x - width) * 0.5, HudStyle.TOP_MARGIN, width, view.y - HudStyle.TOP_MARGIN - HudStyle.BOTTOM_MARGIN)


## Coloca las piezas: el lugar arriba a la izquierda, el objetivo arriba a la derecha con las
## notificaciones debajo, la barra de teclas al pie y el aviso de interacción sobre ella. El
## objetivo cede ancho antes de pisar el panel del lugar, y la barra se compacta o prescinde de
## teclas secundarias antes de salirse de la pantalla.
func _layout() -> void:
	_layout_queued = false
	var area := _content_rect()
	var location_size := _location.get_combined_minimum_size()
	_location.size = location_size
	_rest_positions[_location] = area.position
	var free_width := area.size.x - location_size.x - HudStyle.PANEL_GAP * 2.0
	_objective.set_panel_width(clampf(free_width, HudStyle.OBJECTIVE_MIN_WIDTH, HudStyle.OBJECTIVE_WIDTH))
	var objective_size := _objective.get_combined_minimum_size()
	_objective.size = objective_size
	_rest_positions[_objective] = Vector2(area.end.x - objective_size.x, area.position.y)
	if DialogueManager.active:
		# En una conversación, centradas arriba: las siluetas ocupan los lados.
		_toasts.position = Vector2(area.get_center().x - HudStyle.TOAST_WIDTH * 0.5, area.position.y)
	else:
		var toasts_top := area.position.y
		if _objective.visible:
			toasts_top += objective_size.y + HudStyle.PANEL_GAP
		_toasts.position = Vector2(area.end.x - HudStyle.TOAST_WIDTH, toasts_top)
	_toasts.size = Vector2(HudStyle.TOAST_WIDTH, 0.0)
	_controls.fit_width(area.size.x)
	_controls.size = Vector2(area.size.x, _controls.get_combined_minimum_size().y)
	_rest_positions[_controls] = Vector2(area.position.x, area.end.y - _controls.size.y)
	var prompt_size := _prompt.get_combined_minimum_size()
	_prompt.size = prompt_size
	var prompt_x := area.get_center().x - prompt_size.x * 0.5
	_rest_positions[_prompt] = Vector2(prompt_x, area.end.y - _controls.size.y - HudStyle.PANEL_GAP - prompt_size.y)
	_apply_slide()


## Al aparecer, los paneles de arriba bajan y la barra sube unos píxeles hasta su sitio.
func _apply_slide() -> void:
	var slide := (1.0 - _reveal) * HudStyle.SLIDE * UiAccessibility.motion()
	for control: Control in _rest_positions:
		var direction := 1.0 if control == _controls or control == _prompt else -1.0
		control.position = _rest_positions[control] + Vector2(0.0, direction * slide)


## Durante una conversación, las notificaciones suben por encima de ella; al terminar, vuelven a la
## capa del HUD y a su sitio bajo el objetivo.
func _on_conversation_changed() -> void:
	_notices.layer = HudStyle.NOTICES_OVER_DIALOGUE_LAYER if DialogueManager.active else layer
	_queue_layout()


# --- Lugar, fecha y objetivo ---

func _on_location_changed(location_id: String) -> void:
	_refresh_location(location_id, true)


func _refresh_location(location_id: String, animate: bool) -> void:
	_location.set_location(HudInfo.location_name(location_id), HudInfo.location_icon(location_id), animate and _shown)
	_queue_layout()


func _on_time_changed(_day: int, _minutes: int) -> void:
	_refresh_date(true)
	_refresh_objective(true)
	_controls.set_wait_available(HudInfo.can_wait())


func _refresh_date(animate: bool) -> void:
	_location.set_date(HudInfo.date_text(), animate and _shown)


## Muestra el primer objetivo pendiente. Sin ninguno, el panel se oculta y las notificaciones suben.
## Si cambia con el HUD oculto (en una conversación, por ejemplo), la cinta destella al volver.
func _refresh_objective(animate: bool) -> void:
	var objective := HudInfo.current_objective()
	var had_objective := _objective.visible
	_objective.visible = not objective.is_empty()
	if objective.is_empty():
		if had_objective:
			_queue_layout()
		return
	var changed := _objective.set_objective(objective, animate and had_objective and _shown)
	if changed and animate and _started and not _shown:
		_flash_pending = true
	if changed or not had_objective:
		_queue_layout()


# --- Teclas y aviso de interacción ---

func _on_input_device_changed() -> void:
	refresh_controls()
	if _prompt.is_shown():
		_prompt.show_prompt(_prompt.get_text(), HudInfo.action_key("interact"))


## Con algo al alcance aparece el aviso y la tecla de interactuar de la barra se enciende.
func _on_focus_changed(prompt: String) -> void:
	_controls.set_interaction_available(not prompt.is_empty())
	if prompt.is_empty():
		_prompt.hide_prompt()
	else:
		_prompt.show_prompt(prompt, HudInfo.action_key("interact"))


# --- Notificaciones ---

## Cada aviso aparece bajo los anteriores y se desvanece solo. Si se acumulan demasiados, el más
## antiguo deja su sitio para que la columna nunca baje hasta la barra.
func _on_notification(title: String, body: String, kind: String) -> void:
	var toast := HudToast.new(title, body, kind)
	_toasts.add_child(toast)
	var live := get_toasts()
	while live.size() > HudStyle.TOAST_LIMIT:
		var oldest: HudToast = live.pop_front()
		_toasts.remove_child(oldest)
		oldest.queue_free()
	toast.modulate.a = 0.0
	# Ligado al aviso: si se retira antes de tiempo, su animación desaparece con él.
	var tween := toast.create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, TOAST_FADE_IN)
	tween.tween_interval(NOTIFICATION_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, TOAST_FADE_OUT)
	tween.tween_callback(toast.queue_free)
