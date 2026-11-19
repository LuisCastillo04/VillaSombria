class_name SaveSlotRow
extends Button
## Una ranura del expediente: número, imagen real del guardado, lugar, fecha del guardado,
## día y hora del caso, tiempo de juego y pistas. Muestra sólo lo que registró el archivo.
## La selección la decide el menú; aquí sólo se dibuja.

## Doble clic sobre la fila.
signal double_clicked(slot_id: String)

const ROW_RADIUS := 8

var slot_id := ""
var selected := false
var status := SaveFormat.Status.EMPTY

var _styles: Dictionary = {}

@onready var _number: PanelContainer = $Layout/Number
@onready var _number_text: Label = $Layout/Number/Text
@onready var _thumb: PanelContainer = $Layout/Thumb
@onready var _picture: TextureRect = $Layout/Thumb/Picture
@onready var _placeholder: CenterContainer = $Layout/Thumb/Placeholder
@onready var _placeholder_icon: TextureRect = $Layout/Thumb/Placeholder/Icon
@onready var _name: Label = $Layout/Info/NameRow/Name
@onready var _active: Label = $Layout/Info/NameRow/Active
@onready var _saved_row: HBoxContainer = $Layout/Info/Saved
@onready var _saved_icon: TextureRect = $Layout/Info/Saved/Icon
@onready var _saved: Label = $Layout/Info/Saved/Text
@onready var _clock: Label = $Layout/Info/Clock
@onready var _time_row: HBoxContainer = $Layout/Stats/Time
@onready var _time: Label = $Layout/Stats/Time/Text
@onready var _clues_row: HBoxContainer = $Layout/Stats/Clues
@onready var _clues: Label = $Layout/Stats/Clues/Text
@onready var _dashes: Label = $Layout/Stats/Dashes


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	_styles = {
		"normal": CaseFileStyle.box(CaseFileStyle.PARCHMENT_LIGHT, Color("a88a62"), 2, ROW_RADIUS),
		"hover": CaseFileStyle.box(Color("f6ead0"), CaseFileStyle.GOLD, 2, ROW_RADIUS),
		"selected": CaseFileStyle.box(CaseFileStyle.ROSE, CaseFileStyle.BURGUNDY, 3, ROW_RADIUS),
		"selected_hover": CaseFileStyle.box(Color("f0d8c7"), CaseFileStyle.BURGUNDY, 3, ROW_RADIUS),
		"disabled": CaseFileStyle.box(Color(CaseFileStyle.PARCHMENT_LIGHT, 0.7), Color("a88a62"), 2, ROW_RADIUS),
	}
	for style: StyleBoxFlat in _styles.values():
		style.shadow_color = Color(0.2, 0.12, 0.05, 0.22)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("focus", CaseFileStyle.focus_ring(ROW_RADIUS))
	CaseFileStyle.style_label(_number_text, CaseFileStyle.serif_bold(), 32, CaseFileStyle.INK)
	CaseFileStyle.style_label(_name, CaseFileStyle.serif_bold(), 28, CaseFileStyle.INK)
	CaseFileStyle.style_label(_active, CaseFileStyle.serif_bold(), 15, CaseFileStyle.BURGUNDY)
	CaseFileStyle.style_label(_saved, CaseFileStyle.serif(), 20, CaseFileStyle.INK_SOFT)
	CaseFileStyle.style_label(_clock, CaseFileStyle.serif(), 20, CaseFileStyle.INK_SOFT)
	CaseFileStyle.style_label(_time, CaseFileStyle.serif(), 21, CaseFileStyle.INK)
	CaseFileStyle.style_label(_clues, CaseFileStyle.serif(), 21, CaseFileStyle.INK)
	CaseFileStyle.style_label(_dashes, CaseFileStyle.serif(), 24, CaseFileStyle.INK_SOFT)
	_thumb.add_theme_stylebox_override("panel", CaseFileStyle.box(Color("3a2a1e"), Color("2a1b12"), 2, 3, 2.0))
	_saved_icon.texture = CaseFileStyle.icon("calendario")
	(_time_row.get_node("Icon") as TextureRect).texture = CaseFileStyle.icon("cronometro")
	(_clues_row.get_node("Icon") as TextureRect).texture = CaseFileStyle.icon("lupa")
	for icon_rect: TextureRect in [_saved_icon, _time_row.get_node("Icon"), _clues_row.get_node("Icon")]:
		icon_rect.self_modulate = CaseFileStyle.SEPIA
	gui_input.connect(_on_gui_input)
	_apply_styles()


