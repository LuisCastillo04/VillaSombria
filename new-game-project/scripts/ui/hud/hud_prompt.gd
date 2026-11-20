class_name HudPrompt
extends NoirPlate
## Aviso de interacción sobre la barra de teclas: la tecla de interactuar del InputMap, encendida
## en burdeos, y lo que hará («Hablar con Ortega», «Salir a la plaza»). Aparece y desaparece con un
## fundido breve; el texto lo decide el detector de interacción, no el HUD.

const FADE_IN := 0.16
const FADE_OUT := 0.12

var _text := ""
var _key: KeyCap
var _label: Label
var _tween: Tween


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
