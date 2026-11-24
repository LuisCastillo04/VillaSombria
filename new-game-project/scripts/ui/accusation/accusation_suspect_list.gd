class_name AccusationSuspectList
extends Control
## Lista desplegable de sospechosos, propia del juego en lugar del menú genérico de Godot: una hoja
## de papel claro con filete dorado y sombra que se despliega bajo el selector, con el retrato, el
## nombre y el papel de cada sospechoso. El elegido va en burdeos; el que se señala con el ratón se
## aclara y el del teclado o el mando lleva el contorno dorado del foco.
##
## Ocupa toda la pantalla mientras está abierta para recoger los clics de fuera, que la cierran sin
## cambiar nada. Se abre y se cierra con un fundido y un leve desplazamiento.

signal suspect_chosen(suspect_id: String)
signal closed

const SLIDE := 10.0
const SCREEN_MARGIN := 16.0

var _box: PanelContainer
var _rows: VBoxContainer
var _tween: Tween
var _open := false
## Selector bajo el que se despliega: la lista lo sigue mientras la hoja se anima o cambia de escala.
var _anchor: Control
## Desplazamiento de la animación de entrada y salida, en píxeles de diseño.
var _slide := 0.0


func _init() -> void:
	name = "SuspectList"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_box = PanelContainer.new()
	_box.name = "Box"
	var style := AccusationStyle.box(AccusationStyle.PAPER_LIGHT, AccusationStyle.GOLD, 2, 5, Vector4(8.0, 8.0, 8.0, 8.0))
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0.0, 7.0)
	_box.add_theme_stylebox_override("panel", style)
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", 2)
	_box.add_child(_rows)
	add_child(_box)


## Crea una fila por sospechoso: `{id, title, subtitle, portrait}`.
func setup(entries: Array[Dictionary]) -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for index in entries.size():
		var row := AccusationListRow.new(AccusationStyle.SUSPECT_ROW_HEIGHT, AccusationStyle.PORTRAIT_SIZE)
		row.setup(entries[index])
		row.show_separator = index < entries.size() - 1
		row.pressed.connect(_on_row_pressed.bind(row))
		_rows.add_child(row)
	_link_focus()


func is_open() -> bool:
	return _open


## Despliega la lista bajo el selector `anchor`, con su mismo ancho y la escala de la hoja. Marca a
## `chosen_id` y le da el foco (o al primero).
func open_at(anchor: Control, chosen_id: String) -> void:
	_anchor = anchor
	for row in get_rows():
		row.chosen = row.item_id == chosen_id
	_open = true
	show()
	set_process(true)
	_animate(true)
	_place_box()
	var focus_row := get_row(chosen_id)
	if focus_row == null and not get_rows().is_empty():
		focus_row = get_rows()[0]
	if focus_row != null:
		focus_row.grab_focus()


func close(animate: bool = true) -> void:
	if not _open:
		return
	_open = false
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	if animate and is_inside_tree():
		_animate(false)
	else:
		if _tween != null:
			_tween.kill()
		_hide_now()
	closed.emit()


func get_rows() -> Array[AccusationListRow]:
	var rows: Array[AccusationListRow] = []
	for child in _rows.get_children():
		if child is AccusationListRow and not child.is_queued_for_deletion():
			rows.append(child)
	return rows


func get_row(suspect_id: String) -> AccusationListRow:
	for row in get_rows():
		if row.item_id == suspect_id:
			return row
	return null


## Rectángulo de la lista en pantalla, ya escalado.
func get_box_rect() -> Rect2:
	return Rect2(_box.position, _box.size * _box.scale)


func _process(_delta: float) -> void:
	_place_box()


## Bajo el selector; si no cabe hasta el borde inferior, encima de él.
func _place_box() -> void:
	if not is_instance_valid(_anchor):
		return
	var anchor := _anchor.get_global_rect()
	var list_scale := _anchor.get_global_transform().get_scale().x
	_box.scale = Vector2.ONE * list_scale
	_box.size = Vector2(_anchor.size.x, _box.get_combined_minimum_size().y)
	var height := _box.size.y * list_scale
	var gap := 6.0 * list_scale
	var target := Vector2(anchor.position.x, anchor.end.y + gap)
	if target.y + height > size.y - SCREEN_MARGIN and anchor.position.y - height - gap > SCREEN_MARGIN:
		target.y = anchor.position.y - height - gap
	_box.position = target - Vector2(0.0, _slide * list_scale)


func _animate(opening: bool) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if opening else Tween.EASE_IN)
	var seconds := AccusationStyle.LIST_OPEN_SECONDS if opening else AccusationStyle.LIST_CLOSE_SECONDS
	if opening:
		_slide = SLIDE
		_box.modulate.a = 0.0
	_tween.tween_property(self, "_slide", 0.0 if opening else SLIDE * 0.6, seconds)
	_tween.tween_property(_box, "modulate:a", 1.0 if opening else 0.0, seconds)
	if not opening:
		_tween.chain().tween_callback(func() -> void:
			if not _open:
				_hide_now()
		)


func _hide_now() -> void:
	hide()
	set_process(false)


## Arriba desde la primera fila lleva a la última y abajo desde la última, a la primera.
func _link_focus() -> void:
	var rows := get_rows()
	if rows.is_empty():
		return
	rows[0].focus_neighbor_top = rows[0].get_path_to(rows[-1])
	rows[-1].focus_neighbor_bottom = rows[-1].get_path_to(rows[0])


func _on_row_pressed(row: AccusationListRow) -> void:
	suspect_chosen.emit(row.item_id)


## Un clic fuera de la lista la cierra sin cambiar la elección.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and not get_box_rect().has_point(click.position):
		accept_event()
		close()
