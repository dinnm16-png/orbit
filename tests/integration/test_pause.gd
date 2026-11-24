extends "res://tests/test_case.gd"

const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const SAVE := "user://test_pause.cfg"


func _spawn_main() -> Node2D:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var main: Node2D = MAIN_SCENE.instantiate()
	main.random_seed = 42
	main.save_path = SAVE
	tree.root.add_child(main)
	await wait_physics_frames(2)
	return main


func _cleanup(main: Node2D) -> void:
	tree.paused = false  # Never leak a paused tree into other tests.
	main.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_pause_freezes_simulation_and_resume_continues() -> void:
	var main := await _spawn_main()
	main.launcher.fire(Vector2(0, -700))
	var p: Planet = null
	for planet in main.field.get_active_planets():
		p = planet
	await wait_physics_frames(5)
	main.pause()
	assert_eq(main.state, main.State.PAUSED, "paused state")
	assert_true(tree.paused and main.pause_menu.visible, "tree paused, menu shown")
	var pos := p.global_position
	for i in 20:
		await tree.process_frame
	assert_vec_almost(p.global_position, pos, 0.01, "planet does not move while paused")
	main.resume()
	assert_false(tree.paused, "unpaused")
	await wait_physics_frames(10)
	assert_true(p.global_position.distance_to(pos) > 1.0, "planet moves again after resume")
	assert_true(main.launcher.enabled, "input re-enabled")
	await _cleanup(main)


func test_app_going_to_background_pauses() -> void:
	var main := await _spawn_main()
	main.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(main.state, main.State.PAUSED, "backgrounding the app pauses the game")
	await _cleanup(main)


func test_touch_on_pause_button_does_not_aim() -> void:
	var main := await _spawn_main()
	var at: Vector2 = main.pause_button.get_global_rect().get_center()
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = true
	e.position = at
	tree.root.push_input(e, true)
	await tree.process_frame
	assert_false(main.launcher.is_aiming(), "pause button swallows the touch")
	e = e.duplicate()
	e.pressed = false
	tree.root.push_input(e, true)
	await _cleanup(main)


func test_cannot_pause_after_game_over() -> void:
	var main := await _spawn_main()
	main._game_over()
	main.pause()
	assert_eq(main.state, main.State.GAME_OVER, "still game over")
	assert_false(main.pause_button.visible, "pause button hidden at game over")
	await _cleanup(main)


func test_settings_apply_to_game() -> void:
	var main := await _spawn_main()
	var p: Planet = main.launcher.loaded_planet
	main.settings.planet_numbers = true
	main.settings.sound = false
	main._apply_settings()
	assert_true(p.show_number, "existing planet shows its number")
	var q: Planet = main.field.spawn_planet(1, main.core.global_position + Vector2(0, -150), true)
	assert_true(q.show_number, "new planet shows its number")
	assert_false(main.feedback.sound_on, "sound switched off")
	await _cleanup(main)


func test_score_popups_render_below_menus() -> void:
	var main := await _spawn_main()
	main._add_score(10, Vector2(360, 600), 1)
	var popups: Node = main.get_node("HUD/Popups")
	assert_eq(popups.get_child_count(), 1, "popup created in its own layer")
	assert_true(popups.get_index() < main.pause_menu.get_index(), "popups below pause menu")
	assert_true(popups.get_index() < main.game_over_panel.get_index(), "popups below game over")
	await _cleanup(main)
