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

const COLOR_AQUA := Color("#52E5D5")
const COLOR_VIOLET := Color("#917AFF")
const COLOR_WHITE := Color("#F5F5FA")

var config: GameConfig
var loaded_planet: Planet = null

## Which finger is aiming (-1 = nobody). Extra fingers are ignored.
var _touch_index: int = -1
var _drag_start: Vector2 = Vector2.ZERO
var _drag_current: Vector2 = Vector2.ZERO


func setup(p_config: GameConfig) -> void:
	config = p_config


func load_planet(planet: Planet) -> void:
	loaded_planet = planet
	planet.global_position = global_position
	queue_redraw()


func is_aiming() -> bool:
	return _touch_index != -1


## Current launch velocity for the active drag (ZERO = would cancel).
func current_launch_velocity() -> Vector2:
	return OrbitPhysics.launch_velocity(
		_drag_start - _drag_current,
		config.min_drag_distance, config.max_drag_distance, config.max_launch_speed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and loaded_planet != null:
			_touch_index = touch.index
			_drag_start = touch.position
			_drag_current = touch.position
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_drag_current = touch.position
			_release()
			get_viewport().set_input_as_handled()
		elif touch.canceled and touch.index == _touch_index:
			# OS interrupted the touch (e.g. notification): cancel, never fire.
			_touch_index = -1
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_drag_current = drag.position
			queue_redraw()
			get_viewport().set_input_as_handled()


func _release() -> void:
	_touch_index = -1
	var velocity := current_launch_velocity()
	if velocity != Vector2.ZERO and loaded_planet != null:
		fire(velocity)
	queue_redraw()


## Launches the loaded planet. Public so tests can fire without real input.
func fire(velocity: Vector2) -> void:
	if loaded_planet == null:
		return
	var planet := loaded_planet
	loaded_planet = null
	planet.launch(velocity)
	planet_launched.emit(planet)
	queue_redraw()


func _draw() -> void:
	# Launch pad: a subtle ring where the next planet waits.
	draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 64, Color(COLOR_VIOLET, 0.25), 1.2, true)

	if not is_aiming() or loaded_planet == null:
		return

	var pull := _drag_start - _drag_current
	var power := OrbitPhysics.launch_power(pull.length(), config.max_drag_distance)
	var will_fire := pull.length() >= config.min_drag_distance

	# Power ring around the planet: fills clockwise as you pull further.
	var r := loaded_planet.radius + 10.0
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(COLOR_WHITE, 0.08), 2.0, true)
	if power > 0.0:
		draw_arc(Vector2.ZERO, r, -PI / 2.0, -PI / 2.0 + TAU * power, 64,
			Color(COLOR_AQUA, 0.85 if will_fire else 0.3), 2.5, true)

	if not will_fire:
		return

	# Dotted aim line in the launch direction, length proportional to power.
	var dir := pull.normalized()
	var length := 60.0 + 240.0 * power
	var dots := 14
	for i in dots:
		var t := float(i + 1) / dots
		var p := dir * (r + length * t)
		draw_circle(p, lerpf(3.2, 1.4, t), Color(COLOR_AQUA, lerpf(0.9, 0.1, t)), true, -1.0, true)
