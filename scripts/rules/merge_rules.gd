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


## What happens when planets of these two levels touch.
## `max_level` = highest level index. Two max-level planets either vanish
## (clearing space, big bonus) or simply don't merge, depending on config.
static func outcome(level_a: int, level_b: int, max_level: int, max_pairs_vanish: bool) -> Outcome:
	if level_a != level_b:
		return Outcome.NONE
	if level_a < max_level:
		return Outcome.MERGE
	return Outcome.VANISH if max_pairs_vanish else Outcome.NONE


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
