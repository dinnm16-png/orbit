extends "res://tests/test_case.gd"

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SAVE := "user://test_options_game.cfg"


func _spawn(mode_id: String, configure: Callable = Callable()) -> Node2D:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var s := PlayerSettings.new(SAVE)
	if configure.is_valid():
		configure.call(s)
	s.save_settings()
	var main: Node2D = MAIN_SCENE.instantiate()
	main.mode = Session.load_mode(mode_id)
	main.random_seed = 42
	main.save_path = SAVE
	tree.root.add_child(main)
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node2D) -> void:
	main.queue_free()
	await tree.process_frame
	Themes.apply("nebula")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_easy_difficulty_applies_and_keeps_own_best() -> void:
	var main := await _spawn("classic", func(s): s.difficulty = Difficulty.Level.EASY)
	var base: GameConfig = load("res://resources/config/default_config.tres")
	assert_almost(main.config.boundary_radius, base.boundary_radius + 40.0, 0.01, "bigger ring")
	assert_eq(main._store.key, "best_easy", "separate best score")
	await _cleanup(main)


func test_daily_ignores_difficulty() -> void:
	var main := await _spawn("daily", func(s): s.difficulty = Difficulty.Level.HARD)
	var base: GameConfig = load("res://resources/config/default_config.tres")
	assert_almost(main.config.boundary_radius, base.boundary_radius, 0.01, "same rules for everyone")
	await _cleanup(main)


func test_theme_recolors_planets() -> void:
	var main := await _spawn("classic", func(s):
		var p := Progress.new(SAVE)
		p.milestones.append("cascade")  # Solar is unlocked by the Cascade milestone.
		p.save()
		s.theme = "solar")
	var p: Planet = main.field.spawn_planet(3, main.arena_center + Vector2(0, -150), true)
	assert_eq(p.base_color, Themes.planet_colors("solar")[3], "planet uses theme palette")
	assert_eq(UIStyle.VIOLET, Color(Themes.DATA["solar"]["primary"]), "UI uses theme")
	await _cleanup(main)


func test_aim_assist_prediction_matches_real_flight() -> void:
	var main := await _spawn("classic", func(s): s.aim_assist = true)
	var cfg: GameConfig = main.config
	var velocity := Vector2(-260, -620)
	var start: Vector2 = main.launcher.global_position
	var planet: Planet = main.launcher.loaded_planet
	var predicted := OrbitPhysics.predict_path(start, velocity, main.field.gravity_centers,
		cfg.gravity_strength, cfg.planet_linear_damp, cfg.max_planet_speed, 1.0 / 60.0, 40, 0.0)
	main.launcher.fire(velocity)
	await wait_physics_frames(30)
	var err := planet.global_position.distance_to(predicted[29])
	assert_true(err < 12.0, "real position within 12 px of the prediction after 0.5 s (off by %.1f)" % err)
	await _cleanup(main)


func test_locked_theme_falls_back_to_nebula() -> void:
	var main := await _spawn("classic", func(s): s.theme = "solar")
	assert_eq(Themes.current_id, "nebula", "locked theme is not applied")
	await _cleanup(main)
