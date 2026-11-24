class_name Difficulty
extends RefCounted
## Easy / Normal / Hard as small, readable config changes.

enum Level { EASY, NORMAL, HARD }

const NAMES := ["Easy", "Normal", "Hard"]


## A copy of `cfg` adjusted for `level`. Never modifies `cfg`.
static func apply(cfg: GameConfig, level: int) -> GameConfig:
	var c: GameConfig = cfg.duplicate()
	match level:
		Level.EASY:
			c.boundary_radius += 40.0           # more room
			c.spawn_max_level = 1               # fewer different planets -> more matches
			c.game_over_grace_time = 3.0        # more time to react
		Level.HARD:
			c.boundary_radius -= 30.0
			c.spawn_max_level = mini(3, c.level_count() - 1)
			c.game_over_grace_time = 1.2
	return c


## Best scores are kept separately per difficulty (Normal keeps the plain key).
static func best_key_suffix(level: int) -> String:
	match level:
		Level.EASY:
			return "_easy"
		Level.HARD:
			return "_hard"
	return ""
