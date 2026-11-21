extends TestCase
## Calidad de «Sombras e iluminación» y de «Efectos y partículas» con la escena de juego real: qué
## cambia en cada nivel, que «Alto» es el aspecto original, que ninguna luz se apaga, que el cambio
## llega a lo que ya existe y a lo que se crea después, y que la lluvia y la historia no cambian.

var game: Game


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	TestCase.reset_test_settings()
	game = await make_game()
	await game.go_to("plaza", "")


func after_each() -> void:
	game.queue_free()
	await get_tree().process_frame
	TestCase.reset_test_settings()
	GameState.reset()
	GameClock.reset()


func _lights() -> Array[Light3D]:
	var found: Array[Light3D] = []
	for node in get_tree().get_nodes_in_group(GraphicsQuality.LIGHT_GROUP):
		if game.is_ancestor_of(node):
			found.append(node as Light3D)
	return found


func _shadowed(lights: Array[Light3D]) -> int:
	return lights.filter(func(light: Light3D) -> bool: return light.shadow_enabled).size()


func _designed(lights: Array[Light3D]) -> int:
	return lights.filter(func(light: Light3D) -> bool: return bool(light.get_meta(GraphicsQuality.DESIGNED_SHADOW))).size()


func _environment() -> Environment:
	return (game.current_location.get_node("Ambiente") as WorldEnvironment).environment


func _rains() -> Array[Node]:
	return get_tree().get_nodes_in_group(GraphicsQuality.RAIN_GROUP).filter(func(node: Node) -> bool: return game.is_ancestor_of(node))


func test_high_quality_is_the_original_look() -> void:
	var lights := _lights()
	check(lights.size() >= 10, "la plaza registra sus farolas, ventanas y la luz exterior (%d)" % lights.size())
	check(_designed(lights) >= 2, "algunas luces piden sombras: la luz exterior y las farolas de la fuente")
	check_equal(_shadowed(lights), _designed(lights), "en Alto proyectan sombra todas las que la piden")
	for light in lights:
		if light is OmniLight3D:
			check_equal((light as OmniLight3D).omni_shadow_mode, OmniLight3D.SHADOW_CUBE, "las farolas usan su sombra cúbica original")
	check(_environment().glow_enabled, "el resplandor de las farolas sigue")
	check_equal(get_tree().root.positional_shadow_atlas_size, int(ProjectSettings.get_setting(GraphicsQuality.POSITIONAL_SIZE)), "el atlas de sombras es el del proyecto")
	var rain := _rains()
	check_equal(rain.size(), 1, "hay una sola lluvia")
	check_equal((rain[0] as RainEffect).amount, RainEffect.FULL_AMOUNT, "con todas sus gotas")
	var post: PostFx = game.get_node("PostFx")
	check_equal(post.get_fog_octaves(), 4, "la niebla con sus cuatro capas")
	check(is_equal_approx(post.get_grain(), PostFx.GRAIN), "y el grano de película")


func test_lower_lighting_levels_reduce_shadows_without_switching_lights_off() -> void:
	var lights := _lights()
	var energies := lights.map(func(light: Light3D) -> float: return light.light_energy)
	Settings.set_value("graficos/calidad_iluminacion", "medio")
	check_equal(_shadowed(lights), _designed(lights), "en Medio las sombras siguen")
	for light in lights:
		if light is OmniLight3D:
			check_equal((light as OmniLight3D).omni_shadow_mode, OmniLight3D.SHADOW_DUAL_PARABOLOID, "pero las farolas usan la sombra de dos caras, más barata")
	check_equal(get_tree().root.positional_shadow_atlas_size, int(ProjectSettings.get_setting(GraphicsQuality.POSITIONAL_SIZE)) / 2, "y el atlas de sombras es la mitad")
	check(_environment().glow_enabled, "el resplandor se mantiene")
	Settings.set_value("graficos/calidad_iluminacion", "bajo")
	check_equal(_shadowed(lights), 0, "en Bajo no hay sombras dinámicas")
	check(not _environment().glow_enabled, "ni resplandor")
	check_equal(get_tree().root.positional_shadow_atlas_size, int(ProjectSettings.get_setting(GraphicsQuality.POSITIONAL_SIZE)) / 4, "y el atlas es la cuarta parte")
	for index in lights.size():
		check(lights[index].visible and is_equal_approx(lights[index].light_energy, energies[index]), "ninguna luz se apaga ni pierde intensidad")
	Settings.set_value("graficos/calidad_iluminacion", "alto")
	check_equal(_shadowed(lights), _designed(lights), "al volver a Alto vuelven las sombras que se pedían")
	check(_environment().glow_enabled, "y el resplandor")


