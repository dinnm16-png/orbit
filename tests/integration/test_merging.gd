extends "res://tests/test_case.gd"
## Merging with the real scene and real physics, headless.
## Planets are placed by hand (relative to the core) for exact scenarios.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func _spawn_main() -> Node2D:
	var main: Node2D = MAIN_SCENE.instantiate()
	main.random_seed = 42
	tree.root.add_child(main)
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node2D) -> void:
	main.queue_free()
	await tree.process_frame


func _place(main: Node2D, level: int, offset: Vector2) -> Planet:
	return main.field.spawn_planet(level, main.core.global_position + offset, true)


func _levels(main: Node2D) -> Array:
	var result := []
	for p in main.field.get_active_planets():
		result.append(p.level)
	result.sort()
	return result


func test_two_same_level_planets_merge_and_score() -> void:
	var main := await _spawn_main()
	_place(main, 0, Vector2(-17, -100))
	_place(main, 0, Vector2(17, -100))
	await wait_physics_frames(30)
	assert_eq(_levels(main), [1], "one level-1 planet remains")
	assert_eq(main.score, 10, "score for a level-1 merge")
	await _cleanup(main)


func test_different_levels_do_not_merge() -> void:
	var main := await _spawn_main()
	_place(main, 0, Vector2(-20, -100))
	_place(main, 1, Vector2(21, -100))
	await wait_physics_frames(60)
	assert_eq(_levels(main), [0, 1], "both planets still there")
	assert_eq(main.score, 0, "no score")
	await _cleanup(main)


func test_three_touching_planets_merge_exactly_once() -> void:
	var main := await _spawn_main()
	_place(main, 0, Vector2(-17.5, -100))
	_place(main, 0, Vector2(17.5, -100))
	_place(main, 0, Vector2(0, -130))
	var merges := [0]
	main.field.planets_merged.connect(func(_p, _d): merges[0] += 1)
	await wait_physics_frames(30)
	assert_eq(merges[0], 1, "exactly one merge event")
	assert_eq(_levels(main), [0, 1], "one level-0 left over + one level-1")
	assert_eq(main.score, 10, "scored once")
	await _cleanup(main)


func test_chain_reaction_merges_again_with_bonus() -> void:
	var main := await _spawn_main()
	# The two level-0 planets merge into a level-1 at (0, -100), which then
	# touches the existing level-1 planet above it -> level 2, chain depth 2.
	_place(main, 0, Vector2(-17, -100))
	_place(main, 0, Vector2(17, -100))
	_place(main, 1, Vector2(0, -146))
	var depths := []
	main.field.planets_merged.connect(func(_p, d): depths.append(d))
	await wait_physics_frames(60)
	assert_eq(depths, [1, 2], "a merge, then a chained merge")
	assert_eq(_levels(main), [2], "single level-2 planet")
	assert_eq(main.score, 10 + 45, "level-1 (10) + level-2 at ×1.5 (45)")
	await _cleanup(main)


func test_max_level_pair_vanishes_with_bonus() -> void:
	var main := await _spawn_main()
	var top: int = main.config.level_count() - 1
	_place(main, top, Vector2(-117, -200))
	_place(main, top, Vector2(117, -200))
	await wait_physics_frames(20)
	assert_eq(_levels(main), [], "both max-level planets vanished")
	assert_eq(main.score, main.config.vanish_points, "vanish bonus")
	await _cleanup(main)


func test_loaded_planet_at_launcher_never_merges() -> void:
	var main := await _spawn_main()
	var loaded: Planet = main.launcher.loaded_planet
	var p: Planet = main.field.spawn_planet(loaded.level,
		loaded.global_position + Vector2(loaded.radius * 2.0 - 2.0, 0), true)
	await wait_physics_frames(10)
	assert_false(loaded.consumed, "loaded planet untouched")
	assert_eq(main.launcher.loaded_planet, loaded, "still loaded")
	assert_eq(main.score, 0, "no merge happened")
	assert_true(is_instance_valid(p), "active planet still exists")
	await _cleanup(main)


func test_stress_no_duplicate_merges_value_is_conserved() -> void:
	# 2^level is conserved by every merge (2 × 2^L = 2^(L+1)). A duplicate merge
	# (one planet used twice, or a pair producing two results) breaks this.
	var main := await _spawn_main()
	var count := 16
	for i in count:
		var angle := TAU * i / count
		_place(main, 0, Vector2.from_angle(angle) * 150.0)
	var merges := [0]
	main.field.planets_merged.connect(func(_p, _d): merges[0] += 1)

	var max_speed := 0.0
	for i in 60 * 6:
		await tree.physics_frame
		for p in main.field.get_active_planets():
			max_speed = maxf(max_speed, p.linear_velocity.length())

	var value := 0
	for p in main.field.get_active_planets():
		value += 1 << p.level
	var remaining: int = main.field.get_active_planets().size()
	assert_eq(value, count, "total 2^level value conserved")
	assert_eq(merges[0], count - remaining, "each merge removed exactly one planet")
	assert_true(merges[0] >= 4, "merges actually happened (%d)" % merges[0])
	assert_true(max_speed <= main.config.max_planet_speed + 0.5, "speed cap respected")
	await _cleanup(main)
