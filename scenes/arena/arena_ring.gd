class_name ArenaRing
extends Node2D
## The playable boundary ring. Separate from the core because some modes have
## two cores (Binary Star) or a ring that shrinks over time (Collapse).

const COLOR_VIOLET := Color("#917AFF")
const COLOR_WHITE := Color("#F5F5FA")
const COLOR_SECONDARY := Color("#171B30")

## Current ring radius (Collapse changes it every frame).
var radius: float = 300.0:
	set(value):
		if not is_equal_approx(value, radius):
			radius = value
			queue_redraw()
## The starting radius; when the ring has shrunk, a faint ghost ring shows it.
var base_radius: float = 300.0
## 0..1: how close the game is to ending. Pulses the ring white.
var danger: float = 0.0
## Accent color of the current mode (used for the ring itself).
var accent: Color = COLOR_VIOLET

var _time: float = 0.0
var _warning_visible: bool = false


func _process(delta: float) -> void:
	_time += delta
	if danger > 0.0 or _warning_visible:
		_warning_visible = danger > 0.0
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(COLOR_SECONDARY, 0.35), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128, Color(accent, 0.24), 1.5, true)
	if radius < base_radius - 12.0:
		# Ghost of the original ring: shows how far the arena has shrunk.
		var dashes := 72
		for i in dashes:
			var a := TAU * i / dashes
			draw_arc(Vector2.ZERO, base_radius, a, a + TAU / dashes * 0.45, 4, Color(accent, 0.12), 1.0, true)
	if danger > 0.0:
		# Pulses toward white, faster as time runs out; never fully fades.
		var warn := 0.5 + 0.5 * sin(_time * (8.0 + 10.0 * danger))
		var ring := accent.lerp(COLOR_WHITE, danger)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128,
			Color(ring, 0.35 + danger * (0.3 + 0.35 * warn)), 3.0, true)
