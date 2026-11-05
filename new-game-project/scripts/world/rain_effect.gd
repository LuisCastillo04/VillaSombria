class_name RainEffect
extends GPUParticles3D
## Lluvia que sigue al objetivo para cubrir sólo la zona visible.

const AREA := Vector3(34.0, 1.0, 34.0)
const HEIGHT := 16.0

var target: Node3D


func _init() -> void:
	name = "Lluvia"
	amount = 900
	lifetime = 0.75
	preprocess = 0.75
	local_coords = false
	visibility_aabb = AABB(Vector3(-30.0, -20.0, -30.0), Vector3(60.0, 40.0, 60.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = AREA * 0.5
	process.direction = Vector3(0.08, -1.0, 0.05)
	process.spread = 1.5
	process.initial_velocity_min = 22.0
	process.initial_velocity_max = 27.0
	process.gravity = Vector3.ZERO
	process_material = process

	var streak := QuadMesh.new()
	streak.size = Vector2(0.018, 0.75)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.72, 0.8, 0.95, 0.3)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = material
	draw_pass_1 = streak


func _process(_delta: float) -> void:
	if target != null:
		global_position = target.global_position + Vector3.UP * HEIGHT
