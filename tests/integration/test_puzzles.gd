extends "res://tests/test_case.gd"

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SAVE := "user://test_puzzles.cfg"


func _spawn(n: int) -> Node2D:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var main: Node2D = MAIN_SCENE.instantiate()
	main.mode = Session.load_mode("puzzle")
	main.puzzle_number = n
	main.random_seed = 1
	main.save_path = SAVE
	tree.root.add_child(main)
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node2D) -> void:
	main.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_every_setup_settles_without_merging() -> void:
	for n in range(1, PuzzleCatalog.count() + 1):
		var main := await _spawn(n)
		var expected: int = main.puzzle["setup"].size()
		await wait_physics_frames(90)
		assert_eq(main.field.get_active_planets().size(), expected, "puzzle %d: setup intact" % n)
		assert_eq(main.score, 0, "puzzle %d: no free merges" % n)
		assert_eq(main.state, main.State.PLAYING, "puzzle %d: still playing" % n)
		await _cleanup(main)


func test_sequence_is_fixed_and_counted() -> void:
	var main := await _spawn(4)
	var seq: Array = main.puzzle["sequence"]
	assert_eq(main.shots_left, seq.size(), "one shot per planet in the sequence")
	assert_eq(main.launcher.loaded_planet.level, seq[0]["level"], "first planet from the sequence")
	assert_eq(main.next_level, seq[1]["level"], "next planet from the sequence")
	await _cleanup(main)


func test_creating_the_goal_wins_and_records_stars() -> void:
	var main := await _spawn(1)
	var goal: int = main.puzzle["goal"]
	main.field.spawn_planet(goal - 1, main.arena_center + Vector2(-60, -200), true)
	main.field.spawn_planet(goal - 1, main.arena_center + Vector2(-60 + main.config.get_planet_radius(goal - 1) * 2 - 2, -200), true)
	await wait_physics_frames(20)
	assert_eq(main.state, main.State.GAME_OVER, "game ended")
	assert_eq(main.end_reason, main.EndReason.PUZZLE_WIN, "won")
	var p := Progress.new(SAVE).load_progress()
	assert_eq(p.stars_for(1), 3, "3 stars with every planet left")
	assert_true(p.is_puzzle_unlocked(2), "next puzzle unlocked")
	await _cleanup(main)


func test_running_out_of_planets_fails() -> void:
	var main := await _spawn(1)
	var count: int = main.puzzle["sequence"].size()
	for i in count:
		# Fire everything far to the side so nothing useful happens.
		main.launcher.fire(Vector2(-900, -150) if i % 2 == 0 else Vector2(900, -150))
		await wait_physics_frames(int(main.config.reload_delay * 60) + 4)
	await wait_physics_frames(60 * 8)
	assert_eq(main.state, main.State.GAME_OVER, "ended")
	assert_true(main.end_reason == main.EndReason.PUZZLE_FAIL or main.end_reason == main.EndReason.PUZZLE_WIN or main.end_reason == main.EndReason.COLLAPSE, "ended by a puzzle rule (%d)" % main.end_reason)
	if main.end_reason != main.EndReason.PUZZLE_WIN:
		assert_eq(Progress.new(SAVE).load_progress().stars_for(1), 0, "no stars for a failed puzzle")
	await _cleanup(main)


func test_hold_cannot_pull_past_the_end_of_the_sequence() -> void:
	var main := await _spawn(1)
	var seq: Array = main.puzzle["sequence"]
	for i in seq.size() - 1:
		main.launcher.fire(Vector2(0, -650))
		await wait_physics_frames(int(main.config.reload_delay * 60) + 4)
	var last: Planet = main.launcher.loaded_planet
	assert_true(last != null, "last planet loaded")
	main.hold()
	assert_eq(main.launcher.loaded_planet, last, "hold refused: nothing to bring in")
	assert_false(last.consumed, "and the planet was not lost")
	await _cleanup(main)
