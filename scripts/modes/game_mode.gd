class_name GameMode
extends Resource
## The rules of one game mode, as data.
##
## Every mode (Classic, Zen, Blitz...) is a .tres file in res://resources/modes/
## using this script. The game reads these values instead of having mode
## logic scattered through the code, so a new mode = a new data file.
## Defaults below = Classic.

@export_group("Presentation")
@export var id: String = "classic"
@export var title: String = "Classic"
@export var tagline: String = ""
@export_multiline var description: String = ""
@export var accent: Color = Color("#917AFF")

@export_group("Ending")
## Classic rule: a planet resting outside the ring ends the game.
@export var game_over_on_boundary: bool = true
## Zen: planets resting outside the ring gently fade away instead.
@export var fade_outside_boundary: bool = false
## Seconds of play (0 = unlimited).
@export var time_limit: float = 0.0
## Seconds added for every merge that is part of a chain (depth ≥ 2).
@export var time_bonus_per_chain: float = 0.0
## Number of planets the player may launch (0 = unlimited).
@export var shot_limit: int = 0

@export_group("Arena")
## Ring shrink speed in px/s (0 = fixed ring).
@export var boundary_shrink_per_sec: float = 0.0
@export var boundary_min_radius: float = 170.0
## Each merge pushes a shrinking ring back out by this × new planet level (px).
@export var shrink_relief_per_level: float = 0.0
## Ring radius for this mode (0 = use GameConfig.boundary_radius).
@export var boundary_radius_override: float = 0.0
@export var core_count: int = 1
## Distance between the two cores in Binary Star.
@export var core_spacing: float = 170.0
## Gravity multiplier (each core pulls with strength × this).
@export var gravity_scale: float = 1.0

@export_group("Sequence")
## Same planet sequence for every player on a given day.
@export var daily_seed: bool = false
## Special planets (wildcard, comet...) may appear.
@export var specials: bool = true
## Score-driven escalation (Orbit stages). Off for Zen and Puzzles.
@export var escalates: bool = true
## Hold slot (store one planet, swap later).
@export var hold_enabled: bool = true
## Gravity pulse ability (charged by merges).
@export var pulse_enabled: bool = true
## Difficulty setting applies (fixed-rules modes like Daily ignore it).
@export var difficulty_applies: bool = true


## A copy of `base` with this mode's overrides applied. Never modifies `base`.
func apply_to(base: GameConfig) -> GameConfig:
	var cfg: GameConfig = base.duplicate()
	cfg.gravity_strength *= gravity_scale
	if boundary_radius_override > 0.0:
		cfg.boundary_radius = boundary_radius_override
	return cfg


## Save-file key for this mode's best score. Classic keeps the original key
## so best scores from older versions are preserved.
func best_key(date_key: String = "") -> String:
	if daily_seed:
		return "daily_" + date_key
	return "best" if id == "classic" else "best_" + id


func is_timed() -> bool:
	return time_limit > 0.0


func has_shot_limit() -> bool:
	return shot_limit > 0
