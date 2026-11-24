class_name Progress
extends RefCounted
## Long-term, pressure-free progress: stats, the planet collection and
## milestones (which also unlock themes). Saved on the device in the same file
## as scores and settings, in separate sections.
##
## Usage during a game: call the on_* methods as things happen; they return
## the names of anything newly discovered or achieved (for a quiet toast).
## Call finish_game() once when a game ends or is left, then save().

const PLANET_NAMES := ["Pebble", "Tidewater", "Rosette", "Halo", "Amber", "Verdant",
	"Lilac Giant", "Cobalt", "Corona", "Orchid Crown", "Goldfire", "Lumen"]
const PLANET_LINES := [
	"Where every orbit begins.",
	"A small world, mostly ocean.",
	"Pink dust swirls over its poles.",
	"Its thin ring catches the light.",
	"Warm deserts under a golden sky.",
	"A jungle world wrapped in mist.",
	"A gas giant with lavender storms.",
	"Deep winds that never stop.",
	"Glows faintly from inside.",
	"A ringed giant, rare and proud.",
	"Almost a star.",
	"The heart of a new star.",
]

## id: [title, description]
const MILESTONES := {
	"first_merge": ["First Contact", "Merge two planets"],
	"gas_giant": ["Gas Giant", "Create a level-6 planet"],
	"ringworld": ["Ringworld", "Create a level-9 planet"],
	"star_birth": ["Star Birth", "Create a level-12 planet"],
	"cascade": ["Cascade", "Make a chain ×4"],
	"supernova": ["Supernova Chain", "Make a chain ×6"],
	"regular": ["Regular Orbit", "Play 10 games"],
	"five_k": ["Five Thousand", "Score 5,000 in one game"],
	"twenty_k": ["Twenty Thousand", "Score 20,000 in one game"],
	"exotic": ["Exotic Matter", "Discover all 4 special planets"],
	"gravity_well": ["Gravity Well", "Use a gravity pulse"],
	"explorer": ["Explorer", "Play every mode"],
}
## Theme unlocked by each milestone. Nebula is always available.
const THEME_UNLOCKS := {"aurora": "ringworld", "solar": "cascade", "mono": "regular"}

var path: String

var games_played: int = 0
var total_merges: int = 0
var total_score: int = 0
var best_chain: int = 0
var biggest_level: int = -1
var play_seconds: float = 0.0
var pulses_used: int = 0
var discovered_levels: Array = []
var discovered_kinds: Array = []
var modes_played: Array = []
var milestones: Array = []


func _init(p_path: String = "user://orbit_save.cfg") -> void:
	path = p_path


func load_progress() -> Progress:
	var f := ConfigFile.new()
	if f.load(path) != OK:
		return self
	games_played = int(f.get_value("stats", "games_played", 0))
	total_merges = int(f.get_value("stats", "total_merges", 0))
	total_score = int(f.get_value("stats", "total_score", 0))
	best_chain = int(f.get_value("stats", "best_chain", 0))
	biggest_level = int(f.get_value("stats", "biggest_level", -1))
	play_seconds = float(f.get_value("stats", "play_seconds", 0.0))
	pulses_used = int(f.get_value("stats", "pulses_used", 0))
	discovered_levels = Array(f.get_value("collection", "levels", []))
	discovered_kinds = Array(f.get_value("collection", "kinds", []))
	modes_played = Array(f.get_value("stats", "modes_played", []))
	milestones = Array(f.get_value("milestones", "unlocked", []))
	return self


func save() -> bool:
	var f := ConfigFile.new()
	f.load(path)  # Keep scores and settings.
	f.set_value("stats", "games_played", games_played)
	f.set_value("stats", "total_merges", total_merges)
	f.set_value("stats", "total_score", total_score)
	f.set_value("stats", "best_chain", best_chain)
	f.set_value("stats", "biggest_level", biggest_level)
	f.set_value("stats", "play_seconds", play_seconds)
	f.set_value("stats", "pulses_used", pulses_used)
	f.set_value("stats", "modes_played", modes_played)
	f.set_value("collection", "levels", discovered_levels)
	f.set_value("collection", "kinds", discovered_kinds)
	f.set_value("milestones", "unlocked", milestones)
	return f.save(path) == OK


# --- Events (each returns a list of {"type", "title", "text"} news) -------------

func on_merge(level: int, chain_depth: int) -> Array:
	total_merges += 1
	best_chain = maxi(best_chain, chain_depth)
	var news := []
	if level > biggest_level:
		biggest_level = level
	if not discovered_levels.has(level):
		discovered_levels.append(level)
		news.append({"type": "planet", "title": "NEW PLANET", "text": PLANET_NAMES[clampi(level, 0, 11)]})
	news.append_array(_check({"level": level, "chain": chain_depth}))
	return news


## A planet level seen for the first time (e.g. launched, not merged).
func on_planet_seen(level: int) -> Array:
	if discovered_levels.has(level):
		return []
	discovered_levels.append(level)
	return [{"type": "planet", "title": "NEW PLANET", "text": PLANET_NAMES[clampi(level, 0, 11)]}]


func on_special_seen(kind: int) -> Array:
	if kind == PlanetKind.Kind.NORMAL or discovered_kinds.has(kind):
		return []
	discovered_kinds.append(kind)
	var news := [{"type": "planet", "title": "NEW DISCOVERY", "text": PlanetKind.NAMES[kind]}]
	news.append_array(_check({}))
	return news


func on_pulse() -> Array:
	pulses_used += 1
	return _check({})


## Call once per finished (or abandoned) game.
func finish_game(mode_id: String, score: int, seconds: float) -> Array:
	games_played += 1
	total_score += score
	play_seconds += seconds
	if not modes_played.has(mode_id):
		modes_played.append(mode_id)
	return _check({"score": score})


# --- Milestones -------------------------------------------------------------------

func has_milestone(id: String) -> bool:
	return milestones.has(id)


func is_theme_unlocked(theme_id: String) -> bool:
	return not THEME_UNLOCKS.has(theme_id) or has_milestone(THEME_UNLOCKS[theme_id])


func theme_unlock_hint(theme_id: String) -> String:
	if not THEME_UNLOCKS.has(theme_id):
		return ""
	return MILESTONES[THEME_UNLOCKS[theme_id]][1]


func _check(ctx: Dictionary) -> Array:
	var news := []
	var conditions := {
		"first_merge": total_merges >= 1,
		"gas_giant": biggest_level >= 5,
		"ringworld": biggest_level >= 8,
		"star_birth": biggest_level >= 11,
		"cascade": best_chain >= 4,
		"supernova": best_chain >= 6,
		"regular": games_played >= 10,
		"five_k": int(ctx.get("score", 0)) >= 5000,
		"twenty_k": int(ctx.get("score", 0)) >= 20000,
		"exotic": discovered_kinds.size() >= 4,
		"gravity_well": pulses_used >= 1,
		"explorer": _played_all_modes(),
	}
	for id in MILESTONES:
		if conditions.get(id, false) and not milestones.has(id):
			milestones.append(id)
			news.append({"type": "milestone", "title": "MILESTONE", "text": MILESTONES[id][0]})
			for theme_id in THEME_UNLOCKS:
				if THEME_UNLOCKS[theme_id] == id:
					news.append({"type": "theme", "title": "THEME UNLOCKED", "text": Themes.DATA[theme_id]["name"]})
	return news


func _played_all_modes() -> bool:
	for id in Session.ORDER:
		if not modes_played.has(id):
			return false
	return true
