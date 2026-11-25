class_name ComboBadge
extends Control
## "×1.75" with a ring that drains as the combo window runs out.

var multiplier: float = 1.0
var fraction: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(84, 84)
	size = custom_minimum_size


func show_combo(mult: float, frac: float) -> void:
	multiplier = mult
	fraction = frac
	visible = mult > 1.0
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var heat := clampf((multiplier - 1.0) / 2.0, 0.0, 1.0)
	var col := UIStyle.AQUA.lerp(Color("#FFD27A"), heat)
	draw_arc(c, 30.0, 0, TAU, 40, Color(UIStyle.WHITE, 0.1), 3.0, true)
	draw_arc(c, 30.0, -PI / 2, -PI / 2 + TAU * fraction, 40, col, 3.5, true)
	var font := UIStyle.spaced_font(0)
	# 1.75 -> "1.75", 1.5 -> "1.5", 2.0 -> "2" (no stray dot).
	var num := ("%.2f" % multiplier).rstrip("0").rstrip(".")
	draw_string(font, Vector2(0, c.y + 8), "×" + num,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, col)
	draw_string(UIStyle.spaced_font(2), Vector2(0, c.y + 52), "COMBO", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(col, 0.7))
