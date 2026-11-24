class_name StatsPage
extends VBoxContainer
## Personal stats, best scores per mode and milestones.

var progress: Progress
var save_path: String
var difficulty: int = Difficulty.Level.NORMAL


func setup(p_progress: Progress, p_save_path: String, p_difficulty: int) -> void:
	progress = p_progress
	save_path = p_save_path
	difficulty = p_difficulty


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var minutes := int(progress.play_seconds / 60.0)
	var avg := progress.total_score / progress.games_played if progress.games_played > 0 else 0
	var biggest: String = Progress.PLANET_NAMES[progress.biggest_level] if progress.biggest_level >= 0 else "—"
	for item in [
		[str(progress.games_played), "GAMES PLAYED"],
		["%dh %02dm" % [minutes / 60, minutes % 60], "PLAY TIME"],
		[str(progress.total_merges), "TOTAL MERGES"],
		["×%d" % progress.best_chain if progress.best_chain > 1 else "—", "BEST CHAIN"],
		[biggest, "BIGGEST PLANET"],
		[str(avg), "AVERAGE SCORE"],
	]:
		grid.add_child(_stat_card(item[0], item[1]))
	add_child(grid)

	_section("BEST SCORES  ·  %s" % Difficulty.NAMES[difficulty].to_upper())
	for id in Session.ORDER:
		var mode := Session.load_mode(id)
		var key := mode.best_key(DailySeed.today_key())
		if mode.difficulty_applies:
			key += Difficulty.best_key_suffix(difficulty)
		var best := HighScoreStore.new(save_path, key).load_best()
		add_child(_row(mode.title, str(best) if best > 0 else "—", mode.accent))

	_section("MILESTONES  ·  %d / %d" % [progress.milestones.size(), Progress.MILESTONES.size()])
	for id in Progress.MILESTONES:
		add_child(_milestone_row(id))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	add_child(pad)


func _section(title: String) -> void:
	var l := UIStyle.label(title, 16, Color(UIStyle.WHITE, 0.45), 4)
	l.custom_minimum_size = Vector2(0, 48)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(l)


func _stat_card(value: String, title: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := UIStyle.box(Color(UIStyle.SURFACE, 0.8), Color(UIStyle.WHITE, 0.07), 24, 1)
	box.content_margin_left = 22
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", box)
	var v := VBoxContainer.new()
	v.add_child(UIStyle.label(value, 32, UIStyle.WHITE, 1))
	v.add_child(UIStyle.label(title, 13, Color(UIStyle.WHITE, 0.4), 3))
	panel.add_child(v)
	return panel


func _row(title: String, value: String, accent: Color) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 48)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(22, 0)
	dot.draw.connect(func(): dot.draw_circle(Vector2(6, dot.size.y / 2), 5, accent, true, -1.0, true))
	h.add_child(dot)
	var t := UIStyle.label(title, 22, Color(UIStyle.WHITE, 0.85))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
	var v := UIStyle.label(value, 22, UIStyle.WHITE, 1)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(v)
	return h


func _milestone_row(id: String) -> Control:
	var done := progress.has_milestone(id)
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 64)
	h.add_theme_constant_override("separation", 16)
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(36, 0)
	mark.draw.connect(func():
		var c := Vector2(18, mark.size.y / 2)
		if done:
			mark.draw_circle(c, 14, Color(UIStyle.AQUA, 0.9), true, -1.0, true)
			mark.draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-1, 5), c + Vector2(7, -5)]), UIStyle.BG, 2.5, true)
		else:
			mark.draw_arc(c, 13, 0, TAU, 32, Color(UIStyle.WHITE, 0.2), 1.5, true))
	h.add_child(mark)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.add_child(UIStyle.label(Progress.MILESTONES[id][0], 21, UIStyle.WHITE if done else Color(UIStyle.WHITE, 0.55)))
	var desc: String = Progress.MILESTONES[id][1]
	for theme_id in Progress.THEME_UNLOCKS:
		if Progress.THEME_UNLOCKS[theme_id] == id:
			desc += "  ·  unlocks %s theme" % Themes.DATA[theme_id]["name"]
	v.add_child(UIStyle.label(desc, 15, Color(UIStyle.WHITE, 0.4)))
	h.add_child(v)
	return h
