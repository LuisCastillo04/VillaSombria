class_name ContrastFilter
extends RefCounted
## Contraste aumentado para toda la interfaz, sin rehacer ninguna pantalla.
##
## Mientras está activo, cada control del juego (también los que se crean después) recibe:
## - **Texto más nítido**: los colores de texto se vuelven opacos y se separan del fondo. Los claros
##   (crema, dorado, burdeos claro sobre paneles oscuros) se acercan al blanco cálido y los oscuros
##   (tinta sobre pergamino) al negro. El color de lo desactivado no se toca, para que siga
##   distinguiéndose.
## - **Foco inconfundible**: el contorno de foco pasa a ser un filete grueso casi blanco con un halo
##   oscuro, que se ve igual sobre cuero, pergamino o el escenario.
##
## Es reversible: lo que había se guarda en metadatos de cada control y vuelve al desactivarlo. Si
## una pantalla cambia un color mientras está activo (por ejemplo, un aviso que pasa a rojo), el
## filtro lo detecta con `theme_changed` y realza el color nuevo. El modo normal no cambia nada.

const ORIGINAL := &"contraste_original"
const APPLIED := &"contraste_aplicado"
const FOCUS := &"focus"
## Colores de texto que se realzan en cada tipo de control. `font_disabled_color` no está a propósito.
const BUTTON_COLORS: Array[StringName] = [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]
const LABEL_COLORS: Array[StringName] = [&"font_color"]
const RICH_TEXT_COLORS: Array[StringName] = [&"default_color"]
## Hacia dónde se llevan los colores claros y los oscuros, y cuánto.
const LIGHT_TARGET := Color(1.0, 0.97, 0.9)
const DARK_TARGET := Color(0.05, 0.03, 0.02)
const LIGHT_MIX := 0.55
const DARK_MIX := 0.6
## A partir de esta luminancia un color se considera claro (texto sobre fondo oscuro).
const LIGHT_THRESHOLD := 0.4
const FOCUS_COLOR := Color(1.0, 0.96, 0.84)
const FOCUS_HALO := Color(0.0, 0.0, 0.0, 0.9)
const FOCUS_WIDTH := 4

var _tree: SceneTree
var _enabled := false
## Evita que los cambios del propio filtro lo vuelvan a disparar.
var _applying := false


func is_enabled() -> bool:
	return _enabled


## Activa o desactiva el contraste aumentado en todo el árbol.
func set_enabled(tree: SceneTree, enabled: bool) -> void:
	if tree == null or (enabled == _enabled and tree == _tree):
		return
	if _enabled and _tree != null:
		_stop()
	_tree = tree
	_enabled = enabled
	if enabled:
		_tree.node_added.connect(_on_node_added)
		_walk(_tree.root, true)
	else:
		_walk(_tree.root, false)


## Color de texto con más contraste: opaco y llevado hacia el blanco cálido o hacia el negro.
static func boost(color: Color) -> Color:
	var boosted: Color
	if color.get_luminance() >= LIGHT_THRESHOLD:
		boosted = color.lerp(LIGHT_TARGET, LIGHT_MIX)
	else:
		boosted = color.lerp(DARK_TARGET, DARK_MIX)
	boosted.a = 1.0
	return boosted


## Contorno de foco del modo de alto contraste, con el radio y el margen del original.
static func focus_ring(original: StyleBox) -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.anti_aliasing = true
	ring.border_color = FOCUS_COLOR
	ring.set_border_width_all(FOCUS_WIDTH)
	ring.shadow_color = FOCUS_HALO
	ring.shadow_size = 3
	var radius := 6
	var expand := 4.0
	var flat := original as StyleBoxFlat
	if flat != null:
		radius = flat.corner_radius_top_left + 2
		expand = maxf(flat.expand_margin_left, 0.0) + 3.0
	ring.set_corner_radius_all(radius)
	ring.set_expand_margin_all(expand)
	return ring


static func color_names(control: Control) -> Array[StringName]:
	if control is Button:
		return BUTTON_COLORS
	if control is RichTextLabel:
		return RICH_TEXT_COLORS
	if control is Label or control is LineEdit or control is TextEdit:
		return LABEL_COLORS
	var none: Array[StringName] = []
	return none


func _stop() -> void:
	if _tree.node_added.is_connected(_on_node_added):
		_tree.node_added.disconnect(_on_node_added)


func _walk(node: Node, enable: bool) -> void:
	var control := node as Control
	if control != null:
		if enable:
			_watch(control)
			_apply(control)
		else:
			_restore(control)
	for child in node.get_children():
		_walk(child, enable)


func _on_node_added(node: Node) -> void:
	var control := node as Control
	if control != null and _enabled:
		_watch(control)
		_apply(control)


func _watch(control: Control) -> void:
	var callback := _on_theme_changed.bind(control)
	if not control.theme_changed.is_connected(callback):
		control.theme_changed.connect(callback)


## Una pantalla cambió un color o un estilo de este control: se realza lo nuevo.
func _on_theme_changed(control: Control) -> void:
	if _enabled and not _applying and is_instance_valid(control):
		_apply(control)


func _apply(control: Control) -> void:
	_applying = true
	var original: Dictionary = control.get_meta(ORIGINAL, {})
	var applied: Dictionary = control.get_meta(APPLIED, {})
	for color_name in color_names(control):
		if not control.has_theme_color(color_name):
			continue
		var current := control.get_theme_color(color_name)
		var overridden := control.has_theme_color_override(color_name)
		if overridden and applied.has(color_name) and applied[color_name] == current:
			continue
		original[color_name] = current if overridden else null
		var boosted := boost(current)
		applied[color_name] = boosted
		control.add_theme_color_override(color_name, boosted)
	if control.has_theme_stylebox(FOCUS):
		var focus := control.get_theme_stylebox(FOCUS)
		if not (applied.has(FOCUS) and applied[FOCUS] == focus):
			original[FOCUS] = focus if control.has_theme_stylebox_override(FOCUS) else null
			var ring := focus_ring(focus)
			applied[FOCUS] = ring
			control.add_theme_stylebox_override(FOCUS, ring)
	if not original.is_empty():
		control.set_meta(ORIGINAL, original)
		control.set_meta(APPLIED, applied)
	_applying = false


func _restore(control: Control) -> void:
	var callback := _on_theme_changed.bind(control)
	if control.theme_changed.is_connected(callback):
		control.theme_changed.disconnect(callback)
	if not control.has_meta(ORIGINAL):
		return
	_applying = true
	var original: Dictionary = control.get_meta(ORIGINAL)
	for item_name: StringName in original:
		var value: Variant = original[item_name]
		if item_name == FOCUS:
			if value == null:
				control.remove_theme_stylebox_override(FOCUS)
			else:
				control.add_theme_stylebox_override(FOCUS, value)
		elif value == null:
			control.remove_theme_color_override(item_name)
		else:
			control.add_theme_color_override(item_name, value)
	control.remove_meta(ORIGINAL)
	control.remove_meta(APPLIED)
	_applying = false
