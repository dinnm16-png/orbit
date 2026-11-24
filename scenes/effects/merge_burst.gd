class_name MergeBurst
extends Node2D
## Short merge effect: an expanding ring plus a few sparks flying outward.
## Lives ~0.45 s, then frees itself. Drawn with a handful of primitives, so
## even a long chain reaction costs very little.

const LIFETIME := 0.45
const SPARKS := 8

var color: Color = Color.WHITE
var radius: float = 20.0
var strength: float = 1.0  # 1 = normal merge, >1 = bigger (vanish)

var _t: float = 0.0
var _spin: float = 0.0


func setup(p_color: Color, p_radius: float, p_strength: float = 1.0) -> void:
	color = p_color
	radius = p_radius
	strength = p_strength
	_spin = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / LIFETIME, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - k, 3.0)
	var fade := 1.0 - k
	var c := color.lightened(0.3)

	# Shockwave ring.
	var ring_r := radius * lerpf(0.9, 1.6 + 0.4 * strength, ease_out)
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 48, Color(c, 0.55 * fade), lerpf(4.0, 1.0, k) * strength, true)

	# Sparks.
	for i in SPARKS:
		var dir := Vector2.from_angle(_spin + TAU * i / SPARKS)
		var p := dir * radius * lerpf(0.8, 1.9 + 0.5 * strength, ease_out)
		draw_circle(p, lerpf(3.0, 0.8, k) * strength, Color(c, 0.9 * fade), true, -1.0, true)
