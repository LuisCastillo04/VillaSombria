extends TestCase
## Sonido adaptativo: catálogo completo, archivos que se cargan, bucles, paisajes sonoros sin
## duplicados, fundidos que liberan lo anterior, música que no se reinicia, atenuación en los
## diálogos, pausa amortiguada, fragmentos de la investigación, campanadas, puertas y la integración
## con la escena de juego y con el guardado.
##
## Varias pruebas miden la señal real que mezcla el servidor de audio (con `AudioEffectCapture`): en
## modo headless Godot usa el controlador «Dummy», que también mezcla.

const FAST_FADES := {"location": 0.1, "music": 0.1, "silence": 0.1, "intensity": 0.1, "duck": 0.1, "unduck": 0.1}

var _saved_fades: Dictionary = {}
var _capture: AudioEffectCapture
var _capture_bus := -1


func before_each() -> void:
	GameState.reset()
	GameClock.reset()
	AudioManager.reset()
	_saved_fades = (AudioManager.catalog.data["fades"] as Dictionary).duplicate()
	AudioManager.catalog.data["fades"] = FAST_FADES.duplicate()


func after_each() -> void:
	_remove_capture()
	AudioManager.catalog.data["fades"] = _saved_fades
	GameState.reset()
	GameClock.reset()
	AudioManager.reset()
	TestCase.clear_save_storage()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --- Catálogo y archivos ---

func test_catalog_is_coherent_and_covers_every_location() -> void:
	var problems := AudioManager.catalog.validate(GameData.locations.keys())
	check(problems.is_empty(), "el catálogo no tiene problemas: %s" % str(problems))
	for id: String in GameData.locations:
		check(not AudioManager.catalog.location(id).is_empty(), "%s tiene paisaje sonoro" % id)
	check(not AudioManager.catalog.location("menu").is_empty(), "y el menú principal también")


func test_every_referenced_file_loads_with_sound() -> void:
	var files := AudioManager.catalog.referenced_files()
	check(files.size() >= 100, "el catálogo nombra todos los archivos (%d)" % files.size())
	for path in files:
		var stream := load(path) as AudioStream
		check(stream != null, "se carga %s" % path)
		if stream != null:
			check(stream.get_length() > 0.02, "%s dura algo" % path)


func test_loops_loop_and_tension_layers_match_their_music() -> void:
	var catalog := AudioManager.catalog
	for id: String in catalog.section("music"):
		var entry := catalog.music(id)
		var base := catalog.loop_stream(entry["base"]) as AudioStreamOggVorbis
		check(base != null and base.loop, "la pista %s se repite" % id)
		if entry.has("tension"):
			var tension := catalog.loop_stream(entry["tension"]) as AudioStreamOggVorbis
			check(tension != null and tension.loop, "su capa de tensión también")
			check(absf(base.get_length() - tension.get_length()) < 0.002,
				"%s: la capa de tensión dura exactamente lo mismo (%.4f / %.4f)" % [id, base.get_length(), tension.get_length()])
	for id: String in catalog.section("ambience"):
		var stream := catalog.loop_stream(catalog.ambience(id)["file"]) as AudioStreamOggVorbis
		check(stream != null and stream.loop, "el ambiente %s se repite" % id)


func test_old_sound_names_still_work() -> void:
	for id in ["click", "tecla", "pista"]:
		check(AudioManager.catalog.has_sound(id), "«%s» sigue existiendo" % id)
	check(AudioManager.play("click"), "y suena")


# --- Intensidad narrativa (lógica pura) ---

