class_name FilterCard
extends PanelContainer
## Tarjeta de un filtro en Configuración → Filtros: nombre, descripción y, a la derecha, el botón
## «SELECCIONAR» o, si es el filtro aplicado, «✓ ACTIVO» con el filete dorado encendido.
##
## Se maneja como las demás filas de Configuración (`OptionSelector`): con el ratón, un clic en
## cualquier parte de la tarjeta; con el teclado o el mando, arriba y abajo recorren las tarjetas,
## izquierda vuelve a la pestaña y aceptar elige. La señalada toma el fondo burdeos, como el resto.
## La tarjeta no aplica nada: avisa con `chosen` y la página guarda la preferencia, que es la única
## fuente del filtro activo.

signal chosen(filter_id: String)

const TITLE_SIZE := 24
const DETAIL_SIZE := 17
const BADGE_SIZE := 15
const SELECT_TEXT := "SELECCIONAR"
const ACTIVE_TEXT := "ACTIVO"
## Ancho del trazo de la marca de «✓ ACTIVO», dibujada en código para no depender de la fuente.
const CHECK_SIZE := 16.0

var filter_id := ""
var _active := false
var _hovered := false
var _title: Label
var _detail: Label
var _badge: PanelContainer
var _badge_text: Label
var _check: Control
var _styles := {}


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_styles()
	add_theme_stylebox_override("focus", CaseFileStyle.focus_ring(5))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	_title = MenuStyle.make_label("", TITLE_SIZE, MenuStyle.TEXT, CaseFileStyle.serif_bold())
	texts.add_child(_title)
	_detail = MenuStyle.make_label("", DETAIL_SIZE, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(_detail)
	row.add_child(_make_badge())
	focus_entered.connect(_refresh_look)
	focus_exited.connect(_refresh_look)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	_refresh_look()


func setup(id: String, title: String, detail: String) -> void:
	filter_id = id
	name = "Filtro_" + id
	_title.text = title
	_detail.text = detail


## Marca la tarjeta como el filtro aplicado (o no). No avisa ni guarda nada.
func set_active(active: bool) -> void:
	if active == _active:
		return
	_active = active
	_refresh_look()


func is_active() -> bool:
	return _active


func get_title_text() -> String:
	return _title.text


func get_detail_text() -> String:
	return _detail.text


## Texto del botón: «SELECCIONAR» o «ACTIVO» (con la marca delante).
func get_badge_text() -> String:
	return _badge_text.text


## Elige este filtro, como un clic o aceptar con la tarjeta señalada.
func choose() -> void:
	AudioManager.play("click")
	chosen.emit(filter_id)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		accept_event()
		choose()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		grab_focus()
		choose()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_refresh_look()


func _refresh_look() -> void:
	if _badge == null:
		return
	var highlighted := has_focus() or _hovered
	var key := ("active" if _active else "idle") + ("_lit" if highlighted else "")
	add_theme_stylebox_override("panel", _styles[key])
	_badge.add_theme_stylebox_override("panel", _styles["badge_active" if _active else ("badge_lit" if highlighted else "badge")])
	_badge_text.text = ACTIVE_TEXT if _active else SELECT_TEXT
	_badge_text.add_theme_color_override("font_color", CaseFileStyle.GOLD_LIGHT if _active else MenuStyle.TEXT)
	_check.visible = _active
	queue_redraw()


## Botón de la derecha. Su ancho es el de «SELECCIONAR», para que no cambie al activarse.
func _make_badge() -> PanelContainer:
	_badge = PanelContainer.new()
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_child(content)
	_check = Control.new()
	_check.name = "Marca"
	_check.custom_minimum_size = Vector2(CHECK_SIZE + 4.0, CHECK_SIZE)
	_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check.draw.connect(_draw_check)
	content.add_child(_check)
	_badge_text = MenuStyle.make_label(SELECT_TEXT, BADGE_SIZE, MenuStyle.TEXT, CaseFileStyle.serif_bold())
	_badge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_badge_text)
	var font := _badge_text.get_theme_font("font")
	var widest := maxf(font.get_string_size(SELECT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_SIZE).x,
		font.get_string_size(ACTIVE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, BADGE_SIZE).x + CHECK_SIZE + 14.0)
	_badge.custom_minimum_size.x = ceilf(widest) + 26.0
	return _badge


func _draw_check() -> void:
	var height := _check.size.y
	var points := PackedVector2Array([
		Vector2(1.0, height * 0.55),
		Vector2(CHECK_SIZE * 0.38, height * 0.88),
		Vector2(CHECK_SIZE, height * 0.12),
	])
	_check.draw_polyline(points, CaseFileStyle.GOLD_LIGHT, 2.5, true)


## Fondos de la tarjeta y del botón en cada estado. El filtro activo lleva el filete dorado claro
## con un halo; la tarjeta señalada, el fondo burdeos de las filas de los menús.
func _build_styles() -> void:
	var idle := MenuStyle.row_box()
	idle.border_color = Color(MenuStyle.GOLD, 0.5)
	idle.content_margin_left = 22.0
	idle.content_margin_right = 14.0
	idle.content_margin_top = 8.0
	idle.content_margin_bottom = 10.0
	var idle_lit := idle.duplicate() as StyleBoxFlat
	idle_lit.bg_color = Color(MenuStyle.SELECTION, 0.22)
	idle_lit.border_color = Color(MenuStyle.GOLD, 0.85)
	var active := idle.duplicate() as StyleBoxFlat
	active.bg_color = Color(0.09, 0.07, 0.05, 0.6)
	active.border_color = CaseFileStyle.GOLD_LIGHT
	active.set_border_width_all(2)
	active.shadow_color = Color(CaseFileStyle.GOLD_LIGHT, 0.35)
	active.shadow_size = 9
	var active_lit := active.duplicate() as StyleBoxFlat
	active_lit.bg_color = Color(MenuStyle.SELECTION, 0.26)
	_styles = {"idle": idle, "idle_lit": idle_lit, "active": active, "active_lit": active_lit}
	var badge := CaseFileStyle.box(Color(0.0, 0.0, 0.0, 0.35), Color(MenuStyle.GOLD, 0.7), 1, 4)
	badge.content_margin_left = 12.0
	badge.content_margin_right = 12.0
	badge.content_margin_top = 4.0
	badge.content_margin_bottom = 5.0
	var badge_lit := badge.duplicate() as StyleBoxFlat
	badge_lit.border_color = CaseFileStyle.GOLD_LIGHT
	var badge_active := badge.duplicate() as StyleBoxFlat
	badge_active.bg_color = CaseFileStyle.BURGUNDY_DARK.darkened(0.3)
	badge_active.border_color = CaseFileStyle.GOLD_LIGHT
	badge_active.set_border_width_all(2)
	badge_active.shadow_color = Color(CaseFileStyle.GOLD_LIGHT, 0.3)
	badge_active.shadow_size = 5
	_styles["badge"] = badge
	_styles["badge_lit"] = badge_lit
	_styles["badge_active"] = badge_active


func _draw() -> void:
	if has_focus():
		draw_style_box(get_theme_stylebox("focus"), Rect2(Vector2.ZERO, size))
