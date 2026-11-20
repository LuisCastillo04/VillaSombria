class_name HudLocationPanel
extends ParchmentPanel
## Panel superior izquierdo del HUD: el icono del lugar, un filete y, a su derecha, el nombre del
## escenario en burdeos sobre la fecha y la hora en cursiva.
##
## No sabe de dónde salen los datos: el HUD le pasa el nombre, el icono y la fecha que lee
## `HudInfo`. Al cambiar de lugar con el panel a la vista, el contenido se desvanece, se actualiza
## y vuelve a aparecer; al cambiar la hora, sólo la fecha. Los nombres largos reducen la letra
## hasta `HudStyle.TITLE_MIN_SIZE` y, si aun así no caben, terminan en puntos suspensivos.

var _title_text := ""
var _icon_name := ""
var _date_text := ""
var _content: HBoxContainer
var _icon: TextureRect
var _title: Label
var _date: Label
var _content_tween: Tween
var _date_tween: Tween


func _init() -> void:
	padding = Vector4(22.0, 12.0, 30.0, 14.0)
	paper_seed = 2.3
	custom_minimum_size.x = HudStyle.LOCATION_MIN_WIDTH
	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = HudStyle.make_icon(HudStyle.icon(HudStyle.FALLBACK_ICON), HudStyle.LOCATION_ICON, HudStyle.INK)
	_content.add_child(_icon)
	_content.add_child(HudStyle.make_separator(Color(HudStyle.INK, 0.5), HudStyle.LOCATION_ICON))
	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 0)
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = HudStyle.make_label("", HudStyle.title_font(), HudStyle.TITLE_SIZE, HudStyle.BURGUNDY)
	text_box.add_child(_title)
	var rule := GoldDivider.new()
	rule.diamond = false
	rule.color = Color(HudStyle.INK, 0.42)
	rule.custom_minimum_size = Vector2(0.0, 7.0)
	text_box.add_child(rule)
	_date = HudStyle.make_label("", HudStyle.date_font(), HudStyle.DATE_SIZE, HudStyle.INK)
	text_box.add_child(_date)
	_content.add_child(text_box)
	add_child(_content)


func get_title() -> String:
	return _title_text


func get_icon_name() -> String:
	return _icon_name


func get_date() -> String:
	return _date_text


## Tamaño de letra con el que se muestra ahora el nombre del lugar.
func get_title_font_size() -> int:
	return _title.get_theme_font_size("font_size")


## Cambia el lugar. Con `animate`, el contenido anterior se desvanece antes de mostrar el nuevo.
func set_location(title: String, icon_name: String, animate: bool) -> void:
	if title == _title_text and icon_name == _icon_name:
		return
	_title_text = title
	_icon_name = icon_name
	if _content_tween != null:
		_content_tween.kill()
	if not animate or not is_visible_in_tree():
		_apply_location()
		_content.modulate.a = 1.0
		return
	_content_tween = _swap(_content, _apply_location)


## Cambia la fecha y la hora. Con `animate`, sólo la línea de la fecha se funde.
func set_date(text: String, animate: bool) -> void:
	if text == _date_text:
		return
	_date_text = text
	if _date_tween != null:
		_date_tween.kill()
	if not animate or not is_visible_in_tree():
		_date.text = text
		_date.modulate.a = 1.0
		return
	_date_tween = _swap(_date, func() -> void: _date.text = _date_text)


func _apply_location() -> void:
	_icon.texture = HudStyle.icon(_icon_name)
	_title.text = _title_text
	_fit_title()


## Reduce la letra del nombre hasta que quepa; si ni con la mínima cabe, lo recorta con puntos.
func _fit_title() -> void:
	var font := HudStyle.title_font()
	var font_size := HudStyle.TITLE_SIZE
	while font_size > HudStyle.TITLE_MIN_SIZE and _text_width(font, font_size) > HudStyle.LOCATION_TEXT_MAX:
		font_size -= 2
	_title.add_theme_font_size_override("font_size", font_size)
	var fits := _text_width(font, font_size) <= HudStyle.LOCATION_TEXT_MAX
	_title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if fits else TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.custom_minimum_size.x = 0.0 if fits else HudStyle.LOCATION_TEXT_MAX


func _text_width(font: Font, font_size: int) -> float:
	return font.get_string_size(_title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _swap(target: CanvasItem, apply: Callable) -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "modulate:a", 0.0, HudStyle.SWAP_OUT).set_ease(Tween.EASE_IN)
	tween.tween_callback(apply)
	tween.tween_property(target, "modulate:a", 1.0, HudStyle.SWAP_IN).set_ease(Tween.EASE_OUT)
	return tween
