class_name PlanetField
extends Node2D
## Owns every planet in play: spawning, merging, and removing escaped planets.
##
## Merge flow (once per physics step, in ONE place):
##   1. Collect active planets and who each one is touching.
##   2. MergeRules.find_pairs() picks pairs — each planet at most once.
##   3. Each pair is consumed and replaced by a planet one level up.
## Newly merged planets are checked again on the next step, which is what
## makes chain reactions happen naturally.

signal planets_merged(new_planet: Planet, chain_depth: int)
signal planets_vanished(position: Vector2, level: int, chain_depth: int)
## Special-planet effects: "downgrade", "shatter", "swallow".
signal special_event(event: String, position: Vector2, color: Color)
## A planet landed hard somewhere (dust + thud).
signal planet_impact(position: Vector2, color: Color, speed: float)

const PLANET_SCENE := preload("res://scenes/planet/planet.tscn")

var config: GameConfig
## Seconds of physics time since the field started (used for chain timing).
var time: float = 0.0
## One entry per core. Setting it updates every planet.
var gravity_centers: Array = [Vector2.ZERO]:
	set(value):
		gravity_centers = value.duplicate()
		for planet in get_planets():
			planet.gravity_centers = gravity_centers.duplicate()
			planet.sleeping = false  # Sleeping planets must feel the new centers.
## Center of the arena (escape distance is measured from here).
var arena_center: Vector2 = Vector2.ZERO


## Accessibility setting, applied to existing and future planets.
var show_numbers: bool = false:
	set(value):
		show_numbers = value
		for planet in get_planets():
			planet.show_number = value


func setup(p_config: GameConfig) -> void:
	config = p_config


## Creates a planet. Inactive planets wait frozen (e.g. at the launcher).
func spawn_planet(level: int, at: Vector2, active: bool = false, velocity: Vector2 = Vector2.ZERO,
		kind: int = PlanetKind.Kind.NORMAL) -> Planet:
	var planet: Planet = PLANET_SCENE.instantiate()
	planet.setup(config, level, gravity_centers, kind)
	planet.position = at
	planet.born_time = time
	planet.show_number = show_numbers
	add_child(planet)
	planet.impact.connect(func(p: Planet, speed: float): planet_impact.emit(p.global_position, p.base_color, speed))
	if active:
		planet.activate(velocity)
	return planet


## All planets that are not consumed (includes the one waiting at the launcher).
func get_planets() -> Array[Planet]:
	var result: Array[Planet] = []
	for child in get_children():
		if child is Planet and not child.consumed:
			result.append(child)
	return result


## Planets currently in play (launched or created by merges).
func get_active_planets() -> Array[Planet]:
	var result: Array[Planet] = []
	for planet in get_planets():
		if planet.is_active:
			result.append(planet)
	return result


## Stops the simulation in place (game over): no more movement or merges.
func freeze_all() -> void:
	set_physics_process(false)
	for planet in get_planets():
		planet.set_deferred("freeze", true)


func _physics_process(delta: float) -> void:
	time += delta
	_despawn_escaped()
	_resolve_merges()


func _resolve_merges() -> void:
	var order := []
	var levels := {}
	var kinds := {}
	var contacts := {}
	var by_id := {}
	for planet in get_active_planets():
		var id := planet.get_instance_id()
		order.append(id)
		levels[id] = planet.level
		kinds[id] = planet.kind
		by_id[id] = planet
		var touching := []
		for body in planet.get_colliding_bodies():
			if body is Planet:
				touching.append(body.get_instance_id())
		contacts[id] = touching

	# One resolver for every interaction (merges AND special planets), so the
	# rule "each planet takes part in at most one interaction per step" holds.
	var found := MergeRules.find_interactions(order, levels, kinds, contacts,
		config.level_count() - 1, config.max_level_pairs_vanish)
	for it in found:
		var a: Planet = by_id[it["a"]]
		var b: Planet = by_id[it["b"]]
		var actor := a if it["actor"] == 0 else b
		var other := b if it["actor"] == 0 else a
		match it["action"]:
			MergeRules.Action.MERGE:
				_merge(a, b, MergeRules.merge_result_level(a.kind, a.level, b.kind, b.level))
			MergeRules.Action.VANISH:
				_vanish(a, b)
			MergeRules.Action.DOWNGRADE:
				_downgrade(actor, other)
			MergeRules.Action.SWALLOW:
				_swallow(actor, other)
			MergeRules.Action.DESTROY_BOTH:
				_destroy_both(a, b)


func _merge(a: Planet, b: Planet, new_level: int) -> void:
	var depth := MergeRules.next_chain_depth(
		a.chain_depth, time - a.born_time, b.chain_depth, time - b.born_time, config.chain_window)
	var pos := MergeRules.center_of_mass(a.global_position, a.mass, b.global_position, b.mass)
	var vel := MergeRules.merged_velocity(
		a.linear_velocity, a.mass, b.linear_velocity, b.mass, config.merge_velocity_keep)
	var old_radius := minf(a.radius, b.radius) if a.kind == PlanetKind.Kind.WILDCARD or b.kind == PlanetKind.Kind.WILDCARD else a.radius
	_remove(a, b)
	var merged := spawn_planet(mini(new_level, config.level_count() - 1), to_local(pos), true, vel)
	merged.chain_depth = depth
	merged.start_grow(old_radius)
	planets_merged.emit(merged, depth)


func _vanish(a: Planet, b: Planet) -> void:
	var depth := MergeRules.next_chain_depth(
		a.chain_depth, time - a.born_time, b.chain_depth, time - b.born_time, config.chain_window)
	var pos := MergeRules.center_of_mass(a.global_position, a.mass, b.global_position, b.mass)
	var level := maxi(a.level, b.level)
	_remove(a, b)
	planets_vanished.emit(pos, level, depth)


## Comet hits a planet: the planet drops one level (level 0 shatters).
func _downgrade(comet: Planet, target: Planet) -> void:
	var pos := target.global_position
	var vel := target.linear_velocity
	var color := target.base_color
	var level := target.level
	var kind := target.kind
	_remove(comet, target)
	if level <= 0:
		special_event.emit("shatter", pos, color)
		return
	var smaller := spawn_planet(level - 1, to_local(pos), true, vel * 0.5, kind)
	smaller.born_time = time - config.chain_window  # Not part of a chain.
	special_event.emit("downgrade", pos, config.get_planet_color(level - 1))


## Black hole touches a planet: both disappear.
func _swallow(hole: Planet, target: Planet) -> void:
	var pos := hole.global_position
	_remove(hole, target)
	special_event.emit("swallow", pos, UIStyle.VIOLET)


func _destroy_both(a: Planet, b: Planet) -> void:
	var pos := (a.global_position + b.global_position) * 0.5
	var color := a.base_color
	_remove(a, b)
	special_event.emit("shatter", pos, color)


func _remove(a: Planet, b: Planet) -> void:
	_wake_neighbours(a)
	_wake_neighbours(b)
	a.consume()
	b.consume()


## Planets resting on a removed planet must not stay asleep floating in mid-air.
func _wake_neighbours(planet: Planet) -> void:
	for body in planet.get_colliding_bodies():
		if body is RigidBody2D:
			body.sleeping = false


func _despawn_escaped() -> void:
	var limit_sq := config.despawn_distance * config.despawn_distance
	for planet in get_active_planets():
		if planet.global_position.distance_squared_to(arena_center) > limit_sq:
			planet.consume()
