class_name UIStyle
extends RefCounted
## One place for ORBIT's UI look: colors, fonts, panels, buttons.
## Every screen builds its widgets through these helpers, so the whole app
## stays visually consistent and can be restyled from here.

## Theme colors (see Themes.apply). VIOLET = primary accent, AQUA = second
## accent; the names come from the default "Nebula" theme.
static var BG := Color("#080910")
static var SURFACE := Color("#11142A")
static var SECONDARY := Color("#171B30")
static var VIOLET := Color("#917AFF")
static var AQUA := Color("#52E5D5")
static var WHITE := Color("#F5F5FA")

static var _fonts: Dictionary = {}


## The default font with extra letter spacing (for titles and wordmarks).
static func spaced_font(spacing: int) -> FontVariation:
	if not _fonts.has(spacing):
		var f := FontVariation.new()
		f.base_font = ThemeDB.fallback_font
		f.spacing_glyph = spacing
		_fonts[spacing] = f
	return _fonts[spacing]


static func label(text: String, size: int, color: Color = WHITE, spacing: int = 0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if spacing != 0:
		l.add_theme_font_override("font", spaced_font(spacing))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(fill: Color, border: Color = Color(0, 0, 0, 0), radius: int = 28, border_width: int = 1) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(border_width if border.a > 0.0 else 0)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


## Pill button. primary = filled accent, otherwise outlined and quiet.
static func button(text: String, primary: bool = true, accent: Color = VIOLET, height: int = 80) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_font_override("font", spaced_font(4))
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, WHITE if primary else Color(WHITE, 0.85))
	b.add_theme_color_override("font_pressed_color", AQUA)
	var line := accent if primary else Color(WHITE, 0.3)
	var r := height / 2
	b.add_theme_stylebox_override("normal", box(Color(accent, 0.22) if primary else Color(0, 0, 0, 0), line, r, 2))
	b.add_theme_stylebox_override("hover", box(Color(accent, 0.32) if primary else Color(WHITE, 0.06), line, r, 2))
	b.add_theme_stylebox_override("pressed", box(Color(AQUA, 0.2), AQUA, r, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Thin, quiet scrollbar for every scrolling list.
static func style_scroll(s: ScrollContainer) -> void:
	var bar := s.get_v_scroll_bar()
	bar.custom_minimum_size.x = 6
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, box(Color(WHITE, 0.14), Color(0, 0, 0, 0), 3))


## Full-screen fade used for every screen change (premium, never abrupt).
static func fade_rect(start_alpha: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(BG, start_alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
