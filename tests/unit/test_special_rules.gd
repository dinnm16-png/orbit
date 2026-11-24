extends "res://tests/test_case.gd"

const K := PlanetKind.Kind
const A := MergeRules.Action
const MAX := 11


func _act(ka: int, la: int, kb: int, lb: int) -> Dictionary:
	return MergeRules.interaction(ka, la, kb, lb, MAX, true)


func test_normal_planets_follow_level_rules() -> void:
	assert_eq(_act(K.NORMAL, 3, K.NORMAL, 3)["action"], A.MERGE, "same level merges")
	assert_eq(_act(K.NORMAL, 3, K.NORMAL, 4)["action"], A.NONE, "different levels don't")
	assert_eq(_act(K.ANCHOR, 2, K.NORMAL, 2)["action"], A.MERGE, "anchor merges by level")


func test_wildcard_merges_with_any_level() -> void:
	assert_eq(_act(K.WILDCARD, 1, K.NORMAL, 7)["action"], A.MERGE, "wildcard + level 7")
	assert_eq(MergeRules.merge_result_level(K.WILDCARD, 1, K.NORMAL, 7), 8, "becomes level 8")
	assert_eq(MergeRules.merge_result_level(K.NORMAL, 4, K.WILDCARD, 1), 5, "order doesn't matter")
	assert_eq(MergeRules.merge_result_level(K.WILDCARD, 1, K.WILDCARD, 1), 1, "two wildcards -> level 1")
	assert_eq(_act(K.WILDCARD, 1, K.NORMAL, MAX)["action"], A.VANISH, "wildcard + max level vanishes")


func test_comet_downgrades_and_names_the_actor() -> void:
	var r := _act(K.NORMAL, 5, K.COMET, 0)
	assert_eq(r["action"], A.DOWNGRADE, "comet downgrades")
	assert_eq(r["actor"], 1, "B (the comet) is the actor")
	assert_eq(_act(K.COMET, 0, K.COMET, 0)["action"], A.DESTROY_BOTH, "two comets shatter")
	assert_eq(_act(K.COMET, 0, K.WILDCARD, 1)["action"], A.DESTROY_BOTH, "comet + wildcard shatter")


func test_black_hole_swallows_anything() -> void:
	for k in [K.NORMAL, K.ANCHOR, K.WILDCARD, K.COMET]:
		var r := _act(k, 3, K.BLACK_HOLE, 1)
		assert_eq(r["action"], A.SWALLOW, "black hole swallows kind %d" % k)
		assert_eq(r["actor"], 1, "the black hole acts")
	assert_eq(_act(K.BLACK_HOLE, 1, K.BLACK_HOLE, 1)["action"], A.DESTROY_BOTH, "two black holes annihilate")


func test_black_hole_touching_two_planets_swallows_only_one() -> void:
	# Duplicate-interaction guard still holds with special planets.
	var order := [1, 2, 3]
	var levels := {1: 1, 2: 4, 3: 6}
	var kinds := {1: K.BLACK_HOLE, 2: K.NORMAL, 3: K.NORMAL}
	var contacts := {1: [2, 3], 2: [1], 3: [1]}
	var found := MergeRules.find_interactions(order, levels, kinds, contacts, MAX, true)
	assert_eq(found.size(), 1, "one interaction")
	assert_eq(found[0]["action"], A.SWALLOW, "a swallow")


func test_find_pairs_unchanged_for_normal_planets() -> void:
	var pairs := MergeRules.find_pairs([1, 2, 3], {1: 0, 2: 0, 3: 0}, {1: [2, 3], 2: [1, 3], 3: [1, 2]}, MAX, true)
	assert_eq(pairs, [[1, 2]], "legacy API still deterministic")


func test_special_sizes() -> void:
	assert_eq(PlanetKind.size_level(K.COMET, 6), 0, "comets are small")
	assert_eq(PlanetKind.size_level(K.ANCHOR, 6), 6, "anchors keep their level")
