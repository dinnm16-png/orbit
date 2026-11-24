extends SceneTree
## Proves puzzles are solvable: a bot plays each one several times.
##   godot --headless --fixed-fps 60 --path . -s res://tools/puzzle_check.gd -- [first] [last] [aimed] [random]
## "aimed" attempts pick a sensible target and use OrbitPhysics.predict_path to
## choose the shot; "random" attempts fire randomly. Prints wins and best stars.

const K := PlanetKind.Kind


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var first: int = int(args[0]) if args.size() > 0 else 1
	var last: int = int(args[1]) if args.size() > 1 else PuzzleCatalog.count()
	var aimed: int = int(args[2]) if args.size() > 2 else 6
	var random: int = int(args[3]) if args.size() > 3 else 4
	var unsolved := []
	for n in range(first, last + 1):
		var wins := 0
		var best := 0
		var aimed_wins := 0
		for a in aimed + random:
			var r: Array = await _attempt(n, a < aimed, 100 + a)
			if r[0]:
				wins += 1
				best = maxi(best, r[1])
				if a < aimed:
					aimed_wins += 1
		print("PUZ %2d  goal %-12s  wins %2d/%2d (aimed %d/%d, random %d/%d)  best %s" % [n,
			Progress.PLANET_NAMES[PuzzleCatalog.get_level(n)["goal"]], wins, aimed + random, aimed_wins, aimed, wins - aimed_wins, random,
			"★".repeat(best) if best > 0 else "—"])
		if wins == 0:
			unsolved.append(n)
	print("PUZ UNSOLVED: ", unsolved)
	quit()


func _attempt(n: int, aimed: bool, seed: int) -> Array:
	var main: Node2D = load("res://scenes/main/main.tscn").instantiate()
	main.mode = Session.load_mode("puzzle")
	main.puzzle_number = n
	main.random_seed = seed
	main.save_path = "user://puzzle_check.cfg"
	root.add_child(main)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 60:  # let the setup settle
		await physics_frame
	var frames := 0
	while main.state == main.State.PLAYING and frames < 60 * 90:
		if main.launcher.loaded_planet != null:
			main.launcher.fire(_choose_shot(main, rng) if aimed else _random_shot(main, rng))
		for i in 50:
			await physics_frame
			frames += 1
			if main.state != main.State.PLAYING:
				break
	var won: bool = main.state == main.State.GAME_OVER and main.end_reason == main.EndReason.PUZZLE_WIN
	var stars: int = PuzzleCatalog.stars(main.shots_left, main.mode.shot_limit) if won else 0
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://puzzle_check.cfg"))
	return [won, stars]


func _random_shot(main: Node2D, rng: RandomNumberGenerator) -> Vector2:
	return Vector2.from_angle(deg_to_rad(-90 + rng.randf_range(-45, 45))) * rng.randf_range(450, 1000)


func _choose_shot(main: Node2D, rng: RandomNumberGenerator) -> Vector2:
	var target = _target(main)
	if target == null:
		return _random_shot(main, rng)
	var cfg: GameConfig = main.config
	var start: Vector2 = main.launcher.global_position
	var best_v := Vector2.ZERO
	var best_d := INF
	for a in range(-70, 71, 5):
		for pi in range(3, 11):
			var v := Vector2.from_angle(deg_to_rad(-90 + a)) * cfg.max_launch_speed * pi / 10.0
			var path := OrbitPhysics.predict_path(start, v, main.field.gravity_centers, cfg.gravity_strength,
				cfg.planet_linear_damp, cfg.max_planet_speed, 1.0 / 60.0, 120, cfg.core_radius)
			for p in path:
				var d: float = p.distance_to(target.global_position)
				if d < best_d:
					best_d = d
					best_v = v
	return best_v.rotated(deg_to_rad(rng.randf_range(-2.0, 2.0)))


## Which planet to aim at, by what is loaded.
func _target(main: Node2D):
	var loaded: Planet = main.launcher.loaded_planet
	var goal: int = main.puzzle["goal"]
	var planets: Array = main.field.get_active_planets()
	var by_level := {}
	for p in planets:
		if p.kind == K.NORMAL or p.kind == K.ANCHOR:
			by_level[p.level] = by_level.get(p.level, 0) + 1
	var best = null
	match loaded.kind:
		K.WILDCARD:
			for p in planets:
				if (p.kind == K.NORMAL or p.kind == K.ANCHOR) and p.level < goal and (best == null or p.level > best.level):
					best = p
		K.COMET:
			# Knock down a planet so it matches a neighbour level.
			for p in planets:
				if p.level > 0 and by_level.get(p.level - 1, 0) > 0 and by_level.get(p.level, 0) == 1 and (best == null or p.level > best.level):
					best = p
		K.BLACK_HOLE:
			# Remove the biggest planet that is above the goal (a blocker).
			for p in planets:
				if p.level >= goal and (best == null or p.level > best.level):
					best = p
		_:
			for p in planets:
				if p.level == loaded.level and (p.kind == K.NORMAL or p.kind == K.ANCHOR):
					best = p
					break
	return best
