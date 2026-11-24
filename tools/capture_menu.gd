extends SceneTree
## Screenshot of the menu. Usage: ... -s res://tools/capture_menu.gd -- <out.png> [tab] [sheet_mode_id]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var tab: String = args[1] if args.size() > 1 else "play"
	var sheet: String = args[2] if args.size() > 2 else ""
	var menu: Control = load("res://scenes/menu/menu.tscn").instantiate()
	menu.save_path = "user://capture_menu.cfg"
	root.add_child(menu)
	current_scene = menu
	for i in 40:
		await process_frame
	menu.show_tab(tab)
	if sheet != "":
		menu._open_sheet(Session.load_mode(sheet))
	for i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("CAPTURED menu ", tab, " ", sheet)
	quit()
