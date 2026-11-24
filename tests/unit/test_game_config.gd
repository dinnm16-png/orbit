extends "res://tests/test_case.gd"

const DEFAULT_CONFIG := "res://resources/config/default_config.tres"


func test_default_config_is_valid() -> void:
	var config: GameConfig = load(DEFAULT_CONFIG)
	assert_true(config != null, "default config loads")
	var errors := config.validate()
	assert_true(errors.is_empty(), "default config valid: %s" % ", ".join(errors))


func test_default_config_has_twelve_levels() -> void:
	var config: GameConfig = load(DEFAULT_CONFIG)
	assert_eq(config.level_count(), 12, "level count")


func test_level_lookup_is_clamped() -> void:
	var config := GameConfig.new()
	assert_eq(config.get_planet_radius(-5), config.planet_radii[0], "below range")
	assert_eq(config.get_planet_radius(99), config.planet_radii[11], "above range")


func test_validate_catches_bad_values() -> void:
	var config := GameConfig.new()
	config.planet_radii = PackedFloat32Array([20.0, 10.0])
	config.planet_colors = PackedColorArray([Color.WHITE, Color.WHITE])
	config.spawn_max_level = 1
	assert_false(config.validate().is_empty(), "non-increasing radii rejected")

	config = GameConfig.new()
	config.max_launch_speed = config.max_planet_speed + 1.0
	assert_false(config.validate().is_empty(), "launch faster than speed cap rejected")


func test_adjacent_levels_have_distinct_colors() -> void:
	# Readability: players must tell neighbouring levels apart instantly.
	var config: GameConfig = load(DEFAULT_CONFIG)
	for i in range(1, config.level_count()):
		var a := config.get_planet_color(i - 1)
		var b := config.get_planet_color(i)
		var diff := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
		assert_true(diff > 0.25, "levels %d and %d look too similar (%.2f)" % [i - 1, i, diff])
