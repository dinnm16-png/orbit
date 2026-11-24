extends "res://tests/test_case.gd"

const PATH := "user://test_progress.cfg"


func _fresh() -> Progress:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return Progress.new(PATH)


func _types(news: Array) -> Array:
	var out := []
	for n in news:
		out.append(n["text"])
	return out


func test_first_merge_discovers_planet_and_milestone() -> void:
	var p := _fresh()
	var news := p.on_merge(1, 1)
	assert_true(_types(news).has("Tidewater"), "level 1 planet discovered")
	assert_true(_types(news).has("First Contact"), "first merge milestone")
	assert_eq(p.on_merge(1, 1).size(), 0, "nothing new the second time")


func test_milestones_unlock_themes() -> void:
	var p := _fresh()
	assert_false(p.is_theme_unlocked("solar"), "solar locked at start")
	assert_true(p.is_theme_unlocked("nebula"), "nebula always open")
	var news := p.on_merge(3, 4)
	assert_true(p.has_milestone("cascade"), "chain x4 milestone")
	assert_true(_types(news).has("Solar"), "theme unlock announced")
	assert_true(p.is_theme_unlocked("solar"), "solar unlocked")
	p.on_merge(8, 1)
	assert_true(p.is_theme_unlocked("aurora"), "level 9 unlocks aurora")


func test_game_count_and_explorer() -> void:
	var p := _fresh()
	for i in 9:
		p.finish_game("classic", 100, 30.0)
	assert_false(p.has_milestone("regular"), "9 games not enough")
	p.finish_game("classic", 100, 30.0)
	assert_true(p.has_milestone("regular"), "10 games")
	assert_true(p.is_theme_unlocked("mono"), "mono unlocked")
	assert_false(p.has_milestone("explorer"), "not every mode yet")
	for id in Session.ORDER:
		p.finish_game(id, 10, 1.0)
	assert_true(p.has_milestone("explorer"), "every mode played")
	assert_almost(p.play_seconds, 10 * 30.0 + Session.ORDER.size(), 0.01, "play time summed")


func test_score_milestones_are_per_game() -> void:
	var p := _fresh()
	p.finish_game("classic", 4999, 1.0)
	p.finish_game("classic", 4999, 1.0)
	assert_false(p.has_milestone("five_k"), "totals don't count")
	p.finish_game("classic", 5000, 1.0)
	assert_true(p.has_milestone("five_k"), "one game of 5,000")


func test_specials_collection() -> void:
	var p := _fresh()
	var K := PlanetKind.Kind
	p.on_special_seen(K.WILDCARD)
	p.on_special_seen(K.COMET)
	p.on_special_seen(K.BLACK_HOLE)
	assert_eq(p.on_special_seen(K.WILDCARD).size(), 0, "already discovered")
	assert_eq(p.on_special_seen(K.NORMAL).size(), 0, "normal is not a discovery")
	var news := p.on_special_seen(K.ANCHOR)
	assert_true(_types(news).has("Exotic Matter"), "all four specials")


func test_progress_persists_and_keeps_other_sections() -> void:
	var p := _fresh()
	HighScoreStore.new(PATH).submit(1234)
	p.on_merge(5, 2)
	p.finish_game("zen", 500, 42.0)
	p.save()
	var q := Progress.new(PATH).load_progress()
	assert_eq(q.games_played, 1, "games")
	assert_eq(q.biggest_level, 5, "biggest")
	assert_eq(q.best_chain, 2, "chain")
	assert_true(q.discovered_levels.has(5), "collection")
	assert_true(q.modes_played.has("zen"), "modes")
	assert_eq(HighScoreStore.new(PATH).load_best(), 1234, "best score untouched")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
