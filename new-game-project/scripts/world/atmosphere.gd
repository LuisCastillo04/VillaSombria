class_name Atmosphere
extends RefCounted
## Crea el ambiente visual de los escenarios: entorno, luz exterior y tonos noir.

const EXTERIOR_BACKGROUND := Color("0a0e16")
const INTERIOR_BACKGROUND := Color("07080c")

## Tramos del día en exteriores: hora de inicio, energía ambiental y luz principal.
const DAYLIGHT := [
	{"from": 8 * 60, "ambient": 0.95, "sky": 0.62, "color": Color("a9b6c9")},
	{"from": 13 * 60, "ambient": 0.78, "sky": 0.5, "color": Color("9fabc0")},
	{"from": 18 * 60, "ambient": 0.62, "sky": 0.45, "color": Color("9aa3c4")},
	{"from": 20 * 60, "ambient": 0.55, "sky": 0.42, "color": Color("8fa6cf")},
]


static func add_exterior(parent: Node3D) -> DirectionalLight3D:
	var environment := _base_environment(EXTERIOR_BACKGROUND)
	environment.ambient_light_color = Color("5a6d92")
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_light_color = Color("1c2536")
	environment.fog_light_energy = 1.0
	environment.fog_density = 0.006
	environment.fog_height = 1.5
	environment.fog_height_density = 0.05
	_attach_environment(parent, environment)

	var moon := DirectionalLight3D.new()
	moon.name = "LuzExterior"
	moon.rotation_degrees = Vector3(-52.0, 25.0, 0.0)
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 90.0
	parent.add_child(moon)
	apply_time_of_day(parent, GameClock.minutes)
	return moon


static func add_interior(parent: Node3D) -> void:
	var environment := _base_environment(INTERIOR_BACKGROUND)
	environment.ambient_light_color = Color("6f5a48")
	environment.ambient_light_energy = 0.42
	_attach_environment(parent, environment)


## Ajusta la luz exterior a la hora: amanece gris y anochece hacia el azul.
static func apply_time_of_day(parent: Node3D, minutes: int) -> void:
	var moon := parent.get_node_or_null("LuzExterior") as DirectionalLight3D
	var ambience := parent.get_node_or_null("Ambiente") as WorldEnvironment
	if moon == null or ambience == null:
		return
	var current: Dictionary = DAYLIGHT[0]
	for stage: Dictionary in DAYLIGHT:
		if minutes >= int(stage["from"]):
			current = stage
	ambience.environment.ambient_light_energy = current["ambient"]
	moon.light_energy = current["sky"]
	moon.light_color = current["color"]


static func _base_environment(background: Color) -> Environment:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = background
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.15
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.95
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 0.88
	return environment


static func _attach_environment(parent: Node3D, environment: Environment) -> void:
	var node := WorldEnvironment.new()
	node.name = "Ambiente"
	node.environment = environment
	parent.add_child(node)
