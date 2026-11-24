class_name PuzzleCatalog
extends RefCounted
## The 30 puzzle levels, as compact data.
##
## Each level: [goal, cores, setup, sequence]
##   goal     — level index the player must CREATE by merging (0-based; shown
##              to the player as a planet name and "level goal+1")
##   cores    — 1 or 2 gravitational cores
##   setup    — planets already in orbit: level digits, "A5" = anchor level 5
##   sequence — the planets you will launch, in order: digits = levels,
##              W = wildcard, C = comet, B = black hole
## Digits 0-9 = levels 0-9, "a" = level 10.

const CHAPTERS := [
	["First Orbits", 1], ["Chain Reactions", 7], ["Wildcards", 13],
	["Comets & Anchors", 19], ["Event Horizon", 25], ["Binary", 28],
]

const LEVELS := [
	# 1 First Orbits
	[2, 1, "1", "0 0 1 0 0 1"],
	[3, 1, "2 1", "1 0 0 1 2 0 0"],
	[3, 1, "2 0 1", "0 1 0 2 1 0 1"],
	[4, 1, "3 2 1", "1 0 0 2 1 3 0 1 2"],
	[4, 1, "3 1 2 0", "0 1 2 0 3 1 0 2 1"],
	[5, 1, "4 3 2 1", "1 0 0 0 1 3 1 2 2 2 3 0 1 2"],
	# 7 Chain Reactions
	[5, 1, "4 3 2", "2 1 1 0 0 3 2 1 0 4"],
	[5, 1, "4 2 3 1", "1 0 0 2 1 3 0 2 4 1"],
	[6, 1, "5 4 3 2", "2 1 1 0 0 3 2 4 1 0 3 5"],
	[6, 1, "5 3 4 2 1", "1 0 0 2 1 3 2 4 0 1 3 2 5"],
	[6, 1, "5 4 2 3", "3 2 2 1 0 0 1 4 2 3 0 5"],
	[7, 1, "6 5 4 3", "3 2 2 1 1 0 0 4 3 5 2 6 1 0"],
	# 13 Wildcards — rule from here on: no single shot can win (checked by
	# tests/unit/test_puzzle_catalog.gd).
	[5, 1, "3 2 1", "W 2 1 3 0 2 0 1 W 1 3 1 2 0"],
	[6, 1, "4 3 2", "W 3 2 3 1 2 W 3 0 1 0 2 4 1 2 3"],
	[6, 1, "4 2 3 1", "W 0 1 3 3 3 W 2 2 1 4 2 0 1 2"],
	[7, 1, "5 3 4 2", "W 4 3 W 2 5 1 3 W 0 4 2"],
	[7, 1, "5 4 2 3 1", "W 2 3 W 4 1 5 0 W 3 2"],
	[8, 1, "6 5 4 3", "W 5 4 W 3 2 W 6 1 4 0 5"],
	# 19 Comets & Anchors
	[5, 1, "3 4 2", "C 2 1 2 3 1 0 3 C 1 2 0 3"],
	[6, 1, "4 5 3", "C 3 2 3 4 2 C 3 1 1 3 0 2 4"],
	[6, 1, "A4 3 2", "2 1 3 4 0 2 3 0 1 2 C 3 3 1 1 2 0 4 2 3 3"],
	[7, 1, "A5 4 3 2", "3 C 2 4 4 3 3 1 2 2 3 4 4 W 1 5 3 0 2 2 W"],
	[7, 1, "5 A4 3 2", "C 4 3 C 5 2 W 1 4 0 3"],
	[8, 1, "A6 5 4 3 2", "3 2 C 5 4 4 W 3 5 W 1 4 3 2 C 5 6 3 2 4"],
	# 25 Event Horizon
	[6, 1, "4 8 3", "B 3 2 3 1 2 4 4 0 1 2 3 1 2 3 0 W"],
	[7, 1, "5 8 4 3", "B 4 3 B 5 2 W 1 4 0"],
	[8, 1, "6 9 5 8 4", "B 5 4 4 B 5 W 3 6 W 3 4 5 2 C 2 4 1"],
	# 28 Binary
	[6, 2, "4 3 2 1", "1 0 0 2 2 2 3 1 1 1 3 2 W W 2 0 0 2 3 1 2 4 1"],
	[7, 2, "5 4 3 2", "W 2 1 4 3 3 C W 4 2 0 3 W 1 5 2 1 2 3"],
	[9, 2, "7 6 5 4 3", "W 6 5 5 B 4 4 3 3 W 7 2 C 5 1 4 W 6 0"],
]

## Fraction of planets left over needed for 3 and 2 stars.
const THREE_STARS := 0.35
const TWO_STARS := 0.15


static func count() -> int:
	return LEVELS.size()


## Level n (1-based) as a dictionary:
## { number, goal, cores, setup: [{level, kind}], sequence: [{level, kind}], chapter }
static func get_level(n: int) -> Dictionary:
	var spec: Array = LEVELS[clampi(n, 1, count()) - 1]
	return {
		"number": clampi(n, 1, count()),
		"goal": spec[0],
		"cores": spec[1],
		"setup": parse(spec[2]),
		"sequence": parse(spec[3]),
		"chapter": chapter_of(n),
	}


static func chapter_of(n: int) -> String:
	var name: String = CHAPTERS[0][0]
	for c in CHAPTERS:
		if n >= c[1]:
			name = c[0]
	return name


## "4 A5 W C B a" -> [{level, kind}, ...]
static func parse(text: String) -> Array:
	var out := []
	for token in text.split(" ", false):
		var kind := PlanetKind.Kind.NORMAL
		var level := 0
		match token[0]:
			"W":
				kind = PlanetKind.Kind.WILDCARD
				level = 1
			"C":
				kind = PlanetKind.Kind.COMET
			"B":
				kind = PlanetKind.Kind.BLACK_HOLE
				level = 1
			"A":
				kind = PlanetKind.Kind.ANCHOR
				level = _digit(token.substr(1))
			_:
				level = _digit(token)
		out.append({"level": level, "kind": kind})
	return out


static func _digit(t: String) -> int:
	return 10 if t == "a" else int(t)


## Stars for a solved puzzle, from the planets left unused.
static func stars(shots_left: int, total: int) -> int:
	if total <= 0:
		return 1
	var left := float(shots_left) / total
	if left >= THREE_STARS:
		return 3
	if left >= TWO_STARS:
		return 2
	return 1


## Player-facing goal text, e.g. "Create a Verdant (level 6)".
static func goal_text(goal: int) -> String:
	return "Create a %s (level %d)" % [Progress.PLANET_NAMES[goal], goal + 1]
