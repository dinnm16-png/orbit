class_name Launcher
extends Node2D
## One-finger slingshot input.
##
## Touch (or click) anywhere, pull back, release: the loaded planet flies in the
## direction opposite to your pull. Pull distance sets the power.
##
## Input decision: the project enables "Emulate Touch From Mouse", so a mouse
## click arrives here as an InputEventScreenTouch. That gives ONE code path
## for both phones and desktop testing, instead of two that can drift apart.

signal planet_launched(planet: Planet)


var config: GameConfig
var loaded_planet: Planet = null
## When false (e.g. game over) all input is ignored and any aim is cancelled.
var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_touch_index = -1
			queue_redraw()

## Movable launcher: slide sideways along a track (see _unhandled_input).
var movable: bool = true:
	set(value):
		movable = value
		queue_redraw()
## Aim assist: draw the predicted flight path while aiming.
var aim_assist: bool = false:
	set(value):
		aim_assist = value
		queue_redraw()
## Core positions (for the prediction). Main sets these.
var gravity_centers: Array = []
## Track limits (global x). Main sets these from the layout.
var track_min_x: float = 200.0
var track_max_x: float = 520.0

## Which finger is aiming (-1 = nobody). Extra fingers are ignored.
var _touch_index: int = -1
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO
## Gesture state: a touch that starts on the launcher is undecided until it
## moves; mostly-sideways = slide the launcher, otherwise = aim.
enum Gesture { NONE, UNDECIDED, AIM, SLIDE }
var _gesture: Gesture = Gesture.NONE
var _slide_start_x: float = 0.0

const SLIDE_DECIDE_DISTANCE := 14.0


func setup(p_config: GameConfig) -> void:
	config = p_config


func load_planet(planet: Planet) -> void:
	loaded_planet = planet
	planet.global_position = global_position
	planet.reset_physics_interpolation()  # Teleport: don't smooth from old spot.
	queue_redraw()


func is_aiming() -> bool:
	return _touch_index != -1 and _gesture != Gesture.SLIDE


func is_sliding() -> bool:
	return _touch_index != -1 and _gesture == Gesture.SLIDE


## Current launch velocity for the active drag (ZERO = would cancel).
func current_launch_velocity() -> Vector2:
	return OrbitPhysics.launch_velocity(
		_drag_start - _drag_current,
		config.min_drag_distance, config.max_drag_distance, config.max_launch_speed)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and loaded_planet != null:
			_touch_index = touch.index
			_drag_start = touch.position
			_drag_current = touch.position
			_slide_start_x = global_position.x
			var on_pad := touch.position.distance_to(global_position) < loaded_planet.radius + 34.0
			_gesture = Gesture.UNDECIDED if (movable and on_pad) else Gesture.AIM
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_drag_current = touch.position
			_release()
			get_viewport().set_input_as_handled()
		elif touch.canceled and touch.index == _touch_index:
			# OS interrupted the touch (e.g. notification): cancel, never fire.
			_touch_index = -1
			_gesture = Gesture.NONE
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_drag_current = drag.position
			var delta := _drag_current - _drag_start
			if _gesture == Gesture.UNDECIDED and delta.length() >= SLIDE_DECIDE_DISTANCE:
				# Aiming pulls go mostly downward; a mostly sideways drag that
				# started on the launcher means "move the launcher".
				_gesture = Gesture.SLIDE if absf(delta.x) > 2.0 * absf(delta.y) else Gesture.AIM
			if _gesture == Gesture.SLIDE:
				_slide_to(_slide_start_x + delta.x)
			queue_redraw()
			get_viewport().set_input_as_handled()


func _slide_to(x: float) -> void:
	global_position.x = clampf(x, track_min_x, track_max_x)
	if loaded_planet:
		loaded_planet.global_position = global_position
		loaded_planet.reset_physics_interpolation()


func _release() -> void:
	_touch_index = -1
	var gesture := _gesture
	_gesture = Gesture.NONE
	if gesture == Gesture.SLIDE:
		queue_redraw()
		return  # Sliding never launches.
	var velocity := current_launch_velocity()
	if velocity != Vector2.ZERO and loaded_planet != null:
		fire(velocity)
	queue_redraw()


## Launches the loaded planet. Public so tests can fire without real input.
func fire(velocity: Vector2) -> void:
	if loaded_planet == null or not enabled:
		return
	var planet := loaded_planet
	loaded_planet = null
	planet.launch(velocity)
	planet_launched.emit(planet)
	queue_redraw()


func _draw() -> void:
	# Launch pad: a subtle ring where the next planet waits.
	draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 64, Color(UIStyle.VIOLET, 0.25), 1.2, true)
	if movable:
		# Slide track with small chevrons at both ends.
		var y := 62.0
		var x0 := track_min_x - global_position.x
		var x1 := track_max_x - global_position.x
		var a := 0.35 if is_sliding() else 0.12
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(UIStyle.WHITE, a), 1.5, true)
		for side in [-1.0, 1.0]:
			var tip := Vector2(x0 - 12.0 if side < 0.0 else x1 + 12.0, y)
			draw_polyline(PackedVector2Array([tip + Vector2(-side * 6.0, -6.0), tip, tip + Vector2(-side * 6.0, 6.0)]),
				Color(UIStyle.WHITE, a + 0.1), 1.5, true)
		draw_circle(Vector2(0, y), 3.5, Color(UIStyle.AQUA, 0.9 if is_sliding() else 0.5), true, -1.0, true)

	if not is_aiming() or loaded_planet == null:
		return

	var pull := _drag_start - _drag_current
	var power := OrbitPhysics.launch_power(pull.length(), config.max_drag_distance)
	var will_fire := pull.length() >= config.min_drag_distance

	# Power ring around the planet: fills clockwise as you pull further.
	var r := loaded_planet.radius + 10.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(UIStyle.WHITE, 0.08), 2.0, true)
	if power > 0.0:
		draw_arc(Vector2.ZERO, r, -PI / 2.0, -PI / 2.0 + TAU * power, 64,
			Color(UIStyle.AQUA, 0.85 if will_fire else 0.3), 2.5, true)

	if not will_fire:
		return

	if aim_assist and not gravity_centers.is_empty():
		_draw_predicted_path(r)
		return

	# Dotted aim line in the launch direction, length proportional to power.
	var dir := pull.normalized()
	var length := 60.0 + 240.0 * power
	var dots := 14
	for i in dots:
		var t := float(i + 1) / dots
		var p := dir * (r + length * t)
		draw_circle(p, lerpf(3.2, 1.4, t), Color(UIStyle.AQUA, lerpf(0.9, 0.1, t)), true, -1.0, true)


## Aim assist: dots along the predicted path (same physics as the game, but
## ignoring other planets), fading with time of flight.
func _draw_predicted_path(ring_radius: float) -> void:
	var path := OrbitPhysics.predict_path(global_position, current_launch_velocity(), gravity_centers,
		config.gravity_strength, config.planet_linear_damp, config.max_planet_speed,
		1.0 / 60.0, 96, config.core_radius + loaded_planet.radius)
	var dots := 0
	for i in range(3, path.size(), 4):
		var local := path[i] - global_position
		if local.length() < ring_radius:
			continue
		var t := float(i) / path.size()
		draw_circle(local, lerpf(3.4, 1.6, t), Color(UIStyle.AQUA, lerpf(0.85, 0.15, t)), true, -1.0, true)
		dots += 1
	if not path.is_empty():
		draw_arc(path[path.size() - 1] - global_position, loaded_planet.radius, 0, TAU, 32,
			Color(UIStyle.AQUA, 0.35), 1.5, true)