func test_story_intensity_grows_with_the_case() -> void:
	var rules: Dictionary = AudioManager.catalog.section("intensity")
	var day_one := AudioMood.story_intensity(rules, "plaza", 1, 9 * 60, {}, true)
	var day_two := AudioMood.story_intensity(rules, "plaza", 2, 9 * 60, {}, true)
	var day_three := AudioMood.story_intensity(rules, "plaza", 3, 9 * 60, {}, true)
	check(is_zero_approx(day_one), "el primer día por la mañana la calle está tranquila")
	check(day_two > day_one and day_three > day_two, "cada día hay más tensión")
	var mansion := AudioMood.story_intensity(rules, "mansion", 1, 9 * 60, {}, false)
	check(mansion > day_one, "la escena del crimen siempre inquieta")
	var known := AudioMood.story_intensity(rules, "plaza", 2, 9 * 60, {"hora_real_conocida": true}, true)
	check(known > day_two, "saber que el reloj miente la sube")
	var night := AudioMood.story_intensity(rules, "plaza", 2, 21 * 60, {}, true)
	check(night > day_two, "la noche en la calle la sube")
	var night_inside := AudioMood.story_intensity(rules, "cafe", 2, 21 * 60, {}, false)
	check(is_equal_approx(night_inside, day_two), "pero no dentro del café")
	var everything := AudioMood.story_intensity(rules, "mansion", 3, 22 * 60, {"ortega_briefing": true, "hora_real_conocida": true}, false)
	check(everything <= float(rules["max"]) + 0.001, "nunca pasa del máximo")


func test_music_priorities() -> void:
	var catalog := AudioManager.catalog
	var plain := AudioMood.desired_music(catalog, "cafe", 0.2, [], "", {}, "")
	check_equal(plain["track"], "cafe", "en el café suena su música")
	var call := AudioMood.desired_music(catalog, "cafe", 0.2, ["dialogo"], "llamada", {}, "")
	check_equal(call["track"], "", "la llamada se oye en silencio")
	var accusation := AudioMood.desired_music(catalog, "mansion", 0.3, ["acusacion"], "", {}, "")
	check_equal(accusation["track"], "acusacion", "la acusación tiene su música")
	check(float(accusation["intensity"]) >= 0.35, "con tensión")
	var climax := AudioMood.desired_music(catalog, "mansion", 0.3, ["dialogo"], "confrontacion", {}, "")
	check_equal(climax["track"], "acusacion", "la confrontación sigue con la misma pieza")
	check(is_equal_approx(float(climax["intensity"]), 1.0), "a plena tensión")
	var solved := AudioMood.desired_music(catalog, "plaza", 0.5, [], "", {"caso_resuelto": true}, "")
	check_equal(solved["track"], "epilogo", "con el caso resuelto suena el epílogo")
	var menu := AudioMood.desired_music(catalog, "menu", 0.0, [], "", {"caso_resuelto": true}, "")
	check_equal(menu["track"], "menu", "el menú conserva su tema")
	var silenced := AudioMood.desired_music(catalog, "plaza", 0.0, [], "", {}, "silencio")
	check_equal(silenced["track"], "", "una orden de silencio manda sobre todo")


# --- Paisajes sonoros ---

func test_entering_the_same_place_twice_does_not_duplicate_or_restart() -> void:
	AudioManager.enter_location("cafe")
	await _wait(0.3)
	var layers := AudioManager.ambience.active_layers()
	var murmur := AudioManager.ambience.get_layer_player("sala_cafe")
	check(murmur != null and murmur.playing, "el murmullo del café suena")
	AudioManager.enter_location("cafe")
	await _wait(0.3)
	check_equal(AudioManager.ambience.active_layers().size(), layers.size(), "las mismas capas, sin duplicar")
	check(AudioManager.ambience.get_layer_player("sala_cafe") == murmur, "el murmullo no se reinicia")
	check_equal(AudioManager.ambience.live_players(), layers.size(), "ningún reproductor de más")


