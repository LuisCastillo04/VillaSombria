class_name ControlsMenu
extends CategoryMenu
## Teclas del juego por categorías. Se leen del InputMap cada vez que se abre: si cambia una
## asignación en project.godot (o, más adelante, la reasigna el jugador), aquí aparece sin tocar
## nada más. Cada fila es un BindingRow.
##
## Para añadir una acción: créala en el InputMap y añade su fila a `CATEGORIES`. Para añadir una
## categoría: otra entrada en `CATEGORIES`. Lo previsto está en `PLANNED`.

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
## Funciones previstas para los controles que todavía no existen.
const PLANNED: Array[Dictionary] = [
	{"label": "Reasignar teclas", "detail": "Elegir otra tecla para cada acción y avisar de conflictos"},
	{"label": "Jugar con mando", "detail": "Esquema de botones para mandos"},
	{"label": "Restaurar las teclas predeterminadas", "detail": "Volver a la configuración original"},
]

var _rows: Array[BindingRow] = []


## Al abrir se vuelven a leer las teclas, por si cambiaron.
func open() -> void:
	refresh()
	super.open()


func refresh() -> void:
	for row in _rows:
		row.set_key_groups(_groups_for(row.get_meta("definition")))


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
	add_planned_section(get_page(CATEGORIES.size() - 1), PLANNED)


func _binding_row(definition: Dictionary) -> BindingRow:
	var actions: Array[String] = []
	actions.assign(definition.get("together", definition.get("actions", [])))
	var row := BindingRow.new(definition["label"], _groups_for(definition), actions)
	row.set_meta("definition", definition)
	_rows.append(row)
	return row


static func _groups_for(definition: Dictionary) -> Array[PackedStringArray]:
	var groups: Array[PackedStringArray] = []
	if definition.has("together"):
		groups = InputLabels.combined(definition["together"])
	elif definition.has("actions"):
		groups = InputLabels.alternatives(definition["actions"])
	for fixed: Array in definition.get("fixed", []):
		groups.append(PackedStringArray(fixed))
	return groups
