class_name PuzzlePage
extends Control
## Puzzle level select: chapters of numbered tiles with stars and locks.

signal play_requested(number: int)
signal closed

var progress: Progress


func setup(p_progress: Progress) -> void:
	progress = p_progress


func _ready() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	var head := HBoxContainer.new()
	var back := Button.new()
	back.text = "‹  MODES"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", UIStyle.spaced_font(3))
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.6))
	back.pressed.connect(func(): closed.emit())
	head.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(UIStyle.label("★ %d / %d" % [progress.total_stars(), PuzzleCatalog.count() * 3], 20, Color("#FFD27A"), 2))
	v.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIStyle.style_scroll(scroll)
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for c in PuzzleCatalog.CHAPTERS.size():
		var first: int = PuzzleCatalog.CHAPTERS[c][1]
		var last: int = PuzzleCatalog.CHAPTERS[c + 1][1] - 1 if c + 1 < PuzzleCatalog.CHAPTERS.size() else PuzzleCatalog.count()
		var title := UIStyle.label("%d  ·  %s" % [c + 1, PuzzleCatalog.CHAPTERS[c][0].to_upper()], 16, Color(UIStyle.WHITE, 0.45), 4)
		title.custom_minimum_size = Vector2(0, 44)
		title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		list.add_child(title)
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for n in range(first, last + 1):
			grid.add_child(_tile(n))
		list.add_child(grid)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 24)
	list.add_child(pad)


func _tile(n: int) -> Button:
	var unlocked := progress.is_puzzle_unlocked(n)
	var stars := progress.stars_for(n)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(98, 104)
	b.disabled = not unlocked
	var border := Color("#FFD27A", 0.55) if stars == 3 else Color(UIStyle.WHITE, 0.12 if unlocked else 0.05)
	b.add_theme_stylebox_override("normal", UIStyle.box(Color(UIStyle.SURFACE, 0.85 if unlocked else 0.4), border, 22, 1))
	b.add_theme_stylebox_override("hover", UIStyle.box(Color(UIStyle.SECONDARY, 0.95), Color(UIStyle.VIOLET, 0.6), 22, 1))
	b.add_theme_stylebox_override("pressed", UIStyle.box(Color(UIStyle.VIOLET, 0.25), UIStyle.VIOLET, 22, 1))
	b.add_theme_stylebox_override("disabled", UIStyle.box(Color(UIStyle.SURFACE, 0.4), border, 22, 1))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): play_requested.emit(n))
	b.draw.connect(func():
		var font := UIStyle.spaced_font(1)
		if unlocked:
			b.draw_string(font, Vector2(0, 52), str(n), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 30, UIStyle.WHITE)
			for i in 3:
				var c := Vector2(b.size.x / 2 + (i - 1) * 22, 80)
				var pts := PackedVector2Array()
				for k in 10:
					pts.append(c + Vector2.from_angle(-PI / 2 + TAU * k / 10.0) * (8.0 if k % 2 == 0 else 3.6))
				if i < stars:
					b.draw_colored_polygon(pts, Color("#FFD27A"))
				else:
					pts.append(pts[0])
					b.draw_polyline(pts, Color(UIStyle.WHITE, 0.2), 1.2, true)
		else:
			# Padlock.
			var c := Vector2(b.size.x / 2, 56)
			b.draw_arc(c + Vector2(0, -8), 9, PI, TAU, 16, Color(UIStyle.WHITE, 0.25), 2.5, true)
			b.draw_rect(Rect2(c + Vector2(-13, -8), Vector2(26, 20)), Color(UIStyle.WHITE, 0.2)))
	return b
