class_name SwitchToggle
extends Button
## A labeled on/off switch in ORBIT's style: label on the left, pill switch on
## the right that turns aqua when on. Unambiguous at a glance.



func _ready() -> void:
	toggle_mode = true
	flat = true
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		add_theme_color_override(c, Color(UIStyle.WHITE, 0.85))
	toggled.connect(func(_on): queue_redraw())


func _draw() -> void:
	var track := Rect2(Vector2(size.x - 64.0, size.y * 0.5 - 16.0), Vector2(64.0, 32.0))
	var on := button_pressed
	# Opaque colors: the track is built from overlapping shapes, and translucent
	# colors would double up where they overlap (visible seams).
	var track_color := UIStyle.AQUA.darkened(0.1) if on else UIStyle.SECONDARY.lightened(0.1)
	var r := track.size.y * 0.5
	# Rounded track = rectangle + two half circles.
	draw_rect(Rect2(track.position + Vector2(r, 0), track.size - Vector2(2 * r, 0)), track_color)
	draw_circle(track.position + Vector2(r, r), r, track_color, true, -1.0, true)
	draw_circle(track.end - Vector2(r, r), r, track_color, true, -1.0, true)
	var knob_x := track.end.x - r if on else track.position.x + r
	draw_circle(Vector2(knob_x, track.position.y + r), r - 4.0, UIStyle.WHITE if on else Color(UIStyle.WHITE, 0.6), true, -1.0, true)
