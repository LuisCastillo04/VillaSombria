class_name HudKeyHint
extends HBoxContainer
## Una tecla y su acción en la barra del HUD: el recuadro de `KeyCap`, el mismo de la pantalla de
## controles, seguido del nombre de la acción en crema. Varias teclas de una letra se juntan en un
## solo recuadro («WASD»); si alguna es más larga, cada una lleva el suyo.
##
## `set_lit` resalta la tecla en burdeos cuando se puede usar ahora mismo, y `set_dimmed` la apaga
## cuando de momento no sirve. Ninguno de los dos cambia lo que hace la tecla.

## Identificador de la entrada (`HudInfo.CONTROL_HINTS`) que representa.
var hint_id := ""

var _keys: PackedStringArray = []
var _caps: HBoxContainer
var _label: Label
var _compact := false
var _lit := false
var _dimmed := false


func _init(keys: PackedStringArray = PackedStringArray(), label_text: String = "") -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caps = HBoxContainer.new()
	_caps.add_theme_constant_override("separation", 4)
	_caps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caps.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_caps)
	_label = HudStyle.make_label(label_text, HudStyle.body_font(), HudStyle.HINT_SIZE, HudStyle.CREAM)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_label)
	set_keys(keys)


func _ready() -> void:
	# Las teclas aplican su estilo propio al entrar en el árbol; el del HUD va después.
	_style_caps()


func get_keys() -> PackedStringArray:
	return _keys


## Texto de cada recuadro, p. ej. ["WASD"] o ["Mayús"].
func get_cap_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for cap: Label in _caps.get_children():
		texts.append(cap.text)
	return texts


func get_label_text() -> String:
	return _label.text


func set_keys(keys: PackedStringArray) -> void:
	_keys = keys
	for cap in _caps.get_children():
		_caps.remove_child(cap)
		cap.queue_free()
	for text in _cap_texts(keys):
		_caps.add_child(KeyCap.new(text))
	if is_inside_tree():
		_style_caps()


func set_compact(compact: bool) -> void:
	if compact == _compact:
		return
	_compact = compact
	add_theme_constant_override("separation", 8 if compact else 10)
	_label.add_theme_font_size_override("font_size", HudStyle.HINT_SIZE_COMPACT if compact else HudStyle.HINT_SIZE)
	_style_caps()


func is_compact() -> bool:
	return _compact


func set_lit(lit: bool) -> void:
	if lit == _lit:
		return
	_lit = lit
	_style_caps()


func is_lit() -> bool:
	return _lit


func set_dimmed(dimmed: bool) -> void:
	_dimmed = dimmed
	modulate.a = 0.42 if dimmed else 1.0


func is_dimmed() -> bool:
	return _dimmed


func _style_caps() -> void:
	_label.add_theme_color_override("font_color", HudStyle.CREAM if not _lit else HudStyle.GOLD_LIGHT)
	for cap: Label in _caps.get_children():
		cap.add_theme_stylebox_override("normal", HudStyle.keycap_box(_lit))
		cap.add_theme_font_size_override("font_size", HudStyle.KEY_SIZE_COMPACT if _compact else HudStyle.KEY_SIZE)
		cap.custom_minimum_size = Vector2.ONE * (30.0 if _compact else KeyCap.HEIGHT)


## Las teclas de una letra van juntas en un recuadro, como «WASD»; las demás, cada una en el suyo.
static func _cap_texts(keys: PackedStringArray) -> PackedStringArray:
	if keys.size() < 2:
		return keys
	for key in keys:
		if key.length() != 1:
			return keys
	return PackedStringArray(["".join(keys)])
