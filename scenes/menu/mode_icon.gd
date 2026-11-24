class_name ModeIcon
extends Node2D
## Small animated emblem for a mode card. Each mode gets a distinct glyph
## around a shader-drawn planet in the mode's accent color.

var mode_id: String = "classic"
var accent: Color = UIStyle.VIOLET
var radius: float = 20.0

var _t: float = 0.0
var _bodies: Array[Node2D] = []


func setup(p_mode_id: String, p_accent: Color, p_radius: float = 20.0) -> void:
	mode_id = p_mode_id
	accent = p_accent
	radius = p_radius


func _ready() -> void:
	var count := 2 if mode_id == "binary" else 1
	for i in count:
		var body := Node2D.new()
		body.material = PlanetArt.material()
		var r := radius * (0.62 if count == 2 else 1.0)
		body.draw.connect(func(): PlanetArt.draw_body(body, r, accent))
		add_child(body)
		_bodies.append(body)
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	if mode_id == "binary":
		for i in _bodies.size():
			_bodies[i].position = Vector2.from_angle(_t * 1.2 + PI * i) * radius * 0.7
	queue_redraw()


func _draw() -> void:
	var c := accent.lightened(0.25)
	var r := radius
	match mode_id:
		"classic":
			var pts := PackedVector2Array()
			for i in 41:
				var a := TAU * i / 40.0
				pts.append(Vector2(cos(a) * r * 1.6, sin(a) * r * 0.42).rotated(-0.35))
			draw_polyline(pts, Color(c, 0.8), 1.6, true)
		"zen":
			var breathe := 0.5 + 0.5 * sin(_t * 1.4)
			draw_arc(Vector2.ZERO, r * (1.35 + 0.15 * breathe), 0, TAU, 40, Color(c, 0.35 * (1.0 - breathe * 0.5)), 1.2, true)
			draw_arc(Vector2.ZERO, r * (1.7 + 0.2 * breathe), 0, TAU, 40, Color(c, 0.18), 1.0, true)
		"daily":
			draw_arc(Vector2.ZERO, r * 1.55, 0, TAU, 40, Color(c, 0.22), 1.0, true)
			draw_circle(Vector2.from_angle(_t * 0.9) * r * 1.55, 3.5, UIStyle.WHITE, true, -1.0, true)
		"blitz":
			var sweep := fmod(_t * 0.5, 1.0)
			draw_arc(Vector2.ZERO, r * 1.45, -PI / 2, -PI / 2 + TAU * (1.0 - sweep), 40, Color(c, 0.85), 2.2, true)
		"collapse":
			var k := fmod(_t * 0.35, 1.0)
			var rr := lerpf(r * 1.9, r * 1.2, k)
			for i in 16:
				var a := TAU * i / 16.0
				draw_arc(Vector2.ZERO, rr, a, a + TAU / 16.0 * 0.5, 3, Color(c, 0.9 * (1.0 - k * 0.6)), 1.6, true)
		"limited":
			for i in 5:
				var a := lerpf(PI * 0.2, PI * 0.8, i / 4.0)
				var lit := i < 5 - int(fmod(_t, 5.0))
				draw_circle(Vector2.from_angle(a) * r * 1.6, 2.8, Color(c, 0.9 if lit else 0.2), true, -1.0, true)
		"binary":
			draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 40, Color(c, 0.25), 1.0, true)
		"puzzle":
			var star := PackedVector2Array()
			for i in 11:
				var a := -PI / 2 + TAU * i / 10.0
				star.append(Vector2.from_angle(a) * (r * 0.55 if i % 2 == 0 else r * 0.24) + Vector2(r * 1.15, -r * 1.0))
			draw_colored_polygon(star, Color(UIStyle.WHITE, 0.9))
