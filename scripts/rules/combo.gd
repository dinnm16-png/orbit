class_name Combo
extends RefCounted
## Merges in quick succession build a combo that multiplies points.
## Different from chains: chains are cascades; combos reward the player's pace.

const STEP := 0.25       # multiplier gained per combo step
const MAX_MULT := 3.0

var count: int = 0       # merges in the current combo (0 = none)
var remaining: float = 0.0
var window: float = 2.6


## Call on every merge. Returns the multiplier for this merge's points.
func hit() -> float:
	count = count + 1 if remaining > 0.0 else 1
	remaining = window
	return multiplier()


## Advance time (seconds). The combo ends when the window runs out.
func tick(delta: float) -> void:
	if remaining > 0.0:
		remaining = maxf(remaining - delta, 0.0)
		if remaining == 0.0:
			count = 0


func multiplier() -> float:
	return minf(1.0 + STEP * maxi(count - 1, 0), MAX_MULT)


## 0..1 time left in the window (for the draining HUD ring).
func fraction() -> float:
	return remaining / window if window > 0.0 else 0.0
