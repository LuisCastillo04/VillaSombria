extends CanvasLayer
## Indicador de guardado. Es un autoload, así que hay una sola instancia y sigue visible al
## cambiar de escena. Un reloj de bolsillo gira mientras se escribe la partida; sólo se
## confirma cuando `SaveSystem` informa de que la escritura terminó bien, y un fallo se
## muestra como tal.

enum State { HIDDEN, SAVING, SAVED, FAILED }

const FAILED_COLOR := Color("d0574f")
const HAND_TURNS_PER_SECOND := 0.75

## Tiempo mínimo del aviso «Guardando…», para que no sea un parpadeo.
var min_saving_seconds := 0.6
var saved_seconds := 1.6
var failed_seconds := 4.0
var fade_seconds := 0.6
var state := State.HIDDEN

var _hand_angle := 0.0
var _pulse := 0.0
var _saving_since := 0
## Cambia con cada guardado para descartar resultados que llegan tarde.
var _token := 0
var _tween: Tween

@onready var _badge: PanelContainer = $Root/Badge
@onready var _icon: Control = $Root/Badge/Row/Icon
@onready var _title: Label = $Root/Badge/Row/Text/Title
@onready var _detail: Label = $Root/Badge/Row/Text/Detail


func _ready() -> void:
	_badge.add_theme_stylebox_override("panel", _badge_style())
	_title.add_theme_font_override("font", UiTheme.serif())
	_title.add_theme_font_size_override("font_size", 21)
	_title.add_theme_color_override("font_color", UiTheme.PAPER_LIGHT)
	_detail.add_theme_font_override("font", UiTheme.typewriter())
	_detail.add_theme_font_size_override("font_size", 16)
	_detail.add_theme_color_override("font_color", Color(UiTheme.PAPER, 0.75))
	_icon.draw.connect(_draw_icon)
	_badge.modulate.a = 0.0
	_badge.hide()
	set_process(false)
	SaveSystem.save_started.connect(_on_save_started)
	SaveSystem.save_finished.connect(_on_save_finished)


func _process(delta: float) -> void:
	_hand_angle = fmod(_hand_angle + TAU * HAND_TURNS_PER_SECOND * delta, TAU)
	_pulse += delta
	_icon.queue_redraw()


func is_showing() -> bool:
	return _badge.visible


func get_title() -> String:
	return _title.text


func _on_save_started(slot_id: String) -> void:
	_token += 1
	state = State.SAVING
	_saving_since = Time.get_ticks_msec()
	_title.text = "Guardando…"
	_detail.text = _describe(slot_id)
	_badge.show()
	set_process(true)
	_restart_tween()
	_tween.tween_property(_badge, "modulate:a", 1.0, 0.25)


func _on_save_finished(slot_id: String, ok: bool, message: String) -> void:
	if state != State.SAVING:
		return
	var token := _token
	var elapsed := (Time.get_ticks_msec() - _saving_since) / 1000.0
	if elapsed < min_saving_seconds:
		await get_tree().create_timer(min_saving_seconds - elapsed).timeout
		if token != _token:
			return
	if ok:
		_show_result(State.SAVED, "Partida guardada", _detail.text, saved_seconds)
	else:
		_show_result(State.FAILED, "No se pudo guardar", message, failed_seconds)


func _show_result(new_state: State, title: String, detail: String, hold_seconds: float) -> void:
	state = new_state
	_title.text = title
	_title.add_theme_color_override("font_color", FAILED_COLOR if new_state == State.FAILED else UiTheme.PAPER_LIGHT)
	_detail.text = detail
	set_process(false)
	_icon.queue_redraw()
	_restart_tween()
	_tween.tween_property(_badge, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(hold_seconds)
	_tween.tween_property(_badge, "modulate:a", 0.0, fade_seconds)
	_tween.tween_callback(_hide_badge)


func _hide_badge() -> void:
	state = State.HIDDEN
	_badge.hide()
	_title.add_theme_color_override("font_color", UiTheme.PAPER_LIGHT)


func _restart_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()


func _describe(slot_id: String) -> String:
	var slot_text := "Ranura %d" % SaveSystem.get_slot_number(slot_id)
	if SaveSystem.get_writing_kind() == "auto":
		return "Autoguardado · " + slot_text.to_lower()
	return slot_text


## Reloj de bolsillo: la aguja gira mientras se guarda; al terminar se marca con una señal
## de visto o, si falla, con un aspa.
func _draw_icon() -> void:
	var center := _icon.size * 0.5 + Vector2(0.0, 2.0)
	var radius := minf(_icon.size.x, _icon.size.y) * 0.5 - 5.0
	var color := FAILED_COLOR if state == State.FAILED else UiTheme.AMBER
	var rim := color
	if state == State.SAVING:
		rim.a = 0.7 + 0.3 * sin(_pulse * 5.0)
	_icon.draw_rect(Rect2(center + Vector2(-3.0, -radius - 5.0), Vector2(6.0, 4.0)), color)
	_icon.draw_arc(center, radius, 0.0, TAU, 48, rim, 2.0, true)
	for index in 12:
		var direction := Vector2.UP.rotated(TAU * index / 12.0)
		var inner := radius - (4.5 if index % 3 == 0 else 2.5)
		_icon.draw_line(center + direction * inner, center + direction * (radius - 1.0), Color(color, 0.65), 1.0, true)
	match state:
		State.SAVING:
			var hand := Vector2.UP.rotated(_hand_angle)
			_icon.draw_line(center, center + hand * (radius - 5.0), color, 2.0, true)
			_icon.draw_line(center, center + Vector2.UP * (radius * 0.45), Color(color, 0.6), 2.0, true)
			_icon.draw_circle(center, 2.2, color)
		State.SAVED:
			_icon.draw_circle(center, radius - 3.0, Color(color, 0.18))
			var tick := PackedVector2Array([center + Vector2(-6.0, 0.5), center + Vector2(-1.5, 5.0), center + Vector2(6.5, -5.0)])
			_icon.draw_polyline(tick, color, 2.6, true)
		State.FAILED:
			_icon.draw_line(center + Vector2(-5.0, -5.0), center + Vector2(5.0, 5.0), color, 2.6, true)
			_icon.draw_line(center + Vector2(5.0, -5.0), center + Vector2(-5.0, 5.0), color, 2.6, true)


func _badge_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTheme.NIGHT, 0.9)
	box.border_color = Color(UiTheme.AMBER, 0.45)
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 14.0
	box.content_margin_right = 20.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	box.shadow_size = 8
	return box
