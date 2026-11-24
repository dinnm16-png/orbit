class_name StarRow
extends Control
## Row of 3 stars, `filled` of them lit. Drawn as polygons (no font glyphs).

var filled: int = 0:
	set(value):
		filled = value
		queue_redraw()
var star_size: float = 22.0
var gap: float = 10.0
var color: Color = Color("#FFD27A")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(star_size * 6 + gap * 2, star_size * 2)


func _draw() -> void:
	var total_w := star_size * 6 + gap * 2
	var x0 := (size.x - total_w) * 0.5 + star_size
	for i in 3:
		var c := Vector2(x0 + i * (star_size * 2 + gap), size.y * 0.5)
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2 + TAU * k / 10.0
			pts.append(c + Vector2.from_angle(a) * (star_size if k % 2 == 0 else star_size * 0.45))
		if i < filled:
			draw_colored_polygon(pts, color)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(UIStyle.WHITE, 0.25), 1.5, true)
