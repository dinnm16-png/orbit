extends "res://tests/test_case.gd"

const PATH := "user://test_player_settings.cfg"


func _clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_defaults_on_first_launch() -> void:
	_clear()
	var s := PlayerSettings.new(PATH)
	s.load_settings()
	assert_true(s.sound and s.haptics, "sound and haptics on by default")
	assert_false(s.planet_numbers, "numbers off by default")


func test_settings_persist() -> void:
	_clear()
	var s := PlayerSettings.new(PATH)
	s.sound = false
	s.planet_numbers = true
	assert_true(s.save_settings(), "saved")
	var t := PlayerSettings.new(PATH)
	t.load_settings()
	assert_false(t.sound, "sound off persisted")
	assert_true(t.planet_numbers, "numbers on persisted")
	_clear()


func test_settings_and_best_score_share_file_without_clobbering() -> void:
	_clear()
	HighScoreStore.new(PATH).submit(777)
	var s := PlayerSettings.new(PATH)
	s.haptics = false
	s.save_settings()
	assert_eq(HighScoreStore.new(PATH).load_best(), 777, "best score kept after saving settings")
	HighScoreStore.new(PATH).submit(900)
	var t := PlayerSettings.new(PATH)
	t.load_settings()
	assert_false(t.haptics, "settings kept after saving best score")
	_clear()
