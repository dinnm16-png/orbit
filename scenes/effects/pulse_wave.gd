class_name PulseWave
extends Node2D
## Gravity pulse effect: a ring collapsing from the arena edge into the core.

const LIFETIME := 0.55

var from_radius: float = 300.0
var color: Color = Color("#52E5D5")
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / LIFETIME, 0.0, 1.0)
	var eased := k * k
	var r := lerpf(from_radius, 30.0, eased)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(color, 0.7 * (1.0 - k)), lerpf(5.0, 1.0, k), true)
	draw_arc(Vector2.ZERO, r * 1.06, 0.0, TAU, 96, Color(color, 0.25 * (1.0 - k)), 1.0, true)
