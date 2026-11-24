class_name ModeCard
extends Button
## A tappable card for one mode: animated icon, title, tagline, best score.

signal chosen(mode: GameMode)

var mode: GameMode
var detail_text: String = ""


func setup(p_mode: GameMode, p_detail_text: String) -> void:
	mode = p_mode
	detail_text = p_detail_text


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0, 112)
	var accent := mode.accent
	add_theme_stylebox_override("normal", UIStyle.box(Color(UIStyle.SURFACE, 0.82), Color(accent, 0.22), 30))
	add_theme_stylebox_override("hover", UIStyle.box(Color(UIStyle.SECONDARY, 0.95), Color(accent, 0.5), 30))
	add_theme_stylebox_override("pressed", UIStyle.box(Color(accent, 0.16), Color(accent, 0.8), 30))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(64, 64)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := ModeIcon.new()
	icon.setup(mode.id, accent, 17.0)
	icon.position = Vector2(32, 32)
	icon_box.add_child(icon)
	row.add_child(icon_box)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override("separation", 2)
	texts.add_child(UIStyle.label(mode.title.to_upper(), 25, UIStyle.WHITE, 3))
	texts.add_child(UIStyle.label(mode.tagline, 18, Color(UIStyle.WHITE, 0.5)))
	row.add_child(texts)

	var detail := UIStyle.label(detail_text, 17, Color(accent.lightened(0.3), 0.85), 1, HORIZONTAL_ALIGNMENT_RIGHT)
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(detail)

	pressed.connect(func(): chosen.emit(mode))
