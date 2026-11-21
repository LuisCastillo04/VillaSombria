class_name ClueInspector
extends CanvasLayer
## Inspección de una evidencia encontrada en el escenario. Examinarla la registra si es nueva.
##
## Es el componente general de todas las evidencias: abre y cierra, bloquea al jugador mientras se
## lee, registra la prueba la primera vez, reacciona al teclado, al mando y al ratón y coloca las
## piezas en pantalla. Lo que se ve encima del papel
## lo dibuja la plantilla de la prueba (`scripts/ui/evidence/`), elegida por `EvidenceInfo` a partir
## de `data/clues.json`.
##
## No es un inventario: no hay flechas ni botones para pasar de una prueba a otra, sólo «Cerrar».
## Las pruebas registradas se siguen consultando en el expediente y en el tablero.

## Se emite al mostrar una prueba; `is_new` indica si se acaba de registrar.
signal opened(clue_id: String, is_new: bool)
signal closed(clue_id: String)

## Motivo del bloqueo del jugador mientras se examina una prueba.
const LOCK := "inspeccion"
## Acciones que cierran la evidencia. La primera con tecla asignada es la que muestra el botón.
const CLOSE_ACTIONS: Array[String] = ["interact", "ui_accept"]
## Acciones de volver atrás, que también cierran.
const CANCEL_ACTIONS: Array[String] = ["pause", "ui_cancel"]
const BACKDROP_SHADER := preload("res://assets/shaders/evidence_backdrop.gdshader")

var is_open := false
var _clue_id := ""
## La tecla con la que se examinó la prueba sigue pulsada: no cierra hasta soltarla y volver a
## pulsar, para que la misma pulsación (o su repetición) no cierre la hoja nada más abrirla.
var _close_armed := false
var _document: EvidenceDocument
var _transition: Tween
var _layout_queued := false
var _frame_rect := Rect2()

var _backdrop: ColorRect
var _frame: EvidenceFrame
var _holder: Control
var _header: EvidenceHeaderPlate
var _close: EvidenceCloseButton

@onready var _root: Control = $Root


func _ready() -> void:
	_build()
	_root.hide()
	_root.resized.connect(_queue_layout)
	EventBus.clue_inspection_requested.connect(open)
	Controls.input_device_changed.connect(_on_input_device_changed.unbind(1))
	set_process(false)


func _exit_tree() -> void:
	# Si la partida se cierra con la hoja abierta, el jugador no se queda bloqueado.
	if is_open:
		GameState.unlock_player(LOCK)


## Examina una prueba: la registra si es nueva (y deja pasar el tiempo de examinarla) y la muestra.
func open(clue_id: String) -> void:
	if not GameData.clues.has(clue_id):
		push_error("Evidencia desconocida: %s" % clue_id)
		return
	var is_new := Investigation.discover_clue(clue_id)
	if is_new:
		GameClock.advance(Investigation.CLUE_MINUTES)
	_present(clue_id)
	opened.emit(clue_id, is_new)


func close() -> void:
	if not is_open:
		return
	is_open = false
	set_process(false)
	GameState.unlock_player(LOCK)
	_animate_close()
	closed.emit(_clue_id)


## Prueba que se está mostrando (o la última que se mostró).
func get_current_clue() -> String:
	return _clue_id


func get_document() -> EvidenceDocument:
	return _document


func get_header() -> EvidenceHeaderPlate:
	return _header


func get_close_button() -> EvidenceCloseButton:
	return _close


func get_root() -> Control:
	return _root


## Rectángulo del marco en pantalla (coordenadas de la interfaz).
func get_frame_rect() -> Rect2:
	return _frame_rect


## Rectángulo que ocupa el papel en pantalla, ya escalado.
func get_document_rect() -> Rect2:
	if _document == null:
		return Rect2()
	return Rect2(_holder.position, _document.get_design_size() * _document.scale)


## Si una pulsación de cerrar ya puede cerrar (la tecla con la que se abrió se ha soltado).
func is_close_armed() -> bool:
	return _close_armed


# --- Construcción ---

func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = BACKDROP_SHADER
	backdrop_material.set_shader_parameter("tint", EvidenceStyle.DIM)
	_backdrop.material = backdrop_material
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = EvidenceFrame.new()
	_frame.name = "Frame"
	_root.add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_holder = Control.new()
	_holder.name = "Document"
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)
	_header = EvidenceHeaderPlate.new()
	_header.name = "Header"
	_root.add_child(_header)
	_close = EvidenceCloseButton.new()
	_close.pressed.connect(close)
	_root.add_child(_close)


