class_name JournalUi
extends CanvasLayer
## Expediente del detective: objetivos, pistas, testimonios, sospechosos y deducciones. Los datos
## los lee `JournalInfo`; aquí sólo se presentan.

enum Tab { OBJECTIVES, CLUES, TESTIMONIES, SUSPECTS, DEDUCTIONS }

const TAB_TITLES: Array[String] = ["Objetivos", "Pistas", "Testimonios", "Sospechosos", "Deducciones"]
## Lo usa también el tablero para las valoraciones de los sospechosos.
const STATUS_LABELS := JournalInfo.STATUS_LABELS

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
	_add_header(JournalInfo.day_title())
	var text := "[b]%s[/b]\n\n" % JournalInfo.day_title()
	for objective in JournalInfo.objectives():
		var done: bool = objective["state"] == JournalInfo.ObjectiveState.DONE
		_add_note("%s %s" % ["[x]" if done else "[ ]", objective["text"]])
	var stats := JournalInfo.stats()
	text += "Pistas: %d de %d\n" % [stats["clues"], stats["clues_total"]]
	text += "Testimonios: %d\n" % stats["testimonies"]
	text += "Deducciones: %d de %d\n\n" % [stats["deductions"], stats["deductions_total"]]
	for rule in JournalInfo.time_rules():
		var key: String = rule.get("key", "")
		text += ("[%s] " % key if not key.is_empty() else "") + rule["text"] + "\n"
	_show_detail(text, null)


func _fill_clues() -> void:
	var clues := JournalInfo.clues()
	if clues.is_empty():
		_add_note("Aún no hay pistas registradas.")
		return
	for clue in clues:
		var text := "[b]%s[/b]\n[i]%s · %s[/i]\n\n%s" % [clue["title"], clue["category"], clue["where"], clue["text"]]
		_add_entry(clue["title"], text, null)


func _fill_testimonies() -> void:
	var testimonies := JournalInfo.testimonies()
	if testimonies.is_empty():
		_add_note("Aún no hay declaraciones registradas.")
		return
	var speaker := ""
	for testimony in testimonies:
		if testimony["speaker"] != speaker:
			speaker = testimony["speaker"]
			_add_header(testimony["name"])
		var text := "[b]%s[/b]\n[i]%s[/i]\n\n«%s»" % [testimony["name"], testimony["topic"], testimony["text"]]
		_add_entry(testimony["topic"], text, _portrait_of(testimony["portrait"]))


func _fill_suspects() -> void:
	for suspect in JournalInfo.suspects():
		var text := "[b]%s[/b]\n[i]%s[/i]\n\n%s\n\n[b]Paradero:[/b] %s\n[b]Valoración:[/b] %s" % [
			suspect["name"], suspect["role"], suspect["bio"], suspect["whereabouts"], suspect["status_label"],
		]
		if not String(suspect["note"]).is_empty():
			text += "\n[b]Hipótesis:[/b] %s" % suspect["note"]
		_add_entry(suspect["name"], text, _portrait_of(suspect["portrait"]))


func _fill_deductions() -> void:
	var deductions := JournalInfo.deductions()
	if deductions.is_empty():
		_add_note("Aún no hay deducciones. Relaciona pruebas y testimonios en el tablero [%s]." % JournalInfo.key_name("open_board"))
		return
	for deduction in deductions:
		_add_entry(deduction["title"], "[b]%s[/b]\n[i]%s[/i]\n\n%s" % [deduction["title"], deduction["kind_label"], deduction["text"]], null)


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


func _portrait_of(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
