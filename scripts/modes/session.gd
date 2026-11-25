class_name Session
extends RefCounted
## Which mode / puzzle level the player picked in the menu.
## Static variables survive scene changes, so the menu sets them and the game
## scene reads them, without needing a global autoload.

const MODE_DIR := "res://resources/modes/"
## Display order in the menu.
const ORDER := ["classic", "puzzle", "zen", "daily", "blitz", "collapse", "limited", "binary"]

static var mode_id: String = "classic"
static var puzzle_index: int = 0
## Active friend challenge ({} = none): {"mode", "seed", "difficulty", "score"}.
## Survives restarts, so "Play again" is a rematch of the same challenge.
static var challenge: Dictionary = {}
## Menu tab to show when the menu (re)opens.
static var menu_tab: String = "play"


static func load_mode(id: String) -> GameMode:
	var path := MODE_DIR + id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("Unknown mode '%s', using classic" % id)
		path = MODE_DIR + "classic.tres"
	return load(path)


static func current_mode() -> GameMode:
	return load_mode(mode_id)
