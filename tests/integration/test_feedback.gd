extends "res://tests/test_case.gd"

const MAIN_SCENE := preload("res://scenes/main/main.tscn")


func test_merge_spawns_burst_that_frees_itself() -> void:
	var main: Node2D = MAIN_SCENE.instantiate()
	main.random_seed = 42
	main.save_path = "user://test_unused.cfg"
	tree.root.add_child(main)
	await wait_physics_frames(2)
	main.field.spawn_planet(0, main.core.global_position + Vector2(-17, -100), true)
	main.field.spawn_planet(0, main.core.global_position + Vector2(17, -100), true)
	await wait_physics_frames(10)
	assert_eq(main.effects.get_child_count(), 1, "one burst for one merge")
	for i in 60:
		await tree.process_frame
	await wait_physics_frames(30)
	assert_eq(main.effects.get_child_count(), 0, "burst removed itself")
	main.queue_free()
	await tree.process_frame


func test_all_feedback_events_run_without_errors() -> void:
	# Sound on, haptics on: in headless runs audio is a dummy driver, but every
	# code path still executes (errors would fail the test via the logger).
	var main: Node2D = MAIN_SCENE.instantiate()
	main.save_path = "user://test_unused.cfg"
	tree.root.add_child(main)
	await wait_physics_frames(2)
	var fb: Feedback = main.feedback
	fb.on_launch(0.5)
	for level in range(1, 12):
		fb.on_merge(level, 2)
	fb.on_vanish()
	fb.on_game_over()
	await tree.process_frame
	main.queue_free()
	await tree.process_frame


func test_sounds_are_generated_in_background() -> void:
	var main: Node2D = MAIN_SCENE.instantiate()
	main.save_path = "user://test_unused.cfg"
	tree.root.add_child(main)
	# Startup must not block: the scene is running while sounds generate.
	for i in 120:
		if Feedback.sounds_ready():
			break
		await tree.process_frame
	assert_true(Feedback.sounds_ready(), "background generation finished")
	main.queue_free()
	await tree.process_frame