func test_changing_place_crossfades_and_releases_the_previous_one() -> void:
	AudioManager.enter_location("mansion")
	await _wait(0.3)
	check(AudioManager.ambience.active_layers().has("casa_grande"), "la mansión suena a casa grande")
	check_equal(AudioManager.ambience.active_emitters(), 2, "con el reloj de pie y la chimenea")
	AudioManager.enter_location("plaza")
	check(AudioManager.ambience.active_layers().has("lluvia_calle"), "la lluvia de la calle entra enseguida")
	var wanted := AudioManager.ambience.active_layers().size() + AudioManager.ambience.active_emitters()
	check(AudioManager.ambience.live_players() > wanted, "mientras tanto la mansión se apaga con un fundido")
	await _wait(0.4)
	check(not AudioManager.ambience.active_layers().has("casa_grande"), "la mansión ya no suena")
	check_equal(AudioManager.ambience.active_emitters(), 1, "la fuente sustituye al reloj y la chimenea")
	check_equal(AudioManager.ambience.live_players(), wanted, "y los reproductores de la mansión se han liberado")


func test_rain_continues_between_outdoor_places() -> void:
	AudioManager.enter_location("plaza")
	await _wait(0.3)
	var rain := AudioManager.ambience.get_layer_player("lluvia_calle")
	AudioManager.enter_location("estacion")
	await _wait(0.3)
	check(AudioManager.ambience.get_layer_player("lluvia_calle") == rain, "la lluvia sigue sin cortarse de la plaza a la estación")


func test_same_track_is_not_restarted_between_places() -> void:
	AudioManager.enter_location("plaza")
	AudioManager.refresh_music_now()
	await _wait(0.2)
	var player := AudioManager.music.get_current_player()
	check_equal(AudioManager.music.track_id, "pueblo", "en la plaza suena la música del pueblo")
	AudioManager.enter_location("estacion")
	AudioManager.refresh_music_now()
	await _wait(0.2)
	check(AudioManager.music.get_current_player() == player, "en la estación sigue la misma, sin reiniciar")
	AudioManager.enter_location("mansion")
	AudioManager.refresh_music_now()
	check_equal(AudioManager.music.track_id, "mansion", "la mansión cambia de pieza")
	await _wait(0.3)
	check_equal(AudioManager.music.active_players(), 1, "y la anterior se libera tras el fundido")


func test_details_and_night_layers() -> void:
	AudioManager.enter_location("cafe")
	var played := AudioManager.ambience.play_detail_now()
	check(played in ["taza_plato", "cucharilla", "silla", "cafetera", "caja_registradora"], "un detalle propio del café (%s)" % played)
	GameClock.minutes = 21 * 60
	AudioManager.enter_location("plaza")
	check(AudioManager.ambience.active_layers().has("viento_noche"), "de noche sopla el viento en la plaza")
	GameClock.minutes = 10 * 60
	AudioManager.enter_location("plaza")
	await _wait(0.3)
	check(not AudioManager.ambience.active_layers().has("viento_noche"), "de día no")


func test_hour_chime_in_the_square() -> void:
	AudioManager.enter_location("plaza")
	EventBus.time_changed.emit(1, 9 * 60 + 55)
	EventBus.time_changed.emit(1, 10 * 60 + 5)
	await _wait(1.5)
	check(AudioManager.effects.history.has("campana_torre"), "la torre da la hora")
	AudioManager.effects.history.clear()
	EventBus.time_changed.emit(1, 10 * 60 + 15)
	await _wait(1.5)
	check(not AudioManager.effects.history.has("campana_torre"), "sin cambiar de hora no hay campanada")
	AudioManager.enter_location("estacion")
	EventBus.time_changed.emit(1, 10 * 60 + 55)
	EventBus.time_changed.emit(1, 11 * 60 + 5)
	await _wait(1.5)
	check(not AudioManager.effects.history.has("campana_torre"), "en la estación no hay torre")


# --- Situaciones ---

func test_dialogue_ducks_music_and_ambience_and_restores_them() -> void:
	AudioManager.enter_location("plaza")
	AudioManager.refresh_music_now()
	GameState.lock_player("dialogo")
	await _wait(0.3)
	check(AudioManager.music.duck_db < -6.0, "la música baja durante el diálogo (%.1f dB)" % AudioManager.music.duck_db)
	check(AudioManager.ambience.duck_db < -3.0, "el ambiente también")
	check(not AudioManager.ambience.details_enabled, "y no hay detalles que distraigan")
	check_equal(AudioManager.music.track_id, "pueblo", "sin cambiar de pieza")
	GameState.unlock_player("dialogo")
	await _wait(0.3)
	check(is_zero_approx(AudioManager.music.duck_db), "al terminar vuelve la música")
	check(AudioManager.ambience.details_enabled, "y los detalles")


