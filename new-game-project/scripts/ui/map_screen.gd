class_name MapScreen
extends MenuScreen
## Mapa del pueblo. Se abre encima de la pausa, con el juego congelado: con la tecla del mapa (M)
## directamente desde la exploración, o desde la opción «Mapa» de la pausa. Escape, la misma tecla o
## «Volver» lo cierran y devuelven al sitio desde el que se abrió.
##
## A la izquierda, el mapa ilustrado con las chinchetas de los lugares y el marcador del detective
## en su posición real. A la derecha, la leyenda, los objetivos pendientes de hoy (los de
## StoryDirector) y la ficha del lugar señalado. Las chinchetas se recorren con el ratón, las
## flechas, el mando o el dedo; pulsar una la selecciona.

## Ancho del panel lateral y de su texto, en píxeles. El texto con saltos de línea necesita un
## ancho fijo: sin él, su contenedor lo mediría letra a letra y el panel crecería sin fin.
const SIDE_WIDTH := 390.0
const SIDE_PADDING := 24.0
const TEXT_WIDTH := SIDE_WIDTH - SIDE_PADDING * 2.0
const OBJECTIVE_ICON := 26.0
const OBJECTIVE_GAP := 12.0
const MIN_MAP_HEIGHT := 360.0
## Objetivos que caben en el panel; el resto se resume en una línea.
const MAX_OBJECTIVES := 4
const SLIDE_PIXELS := 18.0
const SLIDE_SECONDS := 0.24

## Detective cuya posición muestra el mapa. Lo asigna la escena de juego.
var target: PlayerController:
	set(value):
		target = value
		if _view != null:
			_view.target = value

var _objective_list: VBoxContainer
var _place_name: Label
var _place_detail: Label
var _selected_place := ""
var _slide_tween: Tween

@onready var _layout_box: VBoxContainer = %Layout
@onready var _heading: MenuHeading = %Heading
@onready var _frame: MenuFrame = %Frame
@onready var _body: HBoxContainer = %Body
@onready var _view: TownMapView = %MapView
@onready var _side: PanelContainer = %Side
@onready var _side_box: VBoxContainer = %SideBox
@onready var _back: MenuOptionButton = %Back


func _ready() -> void:
	_view.target = target
	_view.exit_control = _back
	_view.place_focused.connect(_show_place)
	_view.place_pressed.connect(_on_place_pressed)
	_back.pressed.connect(_on_back_pressed)
	_back.focus_entered.connect(_on_back_focused)
	_build_side()
	_layout_box.resized.connect(_fit_layout)
	EventBus.objectives_changed.connect(_refresh_objectives)
	_fit_layout()


## Abre el mapa con la posición del detective de este instante, sin animar desde la anterior.
func open() -> void:
	_view.refresh_places()
	_view.update_tracking(true)
	_select_place("")
	_refresh_objectives()
	_show_place(_current_place_id())
	super.open()
	_slide_in()


func get_view() -> TownMapView:
	return _view


func get_back_button() -> MenuOptionButton:
	return _back


func get_selected_place() -> String:
	return _selected_place


## Texto de la ficha del lugar: nombre y detalle.
func get_place_card() -> PackedStringArray:
	return PackedStringArray([_place_name.text, _place_detail.text])


func get_objective_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for row in _objective_list.get_children():
		if row.has_meta("objective_text"):
			texts.append(row.get_meta("objective_text"))
	return texts


func _input(event: InputEvent) -> void:
	if is_open() and not ExitManager.is_dialog_open() and not ConfirmDialog.is_open() and event.is_action_pressed("open_map"):
		get_viewport().set_input_as_handled()
		close()
		return
	super._input(event)


## El foco empieza en la chincheta del lugar donde está el detective. Fuera del mapa empieza en
## «Volver», para que la ficha siga explicando que el lugar actual no figura en él.
func _focus_default() -> void:
	_link_back_button()
	var pin := _current_pin()
	if pin != null:
		pin.grab_focus()
	else:
		_back.grab_focus()


func _current_place_id() -> String:
	return str(_view.get_fix().get("place_id", ""))


## Chincheta del lugar actual o, si no se ve, la más cercana al detective. Null fuera del mapa.
func _current_pin() -> MapPlacePin:
	var pin := _view.get_pin(_current_place_id())
	if pin != null and pin.visible:
		return pin
	var fix := _view.get_fix()
	if bool(fix.get("known", false)):
		return _view.nearest_pin_to(fix["map_point"])
	return null


