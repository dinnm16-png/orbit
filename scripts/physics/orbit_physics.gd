class_name OrbitPhysics
extends RefCounted
## Pure, side-effect-free physics math.
##
## Keeping the math in static functions (instead of inside nodes) means we can
## unit-test it without running a scene, and reuse it later (e.g. for a
## trajectory preview that must match the real simulation exactly).


## Acceleration (pixels/s²) pulling a body at `position` toward `center`.
## Constant magnitude by design: real inverse-square gravity explodes near the
## core and makes stacks jittery. Constant pull = predictable, fair, stable.
static func gravity_acceleration(position: Vector2, center: Vector2, strength: float) -> Vector2:
	var to_center := center - position
	var distance := to_center.length()
	if distance < 0.001:
		return Vector2.ZERO
	return to_center / distance * strength


## Sum of the pulls of several cores (Binary Star). Each core pulls with
## `strength`; with one core this equals gravity_acceleration().
static func gravity_acceleration_multi(position: Vector2, centers: Array, strength: float) -> Vector2:
	var total := Vector2.ZERO
	for c in centers:
		total += gravity_acceleration(position, c, strength)
	return total


## Caps a velocity to `max_speed` while keeping its direction.
static func clamp_velocity(velocity: Vector2, max_speed: float) -> Vector2:
	return velocity.limit_length(max_speed)


## Converts a slingshot drag into a launch velocity.
## `pull` = drag start - current finger position (i.e. the player pulls back,
## the planet flies the opposite way of the finger movement).
## Returns Vector2.ZERO when the drag is too short (treated as cancel).
static func launch_velocity(pull: Vector2, min_drag: float, max_drag: float, max_speed: float) -> Vector2:
	var length := pull.length()
	if length < min_drag:
		return Vector2.ZERO
	return pull / length * launch_power(length, max_drag) * max_speed


## Launch power from 0.0 to 1.0 for a given drag length.
static func launch_power(drag_length: float, max_drag: float) -> float:
	if max_drag <= 0.0:
		return 0.0
	return clampf(drag_length / max_drag, 0.0, 1.0)


## Mass proportional to area, so bigger planets feel heavier.
static func mass_for_radius(radius: float, reference_radius: float) -> float:
	var ratio := radius / maxf(reference_radius, 0.001)
	return maxf(ratio * ratio, 0.05)