## Rellena la fila con los datos de `SaveSystem.get_slot_info` y la imagen de la ranura.
func set_info(info: Dictionary, preview: Texture2D) -> void:
	slot_id = info["id"]
	status = info["status"]
	_number_text.text = "%02d" % int(info["number"])
	_active.visible = bool(info.get("active", false)) and status == SaveFormat.Status.OK
	var occupied := status == SaveFormat.Status.OK
	_saved_row.visible = occupied or status != SaveFormat.Status.EMPTY
	_clock.visible = occupied
	_time_row.visible = occupied
	_clues_row.visible = occupied
	_dashes.visible = not occupied
	match status:
		SaveFormat.Status.EMPTY:
			_name.text = "Ranura vacía"
			_set_name_style(CaseFileStyle.serif_italic(), CaseFileStyle.INK_SOFT)
			_show_placeholder(CaseFileStyle.icon("carpeta_vacia"), Color("d9c49c"), CaseFileStyle.SEPIA)
		SaveFormat.Status.OK:
			var summary: Dictionary = info["summary"]
			_name.text = summary["location_name"]
			_set_name_style(CaseFileStyle.serif_bold(), CaseFileStyle.INK)
			var verb := "Autoguardada" if info.get("kind", "") == "auto" else "Guardada"
			_saved.text = "%s el %s" % [verb, format_saved_at(float(summary["saved_at"]))]
			_saved_icon.show()
			_clock.text = "Día %d  ·  %s" % [int(summary["day"]), format_clock(int(summary["minutes"]))]
			_time.text = "Tiempo de juego:  %s" % format_play_time(float(summary["play_seconds"]))
			var clues := int(summary["clues"])
			_clues.text = "Pistas encontradas:  %d" % clues
			if preview != null:
				_picture.texture = preview
				_picture.show()
				_placeholder.hide()
			else:
				_show_placeholder(CaseFileStyle.icon("sin_imagen"), Color("3a2a1e"), Color(CaseFileStyle.CREAM, 0.55))
		_:
			_name.text = "Archivo incompatible" if status == SaveFormat.Status.INCOMPATIBLE else "Archivo dañado"
			_set_name_style(CaseFileStyle.serif_bold(), CaseFileStyle.BURGUNDY)
			_saved.text = info["error"]
			_saved_icon.hide()
			_show_placeholder(CaseFileStyle.icon("sin_imagen"), Color("3a2a1e"), Color(CaseFileStyle.ROSE, 0.7))
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	_apply_styles()
	queue_redraw()


## Mientras se escribe la ranura, la línea del guardado lo indica.
func set_busy(busy: bool) -> void:
	if busy:
		_saved_row.show()
		_saved_icon.hide()
		_saved.text = "Guardando…"


func _show_placeholder(texture: Texture2D, background: Color, tint: Color) -> void:
	_picture.texture = null
	_picture.hide()
	_placeholder.show()
	_placeholder_icon.texture = texture
	_placeholder_icon.self_modulate = tint
	_thumb.add_theme_stylebox_override("panel", CaseFileStyle.box(background, Color("2a1b12"), 2, 3, 2.0))


func _set_name_style(font: Font, color: Color) -> void:
	_name.add_theme_font_override("font", font)
	_name.add_theme_color_override("font_color", color)


func _apply_styles() -> void:
	var base: StyleBox = _styles["selected" if selected else "normal"]
	var hover: StyleBox = _styles["selected_hover" if selected else "hover"]
	add_theme_stylebox_override("normal", base)
	add_theme_stylebox_override("pressed", base)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("hover_pressed", hover)
	add_theme_stylebox_override("disabled", _styles["selected" if selected else "disabled"])
	var number_style := CaseFileStyle.box(Color("dcc193"), Color("8e6a43"), 2, 6)
	var number_color := CaseFileStyle.INK
	if selected:
		number_style = CaseFileStyle.box(CaseFileStyle.BURGUNDY, CaseFileStyle.BURGUNDY_DARK, 2, 6)
		number_color = CaseFileStyle.CREAM
	_number.add_theme_stylebox_override("panel", number_style)
	_number_text.add_theme_color_override("font_color", number_color)


## La ranura seleccionada lleva una punta burdeos en el borde derecho, como un separador de
## carpeta.
func _draw() -> void:
	if not selected:
		return
	var middle := size.y * 0.5
	var tip := PackedVector2Array([
		Vector2(size.x - 2.0, middle - 13.0), Vector2(size.x + 16.0, middle), Vector2(size.x - 2.0, middle + 13.0),
	])
	draw_colored_polygon(tip, CaseFileStyle.BURGUNDY)


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.double_click and click.button_index == MOUSE_BUTTON_LEFT and not disabled:
		double_clicked.emit(slot_id)


static func format_clock(minutes: int) -> String:
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## Fecha y hora locales del guardado; el archivo la registra en UTC.
static func format_saved_at(unix_time: float) -> String:
	var bias_minutes := int(Time.get_time_zone_from_system().get("bias", 0))
	var local := Time.get_datetime_dict_from_unix_time(int(unix_time) + bias_minutes * 60)
	return "%02d/%02d/%04d %02d:%02d" % [local["day"], local["month"], local["year"], local["hour"], local["minute"]]


static func format_play_time(seconds: float) -> String:
	if seconds < 0.0:
		return "sin registrar"
	var total_minutes := int(seconds) / 60
	return "%d h %02d min" % [total_minutes / 60, total_minutes % 60]
