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


func _init(p_path: String = "user://orbit_save.cfg") -> void:
	path = p_path


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return  # First launch or unreadable file: keep defaults.
	sound = bool(file.get_value(SECTION, "sound", sound))
	haptics = bool(file.get_value(SECTION, "haptics", haptics))
	planet_numbers = bool(file.get_value(SECTION, "planet_numbers", planet_numbers))


func save_settings() -> bool:
	var file := ConfigFile.new()
	file.load(path)  # Keep the best score and any other sections.
	file.set_value(SECTION, "sound", sound)
	file.set_value(SECTION, "haptics", haptics)
	file.set_value(SECTION, "planet_numbers", planet_numbers)
	return file.save(path) == OK
