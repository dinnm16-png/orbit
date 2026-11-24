class_name PlayerSettings
extends RefCounted
## Player preferences, saved on the device next to the best score
## (same file, separate "settings" section).

const SECTION := "settings"

var path: String
var sound: bool = true
var haptics: bool = true
## Accessibility: draw each planet's level number (helps color-blind players).
var planet_numbers: bool = false
## Slide the launcher sideways by dragging it horizontally.
var movable_launcher: bool = true
## Difficulty.Level (0 easy, 1 normal, 2 hard).
var difficulty: int = Difficulty.Level.NORMAL
## Show the predicted flight path while aiming.
var aim_assist: bool = false
## Themes id.
var theme: String = "nebula"


func _init(p_path: String = "user://orbit_save.cfg") -> void:
	path = p_path


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return  # First launch or unreadable file: keep defaults.
	sound = bool(file.get_value(SECTION, "sound", sound))
	haptics = bool(file.get_value(SECTION, "haptics", haptics))
	planet_numbers = bool(file.get_value(SECTION, "planet_numbers", planet_numbers))
	movable_launcher = bool(file.get_value(SECTION, "movable_launcher", movable_launcher))
	difficulty = clampi(int(file.get_value(SECTION, "difficulty", difficulty)), 0, 2)
	aim_assist = bool(file.get_value(SECTION, "aim_assist", aim_assist))
	theme = str(file.get_value(SECTION, "theme", theme))
	if not Themes.exists(theme):
		theme = "nebula"


func save_settings() -> bool:
	var file := ConfigFile.new()
	file.load(path)  # Keep the best score and any other sections.
	file.set_value(SECTION, "sound", sound)
	file.set_value(SECTION, "haptics", haptics)
	file.set_value(SECTION, "planet_numbers", planet_numbers)
	file.set_value(SECTION, "movable_launcher", movable_launcher)
	file.set_value(SECTION, "difficulty", difficulty)
	file.set_value(SECTION, "aim_assist", aim_assist)
	file.set_value(SECTION, "theme", theme)
	return file.save(path) == OK
