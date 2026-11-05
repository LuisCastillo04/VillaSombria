class_name JournalUi
extends CanvasLayer
## Expediente del detective: objetivos, pistas, testimonios, sospechosos y deducciones.

enum Tab { OBJECTIVES, CLUES, TESTIMONIES, SUSPECTS, DEDUCTIONS }

const TAB_TITLES: Array[String] = ["Objetivos", "Pistas", "Testimonios", "Sospechosos", "Deducciones"]
const STATUS_LABELS := {
	"": "Sin valorar",
	"sospechoso": "Sospechoso",
	"descartado": "Descartado",
	"principal": "Principal sospechoso",
}

var is_open := false
var _current_tab := Tab.OBJECTIVES

@onready var _root: Control = $Root
@onready var _heading: Label = $Root/Folder/Margin/Box/Heading
@onready var _tabs: TabBar = $Root/Folder/Margin/Box/Tabs
@onready var _list: VBoxContainer = $Root/Folder/Margin/Box/Content/ListScroll/List
@onready var _portrait: TextureRect = $Root/Folder/Margin/Box/Content/Detail/Portrait
@onready var _detail: RichTextLabel = $Root/Folder/Margin/Box/Content/Detail/Text


func _ready() -> void:
	_root.theme = UiTheme.get_theme()
	_heading.add_theme_font_override("font", UiTheme.serif())
	_heading.add_theme_font_size_override("font_size", 34)
	_heading.add_theme_color_override("font_color", UiTheme.STAMP)
	for title in TAB_TITLES:
		_tabs.add_tab(title)
	_tabs.tab_changed.connect(_on_tab_changed)
	_root.hide()


func open(tab: Tab = Tab.OBJECTIVES) -> void:
	is_open = true
	GameState.lock_player("expediente")
	_root.show()
	_tabs.current_tab = tab
	_on_tab_changed(tab)


func close() -> void:
	is_open = false
	GameState.unlock_player("expediente")
	_root.hide()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("open_journal") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _on_tab_changed(tab: int) -> void:
	_current_tab = tab as Tab
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_show_detail("", null)
	match _current_tab:
		Tab.OBJECTIVES:
			_fill_objectives()
		Tab.CLUES:
			_fill_clues()
		Tab.TESTIMONIES:
			_fill_testimonies()
		Tab.SUSPECTS:
			_fill_suspects()
		Tab.DEDUCTIONS:
			_fill_deductions()


func _fill_objectives() -> void:
	_add_header(StoryDirector.get_day_title())
	var text := "[b]%s[/b]\n\n" % StoryDirector.get_day_title()
	for objective in StoryDirector.get_objectives():
		var mark := "[x]" if bool(objective["done"]) else "[ ]"
		_add_note("%s %s" % [mark, objective["text"]])
	text += "Pistas: %d de %d\n" % [GameState.clues.size(), GameData.clues.size()]
	text += "Testimonios: %d\n" % GameState.testimonies.size()
	text += "Deducciones: %d de %d\n\n" % [GameState.deductions.size(), GameData.deductions.size()]
	text += "El tiempo sólo avanza con tus acciones: ninguna prueba se pierde por llegar tarde. Cada personaje sigue su rutina; consulta su paradero en la pestaña Sospechosos."
	_show_detail(text, null)


func _fill_clues() -> void:
	if GameState.clues.is_empty():
		_add_note("Aún no hay pistas registradas.")
		return
	for clue_id in GameState.clues:
		var clue: Dictionary = GameData.clues[clue_id]
		var text := "[b]%s[/b]\n[i]%s · %s[/i]\n\n%s" % [
			clue["name"],
			ClueInspector.CATEGORY_LABELS.get(clue["category"], "PRUEBA"),
			clue["where"],
			clue["description"],
		]
		_add_entry(clue["name"], text, null)


func _fill_testimonies() -> void:
	if GameState.testimonies.is_empty():
		_add_note("Aún no hay declaraciones registradas.")
		return
	for character_id: String in GameData.characters:
		var header_added := false
		for testimony_id in GameState.testimonies:
			var testimony: Dictionary = GameData.testimonies[testimony_id]
			if testimony["speaker"] != character_id:
				continue
			if not header_added:
				_add_header(GameData.get_character_name(character_id))
				header_added = true
			var text := "[b]%s[/b]\n[i]%s[/i]\n\n«%s»" % [
				GameData.get_character_name(character_id),
				testimony["topic"],
				testimony["text"],
			]
			_add_entry(testimony["topic"], text, _portrait_of(character_id))


func _fill_suspects() -> void:
	for suspect_id in GameData.get_suspects():
		var character: Dictionary = GameData.characters[suspect_id]
		var hypothesis: Dictionary = GameState.hypotheses.get(suspect_id, {})
		var status: String = hypothesis.get("status", "")
		var text := "[b]%s[/b]\n[i]%s[/i]\n\n%s\n\n[b]Paradero:[/b] %s\n[b]Valoración:[/b] %s" % [
			character["name"],
			character["role"],
			character["bio"],
			StoryDirector.describe_whereabouts(suspect_id),
			STATUS_LABELS.get(status, status),
		]
		var note: String = hypothesis.get("note", "")
		if not note.is_empty():
			text += "\n[b]Hipótesis:[/b] %s" % note
		_add_entry(character["name"], text, _portrait_of(suspect_id))


func _fill_deductions() -> void:
	if GameState.deductions.is_empty():
		_add_note("Aún no hay deducciones. Relaciona pruebas y testimonios en el tablero [B].")
		return
	for deduction_id in GameState.deductions:
		var deduction: Dictionary = GameData.deductions[deduction_id]
		var kind := "Contradicción" if deduction["kind"] == "contradiccion" else "Conexión"
		_add_entry(deduction["title"], "[b]%s[/b]\n[i]%s[/i]\n\n%s" % [deduction["title"], kind, deduction["text"]], null)


func _add_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.serif())
	label.add_theme_color_override("font_color", UiTheme.STAMP)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(label)


func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_list.add_child(label)


func _add_entry(label: String, detail: String, portrait: Texture2D) -> void:
	var button := Button.new()
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(_show_detail.bind(detail, portrait))
	_list.add_child(button)
	if _detail.text.is_empty():
		_show_detail(detail, portrait)


func _show_detail(text: String, portrait: Texture2D) -> void:
	_detail.text = text
	_portrait.texture = portrait
	_portrait.visible = portrait != null


func _portrait_of(character_id: String) -> Texture2D:
	return load(GameData.characters[character_id]["portrait"]) as Texture2D