func test_pause_muffles_and_restores() -> void:
	AudioManager.enter_location("plaza")
	GameState.lock_player("pausa")
	await _wait(0.5)
	check(AudioManager.muffled and AudioManager.is_lowpass_enabled(), "la pausa amortigua la música y el ambiente")
	check(AudioManager.effects.history.has("pausa_abrir"), "y suena al abrirse")
	GameState.unlock_player("pausa")
	await _wait(0.9)
	check(not AudioManager.muffled and not AudioManager.is_lowpass_enabled(), "al volver, el filtro se retira")
	check(AudioManager.effects.history.has("pausa_cerrar"), "y suena al cerrarse")


func test_clearing_all_locks_at_once_is_silent() -> void:
	GameState.lock_player("pausa")
	GameState.lock_player("expediente")
	AudioManager.effects.history.clear()
	GameState.clear_player_locks()
	check(not AudioManager.effects.history.has("pausa_cerrar"), "cargar o volver al menú no hace sonar cada pantalla")


func test_investigation_events_play_their_sounds() -> void:
	AudioManager.enter_location("archivo")
	AudioManager.refresh_music_now()
	EventBus.clue_discovered.emit("transferencia")
	check(AudioManager.effects.history.has("pista_descubierta"), "una pista nueva tiene su fragmento")
	await _wait(0.5)
	check(AudioManager.music.get_current_volume_db() < -10.0, "que baja un momento la música de fondo")
	EventBus.deduction_made.emit("d_hora_falsa")
	check(AudioManager.effects.history.has("deduccion"), "una deducción tiene el suyo")
	EventBus.testimony_recorded.emit("t_lucia_escalera")
	check(AudioManager.effects.history.has("testimonio"), "un testimonio se anota con la pluma")
	var before := AudioManager.get_debug_state()["desired"]["intensity"] as float
	EventBus.notification_requested.emit("Rumores", "Algo pasa.", "historia")
	check(AudioManager.effects.history.has("suceso"), "un suceso de la historia suena inquietante")
	check(float(AudioManager.get_debug_state()["desired"]["intensity"]) > before, "y sube la tensión un rato")


func test_accusation_and_story_scenes_change_the_music() -> void:
	AudioManager.enter_location("mansion")
	AudioManager.refresh_music_now()
	GameState.lock_player("acusacion")
	AudioManager.refresh_music_now()
	check_equal(AudioManager.music.track_id, "acusacion", "la acusación cambia la música")
	GameState.unlock_player("acusacion")
	AudioManager.refresh_music_now()
	check_equal(AudioManager.music.track_id, "mansion", "al cancelarla vuelve la de la mansión")
	GameState.set_flag("caso_resuelto")
	AudioManager.refresh_music_now()
	check_equal(AudioManager.music.track_id, "epilogo", "resuelto el caso suena el epílogo")


func test_doors_and_streets_sound_on_the_way() -> void:
	AudioManager.enter_location("plaza")
	EventBus.location_change_requested.emit("cafe", "desde_plaza")
	check(AudioManager.effects.history.has("puerta_cafe"), "la puerta del café tiene su campanilla")
	AudioManager.enter_location("cafe")
	EventBus.location_change_requested.emit("plaza", "desde_cafe")
	check(AudioManager.effects.history.has("puerta_salida"), "salir a la calle")
	AudioManager.enter_location("plaza")
	EventBus.location_change_requested.emit("estacion", "desde_plaza")
	check(AudioManager.effects.history.has("pasos_calle"), "de la plaza a la estación se va andando")


