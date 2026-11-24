class_name PlanetKind
extends RefCounted
## The kinds of planets. NORMAL is the regular merge planet; the others are
## rare "special planets" that add tactical choices.

enum Kind { NORMAL, WILDCARD, COMET, BLACK_HOLE, ANCHOR }

const NAMES := {
	Kind.NORMAL: "Planet",
	Kind.WILDCARD: "Wildcard",
	Kind.COMET: "Comet",
	Kind.BLACK_HOLE: "Black Hole",
	Kind.ANCHOR: "Anchor",
}
const HINTS := {
	Kind.WILDCARD: "Merges with any planet",
	Kind.COMET: "Knocks a planet down one level",
	Kind.BLACK_HOLE: "Swallows the first planet it touches",
	Kind.ANCHOR: "Very heavy — a stable foundation",
}
## Body colors for kinds that don't use the level color.
const COLORS := {
	Kind.WILDCARD: Color("#F5F5FA"),
	Kind.COMET: Color("#BFE9FF"),
	Kind.BLACK_HOLE: Color("#1A1430"),
}


## Size (as a level) of special planets; anchors use their own level.
static func size_level(kind: Kind, level: int) -> int:
	match kind:
		Kind.COMET:
			return 0
		Kind.WILDCARD, Kind.BLACK_HOLE:
			return 1
	return level


static func is_special(kind: Kind) -> bool:
	return kind != Kind.NORMAL
