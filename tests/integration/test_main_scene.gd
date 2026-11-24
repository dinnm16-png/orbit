extends "res://tests/test_case.gd"
## Runs the real main scene with real physics, headless.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func _spawn_main() -> Node2D:
	var main: Node2D = MAIN_SCENE.instantiate()
	main.random_seed = 42
	main.save_path = "user://test_unused.cfg"
	tree.root.add_child(main)
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node2D) -> void:
	main.queue_free()
	await tree.process_frame


func test_planet_waits_frozen_at_launcher() -> void:
	var main := await _spawn_main()
	var planet: Planet = main.launcher.loaded_planet
	assert_true(planet != null, "a planet is loaded at start")
	if planet:
		var start := planet.global_position
		await wait_physics_frames(30)
		assert_true(planet.freeze, "loaded planet is frozen")
		assert_vec_almost(planet.global_position, start, 0.01, "loaded planet does not fall")
	await _cleanup(main)


func test_launched_planet_settles_on_core_without_exceeding_speed_cap() -> void:
	var main := await _spawn_main()
	var config: GameConfig = main.config
	var planet: Planet = main.launcher.loaded_planet
	main.launcher.fire(Vector2(0, -config.max_launch_speed * 0.6))

	var max_speed := 0.0
	for i in 60 * 8:
		await tree.physics_frame
		max_speed = maxf(max_speed, planet.linear_velocity.length())

	assert_true(max_speed <= config.max_planet_speed + 0.5,
		"speed cap respected (max seen %.1f)" % max_speed)
	var dist := planet.global_position.distance_to(main.core.global_position)
	assert_true(dist <= config.core_radius + planet.radius + 3.0,
		"planet rests on the core (distance %.1f)" % dist)
	assert_true(planet.linear_velocity.length() < 5.0,
		"planet has settled (speed %.2f)" % planet.linear_velocity.length())
	assert_true(main.launcher.loaded_planet != null and main.launcher.loaded_planet != planet,
		"a new planet was loaded after the launch")
	await _cleanup(main)


func test_sideways_launch_stays_stable_and_ends_inside_boundary() -> void:
	var main := await _spawn_main()
	var config: GameConfig = main.config
	var planet: Planet = main.launcher.loaded_planet
	main.launcher.fire(Vector2(config.max_launch_speed, -config.max_launch_speed * 0.3))

	var max_speed := 0.0
	for i in 60 * 10:
		await tree.physics_frame
		if not is_instance_valid(planet):
			break
		max_speed = maxf(max_speed, planet.linear_velocity.length())

	assert_true(is_instance_valid(planet), "planet was not lost off-screen")
	if is_instance_valid(planet):
		assert_true(max_speed <= config.max_planet_speed + 0.5, "speed cap respected")
		var dist := planet.global_position.distance_to(main.core.global_position)
		assert_true(dist < config.boundary_radius, "planet ends inside the boundary (%.1f)" % dist)
	await _cleanup(main)


func test_touch_drag_release_launches_upward() -> void:
	var main := await _spawn_main()
	var planet: Planet = main.launcher.loaded_planet
	# Press, pull the finger 200 px DOWN, release -> planet should fly UP.
	_touch(true, Vector2(360, 950))
	_drag(Vector2(360, 1150))
	_touch(false, Vector2(360, 1150))
	await wait_physics_frames(2)
	assert_true(planet.is_active, "planet was launched by touch input")
	assert_true(planet.linear_velocity.y < -100.0,
		"planet flies upward (velocity %s)" % planet.linear_velocity)
	await _cleanup(main)


func test_tiny_drag_cancels() -> void:
	var main := await _spawn_main()
	var planet: Planet = main.launcher.loaded_planet
	_touch(true, Vector2(360, 950))
	_drag(Vector2(365, 960))
	_touch(false, Vector2(365, 960))
	await wait_physics_frames(2)
	assert_false(planet.is_active, "tiny drag does not launch")
	assert_eq(main.launcher.loaded_planet, planet, "planet stays loaded")
	await _cleanup(main)


func _touch(pressed: bool, pos: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = pos
	tree.root.push_input(e, true)


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	tree.root.push_input(e, true)
