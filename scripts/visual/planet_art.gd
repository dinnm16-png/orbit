class_name PlanetArt
extends RefCounted
## Procedural planet drawing, shared by real planets and the next-planet preview
## so both always look identical. Call from inside a CanvasItem's draw callback.

const LIGHT_DIR := Vector2(-0.6, -0.8)


static func draw_planet(ci: CanvasItem, radius: float, c: Color, level: int, glow: bool = true) -> void:
	# Soft outer glow: stacked translucent circles approximate a radial gradient.
	if glow:
		var glow_steps := 6
		for i in glow_steps:
			var t := float(i) / glow_steps
			var r := radius * (1.65 - t * 0.6)
			ci.draw_circle(Vector2.ZERO, r, Color(c, 0.035 + t * 0.02), true, -1.0, true)

	# Body: dark base, then lighter discs shifted toward the light = 3D shading.
	var dark := c.darkened(0.55)
	ci.draw_circle(Vector2.ZERO, radius, dark, true, -1.0, true)
	var shade_steps := 7
	for i in range(1, shade_steps):
		var t := float(i) / shade_steps
		var r := radius * (1.0 - t * 0.62)
		var offset := LIGHT_DIR * radius * t * 0.38
		ci.draw_circle(offset, r, dark.lerp(c.lightened(0.18), t), true, -1.0, true)

	# Rim light on the lit side and a thin full outline for crispness.
	ci.draw_arc(Vector2.ZERO, radius - 0.75, 0.0, TAU, 48, Color(c.lightened(0.5), 0.35), 1.5, true)
	ci.draw_arc(Vector2.ZERO, radius - 1.0, PI * 1.05, PI * 1.6, 24, Color(1, 1, 1, 0.45), 2.0, true)

	# Larger planets get an elegant tilted orbital ring.
	if has_ring(level):
		var points := PackedVector2Array()
		var segments := 64
		for i in segments + 1:
			var a := TAU * i / segments
			points.append(Vector2(cos(a) * radius * 1.55, sin(a) * radius * 0.38).rotated(-0.35))
		ci.draw_polyline(points, Color(c.lightened(0.35), 0.55), 1.5, true)


static func has_ring(level: int) -> bool:
	return (level >= 3 and level % 3 == 0) or level >= 9
