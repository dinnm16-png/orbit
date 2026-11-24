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


static func has_ring(level: int) -> bool:
	return (level >= 3 and level % 3 == 0) or level >= 9
