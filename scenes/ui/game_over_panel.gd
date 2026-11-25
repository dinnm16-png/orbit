class_name GameOverPanel
extends Control
## Full-screen game-over overlay: final score, best score, one-tap restart.
## Built in code (not in the .tscn) so the layout logic is readable in one place.

signal restart_requested
signal menu_requested
signal next_requested
signal share_requested


var _title_label: Label
var _mode_label: Label
var _score_label: Label
var _best_label: Label
var _button: Button
var _menu_button: Button
var _retry_button: Button
var _share_button: Button
var _summary_label: Label
var _highlight_label: Label
var _stars: StarRow


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(UIStyle.BG, 0.84)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	_mode_label = _make_label("", 18, Color(UIStyle.WHITE, 0.4))
	box.add_child(_mode_label)
	_title_label = _make_label("ORBIT COLLAPSED", 22, Color(UIStyle.WHITE, 0.6))
	box.add_child(_title_label)
	_score_label = _make_label("0", 96, UIStyle.WHITE)
	box.add_child(_score_label)
	_stars = StarRow.new()
	_stars.star_size = 34.0
	_stars.visible = false
	box.add_child(_stars)
	_best_label = _make_label("", 24, Color(UIStyle.WHITE, 0.6))
	box.add_child(_best_label)
	_summary_label = _make_label("", 19, Color(UIStyle.WHITE, 0.55))
	_summary_label.visible = false
	box.add_child(_summary_label)
	_highlight_label = _make_label("", 17, UIStyle.AQUA)
	_highlight_label.add_theme_font_override("font", UIStyle.spaced_font(3))
	_highlight_label.visible = false
	box.add_child(_highlight_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)

	_button = Button.new()
	_button.text = "PLAY AGAIN"
	_button.custom_minimum_size = Vector2(300, 84)
	_button.focus_mode = Control.FOCUS_NONE
	_button.add_theme_font_size_override("font_size", 28)
	_button.add_theme_color_override("font_color", UIStyle.WHITE)
	_button.add_theme_color_override("font_hover_color", UIStyle.WHITE)
	_button.add_theme_color_override("font_pressed_color", UIStyle.AQUA)
	_button.add_theme_stylebox_override("normal", _make_box(Color(UIStyle.VIOLET, 0.16), UIStyle.VIOLET))
	_button.add_theme_stylebox_override("hover", _make_box(Color(UIStyle.VIOLET, 0.26), UIStyle.VIOLET))
	_button.add_theme_stylebox_override("pressed", _make_box(Color(UIStyle.AQUA, 0.18), UIStyle.AQUA))
	_button.pressed.connect(_on_primary)
	var button_row := CenterContainer.new()
	button_row.add_child(_button)
	box.add_child(button_row)

	_menu_button = Button.new()
	_menu_button.text = "MENU"
	_menu_button.custom_minimum_size = Vector2(300, 72)
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.add_theme_font_size_override("font_size", 24)
	_menu_button.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.8))
	_menu_button.add_theme_color_override("font_hover_color", UIStyle.WHITE)
	_menu_button.add_theme_color_override("font_pressed_color", UIStyle.AQUA)
	var quiet := Color(UIStyle.WHITE, 0.3)
	_menu_button.add_theme_stylebox_override("normal", _make_box(Color(0, 0, 0, 0), quiet))
	_menu_button.add_theme_stylebox_override("hover", _make_box(Color(UIStyle.WHITE, 0.06), quiet))
	_menu_button.add_theme_stylebox_override("pressed", _make_box(Color(UIStyle.AQUA, 0.12), UIStyle.AQUA))
	_menu_button.pressed.connect(func(): menu_requested.emit())
	_share_button = _menu_button.duplicate()
	_share_button.text = "SHARE RESULT"
	_share_button.visible = false
	_share_button.add_theme_color_override("font_color", UIStyle.AQUA)
	_share_button.add_theme_stylebox_override("normal", _make_box(Color(UIStyle.AQUA, 0.08), Color(UIStyle.AQUA, 0.6)))
	_share_button.pressed.connect(func(): share_requested.emit())
	var share_row := CenterContainer.new()
	share_row.add_child(_share_button)
	box.add_child(share_row)
	_retry_button = _menu_button.duplicate()
	_retry_button.text = "RETRY"
	_retry_button.visible = false
	_retry_button.pressed.connect(func(): restart_requested.emit())
	var retry_row := CenterContainer.new()
	retry_row.add_child(_retry_button)
	box.add_child(retry_row)
	var menu_row := CenterContainer.new()
	menu_row.add_child(_menu_button)
	box.add_child(menu_row)


var _primary_is_next: bool = false


## End-screen extras: what happened, an honest highlight, and sharing.
func set_details(summary: String, highlight: String, share_text: String) -> void:
	_summary_label.text = summary
	_summary_label.visible = summary != ""
	_highlight_label.text = highlight
	_highlight_label.visible = highlight != ""
	_share_button.visible = share_text != ""


func _on_primary() -> void:
	if _primary_is_next:
		next_requested.emit()
	else:
		restart_requested.emit()


## Puzzle result: stars instead of a score; NEXT PUZZLE when solved.
func present_puzzle(won: bool, stars: int, header: String, goal: String, has_next: bool) -> void:
	_mode_label.text = header.to_upper()
	_mode_label.visible = true
	_title_label.text = "PUZZLE COMPLETE" if won else "NOT QUITE"
	_score_label.visible = false
	_stars.visible = true
	_stars.filled = stars
	_best_label.text = goal
	_best_label.add_theme_color_override("font_color", Color(UIStyle.WHITE, 0.6))
	_primary_is_next = won and has_next
	_button.text = "NEXT PUZZLE" if _primary_is_next else ("PLAY AGAIN" if won else "TRY AGAIN")
	_retry_button.visible = _primary_is_next
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.45)


## title: why the game ended ("ORBIT COLLAPSED", "TIME'S UP"...).
## mode_title: e.g. "BLITZ" — shown small above the title.
func present(score: int, best: int, is_new_best: bool, title: String = "ORBIT COLLAPSED", mode_title: String = "") -> void:
	_title_label.text = title
	_mode_label.text = mode_title.to_upper()
	_mode_label.visible = mode_title != ""
	_score_label.text = str(score)
	if is_new_best:
		_best_label.text = "NEW BEST"
		_best_label.add_theme_color_override("font_color", UIStyle.AQUA)
	else:
		_best_label.text = "BEST  %d" % best
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.45)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(42)
	box.anti_aliasing = true
	return box
