class_name GamepadMenu
extends CategoryMenu
## Pantalla «Jugar con mando»: el esquema de botones del mando por situaciones (explorar, conversar y
## manejar los menús). Lo que muestra sale de lo que funciona: los botones y ejes de cada acción del
## InputMap y la navegación de los menús de `GamepadNavigation`. Si cambia un botón en
## project.godot, cambia aquí.
##
## Los nombres de los botones siguen al mando conectado (Xbox, PlayStation o Nintendo, según el nombre
## que da el sistema) y, sin ninguno, son los de un mando de Xbox. Al pie se dice qué mando hay; si se
## conecta o se desconecta uno con la pantalla abierta, se pone al día.
##
## Para añadir una fila: otra entrada en `CATEGORIES`, con el formato de `ControlsMenu.CATEGORIES`.

const CATEGORIES: Array[Dictionary] = [
	{"title": "Explorar", "icon": "cruceta", "rows": [
		{"label": "Moverse", "together": ["move_forward", "move_left", "move_back", "move_right"]},
		{"label": "Correr (mantener)", "actions": ["sprint"]},
		{"label": "Interactuar", "actions": ["interact"]},
		{"label": "Abrir el expediente", "actions": ["open_journal"]},
		{"label": "Abrir el tablero", "actions": ["open_board"]},
		{"label": "Abrir el mapa", "actions": ["open_map"]},
		{"label": "Dejar pasar una hora", "actions": ["wait_time"]},
		{"label": "Pausar el juego", "actions": ["pause"]},
	]},
	{"title": "Conversaciones", "icon": "testigos", "rows": [
		{"label": "Avanzar el diálogo", "actions": ["interact", "ui_accept"]},
		{"label": "Recorrer las preguntas", "together": ["ui_up", "ui_down"]},
		{"label": "Elegir la pregunta señalada", "actions": ["interact", "ui_accept"]},
	]},
	{"title": "Menús", "icon": "lista", "rows": [
		{"label": "Moverse por los menús", "together": ["ui_up", "ui_left", "ui_down", "ui_right"]},
		{"label": "Confirmar", "actions": ["ui_accept"]},
		{"label": "Volver atrás o cerrar una pantalla", "actions": ["ui_cancel"]},
		{"label": "Cambiar de sección en el expediente", "together": ["ui_left", "ui_right"]},
		{"label": "Desplazar la ficha del expediente", "together": ["ui_page_up", "ui_page_down"]},
		{"label": "Reanudar desde la pausa", "actions": ["pause"]},
	]},
]
const STATUS_SIZE := 18

var _rows: Array[BindingRow] = []
var _status: Label


func _ready() -> void:
	super._ready()
	_status = MenuStyle.make_label("", STATUS_SIZE, MenuStyle.TEXT_SECONDARY, CaseFileStyle.serif_italic())
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 50.0
	var box := _back.get_parent()
	box.add_child(_status)
	box.move_child(_status, _back.get_index())
	Controls.gamepad_connected.connect(_on_gamepads_changed.unbind(2))
	Controls.gamepad_disconnected.connect(_on_gamepads_changed.unbind(2))
	refresh()


## Al abrir se vuelven a leer los botones y el mando conectado.
func open() -> void:
	refresh()
	super.open()


func refresh() -> void:
	for row in _rows:
		row.set_key_groups(groups_for(row.get_meta("definition")))
	if _status != null:
		_status.text = status_text()


## Fila por su texto, o null si no existe.
func find_row(label_text: String) -> BindingRow:
	for row in _rows:
		if row.get_action_text() == label_text:
			return row
	return null


func get_status_text() -> String:
	return _status.text


## Qué mando hay conectado y con qué nombres se muestran los botones.
static func status_text() -> String:
	var pads := Controls.get_connected_gamepads()
	var style := String(InputLabels.STYLE_NAMES.get(Controls.get_gamepad_style(), "Xbox"))
	if pads.is_empty():
		return "No hay ningún mando conectado. Conéctalo cuando quieras: el juego lo detecta solo. Se muestran los botones de un mando de %s." % style
	var pad_name := Controls.get_gamepad_name()
	var text := "Mando conectado: %s. Botones de %s." % [pad_name if not pad_name.is_empty() else "mando", style]
	if pads.size() > 1:
		text = "%d mandos conectados; el último que usaste: %s. Botones de %s." % [pads.size(), pad_name, style]
	return text + " El ratón y el teclado siguen funcionando."


## Botones que muestra una fila de `CATEGORIES`.
static func groups_for(definition: Dictionary) -> Array[PackedStringArray]:
	if definition.has("together"):
		return InputLabels.combined(definition["together"], InputLabels.Device.GAMEPAD)
	return InputLabels.alternatives(definition.get("actions", []), InputLabels.Device.GAMEPAD)


func _build_categories() -> void:
	for category: Dictionary in CATEGORIES:
		var page := add_category(category["title"], category["icon"])
		page.add_theme_constant_override("separation", 8)
		page.add_child(MenuStyle.make_label(category["title"], 26, MenuStyle.TEXT, CaseFileStyle.serif_bold()))
		for definition: Dictionary in category["rows"]:
			var actions: Array[String] = []
			actions.assign(definition.get("together", definition.get("actions", [])))
			var row := BindingRow.new(definition["label"], groups_for(definition), actions)
			row.set_meta("definition", definition)
			_rows.append(row)
			page.add_child(row)


func _on_gamepads_changed() -> void:
	refresh()
