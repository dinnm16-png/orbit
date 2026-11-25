class_name Coach
extends Control
## First-game tutorial: no walls of text. An animated hand shows the gesture,
## then a few short captions appear as the player does each thing.
##   AIM -> (first launch) MERGE -> (first merge) CHAIN -> RING -> done

signal finished

enum Step { AIM, MERGE, CHAIN, RING, DONE }

var step: Step = Step.AIM
## Where the gesture starts (the launcher) and where the ring is.
var launcher_pos: Vector2 = Vector2.ZERO
## Caption baseline (Main passes the old hint line's position).
var caption_y: float = 0.0
var ring_center: Vector2 = Vector2.ZERO
var ring_radius: float = 300.0

var _t: float = 0.0
var _caption: Label
var _step_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption = UIStyle.label("", 24, UIStyle.WHITE, 2, HORIZONTAL_ALIGNMENT_CENTER)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_caption)
	_show_caption("Pull back and release")


func _process(delta: float) -> void:
	_t += delta
	_step_time += delta
	if step == Step.CHAIN and _step_time > 3.2:
		advance(Step.RING)
	elif step == Step.RING and _step_time > 3.4:
		advance(Step.DONE)
	queue_redraw()


func on_launch() -> void:
	if step == Step.AIM:
		advance(Step.MERGE)


func on_merge() -> void:
	if step == Step.AIM or step == Step.MERGE:
		advance(Step.CHAIN)


func advance(to: Step) -> void:
	step = to
	_step_time = 0.0
	match step:
		Step.MERGE:
			_show_caption("Matching planets merge into bigger ones")
		Step.CHAIN:
			_show_caption("Nice! Merges in a row make chains — and big scores")
		Step.RING:
			_show_caption("Keep every planet inside the ring")
		Step.DONE:
			var t := create_tween()
			t.tween_property(self, "modulate:a", 0.0, 0.4)
			t.tween_callback(func():
				finished.emit()
				queue_free())


func _show_caption(text: String) -> void:
	_caption.text = text
	_caption.size = Vector2(size.x - 80.0, 80.0)
	# Below the launcher, where the gesture never draws.
	_caption.position = Vector2(40.0, caption_y)
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.3)


func _draw() -> void:
	match step:
		Step.AIM:
			# A ghost finger presses on the launcher, pulls down, and lets go;
			# a dotted arrow shows the planet flying the other way.
			var cycle := fmod(_t, 2.2) / 2.2
			var pull := smoothstep(0.1, 0.6, cycle) * 70.0 if cycle < 0.75 else 0.0
			var finger := launcher_pos + Vector2(0, 10.0 + pull)
			var alpha := 0.0 if cycle > 0.85 else 0.85
			draw_circle(finger, 22.0, Color(UIStyle.WHITE, 0.18 * alpha), true, -1.0, true)
			draw_arc(finger, 22.0, 0, TAU, 32, Color(UIStyle.WHITE, 0.7 * alpha), 2.0, true)
			if pull > 15.0:
				for i in 8:
					var p := launcher_pos + Vector2(0, -60.0 - i * 22.0 * (pull / 70.0))
					draw_circle(p, 3.0, Color(UIStyle.AQUA, (0.9 - i * 0.1) * alpha), true, -1.0, true)
		Step.RING:
			var pulse := 0.5 + 0.5 * sin(_t * 5.0)
			draw_arc(ring_center, ring_radius, 0, TAU, 128, Color(UIStyle.AQUA, 0.3 + 0.5 * pulse), 4.0, true)
