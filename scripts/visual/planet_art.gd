class_name PlanetArt
extends RefCounted
## Planet drawing shared by real planets and the next-planet preview.
##
## The body (shading, rim light, glow) is ONE quad rendered by
## res://resources/shaders/planet.gdshader. All planets share a single
## ShaderMaterial and pass their color as the vertex color, so Godot can batch
## many planets into very few draw calls. Rings are a thin separate overlay.

## Quad half-size relative to the radius. Must match GLOW_SCALE in the shader.
const GLOW_SCALE := 1.7
const SHADER := preload("res://resources/shaders/planet.gdshader")

static var _material: ShaderMaterial


## The one shared material. Assign it to the CanvasItem that calls draw_body().
static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	return _material


## Draws the planet body + glow. `ci` must use PlanetArt.material().
## The quad always covers the full glow area: the shader fades the glow to
## zero exactly at the quad's edge, so no square corners can ever show.
static func draw_body(ci: CanvasItem, radius: float, color: Color) -> void:
	var h := radius * GLOW_SCALE
	var points := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var uvs := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var colors := PackedColorArray([color, color, color, color])
	ci.draw_primitive(points, colors, uvs)


## Draws the tilted orbital ring for levels that have one (default material).
static func draw_ring(ci: CanvasItem, radius: float, color: Color, level: int) -> void:
	if not has_ring(level):
		return
	var points := PackedVector2Array()
	var segments := 48
	for i in segments + 1:
		var a := TAU * i / segments
		points.append(Vector2(cos(a) * radius * 1.55, sin(a) * radius * 0.38).rotated(-0.35))
	ci.draw_polyline(points, Color(color.lightened(0.35), 0.55), 1.5, true)


## Level number (1-based) in the planet's center, for color-blind players.
static func draw_number(ci: CanvasItem, radius: float, level: int) -> void:
	var font := ThemeDB.fallback_font
	var size := int(clampf(radius * 0.75, 14.0, 44.0))
	var text := str(level + 1)
	var w := radius * 2.0
	ci.draw_string(font, Vector2(-radius, size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, w, size,
		Color(0.03, 0.035, 0.07, 0.8))


## Animated extras for special planets. `t` = time in seconds, `motion` =
## current velocity (the comet's tail points away from it).
static func draw_kind_overlay(ci: CanvasItem, kind: int, radius: float, t: float, motion: Vector2 = Vector2.ZERO) -> void:
	var K := PlanetKind.Kind
	match kind:
		K.WILDCARD:
			# Prismatic ring: six palette colors slowly rotating.
			var cols := ["#917AFF", "#52E5D5", "#FF8FC8", "#FFD27A", "#5EE6A8", "#7A9BFF"]
			for i in 6:
				var a0 := t * 0.8 + TAU * i / 6.0
				ci.draw_arc(Vector2.ZERO, radius * 1.3, a0, a0 + TAU / 6.0 * 0.75, 12, Color(cols[i]), 2.5, true)
			var s := 0.5 + 0.5 * sin(t * 3.0)
			ci.draw_circle(Vector2(-radius * 0.35, -radius * 0.4), 2.0 + s * 1.5, Color(1, 1, 1, 0.6 + 0.4 * s), true, -1.0, true)
		K.COMET:
			ci.draw_arc(Vector2.ZERO, radius * 1.25, 0, TAU, 32, Color("#BFE9FF", 0.25), 1.0, true)
			if motion.length() > 30.0:
				var back := -motion.normalized()
				var side := back.orthogonal() * radius * 0.85
				var tip := back * radius * (2.0 + minf(motion.length() / 300.0, 3.0))
				ci.draw_polygon(PackedVector2Array([side, tip, -side]),
					PackedColorArray([Color("#BFE9FF", 0.55), Color("#BFE9FF", 0.0), Color("#BFE9FF", 0.55)]))
		K.BLACK_HOLE:
			# Lensing glow, accretion arcs, then the dark event horizon on top.
			ci.draw_circle(Vector2.ZERO, radius * 1.7, Color("#917AFF", 0.08), true, -1.0, true)
			var arcs := [["#FFB36B", 1.45, 1.0], ["#917AFF", 1.3, -1.4], ["#52E5D5", 1.18, 1.9]]
			for arc in arcs:
				var a0: float = t * arc[2]
				ci.draw_arc(Vector2.ZERO, radius * arc[1], a0, a0 + PI * 1.2, 24, Color(arc[0], 0.75), 2.0, true)
			ci.draw_circle(Vector2.ZERO, radius, Color("#05060B"), true, -1.0, true)
			ci.draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(1, 1, 1, 0.55), 1.5, true)
		K.ANCHOR:
			ci.draw_arc(Vector2.ZERO, radius - 2.0, 0, TAU, 48, Color(1, 1, 1, 0.85), 3.5, true)
			for i in 4:
				ci.draw_circle(Vector2.from_angle(PI / 4 + i * PI / 2) * radius * 0.68, 2.6, Color(1, 1, 1, 0.85), true, -1.0, true)


## True if the overlay of this kind animates (needs a redraw every frame).
static func kind_animates(kind: int) -> bool:
	return kind == PlanetKind.Kind.WILDCARD or kind == PlanetKind.Kind.BLACK_HOLE or kind == PlanetKind.Kind.COMET


static func has_ring(level: int) -> bool:
	return (level >= 3 and level % 3 == 0) or level >= 9
