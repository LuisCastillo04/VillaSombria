class_name SettingsPanel
extends PanelContainer
## Panel de ajustes reutilizado por el menú principal y la pausa.

signal closed

const CHANNELS := {
	"Master": "Volumen general",
	"Musica": "Música",
	"Efectos": "Efectos",
	"Ambiente": "Lluvia y ambiente",
}

@onready var _rows: VBoxContainer = $Box/Rows
@onready var _fullscreen: CheckButton = $Box/Fullscreen
@onready var _vsync: CheckButton = $Box/Vsync
@onready var _close: Button = $Box/Close


func _ready() -> void:
	for bus_name: String in CHANNELS:
		var label := Label.new()
		label.text = CHANNELS[bus_name]
		_rows.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.volumes[bus_name]
		slider.value_changed.connect(_on_volume.bind(bus_name))
		_rows.add_child(slider)
	_fullscreen.button_pressed = Settings.fullscreen
	_fullscreen.toggled.connect(Settings.set_fullscreen)
	_vsync.button_pressed = Settings.vsync
	_vsync.toggled.connect(Settings.set_vsync)
	_close.pressed.connect(_on_close)


func _on_volume(value: float, bus_name: String) -> void:
	Settings.set_volume(bus_name, value)


func _on_close() -> void:
	AudioManager.play("click")
	hide()
	closed.emit()