## Desde «Volver», arriba lleva a la chincheta actual o, fuera del mapa, a la primera.
func _link_back_button() -> void:
	var pin := _current_pin()
	if pin == null:
		var pins := _view.get_visible_pins()
		pin = pins[0] if not pins.is_empty() else null
	_back.focus_neighbor_top = _back.get_path_to(pin) if pin != null else NodePath(".")


func _slide_in() -> void:
	if _slide_tween != null:
		_slide_tween.kill()
	var rest := _layout_box.offset_top
	_layout_box.position.y = rest + SLIDE_PIXELS
	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(_layout_box, "position:y", rest, SLIDE_SECONDS)


# --- Panel lateral -----------------------------------------------------------------------

func _build_side() -> void:
	var style := CaseFileStyle.box(Color(0.03, 0.028, 0.032, 0.82), Color(MenuStyle.GOLD, 0.85), 2, 6)
	style.content_margin_left = SIDE_PADDING
	style.content_margin_right = SIDE_PADDING
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	_side.add_theme_stylebox_override("panel", style)
	_side.custom_minimum_size.x = SIDE_WIDTH
	_add_section_title("LEYENDA")
	_add_legend_row(MapSymbols.Kind.PLACE, "Punto de interés")
	_add_legend_row(MapSymbols.Kind.OBJECTIVE, "Objetivo")
	_add_legend_row(MapSymbols.Kind.PLAYER, "Ubicación actual")
	_add_section_title("OBJETIVO")
	_objective_list = VBoxContainer.new()
	_objective_list.name = "Objectives"
	_objective_list.add_theme_constant_override("separation", 10)
	_side_box.add_child(_objective_list)
	_add_section_title("LUGAR")
	_place_name = MenuStyle.make_label("", 24, MenuStyle.TEXT, CaseFileStyle.serif_bold())
	_place_name.name = "PlaceName"
	_place_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place_name.custom_minimum_size.x = TEXT_WIDTH
	_side_box.add_child(_place_name)
	_place_detail = MenuStyle.make_label("", 19, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	_place_detail.name = "PlaceDetail"
	_place_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place_detail.custom_minimum_size.x = TEXT_WIDTH
	_side_box.add_child(_place_detail)


func _add_section_title(text: String) -> void:
	if _side_box.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 6.0
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_side_box.add_child(gap)
	var title := MenuStyle.make_label(text, 26, MenuStyle.TEXT, CaseFileStyle.display_serif())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_side_box.add_child(title)
	var divider := GoldDivider.new()
	divider.custom_minimum_size = Vector2(0.0, 12.0)
	divider.color = Color(MenuStyle.GOLD, 0.7)
	_side_box.add_child(divider)


func _add_legend_row(kind: MapSymbols.Kind, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_symbol(kind, 40.0))
	var label := MenuStyle.make_label(text, 21, MenuStyle.TEXT, CaseFileStyle.serif())
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	_side_box.add_child(row)


func _symbol(kind: MapSymbols.Kind, side: float) -> MapSymbolIcon:
	var icon := MapSymbolIcon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return icon


## Objetivos pendientes de hoy. Los que se cumplen en un lugar del mapa llevan su rombo y el nombre
## del lugar; los demás, un punto.
func _refresh_objectives() -> void:
	if _objective_list == null:
		return
	for child in _objective_list.get_children():
		_objective_list.remove_child(child)
		child.queue_free()
	var pending := TownMap.get_pending_objectives()
	if pending.is_empty():
		var none := MenuStyle.make_label("No queda nada pendiente por hoy.", 19, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = TEXT_WIDTH
		_objective_list.add_child(none)
		return
	for index in mini(pending.size(), MAX_OBJECTIVES):
		_objective_list.add_child(_objective_row(pending[index]))
	if pending.size() > MAX_OBJECTIVES:
		var more := MenuStyle.make_label("Y %d más en el expediente." % (pending.size() - MAX_OBJECTIVES), 18, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
		more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		more.custom_minimum_size.x = TEXT_WIDTH
		_objective_list.add_child(more)


func _objective_row(objective: Dictionary) -> Control:
	var places: PackedStringArray = objective["places"]
	var row := HBoxContainer.new()
	row.set_meta("objective_text", objective["text"])
	row.add_theme_constant_override("separation", int(OBJECTIVE_GAP))
	if places.is_empty():
		var dot := MenuStyle.make_label("•", 22, MenuStyle.GOLD, CaseFileStyle.serif_bold())
		dot.custom_minimum_size.x = OBJECTIVE_ICON
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(dot)
	else:
		row.add_child(_symbol(MapSymbols.Kind.OBJECTIVE, OBJECTIVE_ICON))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	var text := MenuStyle.make_label(objective["text"], 19, MenuStyle.TEXT, CaseFileStyle.serif())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = TEXT_WIDTH - OBJECTIVE_ICON - OBJECTIVE_GAP
	texts.add_child(text)
	if not places.is_empty():
		var names := PackedStringArray()
		for place_id in places:
			names.append(TownMap.get_place_name(TownMap.get_place(place_id)))
		var where := MenuStyle.make_label(", ".join(names), 17, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
		where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		where.custom_minimum_size.x = text.custom_minimum_size.x
		texts.add_child(where)
	row.add_child(texts)
	return row


## Ficha de un lugar: dónde está el detective respecto a él, si ya lo ha visitado y qué tiene
## pendiente. Sin lugar, explica que el escenario actual no figura en el mapa.
func _show_place(place_id: String) -> void:
	var place := TownMap.get_place(place_id)
	var fix := _view.get_fix()
	if place == null:
		if bool(fix.get("known", false)):
			_place_name.text = "Villa Sombría"
			_place_detail.text = "Señala un lugar para ver sus detalles."
		else:
			_place_name.text = "Fuera del mapa"
			_place_detail.text = "Este lugar no figura en el mapa del pueblo."
		return
	_place_name.text = TownMap.get_place_name(place)
	var lines := PackedStringArray()
	var here := str(fix.get("place_id", "")) == place.id and bool(fix.get("known", false))
	if here:
		lines.append("Estás aquí: el marcador sigue tu posición exacta." if bool(fix["precise"]) else "Estás dentro: el marcador señala el edificio.")
	elif TownMap.is_visited(place.id):
		lines.append("Ya has estado aquí.")
	else:
		lines.append("Aún no has estado aquí.")
	if not TownMap.is_place_available(place):
		lines.append("Ahora mismo no se puede entrar.")
	for objective in TownMap.get_pending_objectives():
		if (objective["places"] as PackedStringArray).has(place.id):
			lines.append("Pendiente: %s." % str(objective["text"]).trim_suffix("."))
	_place_detail.text = "\n".join(lines)


func _on_place_pressed(place_id: String) -> void:
	AudioManager.play("click")
	_select_place(place_id)
	_show_place(place_id)


func _select_place(place_id: String) -> void:
	_selected_place = place_id
	for pin in _view.get_visible_pins():
		pin.selected = pin.place_id == place_id


## En «Volver» la ficha muestra el lugar elegido o, si no hay, el actual.
func _on_back_focused() -> void:
	_link_back_button()
	_show_place(_selected_place if not _selected_place.is_empty() else _current_place_id())


func _on_back_pressed() -> void:
	AudioManager.play("click")
	close()


## El pergamino ocupa todo el alto disponible sin perder su proporción ni empujar el panel lateral
## fuera de la pantalla, en cualquier resolución.
func _fit_layout() -> void:
	if _layout_box.size.y <= 0.0:
		return
	var separation := float(_layout_box.get_theme_constant("separation"))
	var frame_padding := _frame.get_theme_stylebox("panel")
	var free_height := _layout_box.size.y - _heading.get_combined_minimum_size().y - _back.get_combined_minimum_size().y - separation * 2.0
	free_height -= frame_padding.content_margin_top + frame_padding.content_margin_bottom + 4.0
	var free_width := _layout_box.size.x - frame_padding.content_margin_left - frame_padding.content_margin_right
	free_width -= SIDE_WIDTH + float(_body.get_theme_constant("separation")) + 4.0
	var canvas := TownMap.canvas_size
	var map_height := minf(free_height, free_width * canvas.y / canvas.x)
	map_height = maxf(map_height, MIN_MAP_HEIGHT)
	_view.custom_minimum_size = Vector2(map_height * canvas.x / canvas.y, map_height).floor()
