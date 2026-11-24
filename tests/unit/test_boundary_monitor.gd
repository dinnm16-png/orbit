extends "res://tests/test_case.gd"
# Boundary 300 px, "slow" = under 60 px/s, grace 2 s.

func _monitor() -> BoundaryMonitor:
	return BoundaryMonitor.new(300.0, 60.0, 2.0)


func _sample(id: int, distance: float, speed: float) -> Dictionary:
	return {"id": id, "distance": distance, "speed": speed}


func _run(m: BoundaryMonitor, samples: Array, seconds: float) -> Dictionary:
	var result := {}
	for i in int(round(seconds * 60.0)):
		result = m.update(samples, 1.0 / 60.0)
	return result


func test_planet_inside_boundary_is_safe() -> void:
	var r := _run(_monitor(), [_sample(1, 250.0, 0.0)], 10.0)
	assert_false(r["game_over"], "resting inside never ends the game")
	assert_almost(r["max_progress"], 0.0, 0.0001, "no danger")


func test_fast_planet_outside_is_safe() -> void:
	var r := _run(_monitor(), [_sample(1, 500.0, 400.0)], 10.0)
	assert_false(r["game_over"], "flying through/outside the ring never ends the game")


func test_slow_planet_outside_ends_game_after_grace() -> void:
	var m := _monitor()
	var r := _run(m, [_sample(1, 320.0, 10.0)], 1.5)
	assert_false(r["game_over"], "still within grace at 1.5 s")
	assert_almost(r["max_progress"], 0.75, 0.02, "progress reported for warnings")
	r = _run(m, [_sample(1, 320.0, 10.0)], 0.6)
	assert_true(r["game_over"], "game over after 2 s")


func test_timer_resets_when_planet_returns_inside() -> void:
	var m := _monitor()
	_run(m, [_sample(1, 320.0, 0.0)], 1.5)
	_run(m, [_sample(1, 290.0, 0.0)], 0.1)
	var r := _run(m, [_sample(1, 320.0, 0.0)], 1.5)
	assert_false(r["game_over"], "timer must restart from zero")


func test_timer_resets_when_planet_speeds_up() -> void:
	var m := _monitor()
	_run(m, [_sample(1, 320.0, 0.0)], 1.5)
	_run(m, [_sample(1, 320.0, 200.0)], 0.1)
	var r := _run(m, [_sample(1, 320.0, 0.0)], 1.5)
	assert_false(r["game_over"], "timer must restart from zero")


func test_removed_planet_is_forgotten() -> void:
	# A planet that merges away while in danger must not end the game later.
	var m := _monitor()
	_run(m, [_sample(1, 320.0, 0.0)], 1.9)
	var r := _run(m, [], 0.1)
	assert_false(r["game_over"], "no planets, no game over")
	r = _run(m, [_sample(2, 320.0, 0.0)], 0.1)
	assert_false(r["game_over"], "new planet starts with a fresh timer")


func test_timers_are_per_planet() -> void:
	var m := _monitor()
	var r := _run(m, [_sample(1, 320.0, 0.0), _sample(2, 100.0, 0.0)], 1.0)
	assert_eq(r["progress"].has(2), false, "safe planet has no progress entry")
	assert_almost(r["progress"][1], 0.5, 0.02, "planet 1 halfway")
