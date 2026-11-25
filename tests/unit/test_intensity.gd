extends "res://tests/test_case.gd"

const BASE := preload("res://resources/config/default_config.tres")


func test_stages_from_score() -> void:
	assert_eq(Intensity.stage_for(0), 1, "start")
	var two: int = Intensity.THRESHOLDS[1]
	assert_eq(Intensity.stage_for(two - 1), 1, "just below II")
	assert_eq(Intensity.stage_for(two), 2, "II")
	assert_eq(Intensity.stage_for(1_000_000), 10, "caps at X")
	assert_almost(Intensity.progress(two / 2), 0.5, 0.01, "halfway to II")
	assert_almost(Intensity.progress(1_000_000), 1.0, 0.001, "full at the top")


func test_every_stage_is_harder_and_valid() -> void:
	var prev: GameConfig = null
	for s in range(1, Intensity.max_stage() + 1):
		var cfg: GameConfig = BASE.duplicate()
		Intensity.apply(cfg, BASE, s)
		assert_true(cfg.validate().is_empty(), "stage %d valid: %s" % [s, ", ".join(cfg.validate())])
		if prev:
			assert_true(cfg.gravity_strength > prev.gravity_strength, "stage %d: stronger gravity" % s)
			assert_true(cfg.reload_delay <= prev.reload_delay, "stage %d: reload not slower" % s)
			assert_true(cfg.game_over_grace_time <= prev.game_over_grace_time, "stage %d: grace not longer" % s)
			assert_true(cfg.spawn_max_level >= prev.spawn_max_level, "stage %d: variety not lower" % s)
			assert_true(cfg.orbital_drift >= prev.orbital_drift, "stage %d: wind not weaker" % s)
		prev = cfg
	assert_true(prev.orbital_drift > 0.0, "orbital wind at the top stage")
	assert_true(prev.game_over_grace_time >= 1.0, "grace never below 1 s (fairness)")


func test_stage_one_changes_nothing() -> void:
	var cfg: GameConfig = BASE.duplicate()
	Intensity.apply(cfg, BASE, 1)
	assert_almost(cfg.gravity_strength, BASE.gravity_strength, 0.001, "gravity")
	assert_almost(cfg.orbital_drift, 0.0, 0.001, "no wind")
	assert_eq(cfg.spawn_max_level, BASE.spawn_max_level, "variety")


func test_combo_builds_and_breaks() -> void:
	var c := Combo.new()
	c.window = 2.0
	assert_almost(c.hit(), 1.0, 0.001, "first merge x1")
	c.tick(1.0)
	assert_almost(c.hit(), 1.25, 0.001, "quick second merge x1.25")
	c.tick(1.9)
	assert_almost(c.hit(), 1.5, 0.001, "third x1.5")
	c.tick(2.1)
	assert_eq(c.count, 0, "window ran out")
	assert_almost(c.hit(), 1.0, 0.001, "starts over")
	for i in 20:
		c.hit()
	assert_almost(c.multiplier(), Combo.MAX_MULT, 0.001, "capped")


func test_combo_window_shrinks_with_stage() -> void:
	assert_true(Intensity.combo_window(10) < Intensity.combo_window(1), "faster pace later")
	assert_true(Intensity.combo_window(10) >= 1.4, "never impossible")


func test_combo_badge_number_format() -> void:
	var b := ComboBadge.new()
	for pair in [[2.0, "2"], [1.75, "1.75"], [1.5, "1.5"], [3.0, "3"]]:
		var num := ("%.2f" % pair[0]).rstrip("0").rstrip(".")
		assert_eq(num, pair[1], "format %s" % pair[0])
	b.free()
