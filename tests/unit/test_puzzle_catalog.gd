extends "res://tests/test_case.gd"

const K := PlanetKind.Kind


func test_thirty_levels_in_six_chapters() -> void:
	assert_eq(PuzzleCatalog.count(), 30, "30 puzzles")
	assert_eq(PuzzleCatalog.chapter_of(1), "First Orbits", "chapter 1")
	assert_eq(PuzzleCatalog.chapter_of(13), "Wildcards", "chapter 3")
	assert_eq(PuzzleCatalog.chapter_of(30), "Binary", "chapter 6")


func test_parse_tokens() -> void:
	var p := PuzzleCatalog.parse("3 A5 W C B a")
	assert_eq(p[0], {"level": 3, "kind": K.NORMAL}, "digit")
	assert_eq(p[1], {"level": 5, "kind": K.ANCHOR}, "anchor")
	assert_eq(p[2]["kind"], K.WILDCARD, "wildcard")
	assert_eq(p[3]["kind"], K.COMET, "comet")
	assert_eq(p[4]["kind"], K.BLACK_HOLE, "black hole")
	assert_eq(p[5]["level"], 10, "a = level 10")


func test_every_level_is_well_formed() -> void:
	for n in range(1, PuzzleCatalog.count() + 1):
		var lv := PuzzleCatalog.get_level(n)
		var setup_levels := []
		for item in lv["setup"]:
			assert_false(setup_levels.has(item["level"]), "puzzle %d: duplicate setup level would merge instantly" % n)
			setup_levels.append(item["level"])
		assert_true(lv["goal"] >= 1 and lv["goal"] <= 11, "puzzle %d: goal in range" % n)
		assert_true(lv["sequence"].size() >= 6, "puzzle %d: enough planets" % n)
		assert_true(lv["cores"] == 1 or lv["cores"] == 2, "puzzle %d: cores" % n)
		if n >= 13:
			# From chapter 3 on, no single shot may win: a planet (or wildcard)
			# that merges with a starting planet one level below the goal.
			var near_goal: bool = setup_levels.has(lv["goal"] - 1)
			for item in lv["sequence"]:
				var instant: bool = near_goal and (item["kind"] == K.WILDCARD or item["level"] == lv["goal"] - 1)
				assert_false(instant, "puzzle %d: can be won with a single shot" % n)


func test_stars_from_planets_left() -> void:
	assert_eq(PuzzleCatalog.stars(4, 10), 3, "40% left")
	assert_eq(PuzzleCatalog.stars(2, 10), 2, "20% left")
	assert_eq(PuzzleCatalog.stars(0, 10), 1, "solved with the last planet")
	assert_eq(PuzzleCatalog.goal_text(5), "Create a Verdant (level 6)", "goal text")


func test_puzzle_progress_and_unlocking() -> void:
	var path := "user://test_puzzle_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p := Progress.new(path)
	assert_true(p.is_puzzle_unlocked(1), "first always open")
	assert_false(p.is_puzzle_unlocked(2), "second locked")
	p.record_puzzle(1, 2)
	assert_true(p.is_puzzle_unlocked(2), "solving opens the next")
	p.record_puzzle(1, 1)
	assert_eq(p.stars_for(1), 2, "best stars kept")
	p.record_puzzle(1, 3)
	assert_eq(p.total_stars(), 3, "total")
	p.save()
	assert_eq(Progress.new(path).load_progress().stars_for(1), 3, "persisted")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
