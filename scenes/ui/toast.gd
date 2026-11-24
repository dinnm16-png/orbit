class_name Toast
extends Control
## Quiet banner for discoveries and milestones. Messages queue up and show
## one at a time; it never blocks input or covers the play area for long.

const SHOW_TIME := 2.2

var _queue: Array = []
var _busy: bool = false
var _panel: PanelContainer
var _title: Label
var _text: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UIStyle.box(Color(UIStyle.SURFACE, 0.92), Color(UIStyle.AQUA, 0.45), 30, 1)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", box)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	_title = UIStyle.label("", 14, Color(UIStyle.AQUA, 0.9), 4, HORIZONTAL_ALIGNMENT_CENTER)
	_text = UIStyle.label("", 22, UIStyle.WHITE, 1, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_title)
	v.add_child(_text)
	_panel.add_child(v)
	_panel.modulate.a = 0.0
	add_child(_panel)


## news: Array of {"title", "text"} (as returned by Progress).
func push(news: Array) -> void:
	_queue.append_array(news)
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var item: Dictionary = _queue.pop_front()
	_title.text = item["title"]
	_text.text = item["text"]
	_panel.reset_size()
	await get_tree().process_frame
	_panel.position = Vector2((size.x - _panel.size.x) * 0.5, -12.0)
	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.set_parallel(true)
	t.tween_property(_panel, "modulate:a", 1.0, 0.3)
	t.tween_property(_panel, "position:y", 0.0, 0.3)
	t.chain().tween_interval(SHOW_TIME)
	t.chain().tween_property(_panel, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(_next)
