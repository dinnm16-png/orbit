extends SceneTree
## Renders ORBIT's app icons and splash image with the game's own planet
## shader, so the icon always matches what players see in-game.
##
## Usage (needs a display / GPU, e.g. the normal editor machine):
##   godot --path . -s res://tools/render_icons.gd
## Output: res://resources/icons/*.png  (commit them; builds use the PNGs)

const OUT := "res://resources/icons/"
const BG_CENTER := Color("#1B1F3A")
const BG_EDGE := Color("#080910")
const VIOLET := Color("#917AFF")
const AQUA := Color("#52E5D5")
const WHITE := Color("#F5F5FA")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# Full icon (iOS 1024, Android legacy 192, project icon 256).
	await _render(1024, true, true, false, "icon_1024.png")
	await _render(192, true, true, false, "icon_192.png")
	await _render(256, true, true, false, "icon_256.png")
	# Android adaptive icon layers (432 px; the launcher masks them to a
	# circle/squircle and only the central ~66% is guaranteed visible).
	await _render(432, false, true, false, "adaptive_foreground.png", 0.62)
	await _render(432, true, false, false, "adaptive_background.png")
	await _render(432, false, true, true, "adaptive_monochrome.png", 0.62)
	# Splash: emblem + wordmark on transparent background.
	await _render_splash(720, "splash.png")
	print("ICONS DONE")
	quit()


## scale: emblem size relative to the canvas (adaptive icons need margins).
func _render(px: int, background: bool, emblem: bool, mono: bool, file: String, scale: float = 0.8) -> void:
	var vp := _make_viewport(px, not background)
	if background:
		var bg := TextureRect.new()
		bg.texture = _radial_gradient(px)
		bg.size = Vector2(px, px)
		vp.add_child(bg)
	if emblem:
		_add_emblem(vp, Vector2(px, px) * 0.5, px * 0.5 * scale, mono)
	await _save(vp, file)


func _render_splash(px: int, file: String) -> void:
	var vp := _make_viewport(px, true)
	_add_emblem(vp, Vector2(px * 0.5, px * 0.42), px * 0.26, false)
	var word := Node2D.new()
	word.draw.connect(func():
		# Letter-spaced wordmark, drawn letter by letter.
		var font := ThemeDB.fallback_font
		var size := int(px * 0.075)
		var letters := "ORBIT"
		var spacing := size * 0.55
		var widths := []
		var total := 0.0
		for ch in letters:
			var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			widths.append(w)
			total += w
		total += spacing * (letters.length() - 1)
		var x := px * 0.5 - total * 0.5
		for i in letters.length():
			word.draw_string(font, Vector2(x, px * 0.86), letters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(WHITE, 0.92))
			x += widths[i] + spacing)
	vp.add_child(word)
	await _save(vp, file)


## Planet + tilted ring (back half behind, front half in front) + small moon.
func _add_emblem(vp: SubViewport, center: Vector2, extent: float, mono: bool) -> void:
	var r := extent * 0.5          # planet radius
	var ring_rx := r * 1.62
	var ring_ry := r * 0.42
	var tilt := -0.38
	var ring_color := WHITE if mono else AQUA
	var ring_w := maxf(2.0, r * 0.055)

	var back := Node2D.new()
	back.position = center
	back.draw.connect(func(): _draw_ring_half(back, ring_rx, ring_ry, tilt, PI, TAU, ring_color, ring_w, r if mono else 0.0))
	vp.add_child(back)

	var planet := Node2D.new()
	planet.position = center
	if mono:
		# Themed (monochrome) icons use only shape: an outlined planet keeps the
		# ring readable where it crosses in front.
		planet.draw.connect(func(): planet.draw_arc(Vector2.ZERO, r - ring_w, 0.0, TAU, 96, WHITE, ring_w * 1.6, true))
	else:
		planet.material = PlanetArt.material()
		planet.draw.connect(func(): PlanetArt.draw_body(planet, r, VIOLET))
	vp.add_child(planet)

	var front := Node2D.new()
	front.position = center
	front.draw.connect(func(): _draw_ring_half(front, ring_rx, ring_ry, tilt, 0.0, PI, ring_color, ring_w))
	vp.add_child(front)

	var moon := Node2D.new()
	moon.position = center + Vector2(r * 1.25, -r * 1.05)
	if mono:
		moon.draw.connect(func(): moon.draw_circle(Vector2.ZERO, r * 0.2, WHITE, true, -1.0, true))
	else:
		moon.material = PlanetArt.material()
		moon.draw.connect(func(): PlanetArt.draw_body(moon, r * 0.2, AQUA))
	vp.add_child(moon)


## hide_inside: skip the parts closer to the center than this (used for the
## outlined monochrome planet, where the back ring must not show through).
func _draw_ring_half(ci: CanvasItem, rx: float, ry: float, tilt: float, a0: float, a1: float, color: Color, width: float, hide_inside: float = 0.0) -> void:
	# Brightness follows depth smoothly: the far side (sin < 0) is dimmer, and
	# there is no hard step where the back and front halves meet.
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var segments := 64
	for i in segments + 1:
		var a := lerpf(a0, a1, float(i) / segments)
		points.append(Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
		colors.append(Color(color, lerpf(0.45, 1.0, smoothstep(-0.6, 0.6, sin(a)))))
	if hide_inside <= 0.0:
		ci.draw_polyline_colors(points, colors, width, true)
		return
	# Draw only the runs of the ring that lie outside the planet.
	var run_p := PackedVector2Array()
	var run_c := PackedColorArray()
	for i in points.size():
		if points[i].length() > hide_inside + width:
			run_p.append(points[i])
			run_c.append(colors[i])
		elif run_p.size() > 0:
			if run_p.size() > 1:
				ci.draw_polyline_colors(run_p, run_c, width, true)
			run_p = PackedVector2Array()
			run_c = PackedColorArray()
	if run_p.size() > 1:
		ci.draw_polyline_colors(run_p, run_c, width, true)


func _radial_gradient(px: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, BG_CENTER)
	g.set_color(1, BG_EDGE)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.42)
	t.fill_to = Vector2(1.05, 1.05)
	t.width = px
	t.height = px
	return t


func _make_viewport(px: int, transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = transparent
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


func _save(vp: SubViewport, file: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(OUT + file)
	print("saved ", file, " ", img.get_size())
	vp.queue_free()
	await process_frame
