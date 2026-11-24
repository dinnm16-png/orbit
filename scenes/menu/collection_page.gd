class_name CollectionPage
extends VBoxContainer
## The planet collection: 12 planets + 4 special planets. Undiscovered ones
## are silhouettes, so there is always something to look forward to.

var progress: Progress
var colors: PackedColorArray


func setup(p_progress: Progress, p_colors: PackedColorArray) -> void:
	progress = p_progress
	colors = p_colors


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var found := progress.discovered_levels.size() + progress.discovered_kinds.size()
	add_child(UIStyle.label("%d / 16 DISCOVERED" % found, 16, Color(UIStyle.WHITE, 0.45), 4))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for level in 12:
		var known := progress.discovered_levels.has(level)
		grid.add_child(_cell(known, level, PlanetKind.Kind.NORMAL,
			Progress.PLANET_NAMES[level], Progress.PLANET_LINES[level], "LEVEL %d" % (level + 1)))
	add_child(grid)
	add_child(UIStyle.label("SPECIAL PLANETS", 16, Color(UIStyle.WHITE, 0.45), 4))
	var specials := GridContainer.new()
	specials.columns = 2
	specials.add_theme_constant_override("h_separation", 10)
	specials.add_theme_constant_override("v_separation", 10)
	for kind in [PlanetKind.Kind.WILDCARD, PlanetKind.Kind.COMET, PlanetKind.Kind.BLACK_HOLE, PlanetKind.Kind.ANCHOR]:
		var known := progress.discovered_kinds.has(kind)
		specials.add_child(_cell(known, 3, kind, PlanetKind.NAMES[kind], PlanetKind.HINTS[kind], "SPECIAL"))
	add_child(specials)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	add_child(pad)


func _cell(known: bool, level: int, kind: int, title: String, line: String, tag: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UIStyle.box(Color(UIStyle.SURFACE, 0.8), Color(UIStyle.WHITE, 0.07), 24, 1)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 12
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)

	var art := Control.new()
	art.custom_minimum_size = Vector2(0, 92)
	v.add_child(art)
	var r := 18.0 + level * 2.2 if kind == PlanetKind.Kind.NORMAL else 22.0
	var holder := Node2D.new()
	art.add_child(holder)
	art.resized.connect(func(): holder.position = art.size * 0.5)
	if known:
		var color: Color = PlanetKind.COLORS.get(kind, colors[level])
		if kind != PlanetKind.Kind.BLACK_HOLE:
			var body := Node2D.new()
			body.material = PlanetArt.material()
			body.draw.connect(func(): PlanetArt.draw_body(body, r, color))
			holder.add_child(body)
		var over := Node2D.new()
		over.draw.connect(func():
			if kind != PlanetKind.Kind.NORMAL:
				PlanetArt.draw_kind_overlay(over, kind, r, 0.6)
			if kind == PlanetKind.Kind.NORMAL or kind == PlanetKind.Kind.ANCHOR:
				PlanetArt.draw_ring(over, r, color, level))
		holder.add_child(over)
	else:
		holder.draw.connect(func():
			holder.draw_circle(Vector2.ZERO, r, Color(UIStyle.WHITE, 0.05), true, -1.0, true)
			holder.draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(UIStyle.WHITE, 0.12), 1.0, true)
			holder.draw_string(ThemeDB.fallback_font, Vector2(-r, 8), "?", HORIZONTAL_ALIGNMENT_CENTER, r * 2, 22, Color(UIStyle.WHITE, 0.25)))

	v.add_child(UIStyle.label(tag, 12, Color(UIStyle.WHITE, 0.35), 3, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIStyle.label(title if known else "Undiscovered", 19, UIStyle.WHITE if known else Color(UIStyle.WHITE, 0.4), 1, HORIZONTAL_ALIGNMENT_CENTER))
	var desc := UIStyle.label(line if known else "Keep merging…", 14, Color(UIStyle.WHITE, 0.5 if known else 0.25), 0, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(150, 0)
	v.add_child(desc)
	return panel
