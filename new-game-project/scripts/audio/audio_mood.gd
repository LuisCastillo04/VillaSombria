class_name AudioMood
extends RefCounted
## Qué pide la historia al sonido en cada momento. Sólo lee el estado de la partida y las reglas de
## `intensity` del catálogo; no cambia nada, así que se puede probar sin escena.
##
## La intensidad (0 a 1) no se guarda: se deduce del día, del lugar, de las marcas de la historia y de
## la hora. Por eso, al cargar una partida, el sonido vuelve exactamente al estado que le corresponde.


## Tensión de fondo que pide la historia: el día (el tercero es el del ultimátum), el lugar (la
## mansión es la escena del crimen), lo descubierto (marcas) y, en la calle, la noche.
static func story_intensity(rules: Dictionary, location_id: String, day: int, minutes: int,
		flags: Dictionary, outdoor: bool) -> float:
	var value := float((rules.get("days", {}) as Dictionary).get(str(day), 0.0))
	value += float((rules.get("locations", {}) as Dictionary).get(location_id, 0.0))
	var flag_rules: Dictionary = rules.get("flags", {})
	for flag: String in flag_rules:
		if flags.has(flag):
			value += float(flag_rules[flag])
	if outdoor and is_night(rules, minutes):
		value += float(rules.get("night", 0.0))
	return clampf(value, 0.0, float(rules.get("max", 1.0)))


## Si a esta hora es de noche según el catálogo (`night_from`, por defecto las 20:00).
static func is_night(rules: Dictionary, minutes: int) -> bool:
	return minutes >= GameClock.parse_time(String(rules.get("night_from", "20:00")))


## Pista y tensión que corresponden ahora, por orden de prioridad: una orden explícita
## (`override`), una pantalla que cambia la música (la acusación), la escena narrativa en curso, el
## caso ya resuelto y, por último, la música del lugar. `scene_id` vacío si no hay escena.
static func desired_music(catalog: AudioCatalog, location_id: String, base_intensity: float,
		locks: Array, scene_id: String, flags: Dictionary, override: String) -> Dictionary:
	var track := String(catalog.location(location_id).get("music", ""))
	var intensity := base_intensity
	var source := "lugar"
	var resolved: Dictionary = catalog.section("intensity").get("resolved", {})
	if not resolved.is_empty() and flags.has(String(resolved.get("flag", ""))) and location_id != "menu":
		track = String(resolved.get("music", track))
		source = "resuelto"
	if not scene_id.is_empty():
		var scene := catalog.scene(scene_id)
		if scene.has("music"):
			track = String(scene["music"])
			source = "escena"
		intensity = maxf(intensity, float(scene.get("intensity", 0.0)))
	for reason: String in locks:
		var screen := catalog.screen(reason)
		if screen.has("music"):
			track = String(screen["music"])
			intensity = maxf(intensity, float(screen.get("intensity", 0.0)))
			source = "pantalla"
	if not override.is_empty():
		track = "" if override == "silencio" else override
		source = "orden"
	return {"track": track, "intensity": clampf(intensity, 0.0, 1.0), "source": source}
