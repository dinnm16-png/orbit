extends "res://tests/test_case.gd"

const BASE := preload("res://resources/config/default_config.tres")


func test_every_mode_loads_and_produces_a_valid_config() -> void:
	for id in Session.ORDER:
		var mode := Session.load_mode(id)
		assert_true(mode != null, "%s loads" % id)
		if mode:
			assert_eq(mode.id, id, "id matches file name")
			var errors := mode.apply_to(BASE).validate()
			assert_true(errors.is_empty(), "%s config valid: %s" % [id, ", ".join(errors)])
			assert_true(mode.title != "" and mode.tagline != "" and mode.description != "", "%s has texts" % id)


func test_apply_to_never_modifies_the_shared_config() -> void:
	var before := BASE.gravity_strength
	var binary := Session.load_mode("binary")
	var cfg := binary.apply_to(BASE)
	assert_almost(BASE.gravity_strength, before, 0.0001, "base untouched")
	assert_almost(cfg.gravity_strength, before * binary.gravity_scale, 0.0001, "copy scaled")
	assert_almost(cfg.boundary_radius, binary.boundary_radius_override, 0.0001, "ring override")


func test_best_keys_are_separate_per_mode() -> void:
	assert_eq(Session.load_mode("classic").best_key(), "best", "classic keeps the old key")
	assert_eq(Session.load_mode("blitz").best_key(), "best_blitz", "blitz key")
	assert_eq(Session.load_mode("daily").best_key("2026-11-24"), "daily_2026-11-24", "one best per day")


func test_unknown_mode_falls_back_to_classic() -> void:
	assert_eq(Session.load_mode("does-not-exist").id, "classic", "fallback")


func test_daily_seed_is_deterministic_and_changes_daily() -> void:
	assert_eq(DailySeed.seed_for("2026-11-24"), DailySeed.seed_for("2026-11-24"), "same day, same seed")
	# Every day of a year must get its own seed (regression: consecutive days collided).
	var seen := {}
	for m in range(1, 13):
		for d in range(1, 29):
			seen[DailySeed.seed_for(DailySeed.date_key(2026, m, d))] = true
	assert_eq(seen.size(), 12 * 28, "336 different days -> 336 different seeds")
	assert_true(DailySeed.seed_for("2026-11-24") > 0, "seed positive (0 means random)")
	assert_eq(DailySeed.date_key(2026, 3, 7), "2026-03-07", "zero-padded key")
	assert_eq(DailySeed.pretty("2026-11-24"), "Nov 24", "pretty label")


func test_multi_core_gravity_sums_pulls() -> void:
	var a := OrbitPhysics.gravity_acceleration_multi(Vector2(0, 100), [Vector2(-50, 0), Vector2(50, 0)], 100.0)
	assert_almost(a.x, 0.0, 0.001, "sideways pulls cancel on the middle line")
	assert_true(a.y < 0.0, "net pull toward the line between the cores")
	var single := OrbitPhysics.gravity_acceleration_multi(Vector2(100, 0), [Vector2.ZERO], 50.0)
	assert_vec_almost(single, Vector2(-50, 0), 0.001, "one core = normal gravity")
