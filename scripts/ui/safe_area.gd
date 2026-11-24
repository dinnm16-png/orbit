class_name SafeArea
extends RefCounted
## Converts the phone's "safe area" (the part of the screen not covered by a
## notch, camera hole, rounded corners or the home indicator) into margins in
## our game's coordinate space (the 720-wide stretched canvas).
##
## Pure function so it can be tested with made-up phone shapes.


## safe:         safe rectangle in WINDOW pixels (from DisplayServer)
## window_size:  real window size in pixels
## visible_size: size of our stretched canvas (e.g. 720 × 1560)
## Returns { "top", "bottom", "left", "right" } in canvas units (never negative).
static func insets(safe: Rect2i, window_size: Vector2i, visible_size: Vector2) -> Dictionary:
	if window_size.x <= 0 or window_size.y <= 0:
		return {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	var sx := visible_size.x / window_size.x
	var sy := visible_size.y / window_size.y
	return {
		"top": maxf(safe.position.y * sy, 0.0),
		"bottom": maxf((window_size.y - safe.end.y) * sy, 0.0),
		"left": maxf(safe.position.x * sx, 0.0),
		"right": maxf((window_size.x - safe.end.x) * sx, 0.0),
	}


## Insets for the current device. Desktop always returns zeros: there the
## "display safe area" describes the monitor (minus taskbar), not our window.
static func current(visible_size: Vector2) -> Dictionary:
	if not OS.has_feature("mobile"):
		return insets(Rect2i(Vector2i.ZERO, Vector2i.ONE), Vector2i.ONE, visible_size)
	return insets(DisplayServer.get_display_safe_area(), DisplayServer.window_get_size(), visible_size)
