extends "res://tests/test_case.gd"


func test_merge_points_follow_triangular_numbers() -> void:
	assert_eq(ScoreRules.merge_points(1, 1, 10, 0.5), 10, "level 1")
	assert_eq(ScoreRules.merge_points(2, 1, 10, 0.5), 30, "level 2")
	assert_eq(ScoreRules.merge_points(3, 1, 10, 0.5), 60, "level 3")
	assert_eq(ScoreRules.merge_points(11, 1, 10, 0.5), 660, "level 11")


func test_chain_multiplier() -> void:
	assert_almost(ScoreRules.chain_multiplier(0, 0.5), 1.0, 0.0001, "depth 0")
	assert_almost(ScoreRules.chain_multiplier(1, 0.5), 1.0, 0.0001, "depth 1")
	assert_almost(ScoreRules.chain_multiplier(2, 0.5), 1.5, 0.0001, "depth 2")
	assert_almost(ScoreRules.chain_multiplier(4, 0.5), 2.5, 0.0001, "depth 4")


func test_chain_points() -> void:
	assert_eq(ScoreRules.merge_points(2, 2, 10, 0.5), 45, "level 2 at chain depth 2")


func test_vanish_points() -> void:
	assert_eq(ScoreRules.vanish_points(1000, 1, 0.5), 1000, "plain vanish")
	assert_eq(ScoreRules.vanish_points(1000, 3, 0.5), 2000, "vanish in a chain")
