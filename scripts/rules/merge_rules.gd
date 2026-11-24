class_name MergeRules
extends RefCounted
## Pure merge logic. No nodes, no physics — just data in, decisions out.
##
## The physics engine only tells us "which planets touch which". This class
## decides which of those contacts become merges. Because it works on plain
## data it is fully unit-testable, and it is the single place that enforces
## the most important rule: **a planet can take part in at most one merge
## per physics step** (the duplicate-merge guard).

enum Outcome { NONE, MERGE, VANISH }
## Everything that can happen when two planets touch (special planets included).
enum Action { NONE, MERGE, VANISH, DOWNGRADE, SWALLOW, DESTROY_BOTH }

const K := PlanetKind.Kind


## What happens when planets of these two levels touch.
## `max_level` = highest level index. Two max-level planets either vanish
## (clearing space, big bonus) or simply don't merge, depending on config.
static func outcome(level_a: int, level_b: int, max_level: int, max_pairs_vanish: bool) -> Outcome:
	if level_a != level_b:
		return Outcome.NONE
	if level_a < max_level:
		return Outcome.MERGE
	return Outcome.VANISH if max_pairs_vanish else Outcome.NONE


## What happens when planet A (kind ka, level la) touches planet B.
## Returns { "action": Action, "actor": 0 (A acts) or 1 (B acts) }.
## The actor matters for one-sided actions: the comet that downgrades, the
## black hole that swallows.
static func interaction(ka: int, la: int, kb: int, lb: int, max_level: int, max_pairs_vanish: bool) -> Dictionary:
	if ka == K.BLACK_HOLE or kb == K.BLACK_HOLE:
		if ka == K.BLACK_HOLE and kb == K.BLACK_HOLE:
			return {"action": Action.DESTROY_BOTH, "actor": 0}
		return {"action": Action.SWALLOW, "actor": 0 if ka == K.BLACK_HOLE else 1}
	if ka == K.COMET or kb == K.COMET:
		var other_kind := kb if ka == K.COMET else ka
		if other_kind == K.COMET or other_kind == K.WILDCARD:
			return {"action": Action.DESTROY_BOTH, "actor": 0}
		return {"action": Action.DOWNGRADE, "actor": 0 if ka == K.COMET else 1}
	if ka == K.WILDCARD or kb == K.WILDCARD:
		if ka == K.WILDCARD and kb == K.WILDCARD:
			return {"action": Action.MERGE, "actor": 0}
		var other_level := lb if ka == K.WILDCARD else la
		if other_level < max_level:
			return {"action": Action.MERGE, "actor": 0}
		return {"action": Action.VANISH if max_pairs_vanish else Action.NONE, "actor": 0}
	# Normal planets and anchors merge by level.
	match outcome(la, lb, max_level, max_pairs_vanish):
		Outcome.MERGE:
			return {"action": Action.MERGE, "actor": 0}
		Outcome.VANISH:
			return {"action": Action.VANISH, "actor": 0}
	return {"action": Action.NONE, "actor": 0}


## Level of the planet created by a MERGE between A and B.
static func merge_result_level(ka: int, la: int, kb: int, lb: int) -> int:
	if ka == K.WILDCARD and kb == K.WILDCARD:
		return 1
	if ka == K.WILDCARD:
		return lb + 1
	if kb == K.WILDCARD:
		return la + 1
	return la + 1


## Like find_pairs(), for planets of any kind. `kinds`: id -> PlanetKind.Kind.
## Returns an Array of { "a", "b", "action", "actor" }; every id at most once.
static func find_interactions(order: Array, levels: Dictionary, kinds: Dictionary, contacts: Dictionary,
		max_level: int, max_pairs_vanish: bool) -> Array:
	var rank := {}
	for i in order.size():
		rank[order[i]] = i
	var used := {}
	var result := []
	for a in order:
		if used.has(a) or not levels.has(a):
			continue
		var best = null
		var best_info := {}
		for b in contacts.get(a, []):
			if b == a or used.has(b) or not levels.has(b) or not rank.has(b):
				continue
			var info := interaction(kinds.get(a, K.NORMAL), levels[a], kinds.get(b, K.NORMAL), levels[b],
				max_level, max_pairs_vanish)
			if info["action"] == Action.NONE:
				continue
			if best == null or rank[b] < rank[best]:
				best = b
				best_info = info
		if best != null:
			used[a] = true
			used[best] = true
			result.append({"a": a, "b": best, "action": best_info["action"], "actor": best_info["actor"]})
	return result


## Chooses which touching pairs merge this step.
##   order    — planet ids in spawn order (oldest first). Makes results
##              deterministic: the same situation always resolves the same way.
##   levels   — id -> level, only for planets allowed to merge (active ones).
##   contacts — id -> Array of ids it is touching.
## Returns an Array of [id_a, id_b] pairs. Every id appears at most once.
static func find_pairs(order: Array, levels: Dictionary, contacts: Dictionary,
		max_level: int, max_pairs_vanish: bool) -> Array:
	var rank := {}
	for i in order.size():
		rank[order[i]] = i

	var used := {}
	var pairs := []
	for a in order:
		if used.has(a) or not levels.has(a):
			continue
		var best = null
		for b in contacts.get(a, []):
			if b == a or used.has(b) or not levels.has(b) or not rank.has(b):
				continue
			if outcome(levels[a], levels[b], max_level, max_pairs_vanish) == Outcome.NONE:
				continue
			# If several partners are possible, the oldest wins (deterministic).
			if best == null or rank[b] < rank[best]:
				best = b
		if best != null:
			used[a] = true
			used[best] = true
			pairs.append([a, best])
	return pairs


## The merged planet appears at the pair's center of mass (physically natural:
## the bigger/heavier side "absorbs" the other).
static func center_of_mass(pos_a: Vector2, mass_a: float, pos_b: Vector2, mass_b: float) -> Vector2:
	var total := mass_a + mass_b
	if total <= 0.0:
		return (pos_a + pos_b) * 0.5
	return (pos_a * mass_a + pos_b * mass_b) / total


## Momentum is conserved, then scaled by `keep` (0..1). Keeping less than 100%
## makes merges feel "soft" and avoids chaotic chain explosions.
static func merged_velocity(vel_a: Vector2, mass_a: float, vel_b: Vector2, mass_b: float, keep: float) -> Vector2:
	var total := mass_a + mass_b
	if total <= 0.0:
		return Vector2.ZERO
	return (vel_a * mass_a + vel_b * mass_b) / total * clampf(keep, 0.0, 1.0)


## Chain depth of a newly merged planet.
## A parent only passes on its chain if it was itself born from a merge less
## than `window` seconds ago. So depth 1 = normal merge, 2 = a merge caused
## directly by a previous merge, 3 = ... and so on.
## Launched planets have depth 0.
static func next_chain_depth(depth_a: int, age_a: float, depth_b: int, age_b: float, window: float) -> int:
	var carried := 0
	if age_a <= window:
		carried = maxi(carried, depth_a)
	if age_b <= window:
		carried = maxi(carried, depth_b)
	return carried + 1
