class_name BoundaryMonitor
extends RefCounted
## Decides when the game is over. (Rule approved in PROJECT_SPEC §5.)
##
## A planet is "in danger" while its CENTER is outside the boundary ring AND it
## is nearly at rest. If it stays in danger continuously for `grace_time`
## seconds, the game is over. Planets merely flying through the ring (fast)
## never count, and a danger timer resets the moment the planet moves back
## inside or speeds up. This keeps the rule fair and readable.
##
## Stateful but engine-free: feed it plain samples, read plain results.

var boundary_radius: float
var speed_threshold: float
var grace_time: float

## planet id -> seconds spent continuously in danger
var _timers: Dictionary = {}


func _init(p_boundary_radius: float, p_speed_threshold: float, p_grace_time: float) -> void:
	boundary_radius = p_boundary_radius
	speed_threshold = p_speed_threshold
	grace_time = p_grace_time


## Is a planet at this distance from the core / speed currently in danger?
func is_in_danger(distance: float, speed: float) -> bool:
	return distance > boundary_radius and speed < speed_threshold


## Advances the timers by `delta` seconds.
## `samples`: Array of { "id": int, "distance": float, "speed": float }
## for every active planet. Planets not in the list are forgotten.
## Returns { "progress": Dictionary id -> 0..1, "max_progress": float, "game_over": bool }.
func update(samples: Array, delta: float) -> Dictionary:
	var next_timers := {}
	var progress := {}
	var max_progress := 0.0
	for s in samples:
		var id: int = s["id"]
		if is_in_danger(s["distance"], s["speed"]):
			next_timers[id] = _timers.get(id, 0.0) + delta
			var p := 1.0 if grace_time <= 0.0 else clampf(next_timers[id] / grace_time, 0.0, 1.0)
			progress[id] = p
			max_progress = maxf(max_progress, p)
	_timers = next_timers
	return {
		"progress": progress,
		"max_progress": max_progress,
		"game_over": max_progress >= 1.0,
	}


func reset() -> void:
	_timers.clear()
