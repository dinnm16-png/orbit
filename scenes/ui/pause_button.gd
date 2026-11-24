class_name PauseButton
extends Button
## Small, unobtrusive pause button (two rounded bars), drawn in code.



func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(72, 72)  # Comfortable touch target (~9 mm).
	size = custom_minimum_size
	for state in ["normal", "hover", "pressed", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())


func _draw() -> void:
	var c := size * 0.5
	var alpha := 0.75 if is_hovered() or button_pressed else 0.45
	draw_arc(c, 24.0, 0.0, TAU, 40, Color(UIStyle.WHITE, 0.12), 1.5, true)
	for dx in [-6.0, 6.0]:
		draw_rect(Rect2(c + Vector2(dx - 2.5, -9.0), Vector2(5.0, 18.0)), Color(UIStyle.WHITE, alpha))
