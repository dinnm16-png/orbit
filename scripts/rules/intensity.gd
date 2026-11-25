class_name Intensity
extends RefCounted
## Score-driven escalation: "Orbit stages" I to X.
##
## Every stage turns several small dials at once, so a run keeps getting
## faster and harder without any single sudden jump. Everything depends only
## on the score, so Daily and challenge games stay identical for everyone.

## Score needed to reach stage 1..10 (index 0 = stage 1).
## (Tuned with tools/balance.gd: combos inflate scores, so stages are spread
## across a real run instead of arriving in the first minute.)
const THRESHOLDS := [0, 1500, 4000, 8000, 14000, 22000, 33000, 47000, 65000, 90000]
## The ring tightens by this much per stage (px): pressure you can see.
const RING_TIGHTEN := 8.0
const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
## What changes, announced on the stage-up banner.
const SUBTITLES := [
	"", "The orbit tightens", "New planets incoming", "Orbital winds", "Bigger planets incoming",
	"Faster reloads", "Comets and black holes", "Even bigger planets", "Gravity surges", "Maximum orbit",
]


static func max_stage() -> int:
	return THRESHOLDS.size()


## 1-based stage for a score.
static func stage_for(score: int) -> int:
	var stage := 1
	for i in THRESHOLDS.size():
		if score >= THRESHOLDS[i]:
			stage = i + 1
	return stage


## 0..1 progress from this stage to the next (1 at the last stage).
static func progress(score: int) -> float:
	var s := stage_for(score)
	if s >= max_stage():
		return 1.0
	var lo: int = THRESHOLDS[s - 1]
	var hi: int = THRESHOLDS[s]
	return clampf(float(score - lo) / (hi - lo), 0.0, 1.0)


## Sets the live config for `stage`, from the untouched `base` (mode +
## difficulty). Writes in place: planets and the launcher hold this same
## config object, so they pick the changes up immediately.
static func apply(cfg: GameConfig, base: GameConfig, stage: int) -> void:
	var k := clampi(stage, 1, max_stage()) - 1
	cfg.gravity_strength = base.gravity_strength * (1.0 + 0.07 * k)
	cfg.max_planet_speed = base.max_planet_speed * (1.0 + 0.06 * k)
	cfg.max_launch_speed = base.max_launch_speed * (1.0 + 0.05 * k)
	cfg.reload_delay = base.reload_delay * maxf(0.55, 1.0 - 0.06 * k)
	cfg.game_over_grace_time = maxf(1.0, base.game_over_grace_time - 0.12 * k)
	# More planet sizes at stages III, V and VII: the board fills faster.
	var extra := (1 if k >= 2 else 0) + (1 if k >= 4 else 0) + (1 if k >= 6 else 0) + (1 if k >= 8 else 0)
	cfg.spawn_max_level = mini(base.spawn_max_level + extra, base.level_count() - 3)
	cfg.special_chance = minf(0.2, base.special_chance + 0.01 * k)
	var w := base.special_weights.duplicate()
	if k >= 6:
		w[1] += 0.1  # comets
		w[2] += 0.1  # black holes
	cfg.special_weights = w
	# Orbital wind from stage IV: a sideways push that slowly swirls the pile.
	# (Kept gentle: measured with the bot, a strong wind *helps* by causing merges.)
	cfg.orbital_drift = 0.0 if k < 3 else 30.0 + 12.0 * (k - 3)


## Ring radius for a stage (the base ring minus a little per stage).
static func ring_radius(base_radius: float, stage: int) -> float:
	return base_radius - RING_TIGHTEN * (clampi(stage, 1, max_stage()) - 1)


## Combo window (seconds) shrinks as stages climb: keep the pace up.
static func combo_window(stage: int) -> float:
	return maxf(1.4, 2.6 - 0.12 * (clampi(stage, 1, max_stage()) - 1))
