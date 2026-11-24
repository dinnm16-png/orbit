class_name ScoreRules
extends RefCounted
## Pure scoring logic.
##
## Merge points grow with the new planet's level using triangular numbers
## (1, 3, 6, 10, 15 ...): bigger merges are clearly worth more, but scores stay
## readable (no exponential blow-up). Chains multiply the points.


## Multiplier for a chain depth: depth 1 = ×1.0, depth 2 = ×(1 + bonus), ...
static func chain_multiplier(chain_depth: int, chain_bonus: float) -> float:
	return 1.0 + chain_bonus * maxi(chain_depth - 1, 0)


## Points for creating a planet of `new_level` (level 1 = first merge result).
static func merge_points(new_level: int, chain_depth: int, base_points: int, chain_bonus: float) -> int:
	var triangular := new_level * (new_level + 1) / 2
	return int(round(base_points * triangular * chain_multiplier(chain_depth, chain_bonus)))


## Points for two max-level planets vanishing together.
static func vanish_points(vanish_base: int, chain_depth: int, chain_bonus: float) -> int:
	return int(round(vanish_base * chain_multiplier(chain_depth, chain_bonus)))
