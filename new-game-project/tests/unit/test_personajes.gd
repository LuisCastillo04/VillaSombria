extends TestCase
## Personajes con mallas de Blender (`CharacterModel` + `ModelCatalog.draw_in`): misma estructura,
## mismos pivotes, misma animación y la misma interfaz que con las mallas procedurales.

const PIVOTS := ["PiernaIzq", "PiernaDer", "Torso", "BrazoIzq", "BrazoDer", "Cabeza"]


func after_each() -> void:
	ModelCatalog.enabled = true
	ModelCatalog.clear()


## Los personajes que captura la herramienta de referencias (el detective y los de characters.json).
static func _characters() -> Array:
	var tool: Node = (load("res://tools/modelos/exportar_referencias.gd") as GDScript).new()
	var found: Array = tool.characters()
	tool.free()
	return found


func test_every_character_uses_its_model() -> void:
	var characters := _characters()
	check(characters.size() == 10, "El detective y los nueve NPC (%d)" % characters.size())
	for character: Array in characters:
		var model := CharacterModel.new()
		model.build(character[1], character[0])
		check(not model.get_model_id().is_empty(), "%s: usa su modelo de Blender" % character[0])
		for pivot_name: String in PIVOTS:
			var pivot := model.get_node_or_null(pivot_name) as Node3D
			check(pivot != null, "%s: tiene el pivote %s" % [character[0], pivot_name])
			if pivot != null:
				var meshes := pivot.find_children("*", "MeshInstance3D", false, false)
				check_equal(meshes.size(), 1, "%s/%s: una sola malla, como antes" % [character[0], pivot_name])
		model.free()


## Con modelo o sin él: mismos pivotes, en el mismo sitio, y la animación los mueve igual.
func test_pivots_and_animation_are_unchanged() -> void:
	for character: Array in _characters():
		var with_model := CharacterModel.new()
		with_model.build(character[1], character[0])
		ModelCatalog.enabled = false
		var procedural := CharacterModel.new()
		procedural.build(character[1], character[0])
		ModelCatalog.enabled = true
		check(procedural.get_model_id().is_empty(), "%s: el modo procedural no usa el modelo" % character[0])
		check(with_model.scale.is_equal_approx(procedural.scale), "%s: misma escala por estatura" % character[0])
		for model: CharacterModel in [with_model, procedural]:
			model.set_motion(0.8)
			model.set_talking(true)
			model.set_head_turn(0.5)
			model.set_head_tilt(-0.2)
			model.set_fade(0.25)
			for frame in 30:
				model._process(1.0 / 30.0)
		for pivot_name: String in PIVOTS:
			var a := with_model.get_node(pivot_name) as Node3D
			var b := procedural.get_node(pivot_name) as Node3D
			check(a.transform.is_equal_approx(b.transform), "%s/%s: mismo pivote y misma pose animada" % [character[0], pivot_name])
			var mesh_a := a.get_child(0) as GeometryInstance3D
			var mesh_b := b.get_child(0) as GeometryInstance3D
			check(is_equal_approx(mesh_a.transparency, mesh_b.transparency), "%s/%s: set_fade llega a la malla" % [character[0], pivot_name])
			var box_a := (a.get_child(0) as MeshInstance3D).get_aabb()
			var box_b := (b.get_child(0) as MeshInstance3D).get_aabb()
			check(box_a.position.distance_to(box_b.position) < 0.002 and box_a.size.distance_to(box_b.size) < 0.002,
				"%s/%s: misma caja (%s, %s)" % [character[0], pivot_name, box_a, box_b])
		with_model.free()
		procedural.free()


## Sin el GLB, el personaje se dibuja con su código y conserva la misma interfaz.
func test_missing_character_model_falls_back() -> void:
	ModelCatalog.paths["personaje_detective"] = "res://assets/modelos/personajes/no_existe.glb"
	ModelCatalog.clear()
	var model := CharacterModel.new()
	model.build(PlayerController.LOOK, "detective")
	check(model.get_model_id().is_empty(), "Sin GLB, el detective vuelve a las mallas procedurales")
	check_equal(model.get_child_count(), PIVOTS.size(), "Con sus seis pivotes")
	model.free()
	ModelCatalog.paths.erase("personaje_detective")
