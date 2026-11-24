class_name Themes
extends RefCounted
## Color themes. A theme recolors the background, core, UI accents and all
## 12 planet levels. Neighbouring planet levels must stay clearly distinct in
## every theme (checked by tests).

const ORDER := ["nebula", "aurora", "solar", "mono"]
const DATA := {
	"nebula": {
		"name": "Nebula", "blurb": "The original violet night",
		"bg": "#080910", "surface": "#11142A", "secondary": "#171B30",
		"primary": "#917AFF", "accent": "#52E5D5",
		"planets": ["#917AFF", "#52E5D5", "#FF8FC8", "#7A9BFF", "#FFD27A", "#5EE6A8",
			"#C59BFF", "#52B8E5", "#FF9F7A", "#D77BFF", "#FFE9A8", "#F5F5FA"],
	},
	"aurora": {
		"name": "Aurora", "blurb": "Polar greens and ice",
		"bg": "#050D0E", "surface": "#0C1C1E", "secondary": "#102628",
		"primary": "#5EE6A8", "accent": "#7AD7FF",
		"planets": ["#5EE6A8", "#7AD7FF", "#C6F27E", "#2F9E8F", "#E7F7A6", "#5A8CFF",
			"#A8F0D8", "#1F7A70", "#FFE08A", "#9BC8FF", "#3CCB7F", "#F2FFF8"],
	},
	"solar": {
		"name": "Solar", "blurb": "Embers, gold and flare",
		"bg": "#0E0806", "surface": "#1F120D", "secondary": "#2A1912",
		"primary": "#FFB36B", "accent": "#FF6F61",
		"planets": ["#FFB36B", "#FF6F61", "#FFE08A", "#B5523E", "#FFD1A8", "#D93F5C",
			"#FFC94D", "#8C4A3A", "#FFF1C9", "#FF8C8C", "#C98A2E", "#FFF8EE"],
	},
	"mono": {
		"name": "Mono", "blurb": "Silver on graphite",
		"bg": "#0A0A0C", "surface": "#151518", "secondary": "#1D1D22",
		"primary": "#D6D9E0", "accent": "#9AA3B5",
		"planets": ["#8A8F9C", "#D6D9E0", "#5E6370", "#B4B8C4", "#6F7480", "#ECEEF2",
			"#4D525E", "#C2C6D0", "#626774", "#A9AEBA", "#3F434D", "#FFFFFF"],
	},
}

static var current_id: String = "nebula"


static func exists(id: String) -> bool:
	return DATA.has(id)


static func planet_colors(id: String) -> PackedColorArray:
	var out := PackedColorArray()
	for c in DATA.get(id, DATA["nebula"])["planets"]:
		out.append(Color(c))
	return out


## Makes `id` the active theme for everything created from now on.
static func apply(id: String) -> void:
	if not DATA.has(id):
		id = "nebula"
	current_id = id
	var t: Dictionary = DATA[id]
	UIStyle.BG = Color(t["bg"])
	UIStyle.SURFACE = Color(t["surface"])
	UIStyle.SECONDARY = Color(t["secondary"])
	UIStyle.VIOLET = Color(t["primary"])
	UIStyle.AQUA = Color(t["accent"])
	RenderingServer.set_default_clear_color(UIStyle.BG)
