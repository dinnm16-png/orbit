extends "res://tests/test_case.gd"
## Special planets, hold, sliding launcher, gravity pulse — real physics.

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SAVE := "user://test_mechanics.cfg"
const K := PlanetKind.Kind


func _spawn(mode_id: String = "classic", tweak: Callable = Callable()) -> Node2D:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var main: Node2D = MAIN_SCENE.instantiate()
	main.mode = Session.load_mode(mode_id).duplicate()
	main.random_seed = 42
	main.save_path = SAVE
	if tweak.is_valid():
		tweak.call(main)
	tree.root.add_child(main)
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node2D) -> void:
	tree.paused = false
	main.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _place(main: Node2D, level: int, offset: Vector2, kind: int = K.NORMAL) -> Planet:
	return main.field.spawn_planet(level, main.arena_center + offset, true, Vector2.ZERO, kind)


func _active(main: Node2D) -> Array:
	var r := []
	for p in main.field.get_active_planets():
		r.append([p.level, p.kind])
	r.sort()
	return r


func test_wildcard_upgrades_the_planet_it_touches() -> void:
	var main := await _spawn()
	_place(main, 3, Vector2(-40, -110))
	_place(main, 1, Vector2(12, -110), K.WILDCARD)
	await wait_physics_frames(30)
	assert_eq(_active(main), [[4, K.NORMAL]], "level 3 + wildcard -> level 4")
	assert_true(main.score > 0, "merge scored")
	await _cleanup(main)


func test_comet_knocks_planet_down_one_level() -> void:
	var main := await _spawn()
	_place(main, 3, Vector2(0, -120))
	_place(main, 0, Vector2(0, -175), K.COMET)
	await wait_physics_frames(30)
	assert_eq(_active(main), [[2, K.NORMAL]], "level 3 -> level 2, comet gone")
	await _cleanup(main)


func test_comet_shatters_smallest_planet() -> void:
	var main := await _spawn()
	_place(main, 0, Vector2(0, -90))
	_place(main, 0, Vector2(0, -125), K.COMET)
	await wait_physics_frames(30)
	assert_eq(_active(main), [], "both gone")
	await _cleanup(main)


func test_black_hole_swallows_a_big_planet() -> void:
	var main := await _spawn()
	var events := []
	main.field.special_event.connect(func(e, _p, _c): events.append(e))
	_place(main, 6, Vector2(0, -140))
	_place(main, 1, Vector2(0, -230), K.BLACK_HOLE)
	await wait_physics_frames(40)
	assert_eq(_active(main), [], "planet swallowed, hole collapsed")
	assert_eq(events, ["swallow"], "swallow event")
	await _cleanup(main)


func test_anchor_is_heavy_and_merges_normally() -> void:
	var main := await _spawn()
	var anchor := _place(main, 2, Vector2(-31, -110), K.ANCHOR)
	var normal := _place(main, 2, Vector2(200, 300))
	assert_almost(anchor.mass, normal.mass * main.config.anchor_mass_multiplier, 0.01, "10x heavier")
	normal.global_position = main.arena_center + Vector2(31, -110)
	await wait_physics_frames(30)
	assert_eq(_active(main), [[3, K.NORMAL]], "anchor + same level merge")
	await _cleanup(main)


func test_specials_roll_only_when_mode_allows() -> void:
	var main := await _spawn("classic", func(m):
		var cfg: GameConfig = m.config.duplicate()
		cfg.special_chance = 1.0
		cfg.special_min_launches = 0
		m.config = cfg)
	assert_true(main.next_kind != K.NORMAL, "special queued")
	await _cleanup(main)
	main = await _spawn("classic", func(m):
		var cfg: GameConfig = m.config.duplicate()
		cfg.special_chance = 1.0
		cfg.special_min_launches = 0
		m.config = cfg
		m.mode.specials = false)
	for i in 20:
		main._roll_next()
		assert_eq(main.next_kind, K.NORMAL, "mode without specials")
	await _cleanup(main)


