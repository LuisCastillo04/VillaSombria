class_name Atmosphere
extends RefCounted
## Crea el ambiente visual de los escenarios: entorno, luz lunar y tonos noir.

const EXTERIOR_BACKGROUND := Color("0a0e16")
const INTERIOR_BACKGROUND := Color("07080c")


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
	moon.name = "Luna"
	moon.rotation_degrees = Vector3(-52.0, 25.0, 0.0)
	moon.light_color = Color("8fa6cf")
	moon.light_energy = 0.42
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 90.0
	parent.add_child(moon)
	return moon


static func add_interior(parent: Node3D) -> void:
	var environment := _base_environment(INTERIOR_BACKGROUND)
	environment.ambient_light_color = Color("6f5a48")
	environment.ambient_light_energy = 0.42
	_attach_environment(parent, environment)


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
