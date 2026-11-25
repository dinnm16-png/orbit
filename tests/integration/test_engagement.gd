extends "res://tests/test_case.gd"
## Challenges, big moments and the tutorial, with the real game scene.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SAVE := "user://test_engagement.cfg"


func _spawn(mode_id: String, seed: int = 42, fresh: bool = true) -> Node2D:
	if fresh:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var main: Node2D = MAIN_SCENE.instantiate()
	main.mode = Session.load_mode(mode_id)
	main.random_seed = seed
	main.save_path = SAVE
	tree.root.add_child(main)
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node2D) -> void:
	Session.challenge = {}
	main.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _sequence(main: Node2D) -> Array:
	var seq := [main.launcher.loaded_planet.level, main.next_level]
	for i in 8:
		main._roll_next()
		seq.append(main.next_level)
	return seq


func test_challenge_replays_the_exact_planets() -> void:
	Session.challenge = {"mode": "classic", "seed": 987654321, "difficulty": 1, "score": 500}
	var a := await _spawn("classic", 0)
	var seq_a := _sequence(a)
	assert_eq(a.game_seed, 987654321, "seed from the code")
	await _cleanup(a)
	Session.challenge = {"mode": "classic", "seed": 987654321, "difficulty": 1, "score": 500}
	var b := await _spawn("classic", 0)
	assert_eq(_sequence(b), seq_a, "same planets for both players")
	await _cleanup(b)


func test_challenge_uses_challengers_difficulty() -> void:
	Session.challenge = {"mode": "classic", "seed": 5, "difficulty": Difficulty.Level.HARD, "score": 500}
	var main := await _spawn("classic", 0)
	var base: GameConfig = load("res://resources/config/default_config.tres")
	assert_almost(main.config.boundary_radius, base.boundary_radius - 30.0, 0.01, "hard ring")
	await _cleanup(main)


func test_beating_the_challenge_is_celebrated_once() -> void:
	Session.challenge = {"mode": "classic", "seed": 5, "difficulty": 1, "score": 500}
	var main := await _spawn("classic", 0)
	assert_true(main.best_label.text.contains("BEAT 500"), "target shown")
	main._set_score(600)
	assert_true(main._challenge_beaten, "beaten")
	assert_true(main.best_label.text.contains("+100"), "margin shown")
	main._set_score(700)
	main._end(main.EndReason.COLLAPSE)
	assert_eq(main._highlight_line(false), "CHALLENGE WON BY 200", "result line")
	await _cleanup(main)


func test_share_text_contains_a_working_code() -> void:
	var main := await _spawn("blitz")
	main._set_score(1234)
	var text: String = main.share_text()
	var d := ChallengeCode.decode(text)
	assert_eq(d["mode"], "blitz", "mode")
	assert_eq(d["seed"], main.game_seed, "seed")
	assert_eq(d["score"], 1234, "score")
	await _cleanup(main)


func test_supernova_slow_motion_always_ends() -> void:
	var main := await _spawn("classic")
	var p: Planet = main.field.spawn_planet(4, main.arena_center + Vector2(0, -150), true)
	main._chain_moment(p, 5)
	assert_true(Engine.time_scale < 1.0, "slow motion started")
	assert_true(main.get_node("HUD/Popups").get_child_count() > 0, "callout shown")
	await tree.create_timer(1.2, true, false, true).timeout
	assert_almost(Engine.time_scale, 1.0, 0.001, "back to normal speed")
	main._chain_moment(p, 6)
	await _cleanup(main)  # Leaving mid-slow-motion...
	assert_almost(Engine.time_scale, 1.0, 0.001, "...never leaves the game slowed down")


func test_tutorial_first_shot_merges_and_completes() -> void:
	Session.challenge = {}
	var main := await _spawn("classic", 0)
	assert_true(main.coach != null, "coach shown to a new player")
	assert_eq(main.launcher.loaded_planet.level, 0, "first planet matches the starter")
	assert_eq(main.field.get_active_planets().size(), 1, "starter planet in place")
	main.launcher.fire(Vector2(0, -520))
	assert_eq(main.coach.step, Coach.Step.MERGE, "second caption after the launch")
	var merged := false
	for i in 150:
		await tree.physics_frame
		if main.score > 0:
			merged = true
			break
	assert_true(merged, "the very first straight shot merges")
	assert_eq(main.coach.step, Coach.Step.CHAIN, "chain caption after the merge")
	await tree.create_timer(7.5).timeout
	var s := PlayerSettings.new(SAVE)
	s.load_settings()
	assert_true(s.tutorial_done, "tutorial marked done")
	await _cleanup(main)


func test_no_tutorial_for_returning_players_or_daily() -> void:
	var s := PlayerSettings.new(SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	s.tutorial_done = true
	s.save_settings()
	var main := await _spawn("classic", 0, false)
	assert_true(main.coach == null, "no tutorial once done")
	await _cleanup(main)
	main = await _spawn("daily", 0)
	assert_true(main.coach == null, "never in Daily (fairness)")
	await _cleanup(main)
