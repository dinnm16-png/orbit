extends "res://tests/test_case.gd"

const BASE := preload("res://resources/config/default_config.tres")


func _diff(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_difficulty_changes_rules_without_touching_base() -> void:
	var r := BASE.boundary_radius
	var easy := Difficulty.apply(BASE, Difficulty.Level.EASY)
	var hard := Difficulty.apply(BASE, Difficulty.Level.HARD)
	var normal := Difficulty.apply(BASE, Difficulty.Level.NORMAL)
	assert_almost(BASE.boundary_radius, r, 0.001, "base untouched")
	assert_true(easy.boundary_radius > normal.boundary_radius and normal.boundary_radius > hard.boundary_radius, "ring size ordered")
	assert_true(easy.spawn_max_level < hard.spawn_max_level, "fewer sizes on easy")
	assert_true(easy.game_over_grace_time > hard.game_over_grace_time, "more grace on easy")
	for c in [easy, normal, hard]:
		assert_true(c.validate().is_empty(), "valid config")


func test_difficulty_has_separate_best_keys() -> void:
	assert_eq(Difficulty.best_key_suffix(Difficulty.Level.NORMAL), "", "normal keeps old keys")
	assert_eq(Difficulty.best_key_suffix(Difficulty.Level.EASY), "_easy", "easy")
	assert_eq(Difficulty.best_key_suffix(Difficulty.Level.HARD), "_hard", "hard")


func test_every_theme_keeps_planets_distinguishable() -> void:
	for id in Themes.ORDER:
		var cols := Themes.planet_colors(id)
		assert_eq(cols.size(), 12, "%s has 12 planet colors" % id)
		for i in range(1, cols.size()):
			assert_true(_diff(cols[i - 1], cols[i]) > 0.25, "%s: levels %d/%d too similar (%.2f)" % [id, i - 1, i, _diff(cols[i - 1], cols[i])])
		for i in range(9, 12):
			for j in range(i + 1, 12):
				assert_true(_diff(cols[i], cols[j]) > 0.25, "%s: top levels %d/%d too similar" % [id, i, j])


func test_theme_apply_sets_ui_colors() -> void:
	Themes.apply("solar")
	assert_eq(UIStyle.VIOLET, Color(Themes.DATA["solar"]["primary"]), "primary from theme")
	assert_eq(UIStyle.BG, Color(Themes.DATA["solar"]["bg"]), "background from theme")
	Themes.apply("does-not-exist")
	assert_eq(Themes.current_id, "nebula", "unknown theme falls back")
	Themes.apply("nebula")


func test_new_settings_persist() -> void:
	var path := "user://test_options.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var s := PlayerSettings.new(path)
	s.difficulty = Difficulty.Level.HARD
	s.aim_assist = true
	s.theme = "aurora"
	s.save_settings()
	var t := PlayerSettings.new(path)
	t.load_settings()
	assert_eq(t.difficulty, Difficulty.Level.HARD, "difficulty")
	assert_true(t.aim_assist, "aim assist")
	assert_eq(t.theme, "aurora", "theme")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_predicted_path_curves_toward_the_core() -> void:
	var path := OrbitPhysics.predict_path(Vector2(0, 400), Vector2(300, -600), [Vector2.ZERO], 1000.0,
		0.8, 1300.0, 1.0 / 60.0, 120, 60.0)
	assert_true(path.size() > 10, "path has points")
	assert_true(path[path.size() - 1].length() <= 400.0, "path ends closer to the core")
