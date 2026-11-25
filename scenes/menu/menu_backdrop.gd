class_name MenuBackdrop
extends Node2D
## Calm animated background for the menus: a faint core with planets slowly
## orbiting on tilted ellipses, plus a static star field. Only transforms
## change each frame (planet bodies are cached shader quads).

const ORBITS := [
	# [radius_x, radius_y, speed, phase, planet_radius, color]
	[150.0, 52.0, 0.22, 0.0, 15.0, "#52E5D5"],
	[235.0, 82.0, 0.15, 2.1, 22.0, "#FF8FC8"],
	[320.0, 112.0, 0.10, 4.0, 30.0, "#FFD27A"],
	[410.0, 142.0, 0.07, 1.2, 18.0, "#7A9BFF"],
]
const TILT := -0.32

var center: Vector2 = Vector2(360, 300)
## Planet colors (the current theme's palette).
var colors: PackedColorArray = PackedColorArray()

var _t: float = 0.0
var _planets: Array[Node2D] = []
var _stars := PackedVector3Array()


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		_stars.append(Vector3(rng.randf() * 720.0, rng.randf() * 1600.0, rng.randf()))
	var glow := Node2D.new()
	glow.material = PlanetArt.material()
	glow.draw.connect(func(): PlanetArt.draw_body(glow, 46.0, UIStyle.VIOLET))
	var palette := [1, 2, 4, 3]
	glow.position = center
	glow.modulate.a = 0.4
	add_child(glow)
	for k in ORBITS.size():
		var o: Array = ORBITS[k]
		var p := Node2D.new()
		p.material = PlanetArt.material()
		var r: float = o[4]
		var col := colors[palette[k]] if colors.size() >= 5 else Color(o[5])
		p.draw.connect(func(): PlanetArt.draw_body(p, r, col))
		p.modulate.a = 0.75
		add_child(p)
		_planets.append(p)
	_place()


func _process(delta: float) -> void:
	_t += delta
	_place()


func _place() -> void:
	for i in _planets.size():
		var o: Array = ORBITS[i]
		var a: float = o[3] + _t * o[2]
		_planets[i].position = center + Vector2(cos(a) * o[0], sin(a) * o[1]).rotated(TILT)
		# Planets on the far side of the orbit look smaller and dimmer.
		var depth := 0.5 + 0.5 * sin(a)
		_planets[i].scale = Vector2.ONE * lerpf(0.75, 1.0, depth)
		_planets[i].modulate.a = lerpf(0.35, 0.8, depth)


func _draw() -> void:
	for s in _stars:
		draw_rect(Rect2(Vector2(s.x, s.y) - Vector2.ONE * (0.6 + s.z), Vector2.ONE * (1.2 + s.z * 2.0)), Color(UIStyle.WHITE, 0.08 + s.z * 0.22))  # batched (see Starfield)
	for o in ORBITS:
		var pts := PackedVector2Array()
		for i in 97:
			var a := TAU * i / 96.0
			pts.append(center + Vector2(cos(a) * o[0], sin(a) * o[1]).rotated(TILT))
		draw_polyline(pts, Color(UIStyle.WHITE, 0.05), 1.0, true)
