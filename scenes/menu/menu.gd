extends Control
## Main menu: animated backdrop, ORBIT wordmark, tabbed pages (Play, Settings,
## and later Collection/Stats), mode cards and a mode detail sheet.
##
## Navigation rules (kept simple on purpose):
##   Home tab lists every mode -> tap a card -> sheet with rules -> PLAY.
##   Back button: closes the sheet, else returns to the Play tab, else quits.

const GAME_SCENE := "res://scenes/main/main.tscn"
const TABS := ["play", "collection", "stats", "settings"]
const TAB_TITLES := {"play": "PLAY", "collection": "PLANETS", "stats": "STATS", "settings": "SETTINGS"}

@export var save_path: String = "user://orbit_save.cfg"

var settings: PlayerSettings
var progress: Progress
var current_tab: String = "play"

var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _sheet: ModeSheet
var _fade: ColorRect
var _leaving: bool = false
var _insets: Dictionary
var _hero: VBoxContainer
var _tagline: Label


func _ready() -> void:
	settings = PlayerSettings.new(save_path)
	settings.load_settings()
	progress = Progress.new(save_path).load_progress()
	if not progress.is_theme_unlocked(settings.theme):
		settings.theme = "nebula"
	Themes.apply(settings.theme)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_insets = SafeArea.current(get_viewport_rect().size)

	var bg := ColorRect.new()
	bg.color = UIStyle.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var backdrop := MenuBackdrop.new()
	backdrop.center = Vector2(get_viewport_rect().size.x * 0.5, 250.0 + _insets["top"])
	backdrop.modulate.a = 0.6  # Atmosphere, not decoration: keep the wordmark clean.
	backdrop.colors = Themes.planet_colors(settings.theme)
	add_child(backdrop)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_top = _insets["top"]
	layout.offset_bottom = -_insets["bottom"]
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)

	# Hero: wordmark over the glowing core of the backdrop.
	_hero = VBoxContainer.new()
	_hero.custom_minimum_size = Vector2(0, 430)
	_hero.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero.add_theme_constant_override("separation", 10)
	_hero.add_child(UIStyle.label("ORBIT", 78, UIStyle.WHITE, 26, HORIZONTAL_ALIGNMENT_CENTER))
	_tagline = UIStyle.label("Simple to play. Infinite to master.", 20, Color(UIStyle.WHITE, 0.5), 1, HORIZONTAL_ALIGNMENT_CENTER)
	_hero.add_child(_tagline)
	layout.add_child(_hero)

	var pages := MarginContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		pages.add_theme_constant_override("margin_" + side, 40)
	layout.add_child(pages)
	_pages["play"] = _build_play_page()
	var collection := CollectionPage.new()
	collection.setup(progress, Themes.planet_colors(settings.theme))
	_pages["collection"] = _scroll(collection)
	var stats := StatsPage.new()
	stats.setup(progress, save_path, settings.difficulty)
	_pages["stats"] = _scroll(stats)
	var settings_page := SettingsPage.new()
	settings_page.setup(settings)
	settings_page.is_theme_unlocked = progress.is_theme_unlocked
	settings_page.unlock_hint = progress.theme_unlock_hint
	settings_page.changed.connect(_refresh_cards)
	settings_page.theme_picked.connect(_on_theme_picked)
	_pages["settings"] = _scroll(settings_page)
	for key in _pages:
		pages.add_child(_pages[key])

	layout.add_child(_build_tab_bar())

	_sheet = ModeSheet.new()
	_sheet.play_requested.connect(_start_mode)
	add_child(_sheet)

	_fade = UIStyle.fade_rect(1.0)
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.45)

	show_tab(Session.menu_tab)
	Session.menu_tab = "play"


func _build_play_page() -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	for id in Session.ORDER:
		var mode := Session.load_mode(id)
		var card := ModeCard.new()
		card.setup(mode, _best_text(mode, true))
		card.chosen.connect(_open_sheet)
		list.add_child(card)
	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 20)
	list.add_child(bottom_pad)
	return _scroll(list)


func _scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Thin, quiet scrollbar instead of the default grey bar.
	var bar := s.get_v_scroll_bar()
	bar.custom_minimum_size.x = 6
	bar.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, UIStyle.box(Color(UIStyle.WHITE, 0.14), Color(0, 0, 0, 0), 3))
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


