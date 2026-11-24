class_name HudPrompt
extends NoirPlate
## Aviso de interacción sobre la barra de teclas: la tecla de interactuar del InputMap, encendida
## en burdeos, y lo que hará («Hablar con Ortega», «Salir a la plaza»). Aparece y desaparece con un
## fundido breve; el texto lo decide el detector de interacción, no el HUD.
##
## Si lo que se mira tiene un estado (cómo va el interrogatorio de un personaje), se añade detrás,
## tras un filete, con letra menor y un icono: rombo claro (preguntas nuevas), rombo (pendientes),
## rombo hueco (nada nuevo por ahora) o verificación (interrogatorio completo).

const FADE_IN := 0.16
const FADE_OUT := 0.12
const STATUS_SIZE := 20

var _text := ""
var _status_text := ""
var _key: KeyCap
var _label: Label
var _status: HBoxContainer
var _status_mark: StatusMark
var _status_label: Label
var _tween: Tween


## Icono del estado, dibujado para que siga la paleta del HUD.
class StatusMark extends Control:
	var kind := ""

	func _init() -> void:
		custom_minimum_size = Vector2(16.0, 16.0)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_kind(value: String) -> void:
		kind = value
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		match kind:
			ConversationLog.STATUS_NEW:
				HudOrnaments.draw_diamond(self, center, 7.0, HudStyle.GOLD_LIGHT, Color(HudStyle.GOLD_LIGHT, 0.3))
			ConversationLog.STATUS_PENDING:
				HudOrnaments.draw_diamond(self, center, 6.0, HudStyle.GOLD)
			ConversationLog.STATUS_WAITING:
				draw_polyline(HudOrnaments.closed(HudOrnaments.diamond(center, 6.0)), HudStyle.CREAM_SOFT, 1.6, true)
			ConversationLog.STATUS_DONE:
				DialogueOrnaments.draw_check(self, center, 6.5, HudStyle.CREAM_SOFT)


func _init() -> void:
	padding = Vector4(26.0, 9.0, 30.0, 9.0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key = KeyCap.new("")
	row.add_child(_key)
	_label = HudStyle.make_label("", HudStyle.body_font(), HudStyle.PROMPT_SIZE, HudStyle.CREAM)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	_status = HBoxContainer.new()
	_status.name = "Status"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_constant_override("separation", 10)
	var rule := ColorRect.new()
	rule.color = Color(HudStyle.GOLD, 0.45)
	rule.custom_minimum_size = Vector2(1.5, 24.0)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_child(rule)
	_status_mark = StatusMark.new()
	_status.add_child(_status_mark)
	_status_label = HudStyle.make_label("", HudStyle.date_font(), STATUS_SIZE, HudStyle.CREAM_SOFT)
	_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.add_child(_status_label)
	_status.visible = false
	row.add_child(_status)
	add_child(row)
	modulate.a = 0.0
	visible = false


func _ready() -> void:
	super._ready()
	# KeyCap aplica su estilo al entrar en el árbol; el encendido va después.
	_key.add_theme_stylebox_override("normal", HudStyle.keycap_box(true))


func get_text() -> String:
	return _text


func get_key() -> String:
	return _key.text


## Estado que acompaña al aviso («Preguntas pendientes») y su clase, o vacíos para quitarlo.
func set_status(text: String, kind: String = "") -> void:
	_status_text = text
	_status_label.text = text
	_status_mark.set_kind(kind)
	_status.visible = not text.is_empty()


func get_status_text() -> String:
	return _status_text


func get_status_kind() -> String:
	return _status_mark.kind


func is_shown() -> bool:
	return not _text.is_empty()


## Muestra el aviso con la tecla `key`. Sin tecla asignada, sólo el texto.
func show_prompt(text: String, key: String) -> void:
	_text = text
	_label.text = text
	_key.text = key
	_key.visible = not key.is_empty()
	_fade(true)


func hide_prompt() -> void:
	if _text.is_empty():
		return
	_text = ""
	_fade(false)


func _fade(shown: bool) -> void:
	if _tween != null:
		_tween.kill()
	if shown:
		visible = true
	if not is_inside_tree():
		modulate.a = 1.0 if shown else 0.0
		visible = shown
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0 if shown else 0.0, FADE_IN if shown else FADE_OUT)
	if not shown:
		_tween.tween_callback(hide)
