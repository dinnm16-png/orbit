class_name ModeSheet
extends Control
## Bottom sheet with a mode's rules and a big PLAY button. Slides up over a
## dimmed background; tapping outside (or Back) closes it.

signal play_requested(mode: GameMode)
signal closed

var mode: GameMode
var is_open: bool = false

var _dim: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_dim = ColorRect.new()
	_dim.color = Color(UIStyle.BG, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			close())
	add_child(_dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)


func open(p_mode: GameMode, best_text: String, bottom_inset: float) -> void:
	mode = p_mode
	if _content:
		_content.queue_free()
	_panel.add_theme_stylebox_override("panel", _panel_box(mode.accent, bottom_inset))
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 14)
	_panel.add_child(_content)

	var grabber := Control.new()
	grabber.custom_minimum_size = Vector2(0, 10)
	grabber.draw.connect(func(): grabber.draw_line(Vector2(grabber.size.x / 2 - 28, 4), Vector2(grabber.size.x / 2 + 28, 4), Color(UIStyle.WHITE, 0.25), 4.0, true))
	_content.add_child(grabber)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	var icon_box := Control.new()
	icon_box.custom_minimum_size = Vector2(96, 96)
	var icon := ModeIcon.new()
	icon.setup(mode.id, mode.accent, 26.0)
	icon.position = Vector2(48, 48)
	icon_box.add_child(icon)
	head.add_child(icon_box)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_child(UIStyle.label(mode.title.to_upper(), 36, UIStyle.WHITE, 5))
	titles.add_child(UIStyle.label(mode.tagline, 20, Color(mode.accent.lightened(0.3), 0.9)))
	head.add_child(titles)
	_content.add_child(head)

	var desc := UIStyle.label(mode.description, 22, Color(UIStyle.WHITE, 0.75))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(560, 0)
	_content.add_child(desc)
	_content.add_child(UIStyle.label(best_text, 18, Color(UIStyle.WHITE, 0.45), 3))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_content.add_child(gap)
	var play := UIStyle.button("PLAY", true, mode.accent, 92)
	play.pressed.connect(func(): play_requested.emit(mode))
	_content.add_child(play)

	visible = true
	is_open = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Slide up once the panel knows its height.
	await get_tree().process_frame
	var target_y := _panel.position.y
	_panel.position.y = size.y
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_panel, "position:y", target_y, 0.32)
	t.tween_property(_dim, "color:a", 0.62, 0.32)


func close() -> void:
	if not is_open:
		return
	is_open = false
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(_panel, "position:y", size.y, 0.24)
	t.tween_property(_dim, "color:a", 0.0, 0.24)
	t.chain().tween_callback(func():
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE)
	closed.emit()


func _panel_box(accent: Color, bottom_inset: float) -> StyleBoxFlat:
	var b := UIStyle.box(Color(UIStyle.SURFACE, 0.98), Color(accent, 0.35), 40, 1)
	b.corner_radius_bottom_left = 0
	b.corner_radius_bottom_right = 0
	b.content_margin_left = 44
	b.content_margin_right = 44
	b.content_margin_top = 18
	b.content_margin_bottom = 44 + bottom_inset
	return b