func _build_tab_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 104)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	for key in TABS:
		var b := Button.new()
		b.text = TAB_TITLES[key]
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(160, 88)
		b.add_theme_font_override("font", UIStyle.spaced_font(4))
		b.add_theme_font_size_override("font_size", 17)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		b.pressed.connect(show_tab.bind(key))
		# Active-tab dot.
		b.draw.connect(func():
			if current_tab == key:
				b.draw_circle(Vector2(b.size.x / 2, b.size.y - 16), 3.5, UIStyle.AQUA, true, -1.0, true))
		bar.add_child(b)
		_tab_buttons[key] = b
	return bar


func show_tab(key: String) -> void:
	var changed := key != current_tab
	current_tab = key
	# Content tabs get more room: the hero header collapses smoothly.
	if _hero:
		var tall := key == "play"
		var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(_hero, "custom_minimum_size:y", 430.0 if tall else 250.0, 0.3 if changed else 0.0)
		t.tween_property(_tagline, "modulate:a", 1.0 if tall else 0.0, 0.25 if changed else 0.0)
	for k in _pages:
		_pages[k].visible = k == key
	for k in _tab_buttons:
		var b: Button = _tab_buttons[k]
		var col := UIStyle.WHITE if k == key else Color(UIStyle.WHITE, 0.4)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(c, col)
		b.queue_redraw()
	if key == "play" and _pages.has("play"):
		_pages["play"].modulate.a = 0.0
		create_tween().tween_property(_pages["play"], "modulate:a", 1.0, 0.25)


func _best_key(mode: GameMode) -> String:
	var key := mode.best_key(DailySeed.today_key())
	if mode.difficulty_applies:
		key += Difficulty.best_key_suffix(settings.difficulty)
	return key


func _best_text(mode: GameMode, short: bool) -> String:
	var key := _best_key(mode)
	var best := HighScoreStore.new(save_path, key).load_best()
	if mode.daily_seed:
		var today := DailySeed.pretty(DailySeed.today_key()).to_upper()
		return ("TODAY\n%s" % (str(best) if best > 0 else today)) if short else \
			("TODAY  ·  %s  ·  BEST  %s" % [today, str(best) if best > 0 else "—"])
	var diff := ""
	if mode.difficulty_applies and settings.difficulty != Difficulty.Level.NORMAL:
		diff = "  ·  " + Difficulty.NAMES[settings.difficulty].to_upper()
	if best <= 0:
		return "NEW" if short else "NOT PLAYED YET" + diff
	return ("BEST\n%d" % best) if short else ("BEST  %d" % best) + diff


func _open_sheet(mode: GameMode) -> void:
	_sheet.open(mode, func(m): return _best_text(m, false), _insets["bottom"], settings)


## Card best scores depend on the difficulty: rebuild them when it changes.
func _refresh_cards() -> void:
	for card in _cards():
		card.queue_free()
	var list: VBoxContainer = _pages["play"].get_child(0)
	var pad := list.get_child(list.get_child_count() - 1)
	for id in Session.ORDER:
		var mode := Session.load_mode(id)
		var card := ModeCard.new()
		card.setup(mode, _best_text(mode, true))
		card.chosen.connect(_open_sheet)
		list.add_child(card)
	list.move_child(pad, -1)


func _cards() -> Array:
	var out := []
	for n in _pages["play"].get_child(0).get_children():
		if n is ModeCard:
			out.append(n)
	return out


## A new theme recolors everything: reload the menu (with a fade), staying on
## the Settings tab.
func _on_theme_picked(theme_id: String) -> void:
	if _leaving:
		return
	_leaving = true
	Themes.apply(theme_id)
	Session.menu_tab = "settings"
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.2)
	t.tween_callback(func(): get_tree().reload_current_scene() if get_tree().current_scene == self else null)


func _start_mode(mode: GameMode) -> void:
	if _leaving:
		return
	_leaving = true
	Session.mode_id = mode.id
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.28)
	t.tween_callback(func(): get_tree().change_scene_to_file(GAME_SCENE))


func _go_back() -> void:
	if _sheet.is_open:
		_sheet.close()
	elif current_tab != "play":
		show_tab("play")
	else:
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_go_back()
