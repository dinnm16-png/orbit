extends "res://tests/test_case.gd"


func test_notched_phone_insets() -> void:
	# A tall phone: 1179×2556 px window, notch area 162 px at the top,
	# home indicator 102 px at the bottom. Our canvas is 720 wide.
	var window := Vector2i(1179, 2556)
	var visible := Vector2(720.0, 720.0 * 2556.0 / 1179.0)
	var safe := Rect2i(Vector2i(0, 162), Vector2i(1179, 2556 - 162 - 102))
	var i := SafeArea.insets(safe, window, visible)
	var scale := 720.0 / 1179.0
	assert_almost(i["top"], 162.0 * scale, 0.01, "top inset scaled to canvas units")
	assert_almost(i["bottom"], 102.0 * scale, 0.01, "bottom inset scaled to canvas units")
	assert_almost(i["left"], 0.0, 0.001, "no left inset")


func test_full_screen_safe_area_gives_zero_insets() -> void:
	var i := SafeArea.insets(Rect2i(0, 0, 1080, 1920), Vector2i(1080, 1920), Vector2(720, 1280))
	for k in ["top", "bottom", "left", "right"]:
		assert_almost(i[k], 0.0, 0.001, k)


func test_bad_input_never_negative_or_crashes() -> void:
	var i := SafeArea.insets(Rect2i(0, -50, 2000, 3000), Vector2i(1080, 1920), Vector2(720, 1280))
	for k in ["top", "bottom", "left", "right"]:
		assert_true(i[k] >= 0.0, "%s not negative" % k)
	i = SafeArea.insets(Rect2i(), Vector2i.ZERO, Vector2(720, 1280))
	assert_almost(i["top"], 0.0, 0.001, "zero window handled")


func test_desktop_has_no_insets() -> void:
	var i := SafeArea.current(Vector2(720, 1280))
	assert_almost(i["top"], 0.0, 0.001, "desktop/headless: no insets")