func test_focus_sounds_only_when_the_player_navigates() -> void:
	var button := Button.new()
	add_child(button)
	AudioManager.effects.history.clear()
	button.grab_focus()
	check(not AudioManager.effects.history.has("ui_mover"), "un foco puesto por el juego no suena")
	button.release_focus()
	var event := InputEventAction.new()
	event.action = "ui_down"
	event.pressed = true
	AudioManager._input(event)
	button.grab_focus()
	check(AudioManager.effects.history.has("ui_mover"), "moverse por el menú sí")
	button.queue_free()


func test_effects_respect_cooldown_and_instances() -> void:
	check(AudioManager.play("ui_mover"), "suena la primera vez")
	check(not AudioManager.play("ui_mover"), "repetido al instante se ignora")
	check(not AudioManager.play("no_existe"), "un efecto desconocido no suena ni rompe nada")
	for index in 20:
		AudioManager.effects.play("tecla", {"force": true})
	check(AudioManager.effects.count_playing("tecla") <= 2, "nunca más copias de las permitidas")
	check(AudioManager.effects.playing_voices() <= AudioEffects.VOICES, "ni más voces que las del grupo")


# --- Señal real ---

func test_real_output_is_audible_and_dialogue_lowers_it() -> void:
	_add_capture("Musica")
	AudioManager.enter_location("menu")
	await _wait(0.6)
	var loud := await _measure(0.5)
	check(loud > -45.0, "el tema del menú se oye de verdad (%.1f dBFS)" % loud)
	GameState.lock_player("dialogo")
	await _wait(0.4)
	var ducked := await _measure(0.5)
	check(ducked < loud - 5.0, "en un diálogo la música baja de verdad (%.1f → %.1f dBFS)" % [loud, ducked])


func test_tension_layer_volume_changes_while_playing() -> void:
	_add_capture("Musica")
	AudioManager.enter_location("plaza")
	AudioManager.refresh_music_now()
	await _wait(0.4)
	var player := AudioManager.music.get_current_player()
	var sync := player.stream as AudioStreamSynchronized
	check(sync != null, "la música del pueblo lleva su capa de tensión sincronizada")
	if sync == null:
		return
	# Sólo la capa de tensión: callada primero y a pleno después, sin reiniciar la pista.
	AudioManager.music.set_intensity(0.0, 0.0)
	sync.set_sync_stream_volume(0, -80.0)
	await _wait(0.3)
	var silent := await _measure(0.4)
	sync.set_sync_stream_volume(1, 0.0)
	await _wait(0.3)
	var tense := await _measure(0.4)
	check(tense > silent + 20.0, "la capa de tensión entra en plena reproducción (%.1f → %.1f dBFS)" % [silent, tense])
	check(player.playing, "sin detener la pista")


# --- Integración con el juego ---

func test_game_scene_drives_the_soundscape() -> void:
	var game := await make_game()
	check_equal(AudioManager.location_id, "estacion", "la partida empieza sonando a estación")
	check(get_viewport().get_audio_listener_3d() != null, "el detective lleva el oído")
	check_equal(AudioManager.ambience.active_emitters(), 1, "la locomotora suena en su sitio")
	game.go_to("plaza", "desde_estacion")
	await _wait(1.6)
	check_equal(AudioManager.location_id, "plaza", "al cambiar de escenario cambia el sonido")
	check(AudioManager.ambience.active_layers().has("lluvia_calle"), "con la lluvia de la calle")
	check_equal(AudioManager.ambience.active_emitters(), 1, "y la fuente en lugar de la locomotora")
	game.queue_free()
	await get_tree().process_frame


