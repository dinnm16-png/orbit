class_name SettingsPage
extends VBoxContainer
## Player settings, as a page of switches. Used in the main menu.
## (Difficulty, aim assist and themes are added in later milestones.)

signal changed

var settings: PlayerSettings
var _toggles: Dictionary = {}


func setup(p_settings: PlayerSettings) -> void:
	settings = p_settings


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_section("GAME FEEL")
	_toggle("sound", "Sound")
	_toggle("haptics", "Vibration")
	_section("ACCESSIBILITY")
	_toggle("planet_numbers", "Planet numbers")
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