func test_hold_stores_then_swaps_once_per_launch() -> void:
	var main := await _spawn()
	var first: int = main.launcher.loaded_planet.level
	var queued: int = main.next_level
	main.hold()
	assert_eq(main.held["level"], first, "first planet held")
	assert_eq(main.launcher.loaded_planet.level, queued, "next planet loaded")
	var loaded_before: Planet = main.launcher.loaded_planet
	main.hold()
	assert_eq(main.launcher.loaded_planet, loaded_before, "second hold in the same turn ignored")
	main.launcher.fire(Vector2(0, -650))
	await wait_physics_frames(int(main.config.reload_delay * 60) + 5)
	var now: int = main.launcher.loaded_planet.level
	main.hold()
	assert_eq(main.launcher.loaded_planet.level, first, "swap brings the held planet back")
	assert_eq(main.held["level"], now, "and holds the other one")
	await _cleanup(main)


func test_hold_does_not_cost_a_shot() -> void:
	var main := await _spawn("limited")
	var before: int = main.shots_left
	main.hold()
	assert_eq(main.shots_left, before, "shots unchanged")
	await _cleanup(main)


func _touch(pressed: bool, pos: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = pos
	tree.root.push_input(e, true)


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = pos
	tree.root.push_input(e, true)


func test_sideways_drag_on_launcher_slides_it_without_firing() -> void:
	var main := await _spawn()
	var start: Vector2 = main.launcher.global_position
	var planet: Planet = main.launcher.loaded_planet
	_touch(true, start)
	_drag(start + Vector2(30, 2))
	_drag(start + Vector2(90, 4))
	_touch(false, start + Vector2(90, 4))
	await wait_physics_frames(2)
	assert_almost(main.launcher.global_position.x, start.x + 90.0, 0.5, "launcher moved")
	assert_vec_almost(planet.global_position, main.launcher.global_position, 0.5, "planet moved with it")
	assert_false(planet.is_active, "sliding never launches")
	_touch(true, main.launcher.global_position)
	_drag(main.launcher.global_position + Vector2(900, 0))
	_touch(false, main.launcher.global_position)
	await wait_physics_frames(1)
	assert_almost(main.launcher.global_position.x, main.launcher.track_max_x, 0.5, "clamped to the track")
	await _cleanup(main)


func test_downward_drag_from_launcher_still_aims() -> void:
	var main := await _spawn()
	var start: Vector2 = main.launcher.global_position
	var planet: Planet = main.launcher.loaded_planet
	_touch(true, start)
	_drag(start + Vector2(10, 60))
	_drag(start + Vector2(20, 180))
	_touch(false, start + Vector2(20, 180))
	await wait_physics_frames(2)
	assert_true(planet.is_active, "launched")
	assert_true(planet.linear_velocity.y < -100.0, "upward")
	await _cleanup(main)


func test_slide_disabled_by_setting() -> void:
	var main := await _spawn()
	main.settings.movable_launcher = false
	main._apply_settings()
	var start: Vector2 = main.launcher.global_position
	_touch(true, start)
	_drag(start + Vector2(90, 0))
	_touch(false, start + Vector2(90, 0))
	await wait_physics_frames(2)
	assert_almost(main.launcher.global_position.x, start.x, 0.01, "launcher fixed when disabled")
	await _cleanup(main)


func test_pulse_charges_and_pushes_inward() -> void:
	var main := await _spawn()
	var p := _place(main, 2, Vector2(0, -200))
	await wait_physics_frames(1)
	main.pulse()
	assert_eq(main.pulse_charge, 0, "pulse unusable before charged")
	main.pulse_charge = main.config.pulse_merges_needed
	var v_before := p.linear_velocity
	main.pulse()
	assert_eq(main.pulse_charge, 0, "charge spent")
	await wait_physics_frames(1)  # Impulses apply on the next physics step.
	var gained: Vector2 = p.linear_velocity - v_before
	assert_true(gained.y > 300.0, "pushed toward the core (gained %s)" % gained)
	await _cleanup(main)


func test_merges_charge_the_pulse() -> void:
	var main := await _spawn()
	_place(main, 0, Vector2(-17, -100))
	_place(main, 0, Vector2(17, -100))
	await wait_physics_frames(20)
	assert_eq(main.pulse_charge, 1, "one merge = one charge")
	assert_almost(main.pulse_button.charge, 1.0 / main.config.pulse_merges_needed, 0.001, "button shows progress")
	await _cleanup(main)
