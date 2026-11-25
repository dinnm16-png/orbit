class_name SettingsPage
extends VBoxContainer
## Player settings, as a page of switches. Used in the main menu.
## (Difficulty, aim assist and themes are added in later milestones.)

signal changed
signal theme_picked(theme_id: String)

var settings: PlayerSettings
var _toggles: Dictionary = {}
## Theme locking (filled in by the progress system; everything open by default).
var is_theme_unlocked: Callable = func(_id): return true
var unlock_hint: Callable = func(_id): return ""


func setup(p_settings: PlayerSettings) -> void:
	settings = p_settings


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_section("DIFFICULTY")
	var seg := SegmentedControl.new()
	seg.setup(PackedStringArray(Difficulty.NAMES), settings.difficulty)
	seg.changed.connect(func(i: int):
		settings.difficulty = i
		settings.save_settings()
		changed.emit())
	add_child(seg)
	add_child(UIStyle.label("Easy: bigger ring, fewer planet sizes.  Hard: smaller ring, more sizes.", 15,
		Color(UIStyle.WHITE, 0.35)))
	_section("THEME")
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 8)
	for id in Themes.ORDER:
		var sw := ThemeSwatch.new()
		var locked: bool = not is_theme_unlocked.call(id)
		sw.setup(id, id == settings.theme, locked, unlock_hint.call(id) if locked else "")
		sw.chosen.connect(func(theme_id: String):
			settings.theme = theme_id
			settings.save_settings()
			theme_picked.emit(theme_id))
		swatches.add_child(sw)
	add_child(swatches)
	_section("GAME FEEL")
	_toggle("sound", "Sound")
	_toggle("haptics", "Vibration")
	_section("CONTROLS")
	_toggle("movable_launcher", "Slide launcher sideways")
	_toggle("aim_assist", "Aim assist (show flight path)")
	_section("ACCESSIBILITY")
	_toggle("planet_numbers", "Planet numbers")
	_section("HELP")
	var replay := UIStyle.button("REPLAY TUTORIAL", false, UIStyle.VIOLET, 64)
	replay.pressed.connect(func():
		settings.tutorial_replay = true
		settings.save_settings()
		replay.text = "TUTORIAL ON FOR YOUR NEXT GAME"
		replay.disabled = true)
	add_child(replay)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	add_child(spacer)
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	add_child(UIStyle.label("ORBIT  %s  ·  offline  ·  no ads  ·  no tracking" % version, 16,
		Color(UIStyle.WHITE, 0.3), 1, HORIZONTAL_ALIGNMENT_CENTER))


func _section(title: String) -> void:
	var l := UIStyle.label(title, 16, Color(UIStyle.WHITE, 0.4), 4)
	l.custom_minimum_size = Vector2(0, 44)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(l)


func _toggle(key: String, text: String) -> void:
	var t := SwitchToggle.new()
	t.text = text
	t.custom_minimum_size = Vector2(0, 64)
	t.add_theme_font_size_override("font_size", 24)
	add_child(t)
	t.set_pressed_no_signal(settings.get(key))
	t.toggled.connect(func(on: bool):
		settings.set(key, on)
		settings.save_settings()
		changed.emit())
	_toggles[key] = t
