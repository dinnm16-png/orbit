class_name StageMeter
extends Control
## "ORBIT III" + a thin bar filling toward the next stage. The goal-gradient
## effect: the closer the bar gets, the harder it is to stop playing.

var stage: int = 1:
	set(value):
		stage = value
		queue_redraw()
var fill: float = 0.0:
	set(value):
		fill = clampf(value, 0.0, 1.0)
		queue_redraw()
var accent: Color = UIStyle.AQUA


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 30)


func _draw() -> void:
	var font := UIStyle.spaced_font(4)
	var name: String = "ORBIT " + Intensity.NUMERALS[clampi(stage, 1, 10) - 1]
	draw_string(font, Vector2(0, 14), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(UIStyle.WHITE, 0.65))
	var w := minf(220.0, size.x)
	var x0 := (size.x - w) * 0.5
	var y := 24.0
	draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(UIStyle.WHITE, 0.1), 3.0, true)
	if fill > 0.0:
		draw_line(Vector2(x0, y), Vector2(x0 + w * fill, y), accent, 3.0, true)
