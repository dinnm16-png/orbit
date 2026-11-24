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

const PLANET_SCENE := preload("res://scenes/planet/planet.tscn")

var config: GameConfig
## Seconds of physics time since the field started (used for chain timing).
var time: float = 0.0
var gravity_center: Vector2 = Vector2.ZERO:
	set(value):
		gravity_center = value
		for planet in get_planets():
			planet.gravity_center = value


func setup(p_config: GameConfig) -> void:
	config = p_config


## Creates a planet. Inactive planets wait frozen (e.g. at the launcher).
func spawn_planet(level: int, at: Vector2, active: bool = false, velocity: Vector2 = Vector2.ZERO) -> Planet:
	var planet: Planet = PLANET_SCENE.instantiate()
	planet.setup(config, level, gravity_center)
	planet.position = at
	planet.born_time = time
	add_child(planet)
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


func _physics_process(delta: float) -> void:
	time += delta
	_despawn_escaped()
	_resolve_merges()


func _resolve_merges() -> void:
	var order := []
	var levels := {}
	var contacts := {}
	var by_id := {}
	for planet in get_active_planets():
		var id := planet.get_instance_id()
		order.append(id)
		levels[id] = planet.level
		by_id[id] = planet
		var touching := []
		for body in planet.get_colliding_bodies():
			if body is Planet:
				touching.append(body.get_instance_id())
		contacts[id] = touching

	var pairs := MergeRules.find_pairs(order, levels, contacts,
		config.level_count() - 1, config.max_level_pairs_vanish)
	for pair in pairs:
		_merge(by_id[pair[0]], by_id[pair[1]])


func _merge(a: Planet, b: Planet) -> void:
	var depth := MergeRules.next_chain_depth(
		a.chain_depth, time - a.born_time, b.chain_depth, time - b.born_time, config.chain_window)
	var pos := MergeRules.center_of_mass(a.global_position, a.mass, b.global_position, b.mass)
	var vel := MergeRules.merged_velocity(
		a.linear_velocity, a.mass, b.linear_velocity, b.mass, config.merge_velocity_keep)
	var outcome := MergeRules.outcome(a.level, b.level, config.level_count() - 1, config.max_level_pairs_vanish)
	var level := a.level
	var old_radius := a.radius

	_wake_neighbours(a)
	_wake_neighbours(b)
	a.consume()
	b.consume()

	if outcome == MergeRules.Outcome.VANISH:
		planets_vanished.emit(pos, level, depth)
		return

	var merged := spawn_planet(level + 1, to_local(pos), true, vel)
	merged.chain_depth = depth
	merged.start_grow(old_radius)
	planets_merged.emit(merged, depth)


## Planets resting on a removed planet must not stay asleep floating in mid-air.
func _wake_neighbours(planet: Planet) -> void:
	for body in planet.get_colliding_bodies():
		if body is RigidBody2D:
			body.sleeping = false


func _despawn_escaped() -> void:
	var limit_sq := config.despawn_distance * config.despawn_distance
	for planet in get_active_planets():
		if planet.global_position.distance_squared_to(gravity_center) > limit_sq:
			planet.consume()
