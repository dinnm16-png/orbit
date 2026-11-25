extends "res://tests/test_case.gd"

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SAVE := "user://test_tension.cfg"


func _spawn(mode_id: String = "classic") -> Node2D:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
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
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_stage_up_makes_the_live_game_harder() -> void:
	var main := await _spawn()
	var g0: float = main.config.gravity_strength
	var p: Planet = main.field.spawn_planet(2, main.arena_center + Vector2(0, -160), true)
	main._set_score(Intensity.THRESHOLDS[4])  # Stage V
	assert_eq(main.stage, 5, "stage V")
	assert_true(main.config.gravity_strength > g0 * 1.2, "gravity raised in place")
	assert_true(p.config == main.config, "planets share the live config")
	assert_true(main.config.orbital_drift > 0.0, "orbital wind")
	assert_almost(main._monitor.grace_time, main.config.game_over_grace_time, 0.001, "game-over grace updated")
	assert_true(main.get_node("HUD/Popups").get_child_count() >= 2, "stage banner shown")
	await _cleanup(main)


func test_zen_never_escalates() -> void:
	var main := await _spawn("zen")
	var g0: float = main.config.gravity_strength
	main._set_score(50000)
	assert_eq(main.stage, 1, "Zen stays calm")
	assert_almost(main.config.gravity_strength, g0, 0.001, "unchanged")
	await _cleanup(main)


func test_combo_multiplies_quick_merges() -> void:
	var main := await _spawn()
	main.field.spawn_planet(0, main.arena_center + Vector2(-17, -100), true)
	main.field.spawn_planet(0, main.arena_center + Vector2(17, -100), true)
	main.field.spawn_planet(0, main.arena_center + Vector2(140, 60), true)
	main.field.spawn_planet(0, main.arena_center + Vector2(174, 60), true)
	await wait_physics_frames(20)
	assert_true(main.combo.count >= 2, "two merges in a row form a combo")
	assert_true(main.score > 20, "second merge scored more than the first (score %d)" % main.score)
	await _cleanup(main)


func test_focus_slows_time_while_aiming_and_drains() -> void:
	var main := await _spawn()
	main._on_aim_started()
	assert_almost(Engine.time_scale, main.FOCUS_SCALE, 0.001, "slow motion while aiming")
	await tree.create_timer(0.5, true, false, true).timeout
	assert_true(main.focus < 1.0, "focus drains")
	main._on_aim_ended()
	assert_almost(Engine.time_scale, 1.0, 0.001, "normal speed after the shot")
	await _cleanup(main)


func test_focus_runs_out() -> void:
	var main := await _spawn()
	main.focus = 0.05
	main._on_aim_started()
	await tree.create_timer(0.4, true, false, true).timeout
	assert_almost(Engine.time_scale, 1.0, 0.001, "empty focus ends slow motion even while aiming")
	main._on_aim_ended()
	await _cleanup(main)


func test_pausing_while_aiming_restores_speed() -> void:
	var main := await _spawn()
	var start: Vector2 = main.launcher.global_position
	var e := InputEventScreenTouch.new()
	e.pressed = true
	e.position = start + Vector2(0, -300)
	tree.root.push_input(e, true)
	await tree.process_frame
	assert_true(Engine.time_scale < 1.0, "focus on")
	main.pause()
	main.resume()
	assert_almost(Engine.time_scale, 1.0, 0.001, "pause cancels the aim and its slow motion")
	await _cleanup(main)


func test_overlapping_slowdowns_resolve_correctly() -> void:
	var main := await _spawn()
	main._set_time("focus", 0.35)
	main._set_time("slowmo", 0.5)
	assert_almost(Engine.time_scale, 0.35, 0.001, "slowest wins")
	main._set_time("focus", 1.0)
	assert_almost(Engine.time_scale, 0.5, 0.001, "other request still active")
	main._set_time("slowmo", 1.0)
	assert_almost(Engine.time_scale, 1.0, 0.001, "all clear")
	await _cleanup(main)


func test_danger_raises_tension() -> void:
	var main := await _spawn()
	var cfg: GameConfig = main.config
	cfg.gravity_strength = 0.001
	main.field.spawn_planet(0, main.arena_center + Vector2(0, -360), true)
	await wait_physics_frames(60)
	assert_true(main.fx.tension > 0.2, "vignette rising (%.2f)" % main.fx.tension)
	await _cleanup(main)