## Pone en pantalla la hoja de una prueba, con su plantilla, su encabezado y la tecla de cerrar.
func _present(clue_id: String) -> void:
	var entry := EvidenceInfo.describe(clue_id)
	_clue_id = clue_id
	if _document != null:
		_holder.remove_child(_document)
		_document.queue_free()
	_document = EvidenceInfo.create_document(entry["template"])
	_document.name = "Sheet"
	_holder.add_child(_document)
	_document.setup(entry)
	_header.set_content(entry["header"], EvidenceStyle.icon(entry["icon"]))
	_close.refresh_keys()
	var was_open := is_open
	is_open = true
	_close_armed = not _is_close_held()
	set_process(not _close_armed)
	GameState.lock_player(LOCK)
	_root.show()
	_layout()
	if not was_open:
		_animate_open()


# --- Entrada ---

func _input(event: InputEvent) -> void:
	# Con la pregunta de salida o una confirmación en pantalla, las teclas son suyas.
	if not is_open or ExitManager.is_dialog_open() or ConfirmDialog.is_open():
		return
	for action in CANCEL_ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			close()
			return
	for action in CLOSE_ACTIONS:
		if event.is_action_pressed(action):
			# Se consume siempre: con la hoja abierta, nadie más debe reaccionar a esta tecla.
			get_viewport().set_input_as_handled()
			if _close_armed:
				close()
			return
	if not _close_armed and _is_close_release(event) and not _is_close_held():
		_arm_close()


func _process(_delta: float) -> void:
	# Por si la tecla se soltó sin que llegara su evento (otra ventana tenía el foco, por ejemplo).
	if is_open and not _close_armed and not _is_close_held():
		_arm_close()


func _arm_close() -> void:
	_close_armed = true
	set_process(false)


static func _is_close_held() -> bool:
	for action in CLOSE_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false


static func _is_close_release(event: InputEvent) -> bool:
	for action in CLOSE_ACTIONS:
		if event.is_action_released(action):
			return true
	return false


func _on_input_device_changed() -> void:
	if is_open:
		_close.refresh_keys()


# --- Colocación ---

func _queue_layout() -> void:
	if _layout_queued:
		return
	_layout_queued = true
	_layout.call_deferred()


## Coloca el documento tan grande como quepa entre el margen de arriba y el botón de abajo, sin
## pasar de `MAX_DOCUMENT_SCALE`, y el marco, la placa y el botón alrededor.
func _layout() -> void:
	_layout_queued = false
	if _document == null:
		return
	var view := _root.size
	var padding := EvidenceStyle.FRAME_PADDING
	var top := EvidenceStyle.NOTICE_TOP + EvidenceStyle.NOTICE_HEIGHT + EvidenceStyle.NOTICE_GAP
	var bottom := view.y - EvidenceStyle.BOTTOM_MARGIN - EvidenceStyle.CLOSE_SIZE.y * 0.5
	var room := Vector2(view.x - EvidenceStyle.SIDE_MARGIN * 2.0, bottom - top) - padding * 2.0
	var design := _document.get_design_size()
	var document_scale := minf(minf(room.x / design.x, room.y / design.y), EvidenceStyle.MAX_DOCUMENT_SCALE)
	document_scale = maxf(document_scale, 0.05)
	var document_size := design * document_scale
	var frame_size := document_size + padding * 2.0
	# Con sitio de sobra (pantallas altas), el marco queda centrado en el hueco disponible.
	var frame_position := Vector2((view.x - frame_size.x) * 0.5, top + maxf((bottom - top - frame_size.y) * 0.5, 0.0))
	_frame_rect = Rect2(frame_position.round(), frame_size.round())
	_document.scale = Vector2(document_scale, document_scale)
	_document.position = Vector2.ZERO
	_holder.position = (frame_position + padding).round()
	_holder.size = document_size
	_holder.pivot_offset = document_size * 0.5
	_header.position = (Vector2(_frame_rect.position.x + EvidenceStyle.HEADER_INSET, _frame_rect.position.y - _header.size.y * 0.5)).round()
	_close.size = EvidenceStyle.CLOSE_SIZE
	_close.position = (Vector2(_frame_rect.get_center().x - _close.size.x * 0.5, _frame_rect.end.y - _close.size.y * 0.5)).round()
	_frame.frame_rect = _frame_rect
	_frame.bottom_gap = Rect2(_close.position, _close.size)


# --- Animaciones ---

func _animate_open() -> void:
	if _transition != null:
		_transition.kill()
	var motion := UiAccessibility.motion()
	_root.modulate.a = 0.0
	_holder.scale = Vector2.ONE * lerpf(1.0, EvidenceStyle.OPEN_SCALE, motion)
	_transition = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition.tween_property(_root, "modulate:a", 1.0, EvidenceStyle.OPEN_SECONDS)
	_transition.tween_property(_holder, "scale", Vector2.ONE, EvidenceStyle.OPEN_SECONDS)


func _animate_close() -> void:
	if _transition != null:
		_transition.kill()
	_transition = create_tween()
	_transition.tween_property(_root, "modulate:a", 0.0, EvidenceStyle.CLOSE_SECONDS)
	_transition.tween_callback(_on_closed)


func _on_closed() -> void:
	_root.hide()
	_holder.scale = Vector2.ONE
