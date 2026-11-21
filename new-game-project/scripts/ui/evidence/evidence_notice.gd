class_name EvidenceNotice
extends Control
## Aviso «Evidencia obtenida» que aparece sobre el marco cuando una prueba se registra por primera
## vez: una placa burdeos con la lupa y el rótulo en cursiva, con dos filetes dorados a los lados.
##
## Aparece con un fundido y un leve descenso, se queda `hold` segundos a la vista y se desvanece.
## Es una sola pieza que se reutiliza: volver a reproducirlo reinicia la animación en lugar de
## apilar otro aviso. Va encima del marco, en el hueco que la interfaz le reserva, así que nunca
## tapa el documento ni lo mueve; no recibe el ratón.

signal finished

const TEXT := "Evidencia obtenida"
const ICON := "lupa"
const CUT := 10.0
const PADDING := 30.0
const GAP := 14.0

## Largo de los filetes de cada lado; la interfaz lo acorta si no hay sitio.
var flourish_length := EvidenceStyle.NOTICE_FLOURISH:
	set(value):
		flourish_length = maxf(value, 0.0)
		_fit()

var _icon: TextureRect
var _label: Label
var _tween: Tween
var _rest := Vector2.ZERO
var _slide := 0.0
var _plate_width := 0.0
## Segundos a la vista de la última reproducción, para comprobarlo desde las pruebas.
var _last_hold := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = HudStyle.make_icon(EvidenceStyle.icon(ICON), EvidenceStyle.NOTICE_ICON, EvidenceStyle.GOLD_LIGHT)
	_icon.name = "Icon"
	add_child(_icon)
	_label = EvidenceStyle.make_label(TEXT, EvidenceStyle.notice_font(), EvidenceStyle.NOTICE_SIZE, EvidenceStyle.CREAM)
	_label.name = "Label"
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	visible = false
	modulate.a = 0.0
	_fit()


## Muestra el aviso: espera `delay`, entra, se queda `hold` segundos y sale. Si ya estaba a la
## vista, vuelve a empezar desde el principio.
func play(hold: float = EvidenceStyle.NOTICE_HOLD, delay: float = EvidenceStyle.NOTICE_DELAY) -> void:
	_kill_tween()
	_last_hold = hold
	visible = true
	modulate.a = 0.0
	_set_slide(-EvidenceStyle.NOTICE_SLIDE * UiAccessibility.motion())
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_property(self, "modulate:a", 1.0, EvidenceStyle.NOTICE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_method(_set_slide, _slide, 0.0, EvidenceStyle.NOTICE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(maxf(hold, 0.0))
	_tween.tween_property(self, "modulate:a", 0.0, EvidenceStyle.NOTICE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_on_finished)


## Detiene la animación donde esté, sin ocultarlo: así se desvanece junto con la interfaz.
func cancel() -> void:
	_kill_tween()


## Lo oculta del todo, sin animación.
func reset() -> void:
	_kill_tween()
	modulate.a = 0.0
	visible = false
	_set_slide(0.0)


## Si la animación sigue en marcha (esperando, entrando, a la vista o saliendo).
func is_playing() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Si se ve algo del aviso ahora mismo.
func is_showing() -> bool:
	return visible and modulate.a > 0.01


func get_text() -> String:
	return _label.text


func get_last_hold() -> float:
	return _last_hold


## Duración total de una reproducción con `hold` segundos a la vista.
static func total_seconds(hold: float, delay: float = EvidenceStyle.NOTICE_DELAY) -> float:
	return delay + EvidenceStyle.NOTICE_IN + hold + EvidenceStyle.NOTICE_OUT


## Rectángulo de la placa, sin los filetes, en las coordenadas del aviso.
func get_plate_rect() -> Rect2:
	return Rect2((size.x - _plate_width) * 0.5, 0.0, _plate_width, size.y)


## Coloca el aviso en reposo; durante la entrada se desliza desde un poco más arriba.
func place(rest_position: Vector2) -> void:
	_rest = rest_position
	position = _rest + Vector2(0.0, _slide)


func _set_slide(value: float) -> void:
	_slide = value
	position = _rest + Vector2(0.0, _slide)


func _on_finished() -> void:
	visible = false
	_set_slide(0.0)
	finished.emit()


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _fit() -> void:
	if _label == null:
		return
	var text_width := ceilf(EvidenceStyle.notice_font().get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, EvidenceStyle.NOTICE_SIZE).x)
	_plate_width = PADDING * 2.0 + EvidenceStyle.NOTICE_ICON + GAP + text_width
	var total := Vector2(_plate_width + (flourish_length + 18.0) * 2.0, EvidenceStyle.NOTICE_HEIGHT)
	custom_minimum_size = total
	size = total
	var plate := get_plate_rect()
	_icon.position = Vector2(plate.position.x + PADDING, (total.y - EvidenceStyle.NOTICE_ICON) * 0.5)
	_icon.size = Vector2(EvidenceStyle.NOTICE_ICON, EvidenceStyle.NOTICE_ICON)
	_label.position = Vector2(plate.position.x + PADDING + EvidenceStyle.NOTICE_ICON + GAP, 0.0)
	_label.size = Vector2(text_width, total.y)
	queue_redraw()


func _draw() -> void:
	var plate := get_plate_rect()
	var middle := plate.get_center().y
	if flourish_length > 8.0:
		var color := Color(EvidenceStyle.GOLD, 0.9)
		EvidenceOrnaments.draw_scroll_line(self, Vector2(plate.position.x - 6.0, middle), Vector2(plate.position.x - 6.0 - flourish_length, middle), color, true)
		EvidenceOrnaments.draw_scroll_line(self, Vector2(plate.end.x + 6.0, middle), Vector2(plate.end.x + 6.0 + flourish_length, middle), color, true)
		HudOrnaments.draw_diamond(self, Vector2(plate.position.x - 6.0, middle), 3.6, EvidenceStyle.GOLD_LIGHT)
		HudOrnaments.draw_diamond(self, Vector2(plate.end.x + 6.0, middle), 3.6, EvidenceStyle.GOLD_LIGHT)
	EvidenceOrnaments.draw_plate(self, plate, CUT, EvidenceStyle.BURGUNDY_LIGHT, EvidenceStyle.BURGUNDY_DARK, EvidenceStyle.GOLD, Color(EvidenceStyle.GOLD_LIGHT, 0.45))
