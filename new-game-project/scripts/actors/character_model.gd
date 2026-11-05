class_name CharacterModel
extends Node3D
## Personaje low-poly procedural. El aspecto se describe con un diccionario, de modo
## que el detective y todos los NPC comparten el mismo código y la misma animación.

const HIP_HEIGHT := 0.84
const SHOULDER_HEIGHT := 1.42
const NECK_HEIGHT := 1.5

const DEFAULT_LOOK := {
	"skin": "c9a27e",
	"coat": "2b2f3a",
	"pants": "1c1e26",
	"shoes": "15161b",
	"accent": "b9822e",
	"hair": "1a1a1a",
	"hair_style": "short",
	"hat": "none",
	"coat_length": "short",
	"dress": false,
	"extras": [],
	"height": 1.0,
}

var _torso: Node3D
var _head: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _motion := 0.0
var _phase := 0.0
var _clock := 0.0
var _talking := false


## Reconstruye el modelo a partir de una descripción parcial de aspecto.
func build(look: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var data := DEFAULT_LOOK.duplicate()
	data.merge(look, true)
	scale = Vector3.ONE * float(data["height"])

	_left_leg = _make_part("PiernaIzq", Vector3(-0.11, HIP_HEIGHT, 0.0), _build_leg.bind(data))
	_right_leg = _make_part("PiernaDer", Vector3(0.11, HIP_HEIGHT, 0.0), _build_leg.bind(data))
	_torso = _make_part("Torso", Vector3(0.0, HIP_HEIGHT, 0.0), _build_torso.bind(data))
	_left_arm = _make_part("BrazoIzq", Vector3(-0.27, SHOULDER_HEIGHT, 0.0), _build_arm.bind(data, false))
	_right_arm = _make_part("BrazoDer", Vector3(0.27, SHOULDER_HEIGHT, 0.0), _build_arm.bind(data, true))
	_head = _make_part("Cabeza", Vector3(0.0, NECK_HEIGHT, 0.0), _build_head.bind(data))


## Velocidad normalizada entre 0 y 1 que controla el ciclo de paso.
func set_motion(ratio: float) -> void:
	_motion = clampf(ratio, 0.0, 1.0)


func set_talking(value: bool) -> void:
	_talking = value


func _process(delta: float) -> void:
	if _torso == null:
		return
	_clock += delta
	if _motion > 0.02:
		_phase += delta * (5.0 + 7.0 * _motion)
	var stride := minf(_motion * 2.2, 1.0)
	var swing := sin(_phase) * 0.75 * stride
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.8
	_right_arm.rotation.x = swing * 0.8
	var lift := absf(sin(_phase)) * 0.045 * stride + sin(_clock * 1.7) * 0.006
	_torso.position.y = HIP_HEIGHT + lift
	_left_arm.position.y = SHOULDER_HEIGHT + lift
	_right_arm.position.y = SHOULDER_HEIGHT + lift
	_head.position.y = NECK_HEIGHT + lift
	if _talking:
		_head.rotation.x = sin(_clock * 7.0) * 0.06
	else:
		_head.rotation.x = lerpf(_head.rotation.x, 0.0, minf(delta * 6.0, 1.0))


func _make_part(part_name: String, offset: Vector3, builder: Callable) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part_name
	pivot.position = offset
	add_child(pivot)
	var batch := MeshBatcher.new(part_name.hash())
	batch.color_jitter = 0.012
	builder.call(batch)
	batch.attach_to(pivot, "Malla")
	return pivot


func _build_leg(batch: MeshBatcher, data: Dictionary) -> void:
	var pants := Color(data["pants"] as String)
	var shoes := Color(data["shoes"] as String)
	batch.box(Vector3(0.0, -0.39, 0.0), Vector3(0.15, 0.78, 0.17), pants)
	batch.box(Vector3(0.0, -0.79, -0.05), Vector3(0.16, 0.1, 0.28), shoes)


func _build_arm(batch: MeshBatcher, data: Dictionary, is_right: bool) -> void:
	var coat := Color(data["coat"] as String)
	var skin := Color(data["skin"] as String)
	batch.box(Vector3(0.0, -0.27, 0.0), Vector3(0.13, 0.56, 0.15), coat)
	batch.box(Vector3(0.0, -0.6, 0.0), Vector3(0.1, 0.11, 0.11), skin)
	var extras: Array = data["extras"]
	if is_right and extras.has("tray"):
		batch.cylinder(Vector3(0.05, -0.68, -0.12), 0.24, 0.24, 0.025, Color("9aa0aa"), 8)
	if is_right and extras.has("cigarette"):
		batch.box(Vector3(0.0, -0.64, -0.1), Vector3(0.02, 0.02, 0.12), Color("e0dccf"))


func _build_torso(batch: MeshBatcher, data: Dictionary) -> void:
	var coat := Color(data["coat"] as String)
	var accent := Color(data["accent"] as String)
	var extras: Array = data["extras"]
	batch.cylinder(Vector3.ZERO, 0.24, 0.31, 0.66, coat, 6)
	if bool(data["dress"]):
		batch.cylinder(Vector3(0.0, -0.74, 0.0), 0.44, 0.24, 0.76, coat.darkened(0.08), 7)
	match data["coat_length"]:
		"long":
			batch.cylinder(Vector3(0.0, -0.54, 0.0), 0.34, 0.25, 0.56, coat.darkened(0.08), 6)
			batch.box(Vector3(0.0, 0.02, 0.0), Vector3(0.5, 0.06, 0.42), coat.darkened(0.4))
		"tails":
			batch.box(Vector3(0.0, -0.3, 0.17), Vector3(0.34, 0.6, 0.06), coat.darkened(0.15))
	if extras.has("apron"):
		batch.box(Vector3(0.0, 0.26, -0.27), Vector3(0.26, 0.42, 0.03), Color("d6d2c8"))
		if bool(data["dress"]):
			batch.box(Vector3(0.0, -0.38, -0.33), Vector3(0.42, 0.74, 0.03), Color("d6d2c8"))
	if extras.has("scarf"):
		batch.cylinder(Vector3(0.0, 0.6, 0.0), 0.2, 0.17, 0.1, accent, 6)
		batch.box(Vector3(0.1, 0.42, -0.26), Vector3(0.1, 0.3, 0.04), accent)
	if extras.has("pearls"):
		for index in 7:
			var angle := PI * (float(index) / 6.0) + PI
			batch.sphere(Vector3(cos(angle) * 0.16, 0.58, sin(angle) * 0.17), 0.028, Color("e8e3d6"), 5, 3)
	if extras.has("bowtie"):
		batch.box(Vector3(0.0, 0.58, -0.26), Vector3(0.16, 0.07, 0.04), Color("0d0d10"))
		batch.box(Vector3(0.0, 0.4, -0.25), Vector3(0.14, 0.34, 0.02), Color("d8d4c9"))
	if extras.has("tie"):
		batch.box(Vector3(0.0, 0.42, -0.26), Vector3(0.14, 0.34, 0.02), Color("c9c4b6"))
		batch.box(Vector3(0.03, 0.4, -0.275), Vector3(0.05, 0.32, 0.02), accent)
	if extras.has("badge"):
		batch.box(Vector3(-0.13, 0.46, -0.26), Vector3(0.07, 0.09, 0.02), Color("c9a24d"))


func _build_head(batch: MeshBatcher, data: Dictionary) -> void:
	var skin := Color(data["skin"] as String)
	var hair := Color(data["hair"] as String)
	var accent := Color(data["accent"] as String)
	var extras: Array = data["extras"]
	batch.cylinder(Vector3.ZERO, 0.075, 0.075, 0.08, skin.darkened(0.12), 6)
	batch.sphere(Vector3(0.0, 0.2, 0.0), 0.165, skin, 7, 5, Vector3(0.95, 1.1, 1.0))
	batch.box(Vector3(0.0, 0.18, -0.17), Vector3(0.05, 0.07, 0.06), skin.darkened(0.08))
	_add_hair(batch, data["hair_style"] as String, hair)
	_add_hat(batch, data["hat"] as String, Color(data.get("hat_color", data["coat"]) as String), accent)
	if extras.has("mustache"):
		batch.box(Vector3(0.0, 0.13, -0.165), Vector3(0.15, 0.035, 0.04), hair)
	if extras.has("glasses"):
		batch.box(Vector3(-0.07, 0.22, -0.16), Vector3(0.09, 0.06, 0.02), Color("c9d2df"))
		batch.box(Vector3(0.07, 0.22, -0.16), Vector3(0.09, 0.06, 0.02), Color("c9d2df"))


func _add_hair(batch: MeshBatcher, style: String, hair: Color) -> void:
	var cap := Vector3(1.0, 0.8, 1.0)
	match style:
		"short":
			batch.sphere(Vector3(0.0, 0.25, 0.03), 0.17, hair, 7, 4, cap)
		"slick":
			batch.sphere(Vector3(0.0, 0.26, 0.03), 0.17, hair, 7, 4, cap)
			batch.box(Vector3(0.0, 0.36, -0.1), Vector3(0.2, 0.08, 0.14), hair)
		"bun":
			batch.sphere(Vector3(0.0, 0.26, 0.03), 0.17, hair, 7, 4, cap)
			batch.sphere(Vector3(0.0, 0.38, 0.1), 0.095, hair, 6, 4)
		"long":
			batch.sphere(Vector3(0.0, 0.26, 0.03), 0.175, hair, 7, 4, Vector3(1.05, 0.85, 1.0))
			batch.box(Vector3(0.0, 0.04, 0.12), Vector3(0.3, 0.36, 0.1), hair)
		"braid":
			batch.sphere(Vector3(0.0, 0.26, 0.03), 0.17, hair, 7, 4, cap)
			batch.box(Vector3(0.0, 0.0, 0.17), Vector3(0.07, 0.34, 0.07), hair)
		"curly":
			var puffs: Array[Vector3] = [
				Vector3(-0.1, 0.28, 0.02),
				Vector3(0.1, 0.28, 0.02),
				Vector3(0.0, 0.34, 0.03),
				Vector3(-0.13, 0.17, 0.06),
				Vector3(0.13, 0.17, 0.06),
				Vector3(0.0, 0.25, 0.12),
			]
			for puff in puffs:
				batch.sphere(puff, 0.095, hair, 6, 3)
		"bald":
			batch.box(Vector3(-0.15, 0.2, 0.03), Vector3(0.04, 0.12, 0.16), hair)
			batch.box(Vector3(0.15, 0.2, 0.03), Vector3(0.04, 0.12, 0.16), hair)


func _add_hat(batch: MeshBatcher, hat: String, color: Color, accent: Color) -> void:
	match hat:
		"fedora":
			batch.cylinder(Vector3(0.0, 0.31, 0.0), 0.3, 0.27, 0.03, color, 9)
			batch.cylinder(Vector3(0.0, 0.33, 0.0), 0.18, 0.15, 0.15, color, 7)
			batch.cylinder(Vector3(0.0, 0.335, 0.0), 0.185, 0.18, 0.045, accent, 7)
		"wide_brim":
			batch.cylinder(Vector3(0.0, 0.32, 0.0), 0.42, 0.38, 0.025, color, 10)
			batch.cylinder(Vector3(0.0, 0.34, 0.0), 0.15, 0.13, 0.1, color, 7)
			batch.cylinder(Vector3(0.0, 0.34, 0.0), 0.155, 0.15, 0.04, accent, 7)
		"kepi":
			batch.cylinder(Vector3(0.0, 0.3, 0.0), 0.18, 0.2, 0.15, color, 8)
			batch.box(Vector3(0.0, 0.31, -0.2), Vector3(0.26, 0.025, 0.12), Color("111318"))
			batch.cylinder(Vector3(0.0, 0.34, 0.0), 0.187, 0.19, 0.03, accent, 8)
		"cap":
			batch.cylinder(Vector3(0.0, 0.32, 0.0), 0.18, 0.21, 0.09, color, 8)
			batch.box(Vector3(0.0, 0.33, -0.2), Vector3(0.24, 0.025, 0.11), Color("111318"))
		"maid_cap":
			batch.box(Vector3(0.0, 0.34, -0.03), Vector3(0.26, 0.06, 0.12), Color("e6e2d8"))
			batch.box(Vector3(0.0, 0.385, -0.03), Vector3(0.18, 0.04, 0.09), Color("f0ece2"))
