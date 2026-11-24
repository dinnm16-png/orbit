class_name SegmentedControl
extends HBoxContainer
## Pill-shaped single-choice selector, e.g. EASY | NORMAL | HARD.

signal changed(index: int)

var options: PackedStringArray = PackedStringArray()
var selected: int = 0
var accent: Color = UIStyle.VIOLET

var _buttons: Array[Button] = []


func setup(p_options: PackedStringArray, p_selected: int, p_accent: Color = UIStyle.VIOLET) -> void:
	options = p_options
	selected = p_selected
	accent = p_accent


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	for i in options.size():
		var b := Button.new()
		b.text = options[i].to_upper()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_override("font", UIStyle.spaced_font(3))
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(select.bind(i, true))
		add_child(b)
		_buttons.append(b)
	_refresh()


func select(index: int, emit: bool = false) -> void:
	selected = clampi(index, 0, options.size() - 1)
	_refresh()
	if emit:
		changed.emit(selected)


func _refresh() -> void:
	for i in _buttons.size():
		var b := _buttons[i]
		var on := i == selected
		b.set_pressed_no_signal(on)
		var fill := Color(accent, 0.28) if on else Color(UIStyle.WHITE, 0.04)
		var line := accent if on else Color(UIStyle.WHITE, 0.14)
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, UIStyle.box(fill, line, 30, 1))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, UIStyle.WHITE if on else Color(UIStyle.WHITE, 0.5))
