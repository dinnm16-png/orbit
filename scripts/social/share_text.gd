class_name ShareText
extends RefCounted
## Spoiler-free result text, Wordle-style: a 12-dot "ladder" shows how far up
## the planet levels you climbed. Pure function, easy to test.

## One emoji per planet level (reached), echoing the in-game palette.
const LADDER := ["🟣", "🔵", "🔴", "🟣", "🟡", "🟢", "🟣", "🔵", "🟠", "🟣", "🟡", "⚪"]
const EMPTY := "⚫"


## biggest_level: highest level created (-1 = none). Returns the full text.
static func build(mode_title: String, subtitle: String, score: int, biggest_level: int,
		best_chain: int, code: String) -> String:
	var ladder := ""
	for i in 12:
		ladder += LADDER[i] if i <= biggest_level else EMPTY
	var lines := []
	lines.append("ORBIT · %s%s" % [mode_title, (" · " + subtitle) if subtitle != "" else ""])
	lines.append(ladder)
	var stats := "Score %s" % group(score)
	if best_chain >= 2:
		stats += " · Chain ×%d" % best_chain
	if biggest_level >= 0:
		stats += " · %s" % Progress.PLANET_NAMES[clampi(biggest_level, 0, 11)]
	lines.append(stats)
	if code != "":
		lines.append("Beat me: %s" % code)
	return "\n".join(lines)


## 14250 -> "14,250"
static func group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
