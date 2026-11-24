class_name PauseMenu
extends Control
## Pause overlay: Resume, Restart and settings toggles.
## process_mode is ALWAYS so it keeps working while the game tree is paused.

signal resume_requested
signal restart_requested
signal settings_changed

const COLOR_BG := Color("#080910")
const COLOR_VIOLET := Color("#917AFF")
const COLOR_AQUA := Color("#52E5D5")
const COLOR_WHITE := Color("#F5F5FA")

var settings: PlayerSettings

var _toggles: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var bg := ColorRect.new()
	bg.color = Color(COLOR_BG, 0.86)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(COLOR_WHITE, 0.55))
	box.add_child(title)

	box.add_child(_make_button("RESUME", true, func(): resume_requested.emit()))
	box.add_child(_make_button("RESTART", false, func(): restart_requested.emit()))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)

	_toggles["sound"] = _make_toggle(box, "Sound")
	_toggles["haptics"] = _make_toggle(box, "Vibration")
	_toggles["planet_numbers"] = _make_toggle(box, "Planet numbers")


func open() -> void:
	# Reflect current settings without emitting change signals.
	for key in _toggles:
		_toggles[key].set_pressed_no_signal(settings.get(key))
		_toggles[key].queue_redraw()
	visible = true


func close() -> void:
	visible = false


func _on_toggle(key: String, value: bool) -> void:
	settings.set(key, value)
	settings.save_settings()
	settings_changed.emit()


func _make_toggle(parent: Control, text: String) -> SwitchToggle:
	var key: String = {"Sound": "sound", "Vibration": "haptics", "Planet numbers": "planet_numbers"}[text]
	var toggle := SwitchToggle.new()
	toggle.text = text
	toggle.custom_minimum_size = Vector2(320, 56)
	toggle.add_theme_font_size_override("font_size", 24)
	toggle.toggled.connect(func(on: bool): _on_toggle(key, on))
	parent.add_child(toggle)
	return toggle


func _make_button(text: String, primary: bool, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(320, 80)
	button.add_theme_font_size_override("font_size", 26)
	for c in ["font_color", "font_hover_color"]:
		button.add_theme_color_override(c, COLOR_WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_AQUA)
	var accent := COLOR_VIOLET if primary else Color(COLOR_WHITE, 0.35)
	button.add_theme_stylebox_override("normal", _make_box(Color(accent, 0.16 if primary else 0.0), accent))
	button.add_theme_stylebox_override("hover", _make_box(Color(accent, 0.26), accent))
	button.add_theme_stylebox_override("pressed", _make_box(Color(COLOR_AQUA, 0.18), COLOR_AQUA))
	button.pressed.connect(action)
	return button


func _make_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(40)
	box.anti_aliasing = true
	return box
