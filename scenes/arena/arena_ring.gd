class_name ArenaRing
extends Node2D
## The playable boundary ring. Separate from the core because some modes have
## two cores (Binary Star) or a ring that shrinks over time (Collapse).


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
## 0..1: how close the outermost planet is to the ring (brightens the ring).
var pressure: float = 0.0:
	set(value):
		if absf(value - pressure) > 0.02 or (value == 0.0) != (pressure == 0.0):
			pressure = value
			queue_redraw()
## Accent color of the current mode (used for the ring itself).
var accent: Color = UIStyle.VIOLET

var _time: float = 0.0
var _warning_visible: bool = false


func _process(delta: float) -> void:
	_time += delta
	if danger > 0.0 or _warning_visible:
		_warning_visible = danger > 0.0
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(UIStyle.SECONDARY, 0.35), true, -1.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128, Color(accent, 0.24 + 0.5 * pressure), 1.5 + 1.5 * pressure, true)
	if radius < base_radius - 12.0:
		# Ghost of the original ring: shows how far the arena has shrunk.
		# All dashes in ONE draw call (72 separate arcs were 72+ draw calls).
		var dashes := 72
		var pts := PackedVector2Array()
		for i in dashes:
			var a0 := TAU * i / dashes
			pts.append(Vector2.from_angle(a0) * base_radius)
			pts.append(Vector2.from_angle(a0 + TAU / dashes * 0.45) * base_radius)
		draw_multiline(pts, Color(accent, 0.12), 1.0, true)
	if danger > 0.0:
		# Pulses toward white, faster as time runs out; never fully fades.
		var warn := 0.5 + 0.5 * sin(_time * (8.0 + 10.0 * danger))
		var ring := accent.lerp(UIStyle.WHITE, danger)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128,
			Color(ring, 0.35 + danger * (0.3 + 0.35 * warn)), 3.0, true)
