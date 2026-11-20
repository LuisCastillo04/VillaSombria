class_name JournalUi
extends CanvasLayer
## Expediente del detective: objetivos, pistas, testimonios, sospechosos y deducciones, en una carpeta
## de cuero con páginas de pergamino.
##
## Este nodo sólo coordina: abre y cierra la carpeta, cambia de sección y mantiene las secciones al
## día con las señales de `EventBus`. Lo que se ve lo
## pinta cada sección (`scripts/ui/journal/`) con los datos que lee `JournalInfo`. Las secciones se
## crean una vez y se conservan entre aperturas, así el expediente recuerda la pestaña y la ficha
## elegidas.

enum Tab { OBJECTIVES, CLUES, TESTIMONIES, SUSPECTS, DEDUCTIONS }

const TAB_TITLES: Array[String] = ["Objetivos", "Pistas", "Testimonios", "Sospechosos", "Deducciones"]
const TAB_ICONS: Array[String] = ["objetivo", "lupa", "testigos", "antifaz", "cerebro"]
## Lo usa también el tablero para las valoraciones de los sospechosos.
const STATUS_LABELS := JournalInfo.STATUS_LABELS

var is_open := false
var _current_tab := Tab.OBJECTIVES
var _sections: Array[JournalSection] = []
var _refresh_pending := false
var _photo_busy := false

@onready var _root: Control = $Root
@onready var _dim: ColorRect = $Root/Dim
@onready var _folder: JournalFolder = $Root/Folder


func _ready() -> void:
	_dim.color = JournalStyle.DIM
	_build_sections()
	_folder.tabs.tab_changed.connect(_on_tab_changed)
	_folder.footer.close_pressed.connect(close)
	_root.resized.connect(_layout)
	EventBus.clue_discovered.connect(_on_state_changed.unbind(1))
	EventBus.testimony_recorded.connect(_on_state_changed.unbind(1))
	EventBus.deduction_made.connect(_on_state_changed.unbind(1))
	EventBus.objectives_changed.connect(_on_state_changed)
	EventBus.time_changed.connect(_on_state_changed.unbind(2))
	EventBus.day_changed.connect(_on_state_changed.unbind(1))
	EventBus.location_changed.connect(_on_state_changed.unbind(1))
	_root.hide()
	_layout()


## Abre el expediente en una sección. Sin sección, vuelve a la última que se miró.
func open(tab: int = -1) -> void:
	if tab >= 0 and tab < _sections.size():
		_current_tab = tab as Tab
	is_open = true
	GameState.lock_player("expediente")
	_folder.footer.refresh_keys()
	_show_section(_current_tab)
	_root.show()
	_layout()
	_focus_current()
	_take_location_photo()


func close() -> void:
	if not is_open:
		return
	is_open = false
	GameState.unlock_player("expediente")
	var focused := _root.get_viewport().gui_get_focus_owner()
	if focused != null and _root.is_ancestor_of(focused):
		focused.release_focus()
	_root.hide()


func get_current_tab() -> int:
	return _current_tab


func get_section(tab: int) -> JournalSection:
	return _sections[tab]


func get_folder() -> JournalFolder:
	return _folder


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("open_journal") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
		return


# --- Secciones ---

func _build_sections() -> void:
	_sections = [
		JournalObjectivesSection.new(),
		JournalCluesSection.new(),
		JournalBasicSection.new("Testimonios", "testigos", JournalBasicSection.Kind.TESTIMONIES),
		JournalBasicSection.new("Sospechosos", "antifaz", JournalBasicSection.Kind.SUSPECTS),
		JournalBasicSection.new("Deducciones", "cerebro", JournalBasicSection.Kind.DEDUCTIONS),
	]
	var definitions: Array[Dictionary] = []
	for index in _sections.size():
		definitions.append({"title": TAB_TITLES[index], "icon": TAB_ICONS[index]})
		var section := _sections[index]
		section.hide()
		_folder.body.add_child(section)
		# El pie va bajo la ficha: se recoloca cuando la columna derecha cambia de sitio.
		section.side.item_rect_changed.connect(_update_footer)
	_folder.tabs.setup(definitions)


func _show_section(tab: int) -> void:
	_current_tab = tab as Tab
	_folder.tabs.select(tab)
	for index in _sections.size():
		_sections[index].visible = index == tab
	var section := _sections[tab]
	section.refresh()
	section.link_focus(_folder.tabs.get_tab(tab))
	_update_footer()


func _on_tab_changed(tab: int) -> void:
	_show_section(tab)


## Algo ha cambiado en la partida: si el expediente está abierto, la sección visible se pone al día
## (una sola vez por fotograma aunque lleguen varias señales).
func _on_state_changed() -> void:
	if not is_open or _refresh_pending:
		return
	_refresh_pending = true
	_refresh_current.call_deferred()


func _refresh_current() -> void:
	_refresh_pending = false
	if is_open:
		var section := _sections[_current_tab]
		section.refresh()
		section.link_focus(_folder.tabs.get_tab(_current_tab))


# --- Foco ---

## El foco va a la ficha elegida de la sección o, si no hay fichas, a su pestaña.
func _focus_current() -> void:
	if not _sections[_current_tab].focus_content():
		_folder.tabs.get_tab(_current_tab).grab_focus()


# --- Composición ---

## La carpeta ocupa la pantalla con un margen y sin pasar de un ancho máximo, centrada.
func _layout() -> void:
	var screen := _root.size
	var width := minf(screen.x - JournalStyle.FOLDER_MARGIN.x * 2.0, JournalStyle.FOLDER_MAX_WIDTH)
	var height := screen.y - JournalStyle.FOLDER_MARGIN.y * 2.0
	_folder.position = Vector2((screen.x - width) * 0.5, JournalStyle.FOLDER_MARGIN.y)
	_folder.size = Vector2(width, height)
	_folder.pivot_offset = _folder.size * 0.5
	_folder.relayout()
	_update_footer()


func _update_footer() -> void:
	if not _sections.is_empty():
		_folder.set_footer_left(_sections[_current_tab].get_footer_left())


## Fotografía sepia del lugar donde está el detective, para la sección de objetivos. Se hace con la
## misma cámara que las imágenes de las ranuras (`SavePreview`) y una sola vez por lugar.
func _take_location_photo() -> void:
	var objectives := _sections[Tab.OBJECTIVES] as JournalObjectivesSection
	var location_id := GameState.location_id
	if _photo_busy or objectives.get_photo_location() == location_id:
		return
	var game := get_parent() as Game
	if game == null:
		return
	var post_fx := game.get_node_or_null("PostFx") as PostFx
	var fog := post_fx.get_fog_amount() if post_fx != null else 0.0
	var viewport := SavePreview.build_viewport(game.camera.camera, fog)
	if viewport == null:
		return
	_photo_busy = true
	add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := SavePreview.read_image(viewport)
	viewport.queue_free()
	_photo_busy = false
	if image != null and GameState.location_id == location_id:
		objectives.set_location_photo(ImageTexture.create_from_image(image), location_id)
