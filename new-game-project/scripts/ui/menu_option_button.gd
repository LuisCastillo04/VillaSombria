class_name MenuOptionButton
extends Button
## Opción del menú principal: tarjeta de pergamino con un icono, un filete que lo separa del
## texto y tinta del expediente. La opción señalada, con el ratón, el teclado o el mando, toma un
## borde burdeos con un brillo exterior suave, y el cambio se anima para que no sea brusco.
## Señalar con el ratón también da el foco: así sólo hay una opción resaltada a la vez.

const PARCHMENT_SHADER := preload("res://assets/shaders/parchment.gdshader")

const HEIGHT := 68.0
const CORNER_RADIUS := 7
const MARGIN_LEFT := 50.0
const MARGIN_RIGHT := 28.0
const MARGIN_VERTICAL := 10.0
const ICON_WIDTH := 36
## Distancia entre el icono y el texto; el filete queda justo en medio.
const ICON_GAP := 72
const FONT_SIZE := 32
const DETAIL_FONT_SIZE := 24
const DETAIL_GAP := 12.0
## Al pulsar, el texto y el filete bajan un poco, como una tecla.
const PRESS_SHIFT := 2.0
const HIGHLIGHT_SECONDS := 0.18

const PAPER := Color("eadcbd")
const PAPER_LIT := Color("e2c398")
const PAPER_EDGE := Color("b49b74")
const PAPER_EDGE_LIT := Color("a2683f")
const PAPER_STAIN := Color("b9996a")
const BORDER := Color(0.42, 0.33, 0.22, 0.55)
const BORDER_LIT := Color("8e2329")
const SHADOW := Color(0.0, 0.0, 0.0, 0.5)
const GLOW := Color(0.62, 0.09, 0.1, 0.5)
const DISABLED_TEXT := Color("4b4134")

## Texto secundario, más pequeño, a continuación del principal: «(Día 1 · 08:20)».
@export var detail_text := "":
	set(value):
		detail_text = value
		queue_redraw()

var _highlight := 0.0
var _tween: Tween
## Estilo compartido por los estados normal y señalado; el resaltado lo interpola.
var _card: StyleBoxFlat
var _paper_material: ShaderMaterial


func _ready() -> void:
	custom_minimum_size.y = maxf(custom_minimum_size.y, HEIGHT)
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_build_paper()
	_build_styles()
	_apply_text_style()
	focus_entered.connect(_refresh_highlight)
	focus_exited.connect(_refresh_highlight)
	mouse_entered.connect(_on_mouse_entered)
	_apply_highlight(0.0)


## Activa o desactiva la opción. Desactivada no recibe el foco: el teclado y el mando la saltan.
func set_available(available: bool) -> void:
	disabled = not available
	focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
	_refresh_highlight()


func is_highlighted() -> bool:
	return _highlight > 0.5


func _on_mouse_entered() -> void:
	if not disabled and focus_mode != Control.FOCUS_NONE and is_visible_in_tree():
		grab_focus()


func _refresh_highlight() -> void:
	var target := 1.0 if has_focus() and not disabled else 0.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if not is_visible_in_tree():
		_apply_highlight(target)
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply_highlight, _highlight, target, HIGHLIGHT_SECONDS)


func _apply_highlight(value: float) -> void:
	_highlight = value
	_card.border_color = BORDER.lerp(BORDER_LIT, value)
	_card.shadow_color = SHADOW.lerp(GLOW, value)
	_card.shadow_size = roundi(lerpf(6.0, 14.0, value))
	_card.shadow_offset = Vector2(0.0, lerpf(3.0, 0.0, value))
	_paper_material.set_shader_parameter("base_color", PAPER.lerp(PAPER_LIT, value))
	_paper_material.set_shader_parameter("edge_color", PAPER_EDGE.lerp(PAPER_EDGE_LIT, value))
	var icon_color := CaseFileStyle.INK.lerp(CaseFileStyle.BURGUNDY, value)
	for key: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_hover_pressed_color"]:
		add_theme_color_override(key, icon_color)


