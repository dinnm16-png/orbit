extends "res://tests/test_case.gd"
## Menu navigation, with real scene changes.

const MENU := preload("res://scenes/menu/menu.tscn")
const SAVE := "user://test_menu.cfg"


func _open_menu() -> Control:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var menu: Control = MENU.instantiate()
	menu.save_path = SAVE
	tree.root.add_child(menu)
	tree.current_scene = menu
	await tree.process_frame
	return menu


func _cleanup() -> void:
	tree.paused = false
	if tree.current_scene and is_instance_valid(tree.current_scene):
		tree.current_scene.queue_free()
	tree.current_scene = null
	await tree.process_frame
	Session.mode_id = "classic"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _cards(menu: Control) -> Array:
	var cards := []
	var stack := [menu]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is ModeCard:
			cards.append(n)
		stack.append_array(n.get_children())
	return cards


func test_menu_lists_every_mode() -> void:
	var menu := await _open_menu()
	var ids := []
	for c in _cards(menu):
		ids.append(c.mode.id)
	ids.sort()
	var expected: Array = Session.ORDER.duplicate()
	expected.sort()
	assert_eq(ids, expected, "one card per mode")
	await _cleanup()


func test_card_opens_sheet_and_play_starts_that_mode() -> void:
	var menu := await _open_menu()
	var blitz: ModeCard = null
	for c in _cards(menu):
		if c.mode.id == "blitz":
			blitz = c
	blitz.pressed.emit()
	await tree.process_frame
	assert_true(menu._sheet.is_open, "sheet opened")
	menu._sheet.play_requested.emit(blitz.mode)
	# The fade-out runs in real time (not frames), then the scene changes.
	await tree.create_timer(0.7).timeout
	await tree.process_frame
	assert_eq(Session.mode_id, "blitz", "mode remembered for the game scene")
	var scene := tree.current_scene
	assert_true(scene != null and scene.has_method("pause"), "game scene loaded")
	if scene and scene.has_method("pause"):
		assert_eq(scene.mode.id, "blitz", "game runs Blitz")
	await _cleanup()


func test_back_closes_sheet_then_returns_to_play_tab() -> void:
	var menu := await _open_menu()
	menu._open_sheet(Session.load_mode("zen"))
	await tree.process_frame
	menu._go_back()
	assert_false(menu._sheet.is_open, "back closes the sheet first")
	menu.show_tab("settings")
	menu._go_back()
	assert_eq(menu.current_tab, "play", "back returns to the Play tab")
	await _cleanup()


func test_settings_tab_saves_changes() -> void:
	var menu := await _open_menu()
	var page: SettingsPage = menu._pages["settings"].get_child(0)
	page._toggles["planet_numbers"].button_pressed = true
	var s := PlayerSettings.new(SAVE)
	s.load_settings()
	assert_true(s.planet_numbers, "toggle saved to disk")
	await _cleanup()


func test_game_menu_button_returns_to_menu() -> void:
	Session.mode_id = "zen"
	var game: Node = load("res://scenes/main/main.tscn").instantiate()
	game.save_path = SAVE
	tree.root.add_child(game)
	tree.current_scene = game
	await tree.process_frame
	game.pause()
	game.pause_menu.menu_requested.emit()
	# The fade-out runs in real time (not frames), then the scene changes.
	await tree.create_timer(0.7).timeout
	await tree.process_frame
	assert_false(tree.paused, "tree unpaused when leaving")
	assert_true(tree.current_scene is Control and tree.current_scene.has_method("show_tab"), "menu is the current scene")
	await _cleanup()
