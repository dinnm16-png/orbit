class_name PulseButton
extends Button
## Gravity pulse: a ring that fills as merges charge it; glows when ready.

const COLOR_AQUA := Color("#52E5D5")
const COLOR_WHITE := Color("#F5F5FA")

## 0..1 charge.
var charge: float = 0.0:
	set(value):
		charge = clampf(value, 0.0, 1.0)
		disabled = charge < 1.0
		queue_redraw()

var _t: float = 0.0


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(72, 72)
	size = custom_minimum_size
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	disabled = true


func _process(delta: float) -> void:
	if charge >= 1.0:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var ready := charge >= 1.0
	var glow := 0.5 + 0.5 * sin(_t * 4.0) if ready else 0.0
	if ready:
		draw_circle(c, 30.0, Color(COLOR_AQUA, 0.10 + 0.10 * glow), true, -1.0, true)
	draw_arc(c, 24.0, 0.0, TAU, 48, Color(COLOR_WHITE, 0.12), 2.0, true)
	if charge > 0.0:
		draw_arc(c, 24.0, -PI / 2.0, -PI / 2.0 + TAU * charge, 48,
			Color(COLOR_AQUA, 0.95 if ready else 0.55), 3.0, true)
	# Icon: three chevrons pointing inward (toward the core).
	var a := 0.95 if ready else 0.35
	for i in 3:
		var ang := -PI / 2.0 + TAU * i / 3.0
		var dir := Vector2.from_angle(ang)
		var tip := c + dir * 7.0
		var side := dir.orthogonal() * 5.0
		draw_polyline(PackedVector2Array([tip + dir * 7.0 + side, tip, tip + dir * 7.0 - side]),
			Color(COLOR_WHITE, a), 2.0, true)
