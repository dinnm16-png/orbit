extends "res://tests/test_case.gd"
## Each mode's special rule, with the real scene and real physics.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SAVE := "user://test_modes.cfg"


func _spawn(mode: GameMode, weak_gravity: bool = false, seed: int = 42) -> Node2D:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var main: Node2D = MAIN_SCENE.instantiate()
	main.mode = mode
	main.random_seed = seed
	main.save_path = SAVE
	if weak_gravity:
		var cfg: GameConfig = main.config.duplicate()
		cfg.gravity_strength = 0.001
		main.config = cfg
	tree.root.add_child(main)
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node2D) -> void:
	tree.paused = false
	main.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _mode(id: String) -> GameMode:
	return Session.load_mode(id).duplicate()


func test_zen_fades_stranded_planets_and_never_ends() -> void:
	var main := await _spawn(_mode("zen"), true)
	var p: Planet = main.field.spawn_planet(0, main.arena_center + Vector2(0, -400), true)
	await wait_physics_frames(60)
	assert_true(p.modulate.a < 0.9, "planet visibly fading (alpha %.2f)" % p.modulate.a)
	assert_almost(main.arena.danger, 0.0, 0.001, "no stressful warning in Zen")
	await wait_physics_frames(90)
	assert_true(not is_instance_valid(p) or p.consumed, "stranded planet faded away")
	assert_eq(main.state, main.State.PLAYING, "Zen never ends")
	await _cleanup(main)


func test_blitz_ends_when_time_runs_out() -> void:
	var mode := _mode("blitz")
	mode.time_limit = 1.0
	var main := await _spawn(mode)
	assert_eq(main.status_label.text, "0:01", "timer shown")
	await wait_physics_frames(70)
	assert_eq(main.state, main.State.GAME_OVER, "game ended")
	assert_eq(main.end_reason, main.EndReason.TIME, "because time ran out")
	await _cleanup(main)


func test_blitz_chain_adds_time() -> void:
	var main := await _spawn(_mode("blitz"))
	var before: float = main.time_left
	# Chain: two level-0 merge into a level-1 that touches an existing level-1.
	main.field.spawn_planet(0, main.arena_center + Vector2(-17, -100), true)
	main.field.spawn_planet(0, main.arena_center + Vector2(17, -100), true)
	main.field.spawn_planet(1, main.arena_center + Vector2(0, -146), true)
	await wait_physics_frames(60)
	# 1 s of play passed; one chained merge adds the flat bonus.
	var expected: float = before - 1.0 + main.mode.time_bonus_per_chain
	assert_almost(main.time_left, expected, 0.1, "chain bonus added once")
	await _cleanup(main)


func test_limited_shots_counts_down_and_ends() -> void:
	var mode := _mode("limited")
	mode.shot_limit = 2
	var main := await _spawn(mode)
	assert_eq(main.status_label.text, "2 PLANETS LEFT", "counter shown")
	main.launcher.fire(Vector2(0, -650))
	await wait_physics_frames(40)
	assert_eq(main.status_label.text, "1 PLANET LEFT", "singular wording")
	assert_eq(main.next_preview.level, -1, "no NEXT for the last planet")
	main.launcher.fire(Vector2(0, -650))
	await wait_physics_frames(40)
	assert_true(main.launcher.loaded_planet == null, "no more planets loaded")
	await wait_physics_frames(60 * 7)
	assert_eq(main.state, main.State.GAME_OVER, "game ended")
	assert_eq(main.end_reason, main.EndReason.SHOTS, "because planets ran out")
	await _cleanup(main)


func test_collapse_ring_shrinks_and_merges_push_it_back() -> void:
	var main := await _spawn(_mode("collapse"))
	var start: float = main.arena_radius
	await wait_physics_frames(120)
	var shrunk: float = main.arena_radius
	assert_true(shrunk < start - 4.0, "ring shrank (%.1f -> %.1f)" % [start, shrunk])
	assert_almost(main.arena.radius, shrunk, 0.01, "ring drawn at current radius")
	main.field.spawn_planet(2, main.arena_center + Vector2(-30, -110), true)
	main.field.spawn_planet(2, main.arena_center + Vector2(30, -110), true)
	await wait_physics_frames(10)
	assert_true(main.arena_radius > shrunk, "merge pushed the ring out (%.1f -> %.1f)" % [shrunk, main.arena_radius])
	await _cleanup(main)


func test_collapse_ring_stops_at_minimum() -> void:
	var mode := _mode("collapse")
	mode.boundary_shrink_per_sec = 1000.0
	var main := await _spawn(mode)
	await wait_physics_frames(30)
	assert_almost(main.arena_radius, mode.boundary_min_radius, 0.01, "clamped at minimum")
	await _cleanup(main)


func test_binary_has_two_cores_and_planets_settle() -> void:
	var main := await _spawn(_mode("binary"))
	assert_eq(main.cores.size(), 2, "two cores")
	assert_eq(main.field.gravity_centers.size(), 2, "both cores pull")
	var gap: float = main.cores[0].global_position.distance_to(main.cores[1].global_position)
	assert_almost(gap, main.mode.core_spacing, 0.5, "cores spaced as configured")
	main.launcher.fire(Vector2(120, -700))
	var p: Planet = main.field.get_active_planets()[0]
	# Between two cores the pulls almost cancel, so a small planet bobs gently
	# around the midpoint ("bridge") before settling — slower than one core.
	await wait_physics_frames(60 * 11)
	assert_true(p.linear_velocity.length() < 5.0, "planet settled (speed %.1f)" % p.linear_velocity.length())
	assert_true(p.global_position.distance_to(main.arena_center) < main.arena_radius, "inside the ring")
	assert_eq(main.state, main.State.PLAYING, "still playing")
	await _cleanup(main)


func test_daily_gives_identical_sequences_and_its_own_best() -> void:
	var levels := []
	for run in 2:
		var main := await _spawn(_mode("daily"), false, 0)  # seed 0 -> daily seed
		var seq := [main.launcher.loaded_planet.level, main.next_level]
		for i in 5:
			seq.append(main.rng.randi_range(0, 2))
		levels.append(seq)
		assert_eq(main._store.key, "daily_" + DailySeed.today_key(), "best stored per day")
		await _cleanup(main)
	assert_eq(levels[0], levels[1], "two games today get the same planets")


func test_mode_best_scores_do_not_mix() -> void:
	var main := await _spawn(_mode("blitz"), true)
	main._set_score(500)
	main._end(main.EndReason.TIME)
	assert_eq(HighScoreStore.new(SAVE, "best_blitz").load_best(), 500, "blitz best saved")
	assert_eq(HighScoreStore.new(SAVE, "best").load_best(), 0, "classic best untouched")
	await _cleanup(main)
