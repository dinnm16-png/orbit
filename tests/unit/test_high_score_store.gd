extends "res://tests/test_case.gd"

const PATH := "user://test_high_score_store.cfg"


func _fresh() -> HighScoreStore:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	return HighScoreStore.new(PATH)


func test_no_save_means_zero() -> void:
	assert_eq(_fresh().load_best(), 0, "first launch")


func test_higher_score_is_saved_and_persists() -> void:
	var store := _fresh()
	assert_true(store.submit(500), "first score is a new best")
	assert_eq(HighScoreStore.new(PATH).load_best(), 500, "persists across instances")


func test_lower_or_equal_score_does_not_overwrite() -> void:
	var store := _fresh()
	store.submit(500)
	assert_false(store.submit(300), "lower is not a new best")
	assert_false(store.submit(500), "equal is not a new best")
	assert_eq(store.load_best(), 500, "best unchanged")


func test_corrupt_file_is_treated_as_no_save() -> void:
	var store := _fresh()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("this is [not valid")
	f.close()
	assert_eq(store.load_best(), 0, "corrupt save does not crash, counts as zero")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
