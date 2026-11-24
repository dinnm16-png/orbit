class_name HighScoreStore
extends RefCounted
## Saves the best score on the device (offline).
##
## Uses Godot's ConfigFile (a small INI-like text file) under `user://`, which
## maps to the app's private storage on iOS/Android and to an app-data folder
## on desktop. No accounts, no network.

const SECTION := "scores"
const KEY_BEST := "best"

var path: String
## Which score this store reads/writes (one per mode; see GameMode.best_key).
var key: String


func _init(p_path: String = "user://orbit_save.cfg", p_key: String = KEY_BEST) -> void:
	path = p_path
	key = p_key


func load_best() -> int:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return 0  # No save yet (first launch) or unreadable: start from zero.
	return maxi(int(file.get_value(SECTION, key, 0)), 0)


## Records a finished game. Returns true if it is a new best (and saves it).
func submit(score: int) -> bool:
	if score <= load_best():
		return false
	var file := ConfigFile.new()
	file.load(path)  # Keep any other sections a future version may add.
	file.set_value(SECTION, key, score)
	return file.save(path) == OK
