class_name HudObjectivePanel
extends ParchmentPanel
## Panel superior derecho del HUD: la cinta «OBJETIVO», una lupa, un filete y el objetivo pendiente
## en tinta marrón. El texto se parte en las líneas que haga falta, sin recortes: el panel crece
## hacia abajo y el HUD recoloca lo que va debajo.
##
## El HUD le pasa el objetivo que lee `HudInfo` de `StoryDirector`; el panel no decide nada sobre
## la historia. Cuando llega un objetivo nuevo con el panel a la vista, el texto anterior se funde
## con el nuevo y la cinta destella una vez (`flash`).

const BANNER := "OBJETIVO"
const CONTENT_GAP := 14

var _objective_text := ""
var _content: HBoxContainer
var _icon: TextureRect
var _separator: GoldDivider
var _label: Label
var _text_tween: Tween
var _flash_tween: Tween


func _init() -> void:
	banner_text = BANNER
	padding = Vector4(22.0, 12.0, 26.0, 16.0)
	paper_seed = 7.9
	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", CONTENT_GAP)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = HudStyle.make_icon(HudStyle.icon("lupa"), HudStyle.OBJECTIVE_ICON, HudStyle.INK)
	_content.add_child(_icon)
	_separator = HudStyle.make_separator(Color(HudStyle.INK, 0.5), HudStyle.OBJECTIVE_ICON)
	_separator.size_flags_vertical = Control.SIZE_FILL
	_content.add_child(_separator)
	_label = HudStyle.make_label("", HudStyle.body_font(), HudStyle.OBJECTIVE_SIZE, HudStyle.INK)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_constant_override("line_spacing", 1)
	_content.add_child(_label)
	add_child(_content)
	set_panel_width(HudStyle.OBJECTIVE_WIDTH)


func get_objective() -> String:
	return _objective_text


## Líneas que ocupa ahora el objetivo.
func get_line_count() -> int:
	return _label.get_line_count()


## Si se ve el objetivo completo, sin líneas ocultas.
func is_text_complete() -> bool:
	return _label.get_visible_line_count() >= _label.get_line_count()


## Ancho total del panel. El texto se reparte en el espacio que queda tras la lupa y el filete.
func set_panel_width(width: float) -> void:
	custom_minimum_size.x = width
	var used := padding.x + padding.z + HudStyle.OBJECTIVE_ICON + _separator.custom_minimum_size.x + CONTENT_GAP * 2
	_label.custom_minimum_size.x = maxf(width - used, 120.0)


## Cambia el objetivo. Devuelve si era distinto. Con `animate`, el texto se funde y la cinta destella.
func set_objective(text: String, animate: bool) -> bool:
	if text == _objective_text:
		return false
	_objective_text = text
	if _text_tween != null:
		_text_tween.kill()
	if not animate or not is_visible_in_tree():
		_label.text = text
		_label.modulate.a = 1.0
		return true
	_text_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_text_tween.tween_property(_label, "modulate:a", 0.0, HudStyle.SWAP_OUT).set_ease(Tween.EASE_IN)
	_text_tween.tween_callback(func() -> void: _label.text = _objective_text)
	_text_tween.tween_property(_label, "modulate:a", 1.0, HudStyle.SWAP_IN).set_ease(Tween.EASE_OUT)
	flash()
	return true


## Destello breve de la cinta y la lupa para señalar un objetivo nuevo.
func flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_flash_tween.tween_method(_apply_glow, 0.0, 1.0, HudStyle.FLASH * 0.3).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(_apply_glow, 1.0, 0.0, HudStyle.FLASH * 0.7).set_ease(Tween.EASE_IN_OUT)


func is_flashing() -> bool:
	return _flash_tween != null and _flash_tween.is_running()


func _apply_glow(value: float) -> void:
	banner_glow = value
	_icon.modulate = HudStyle.INK.lerp(HudStyle.BURGUNDY, value)
