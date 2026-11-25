extends SceneTree
## Bot plays a mode until it ends (or a cap) and reports length and score.
## Run with --fixed-fps 60 so physics runs faster than real time:
##   godot --headless --fixed-fps 60 --path . -s res://tools/balance.gd -- <mode> <games> [cap_launches]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode_id: String = args[0] if args.size() > 0 else "classic"
	var games: int = int(args[1]) if args.size() > 1 else 3
	var cap: int = int(args[2]) if args.size() > 2 else 400
	var results := []
	for g in games:
		var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
		main.mode = Session.load_mode(mode_id)
		main.random_seed = 1000 + g
		main.save_path = "user://balance_save.cfg"
		root.add_child(main)
		var rng := RandomNumberGenerator.new()
		rng.seed = 77 + g
		var frames := 0
		var launches := 0
		while main.state == main.State.PLAYING and launches < cap:
			if main.launcher.loaded_planet != null:
				main.launcher.fire(Vector2.from_angle(deg_to_rad(-90 + rng.randf_range(-40, 40))) * rng.randf_range(500, 1000))
				launches += 1
			for i in 40:
				await physics_frame
				frames += 1
				if main.state != main.State.PLAYING:
					break
			if main.state == main.State.PLAYING and main.launcher.loaded_planet == null and not main.mode.has_shot_limit():
				pass
		var ended: bool = main.state == main.State.GAME_OVER
		results.append({"secs": frames / 60.0, "launches": launches, "score": main.score, "ended": ended,
			"radius": main.arena_radius, "stage": main.stage})
		main.queue_free()
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://balance_save.cfg"))
	var total_secs := 0.0
	for r in results:
		total_secs += r["secs"]
		print("BAL %s  %5.0fs  %3d launches  score %6d  stage %2d  ended=%s" % [mode_id, r["secs"], r["launches"], r["score"], r["stage"], r["ended"]])
	print("BAL %s  average %.0fs" % [mode_id, total_secs / results.size()])
	quit()