func test_new_locations_take_the_current_level() -> void:
	Settings.set_value("graficos/calidad_iluminacion", "bajo")
	await game.go_to("mansion", "")
	var lights := _lights()
	check(_designed(lights) >= 1, "la mansión pide sombras en alguna lámpara")
	check_equal(_shadowed(lights), 0, "y llega ya en Bajo")
	Settings.set_value("graficos/calidad_iluminacion", "alto")
	check_equal(_shadowed(lights), _designed(lights), "y cambia al momento")


func test_effects_levels_reduce_rain_and_post_processing() -> void:
	var post: PostFx = game.get_node("PostFx")
	Settings.set_value("graficos/calidad_efectos", "medio")
	var rain: RainEffect = _rains()[0]
	check_equal(rain.amount, GraphicsQuality.rain_amount(RainEffect.FULL_AMOUNT, "medio"), "en Medio caen menos gotas")
	check_equal(post.get_fog_octaves(), 3, "y la niebla tiene tres capas")
	Settings.set_value("graficos/calidad_efectos", "bajo")
	check(rain.amount < RainEffect.FULL_AMOUNT / 2, "en Bajo, menos de la mitad de las gotas (%d)" % rain.amount)
	check(rain.emitting and rain.is_inside_tree(), "pero sigue lloviendo")
	check_equal(post.get_fog_octaves(), 2, "la niebla se simplifica")
	check(is_equal_approx(post.get_grain(), 0.0), "y sin grano de película")
	check(is_equal_approx(post.get_fog_amount(), PostFx.OUTDOOR_FOG), "la cantidad de niebla del exterior no cambia")
	check_equal(_rains().size(), 1, "y no se duplica la lluvia")
	Settings.set_value("graficos/calidad_efectos", "alto")
	check_equal(rain.amount, RainEffect.FULL_AMOUNT, "en Alto vuelven todas las gotas")
	check_equal(post.get_fog_octaves(), 4, "y la niebla original")


func test_quality_does_not_change_the_weather_or_the_story() -> void:
	Settings.set_value("graficos/calidad_efectos", "bajo")
	Settings.set_value("graficos/calidad_iluminacion", "bajo")
	var minutes := GameClock.minutes
	await game.go_to("cafe", "")
	check(_rains().is_empty(), "dentro no llueve, como siempre")
	await game.go_to("plaza", "")
	check_equal(_rains().size(), 1, "al salir vuelve una sola lluvia")
	check_equal((_rains()[0] as RainEffect).amount, GraphicsQuality.rain_amount(RainEffect.FULL_AMOUNT, "bajo"), "con las gotas del nivel elegido")
	check_equal(GameClock.minutes, minutes, "el reloj no se mueve por cambiar la calidad")


func test_quality_levels_are_saved() -> void:
	Settings.set_value("graficos/calidad_iluminacion", "medio")
	Settings.set_value("graficos/calidad_efectos", "bajo")
	Settings.use_file(Settings.settings_path)
	check_equal(Settings.get_value("graficos/calidad_iluminacion"), "medio", "la iluminación persiste")
	check_equal(Settings.get_value("graficos/calidad_efectos"), "bajo", "y los efectos")
	check_equal(get_tree().root.positional_shadow_atlas_size, int(ProjectSettings.get_setting(GraphicsQuality.POSITIONAL_SIZE)) / 2, "y se aplican al leerlos")