func test_loading_a_game_restores_the_right_sound_without_duplicates() -> void:
	SaveSystem.use_storage("user://pruebas_guardado/ranuras")
	var game := await make_game()
	game.go_to("mansion", "desde_plaza")
	await _wait(1.6)
	GameClock.day = 3
	check(await save_and_wait("manual_1"), "se guarda en la mansión")
	game.queue_free()
	await get_tree().process_frame
	AudioManager.enter_location("menu")
	AudioManager.refresh_music_now()
	check(SaveSystem.request_load("manual_1")["ok"], "se pide la carga")
	var loaded := await make_game()
	AudioManager.refresh_music_now()
	await _wait(0.4)
	check_equal(AudioManager.location_id, "mansion", "al cargar suena la mansión")
	check_equal(AudioManager.music.track_id, "mansion", "con su música")
	check(AudioManager.get_debug_state()["desired"]["intensity"] > 0.5, "y la tensión del tercer día")
	check_equal(AudioManager.ambience.active_emitters(), 2, "el reloj y la chimenea, una sola vez")
	check_equal(AudioManager.ambience.live_players(), AudioManager.ambience.active_layers().size() + 2,
		"sin reproductores sobrantes del menú")
	check_equal(AudioManager.music.active_players(), 1, "ni pistas sobrantes")
	loaded.queue_free()
	await get_tree().process_frame


# --- Pasos ---

func test_footsteps_follow_the_floor() -> void:
	var game := await make_game()
	game.go_to("mansion", "desde_plaza")
	await _wait(1.6)
	var mansion: LocationBase = game.current_location
	check_equal(mansion.get_surface_at(mansion.to_global(Vector3(0.5, 0.0, -5.0))), "alfombra", "la alfombra del salón")
	check_equal(mansion.get_surface_at(mansion.to_global(Vector3(-3.5, 0.0, 2.0))), "baldosa", "las baldosas del vestíbulo")
	check_equal(mansion.get_surface_at(mansion.to_global(Vector3(-12.5, 0.0, -3.0))), "madera", "la tarima de la alcoba")
	AudioManager.effects.history.clear()
	check(AudioManager.play_footstep(mansion, mansion.to_global(Vector3(10.0, 0.0, 6.0))), "suena un paso")
	check(AudioManager.effects.history.has("paso_baldosa"), "en las baldosas del office")
	game.go_to("plaza", "desde_mansion")
	await _wait(1.6)
	AudioManager.effects.history.clear()
	AudioManager.play_footstep(game.current_location, game.player.global_position)
	check(AudioManager.effects.history.has("paso_piedra"), "en la plaza, empedrado")
	game.queue_free()
	await get_tree().process_frame


func test_walking_animation_marks_each_step() -> void:
	var model := CharacterModel.new()
	add_child(model)
	model.build({})
	var steps := [0]
	model.stepped.connect(func() -> void: steps[0] += 1)
	model.set_motion(0.625)
	for frame in 60:
		model._process(1.0 / 60.0)
	check(steps[0] >= 2 and steps[0] <= 4, "andando, unos tres pasos por segundo (%d)" % steps[0])
	model.set_motion(0.0)
	steps[0] = 0
	for frame in 60:
		model._process(1.0 / 60.0)
	check_equal(steps[0], 0, "quieto no hay pasos")
	model.queue_free()


# --- Utilidades ---

func _add_capture(bus_name: String) -> void:
	_capture_bus = AudioServer.get_bus_index(bus_name)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 1.0
	AudioServer.add_bus_effect(_capture_bus, _capture)


func _remove_capture() -> void:
	if _capture == null:
		return
	for index in AudioServer.get_bus_effect_count(_capture_bus):
		if AudioServer.get_bus_effect(_capture_bus, index) == _capture:
			AudioServer.remove_bus_effect(_capture_bus, index)
			break
	_capture = null


## Nivel RMS (dBFS) de lo que pasa por el canal durante `seconds`.
func _measure(seconds: float) -> float:
	_capture.clear_buffer()
	await _wait(seconds)
	var frames := _capture.get_buffer(_capture.get_frames_available())
	if frames.is_empty():
		return -120.0
	var total := 0.0
	for frame in frames:
		total += frame.x * frame.x + frame.y * frame.y
	return linear_to_db(sqrt(total / (2.0 * frames.size())) + 1e-9)
