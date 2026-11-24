extends "res://tests/test_case.gd"
## Next-planet queue, game over, best score — real scene, headless.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SAVE := "user://test_game_loop.cfg"


func _spawn_main(weak_gravity: bool = false) -> Node2D:
	var main: Node2D = MAIN_SCENE.instantiate()
	main.random_seed = 42
	main.save_path = SAVE
	if weak_gravity:
		# Nearly no gravity so a planet can rest outside the ring for the test.
		var cfg: GameConfig = main.config.duplicate()
		cfg.gravity_strength = 0.001
		main.config = cfg
	tree.root.add_child(main)
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node2D) -> void:
	main.queue_free()
	await tree.process_frame


func _clear_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_next_preview_predicts_the_next_loaded_planet() -> void:
	var main := await _spawn_main()
	for i in 4:
		var predicted: int = main.next_level
		assert_eq(main.next_preview.level, predicted, "preview shows next level")
		main.launcher.fire(Vector2(0, -600))
		await wait_physics_frames(int(main.config.reload_delay * 60.0) + 5)
		assert_eq(main.launcher.loaded_planet.level, predicted, "loaded planet = previewed level")
	await _cleanup(main)


func test_planet_resting_outside_boundary_ends_game_after_grace() -> void:
	_clear_save()
	var main := await _spawn_main(true)
	var p: Planet = main.field.spawn_planet(0, main.core.global_position + Vector2(0, -400), true)
	await wait_physics_frames(60)  # 1 s
	assert_eq(main.state, main.State.PLAYING, "still playing during grace")
	assert_true(p.danger > 0.3 and main.arena.danger > 0.3, "warning shown during grace")
	await wait_physics_frames(75)  # total 2.25 s
	assert_eq(main.state, main.State.GAME_OVER, "game over after grace")
	assert_true(main.game_over_panel.visible, "overlay shown")
	assert_false(main.launcher.enabled, "input disabled")
	var loaded: Planet = main.launcher.loaded_planet
	main.launcher.fire(Vector2(0, -600))
	assert_false(loaded.is_active, "cannot launch after game over")
	await _cleanup(main)


func test_normal_play_does_not_trigger_game_over() -> void:
	var main := await _spawn_main()
	# Launch from outside the ring (the launcher is outside it): must stay safe.
	for v in [Vector2(0, -700), Vector2(500, -600), Vector2(-500, -600), Vector2(0, -300)]:
		main.launcher.fire(v)
		await wait_physics_frames(60)
	await wait_physics_frames(180)
	assert_eq(main.state, main.State.PLAYING, "no false game over")
	await _cleanup(main)


func test_game_over_saves_best_score_only_when_higher() -> void:
	_clear_save()
	var main := await _spawn_main(true)
	main._set_score(1234)
	main.field.spawn_planet(0, main.core.global_position + Vector2(0, -400), true)
	await wait_physics_frames(140)
	assert_eq(main.state, main.State.GAME_OVER, "game over")
	assert_eq(HighScoreStore.new(SAVE).load_best(), 1234, "best score saved")
	await _cleanup(main)

	main = await _spawn_main(true)
	assert_eq(main.best_score, 1234, "best score loaded on next game")
	main._set_score(50)
	main.field.spawn_planet(0, main.core.global_position + Vector2(0, -400), true)
	await wait_physics_frames(140)
	assert_eq(HighScoreStore.new(SAVE).load_best(), 1234, "lower score did not overwrite")
	await _cleanup(main)
	_clear_save()


func test_no_scoring_after_game_over() -> void:
	_clear_save()
	var main := await _spawn_main(true)
	main.field.spawn_planet(0, main.core.global_position + Vector2(0, -400), true)
	await wait_physics_frames(140)
	var frozen_score: int = main.score
	main._on_planets_vanished(Vector2.ZERO, 11, 1)
	assert_eq(main.score, frozen_score, "score is final once the game is over")
	await _cleanup(main)
	_clear_save()


func test_game_counts_in_stats_exactly_once() -> void:
	_clear_save()
	var main := await _spawn_main(true)
	main.launcher.fire(Vector2(0, -600))
	main.field.spawn_planet(0, main.core.global_position + Vector2(0, -400), true)
	await wait_physics_frames(140)
	assert_eq(main.state, main.State.GAME_OVER, "game over")
	main._commit_progress()  # e.g. Play Again pressed afterwards
	var p := Progress.new(SAVE).load_progress()
	assert_eq(p.games_played, 1, "counted once")
	assert_true(p.modes_played.has("classic"), "mode recorded")
	await _cleanup(main)
	_clear_save()


func test_untouched_game_is_not_counted() -> void:
	_clear_save()
	var main := await _spawn_main()
	main._commit_progress()
	assert_eq(Progress.new(SAVE).load_progress().games_played, 0, "no launch, no game")
	await _cleanup(main)
