extends SceneTree
## Plays a mode with a simple bot and saves a screenshot. For visual checks.
## Usage: godot --path . --resolution 720x1280 -s res://tools/capture.gd -- <mode> <out.png> [launches] [seed]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode_id: String = args[0] if args.size() > 0 else "classic"
	var out: String = args[1] if args.size() > 1 else "user://capture.png"
	var launches: int = int(args[2]) if args.size() > 2 else 12
	var seed: int = int(args[3]) if args.size() > 3 else 2026
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	main.mode = Session.load_mode(mode_id)
	main.random_seed = seed
	main.save_path = "user://capture_save.cfg"
	root.add_child(main)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for n in launches:
		var waited := 0
		while main.launcher.loaded_planet == null and waited < 120:
			await physics_frame
			waited += 1
		if main.state != main.State.PLAYING or main.launcher.loaded_planet == null:
			break
		main.launcher.fire(Vector2.from_angle(deg_to_rad(-90 + rng.randf_range(-35, 35))) * rng.randf_range(550, 900))
		for i in 40:
			await physics_frame
	for i in 30:
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("CAPTURED ", mode_id, " score=", main.score, " state=", main.state)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_save.cfg"))
	quit()
