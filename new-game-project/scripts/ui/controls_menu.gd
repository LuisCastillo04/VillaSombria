class_name ControlsMenu
extends CategoryMenu
## Teclas del juego por categorías. Se leen del InputMap cada vez que se abre y cada vez que cambian:
## si cambia una asignación en project.godot o la reasigna el jugador, aquí aparece sin tocar nada
## más. Cada fila es un BindingRow.
##
## Al pie de «Otros», las herramientas de los controles (`TOOLS`, filas `MenuActionRow`):
## - «Reasignar teclas» abre encima `RebindMenu`.
## - «Jugar con mando» abre encima `GamepadMenu`, el esquema de botones del mando.
## - «Restaurar las teclas predeterminadas» pregunta con `ConfirmDialog` y, si se confirma, vuelve a
##   las teclas de fábrica (`Controls.restore_defaults`). El resto de preferencias no cambia.
## Las dos pantallas son hijas de esta: mientras una está abierta, el panel de Controles se oculta, y
## al volver reaparece con las teclas al día y el foco en la fila que la abrió.
##
## Para añadir una acción: créala en el InputMap y añade su fila a `CATEGORIES` (y, si el jugador
## puede cambiarla, su entrada a `InputBindings.ACTIONS`). Para añadir una categoría: otra entrada en
## `CATEGORIES`.

## Filas de cada categoría.
## - `actions`: acciones del InputMap; cada una de sus teclas es una alternativa.
## - `together`: acciones que se usan como grupo (las cuatro direcciones).
## - `fixed`: teclas o botones que el código lee sin pasar por el InputMap.
const CATEGORIES: Array[Dictionary] = [
	{"title": "Movimiento", "icon": "cruceta", "rows": [
		{"label": "Moverse", "together": ["move_forward", "move_left", "move_back", "move_right"]},
		{"label": "Correr (mantener)", "actions": ["sprint"]},
	]},
	{"title": "Interacción", "icon": "mano", "rows": [
		{"label": "Interactuar", "actions": ["interact"]},
		{"label": "Avanzar el diálogo", "actions": ["interact", "ui_accept"], "fixed": [["Clic"]]},
		# DialogueControls lee los números directamente (fila superior y teclado numérico); la tecla
		# de interactuar confirma la respuesta señalada, como Intro y Espacio en cualquier menú.
		{"label": "Elegir una pregunta", "actions": ["interact"], "fixed": [["1–9"], ["Clic"]]},
		{"label": "Confirmar en los menús", "actions": ["ui_accept"]},
	]},
	{"title": "Menús", "icon": "lista", "rows": [
		{"label": "Abrir o cerrar el expediente", "actions": ["open_journal"]},
		{"label": "Abrir o cerrar el tablero", "actions": ["open_board"]},
		{"label": "Abrir o cerrar el mapa", "actions": ["open_map"]},
		{"label": "Pausar el juego", "actions": ["pause"]},
		{"label": "Moverse por los menús", "together": ["ui_up", "ui_left", "ui_down", "ui_right"]},
		{"label": "Volver atrás", "actions": ["ui_cancel"]},
	]},
	{"title": "Otros", "icon": "puntos", "rows": [
		{"label": "Dejar pasar una hora", "actions": ["wait_time"]},
		# El cierre de la ventana pasa por ExitManager, que guarda antes de salir.
		{"label": "Cerrar el juego guardando", "fixed": [["Alt", "F4"]]},
	]},
]
## Herramientas de los controles, al pie de «Otros».
const TOOLS: Array[Dictionary] = [
	{"id": "reasignar", "label": "Reasignar teclas", "detail": "Elegir otra tecla para cada acción y avisar de conflictos"},
	{"id": "mando", "label": "Jugar con mando", "detail": "Esquema de botones para mandos"},
	{"id": "restaurar", "label": "Restaurar las teclas predeterminadas", "detail": "Volver a la configuración original"},
]
const RESTORE_TITLE := "¿RESTAURAR CONTROLES PREDETERMINADOS?"
const RESTORE_TEXT := "Se eliminarán las asignaciones personalizadas de teclado y se recuperará la configuración original."

var _rows: Array[BindingRow] = []
var _tools: Dictionary = {}
## Fila que abrió la pantalla de encima: recupera el foco al volver.
var _return_focus: Control
var _center_tween: Tween

@onready var _center: Control = $Center
@onready var _rebind: RebindMenu = $RebindMenu
@onready var _gamepad: GamepadMenu = $GamepadMenu


func _ready() -> void:
	super._ready()
	_rebind.hide()
	_gamepad.hide()
	_rebind.closed.connect(_on_screen_closed)
	_gamepad.closed.connect(_on_screen_closed)
	Controls.bindings_changed.connect(_on_bindings_changed.unbind(1))
	Controls.gamepad_connected.connect(_refresh_tools.unbind(2))
	Controls.gamepad_disconnected.connect(_refresh_tools.unbind(2))


## Al abrir se vuelven a leer las teclas, por si cambiaron, y se empieza siempre por esta pantalla.
func open() -> void:
	_rebind.hide()
	_gamepad.hide()
	_show_panel(false)
	refresh()
	super.open()


