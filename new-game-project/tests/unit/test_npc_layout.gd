extends TestCase
## Reparto de los NPC: en ningún momento del caso dos personajes comparten sitio, y todos los
## puntos donde se paran (puestos, rondas y visitas) están libres, lejos de las puertas y sin
## tapar pistas ni salidas. Cada escenario se carga solo: comparten el espacio físico.

const LOCATIONS := ["plaza", "cafe", "mansion", "archivo", "estacion"]
## Paso de la revisión de las rutinas, en minutos.
const STEP_MINUTES := 30


func before_each() -> void:
	GameState.reset()
	GameClock.reset()


func after_each() -> void:
	GameClock.reset()
	await get_tree().process_frame


func _load(location_id: String) -> LocationBase:
	var location: LocationBase = (load("res://scenes/world/locations/%s.tscn" % location_id) as PackedScene).instantiate()
	add_child(location)
	await wait_physics_frames(3)
	return location


func _unload(location: LocationBase) -> void:
	location.queue_free()
	await get_tree().process_frame


func test_npcs_never_share_a_spot() -> void:
	for location_id: String in LOCATIONS:
		var location := await _load(location_id)
		for day in range(1, 4):
			for minutes in range(GameClock.DAY_START, GameClock.DAY_LIMIT, STEP_MINUTES):
				var present := NpcSchedule.get_npcs_at(location_id, day, minutes)
				for npc_id in present:
					var slot := NpcSchedule.get_slot(npc_id, day, minutes)
					for other_id in present:
						if other_id == npc_id:
							continue
						var other_home := location.get_marker(NpcSchedule.get_slot(other_id, day, minutes)["marker"])
						for point: Vector3 in _stops(location, slot):
							var gap := _flat_distance(point, other_home)
							check(gap >= LocationBase.NPC_SPACING, "día %d %02d:%02d, %s: %s se para a %.1f m del puesto de %s" % [day, minutes / 60, minutes % 60, location_id, npc_id, gap, other_id])
		await _unload(location)


func test_every_stop_is_free_and_away_from_doors_and_clues() -> void:
	var checked := {}
	for location_id: String in LOCATIONS:
		var location := await _load(location_id)
		for npc_id: String in GameData.schedules:
			for slot: Dictionary in GameData.schedules[npc_id]:
				if slot["location"] != location_id:
					continue
				for marker_id: String in _stop_ids(slot):
					var key := "%s/%s" % [location_id, marker_id]
					if checked.has(key):
						continue
					checked[key] = true
					var point := location.get_marker(marker_id)
					check(location.has_marker(marker_id), "%s no existe" % key)
					check(location.is_standing_point(point, 0.35), "%s: el punto no está libre de obstáculos" % key)
					for doorway: Vector3 in location.get_doorways():
						check(_flat_distance(point, doorway) >= LocationBase.NPC_DOORWAY_CLEARANCE, "%s: tapa un hueco de paso" % key)
					for child in location.get_children():
						if child is Interactable:
							check(_flat_distance(point, (child as Node3D).global_position) >= LocationBase.NPC_INTERACTABLE_CLEARANCE, "%s: tapa «%s»" % [key, (child as Interactable).get_prompt()])
		await _unload(location)
	check(checked.size() > 15, "se revisan todos los puntos de las rutinas (%d)" % checked.size())


## Cada uno aparece mirando hacia donde tiene sentido, no todos hacia la pared del fondo.
func test_npcs_face_their_post() -> void:
	var cafe := await _load("cafe")
	var rosa := cafe.get_npc("rosa")
	check(rosa != null, "Rosa atiende la barra")
	if rosa != null:
		# Detrás de la barra mira hacia la clientela (+Z), no hacia las botellas.
		var facing := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, rosa.model.rotation.y)
		check(facing.z > 0.9, "Rosa mira hacia el salón (dirección %s)" % str(facing))
	await _unload(cafe)
	var plaza := await _load("plaza")
	var hilario := plaza.get_npc("hilario")
	check(hilario != null, "Hilario pasea por la plaza")
	if hilario != null:
		var toward_fountain := Vector3(3.5, 0.0, 3.0) - hilario.global_position
		toward_fountain.y = 0.0
		var looking := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, hilario.model.rotation.y)
		check(looking.dot(toward_fountain.normalized()) > 0.9, "Hilario mira la fuente")
	await _unload(plaza)


func test_stops_are_on_the_navigation_mesh() -> void:
	for location_id: String in LOCATIONS:
		var location := await _load(location_id)
		var ready := false
		for frame in 120:
			if location.navigation.is_map_ready():
				ready = true
				break
			await get_tree().physics_frame
		check(ready, "%s: la navegación debe estar lista" % location_id)
		for npc_id: String in GameData.schedules:
			for slot: Dictionary in GameData.schedules[npc_id]:
				if slot["location"] != location_id:
					continue
				for marker_id: String in _stop_ids(slot):
					check(location.navigation.is_on_floor_mesh(location.get_marker(marker_id)), "%s/%s fuera de la malla de navegación" % [location_id, marker_id])
		await _unload(location)


func test_schedule_behaviours_are_valid() -> void:
	for npc_id: String in GameData.schedules:
		var ambient: Dictionary = GameData.characters[npc_id].get("ambient", {})
		check(not ambient.is_empty(), "%s necesita su bloque «ambient»" % npc_id)
		check(NpcProfile.ROLES.has(ambient.get("role", "")), "%s: papel desconocido «%s»" % [npc_id, ambient.get("role", "")])
		for slot: Dictionary in GameData.schedules[npc_id]:
			if slot.has("behavior"):
				check(NpcProfile.is_mode(slot["behavior"]), "%s: comportamiento desconocido «%s»" % [npc_id, slot["behavior"]])
			if slot.has("patrol"):
				check((slot["patrol"] as Array).size() >= 2, "%s: una ronda necesita dos puntos" % npc_id)
				check((slot["patrol"] as Array).has(slot["marker"]), "%s: la ronda pasa por su puesto" % npc_id)
	# No todos hacen lo mismo: hay quien se queda, quien pasea y quien hace la ronda.
	var modes := {}
	for npc_id: String in GameData.schedules:
		for slot: Dictionary in GameData.schedules[npc_id]:
			if slot["location"] != "none":
				modes[NpcProfile.build(GameData.characters[npc_id]["ambient"], slot).mode] = true
	check_equal(modes.size(), 3, "se usan los tres modos de comportamiento")


func _stop_ids(slot: Dictionary) -> Array[String]:
	var ids: Array[String] = [slot["marker"]]
	for key: String in ["patrol", "visits"]:
		for marker_id: String in slot.get(key, []):
			if not ids.has(marker_id):
				ids.append(marker_id)
	return ids


func _stops(location: LocationBase, slot: Dictionary) -> Array[Vector3]:
	var points: Array[Vector3] = []
	for marker_id in _stop_ids(slot):
		points.append(location.get_marker(marker_id))
	return points


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
