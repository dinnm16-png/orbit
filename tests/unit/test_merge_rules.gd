extends "res://tests/test_case.gd"

const MAX := 11


func test_outcome_same_level_merges() -> void:
	assert_eq(MergeRules.outcome(3, 3, MAX, true), MergeRules.Outcome.MERGE, "same level")


func test_outcome_different_levels_do_not_merge() -> void:
	assert_eq(MergeRules.outcome(3, 4, MAX, true), MergeRules.Outcome.NONE, "different levels")


func test_outcome_max_level_pair() -> void:
	assert_eq(MergeRules.outcome(MAX, MAX, MAX, true), MergeRules.Outcome.VANISH, "vanish enabled")
	assert_eq(MergeRules.outcome(MAX, MAX, MAX, false), MergeRules.Outcome.NONE, "vanish disabled")


func test_find_pairs_simple_pair() -> void:
	var pairs := MergeRules.find_pairs([1, 2], {1: 0, 2: 0}, {1: [2], 2: [1]}, MAX, true)
	assert_eq(pairs, [[1, 2]], "one pair")


func test_find_pairs_three_touching_merges_only_once() -> void:
	# A, B, C all touch each other at the same level: exactly ONE merge.
	var contacts := {1: [2, 3], 2: [1, 3], 3: [1, 2]}
	var pairs := MergeRules.find_pairs([1, 2, 3], {1: 0, 2: 0, 3: 0}, contacts, MAX, true)
	assert_eq(pairs.size(), 1, "only one merge")
	assert_eq(pairs, [[1, 2]], "oldest two merge (deterministic)")


func test_find_pairs_never_reuses_a_planet() -> void:
	# A chain 1-2-3-4 where everything is the same level: 1+2 and 3+4.
	var contacts := {1: [2], 2: [1, 3], 3: [2, 4], 4: [3]}
	var levels := {1: 0, 2: 0, 3: 0, 4: 0}
	var pairs := MergeRules.find_pairs([1, 2, 3, 4], levels, contacts, MAX, true)
	assert_eq(pairs, [[1, 2], [3, 4]], "two disjoint pairs")
	var seen := {}
	for pair in pairs:
		for id in pair:
			assert_false(seen.has(id), "id %d used twice" % id)
			seen[id] = true


func test_find_pairs_ignores_inactive_planets() -> void:
	# Planet 2 is touching but not in `levels` (e.g. frozen at the launcher).
	var pairs := MergeRules.find_pairs([1, 2], {1: 0}, {1: [2], 2: [1]}, MAX, true)
	assert_true(pairs.is_empty(), "inactive planet can't merge")


func test_find_pairs_ignores_different_levels() -> void:
	var pairs := MergeRules.find_pairs([1, 2], {1: 0, 2: 1}, {1: [2], 2: [1]}, MAX, true)
	assert_true(pairs.is_empty(), "different levels")


func test_find_pairs_with_one_sided_contact() -> void:
	# Physics may report a contact on only one of the two bodies.
	var pairs := MergeRules.find_pairs([1, 2], {1: 0, 2: 0}, {1: [], 2: [1]}, MAX, true)
	assert_eq(pairs, [[2, 1]], "one-sided contact still merges once")


func test_center_of_mass_weights_heavier_planet() -> void:
	var p := MergeRules.center_of_mass(Vector2(0, 0), 3.0, Vector2(4, 0), 1.0)
	assert_vec_almost(p, Vector2(1, 0), 0.0001, "closer to heavier planet")


func test_merged_velocity_conserves_scaled_momentum() -> void:
	var v := MergeRules.merged_velocity(Vector2(10, 0), 1.0, Vector2(-10, 0), 1.0, 1.0)
	assert_vec_almost(v, Vector2.ZERO, 0.0001, "opposite momenta cancel")
	v = MergeRules.merged_velocity(Vector2(10, 0), 1.0, Vector2(10, 0), 1.0, 0.5)
	assert_vec_almost(v, Vector2(5, 0), 0.0001, "keep factor applied")


func test_chain_depth() -> void:
	assert_eq(MergeRules.next_chain_depth(0, 5.0, 0, 5.0, 1.2), 1, "two launched planets")
	assert_eq(MergeRules.next_chain_depth(1, 0.3, 0, 9.0, 1.2), 2, "fresh merge result continues chain")
	assert_eq(MergeRules.next_chain_depth(3, 2.0, 0, 9.0, 1.2), 1, "old merge result starts new chain")
	assert_eq(MergeRules.next_chain_depth(2, 0.1, 4, 0.1, 1.2), 5, "longest fresh chain wins")