## El pergamino va en un hijo dibujado detrás del botón: el estilo sólo pone el borde, la sombra
## y los velos de pulsado y desactivado, así el texto y el icono quedan siempre por encima.
func _build_paper() -> void:
	_paper_material = ShaderMaterial.new()
	_paper_material.shader = PARCHMENT_SHADER
	_paper_material.set_shader_parameter("stain_color", PAPER_STAIN)
	_paper_material.set_shader_parameter("corner_radius", float(CORNER_RADIUS))
	_paper_material.set_shader_parameter("edge_width", 22.0)
	# Cada tarjeta con sus propias manchas, como hojas distintas.
	_paper_material.set_shader_parameter("seed", 1.3 + get_index() * 4.7)
	var paper := ColorRect.new()
	paper.name = "Paper"
	paper.material = _paper_material
	paper.show_behind_parent = true
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(paper, false, Node.INTERNAL_MODE_FRONT)
	paper.resized.connect(func() -> void: _paper_material.set_shader_parameter("rect_size", paper.size))


func _build_styles() -> void:
	_card = _card_style()
	# Con relleno, StyleBoxFlat pinta la sombra también por dentro: los velos van sin sombra.
	var pushed := _card_style()
	pushed.draw_center = true
	pushed.bg_color = Color(0.36, 0.1, 0.08, 0.12)
	pushed.border_color = CaseFileStyle.BURGUNDY_DARK
	pushed.shadow_size = 0
	pushed.content_margin_top += PRESS_SHIFT
	pushed.content_margin_bottom -= PRESS_SHIFT
	var unavailable := _card_style()
	unavailable.draw_center = true
	unavailable.bg_color = Color(0.11, 0.09, 0.07, 0.45)
	unavailable.border_color = Color(BORDER, 0.25)
	unavailable.shadow_size = 0
	add_theme_stylebox_override("normal", _card)
	add_theme_stylebox_override("hover", _card)
	add_theme_stylebox_override("pressed", pushed)
	add_theme_stylebox_override("hover_pressed", pushed)
	add_theme_stylebox_override("disabled", unavailable)
	# El resaltado ya marca el foco; un recuadro encima lo duplicaría.
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _card_style() -> StyleBoxFlat:
	var style := CaseFileStyle.box(Color(0.0, 0.0, 0.0, 0.0), BORDER, 2, CORNER_RADIUS)
	style.draw_center = false
	style.content_margin_left = MARGIN_LEFT
	style.content_margin_right = MARGIN_RIGHT
	style.content_margin_top = MARGIN_VERTICAL
	style.content_margin_bottom = MARGIN_VERTICAL
	style.shadow_color = SHADOW
	style.shadow_size = 6
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _apply_text_style() -> void:
	add_theme_font_override("font", CaseFileStyle.serif_bold())
	add_theme_font_size_override("font_size", FONT_SIZE)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(key, CaseFileStyle.INK)
	add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	add_theme_color_override("icon_pressed_color", CaseFileStyle.BURGUNDY_DARK)
	add_theme_color_override("icon_disabled_color", Color(DISABLED_TEXT, 0.8))
	add_theme_constant_override("icon_max_width", ICON_WIDTH)
	add_theme_constant_override("h_separation", ICON_GAP)


## El filete entre el icono y el texto, y el detalle en letra menor tras el texto.
func _draw() -> void:
	var shift := PRESS_SHIFT if get_draw_mode() in [DRAW_PRESSED, DRAW_HOVER_PRESSED] else 0.0
	var ink := DISABLED_TEXT if disabled else CaseFileStyle.INK_SOFT
	if icon != null:
		var x := MARGIN_LEFT + ICON_WIDTH + ICON_GAP * 0.5
		draw_line(Vector2(x, size.y * 0.24 + shift), Vector2(x, size.y * 0.76 + shift), Color(ink, 0.55), 1.5, true)
	if detail_text.is_empty():
		return
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var text_x := MARGIN_LEFT + (float(ICON_WIDTH + ICON_GAP) if icon != null else 0.0)
	text_x += font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + DETAIL_GAP
	# Misma línea base que el texto principal, que el botón centra en vertical.
	var content_height := size.y - MARGIN_VERTICAL * 2.0
	var baseline := MARGIN_VERTICAL + shift + (content_height - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	draw_string(CaseFileStyle.serif(), Vector2(text_x, baseline), detail_text, HORIZONTAL_ALIGNMENT_LEFT, -1, DETAIL_FONT_SIZE, ink)