func refresh() -> void:
	for row in _rows:
		row.set_key_groups(groups_for(row.get_meta("definition")))
	_refresh_tools()


## Herramienta de «Otros» por su identificador de `TOOLS`.
func get_tool(tool_id: String) -> MenuActionRow:
	return _tools.get(tool_id)


func get_rebind_menu() -> RebindMenu:
	return _rebind


func get_gamepad_menu() -> GamepadMenu:
	return _gamepad


## Fila de una acción por su texto, o null si no existe.
func find_row(label_text: String) -> BindingRow:
	for row in _rows:
		if row.get_action_text() == label_text:
			return row
	return null


func _build_categories() -> void:
	for category: Dictionary in CATEGORIES:
		var page := add_category(category["title"], category["icon"])
		page.add_theme_constant_override("separation", 8)
		page.add_child(MenuStyle.make_label(category["title"], 26, MenuStyle.TEXT, CaseFileStyle.serif_bold()))
		for definition: Dictionary in category["rows"]:
			page.add_child(_binding_row(definition))
	_add_tools(get_page(CATEGORIES.size() - 1))


func _binding_row(definition: Dictionary) -> BindingRow:
	var actions: Array[String] = []
	actions.assign(definition.get("together", definition.get("actions", [])))
	var row := BindingRow.new(definition["label"], groups_for(definition), actions)
	row.set_meta("definition", definition)
	_rows.append(row)
	return row


## Filete y, debajo, las herramientas de los controles.
func _add_tools(page: VBoxContainer) -> void:
	add_divider(page)
	for definition: Dictionary in TOOLS:
		var row := MenuActionRow.new(definition["label"], definition["detail"])
		row.name = "Herramienta_" + String(definition["id"])
		row.pressed.connect(_on_tool_pressed.bind(definition["id"]))
		_tools[definition["id"]] = row
		page.add_child(row)


## La explicación de «Jugar con mando» dice si hay uno conectado y la de «Restaurar», cuántas
## acciones tienen teclas personalizadas.
func _refresh_tools() -> void:
	if _tools.is_empty():
		return
	var pads := Controls.get_connected_gamepads().size()
	var pad_text := "ningún mando conectado"
	if pads == 1:
		pad_text = "mando conectado"
	elif pads > 1:
		pad_text = "%d mandos conectados" % pads
	(_tools["mando"] as MenuActionRow).set_detail("%s · %s" % [TOOLS[1]["detail"], pad_text])
	var custom := Controls.customized_actions().size()
	var custom_text := "ya la usas"
	if custom == 1:
		custom_text = "1 acción personalizada"
	elif custom > 1:
		custom_text = "%d acciones personalizadas" % custom
	(_tools["restaurar"] as MenuActionRow).set_detail("%s · %s" % [TOOLS[2]["detail"], custom_text])


func _on_tool_pressed(tool_id: String) -> void:
	match tool_id:
		"reasignar":
			_open_screen(_rebind, _tools[tool_id])
		"mando":
			_open_screen(_gamepad, _tools[tool_id])
		"restaurar":
			_ask_restore()


## Abre una pantalla encima, en lugar del panel de Controles.
func _open_screen(screen: MenuScreen, opener: Control) -> void:
	if not is_open() or screen.is_open() or ConfirmDialog.is_open():
		return
	AudioManager.play("click")
	_return_focus = opener
	_center.hide()
	screen.open()


func _on_screen_closed() -> void:
	refresh()
	_show_panel(true)
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()
	_return_focus = null


func _show_panel(animate: bool) -> void:
	if _center_tween != null:
		_center_tween.kill()
	_center.show()
	_center.modulate.a = 0.0 if animate else 1.0
	if animate:
		_center_tween = create_tween()
		_center_tween.tween_property(_center, "modulate:a", 1.0, FADE_SECONDS)


## Restaurar pide confirmación; cancelar no cambia nada.
func _ask_restore() -> void:
	if ConfirmDialog.is_open():
		return
	AudioManager.play("click")
	var accepted: bool = await ConfirmDialog.ask(RESTORE_TITLE, RESTORE_TEXT,
		{"confirm_text": "Restaurar controles", "cancel_text": "Cancelar", "focus": "cancel"})
	if not accepted or not is_inside_tree():
		return
	Controls.restore_defaults()
	refresh()
	(_tools["restaurar"] as MenuActionRow).set_detail("Restauradas: vuelves a usar las teclas originales.")


func _on_bindings_changed() -> void:
	if is_visible_in_tree():
		refresh()


## Teclas que muestra una fila de `CATEGORIES` (o con su mismo formato), leídas del InputMap.
static func groups_for(definition: Dictionary) -> Array[PackedStringArray]:
	var groups: Array[PackedStringArray] = []
	if definition.has("together"):
		groups = InputLabels.combined(definition["together"])
	elif definition.has("actions"):
		groups = InputLabels.alternatives(definition["actions"])
	for fixed: Array in definition.get("fixed", []):
		groups.append(PackedStringArray(fixed))
	return groups
