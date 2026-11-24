class_name Planet
extends RigidBody2D
## A single planet.
##
## Lifecycle:
##   1. setup() is called before adding it to the scene (level + config).
##   2. It waits frozen at the launcher (no physics, no gravity).
##   3. launch() unfreezes it and gives it a velocity.
##   4. Every physics step it is pulled toward the core and speed-capped.
##   5. When merged, consume() removes it; PlanetField spawns the result.

signal launched(planet: Planet)

## Level 0 is the smallest planet. Merging creates a new planet one level up.
var level: int = 0
var radius: float = 20.0
var base_color: Color = Color.WHITE
var config: GameConfig
## Where gravity pulls toward (the core's global position).
var gravity_center: Vector2 = Vector2.ZERO
## True once launched. Only active planets feel gravity.
var is_active: bool = false
## True once this planet has been used in a merge. A consumed planet is
## ignored by everything (part of the duplicate-merge guard).
var consumed: bool = false
## 0 = launched by the player, 1+ = created by a merge (see MergeRules).
var chain_depth: int = 0
## PlanetField time (seconds) when this planet was created.
var born_time: float = 0.0

var _circle: CircleShape2D
var _grow_from: float = 0.0
var _grow_elapsed: float = INF

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _visual: Node2D = $Visual


func setup(p_config: GameConfig, p_level: int, p_gravity_center: Vector2) -> void:
	config = p_config
	level = clampi(p_level, 0, config.level_count() - 1)
	radius = config.get_planet_radius(level)
	base_color = config.get_planet_color(level)
	gravity_center = p_gravity_center


func _ready() -> void:
	assert(config != null, "Planet.setup() must be called before adding to the tree")

	# Each planet gets its own shape instance, because radius differs per level.
	_circle = CircleShape2D.new()
	_circle.radius = radius
	_collision.shape = _circle

	# Report contacts so PlanetField can ask "who am I touching?" each step.
	contact_monitor = true
	max_contacts_reported = 8

	var material := PhysicsMaterial.new()
	material.friction = config.planet_friction
	material.bounce = config.planet_bounce
	physics_material_override = material

	mass = OrbitPhysics.mass_for_radius(radius, config.mass_reference_radius)
	gravity_scale = 0.0  # We apply our own gravity toward the core.
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = config.planet_linear_damp
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = config.planet_angular_damp
	# Continuous collision detection: fast planets won't tunnel through others.
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	# Wait at the launcher without moving until launched.
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true

	_visual.draw.connect(_draw_visual)
	_visual.queue_redraw()


## Player launch from the launcher.
func launch(velocity: Vector2) -> void:
	activate(velocity)
	launched.emit(self)


## Starts physics + gravity. Used for launches and for merge results.
func activate(velocity: Vector2) -> void:
	freeze = false
	is_active = true
	linear_velocity = OrbitPhysics.clamp_velocity(velocity, config.max_planet_speed)


## Makes a merge result grow from `from_radius` to its real size over
## config.merge_grow_time. Collision and visuals grow together.
func start_grow(from_radius: float) -> void:
	if config.merge_grow_time <= 0.0 or from_radius >= radius:
		return
	_grow_from = from_radius
	_grow_elapsed = 0.0
	_apply_grow(0.0)


## Removes this planet after a merge. Safe to call twice.
func consume() -> void:
	if consumed:
		return
	consumed = true
	is_active = false
	_collision.set_deferred("disabled", true)
	hide()
	queue_free()


func _physics_process(delta: float) -> void:
	if _grow_elapsed < config.merge_grow_time:
		_grow_elapsed += delta
		_apply_grow(clampf(_grow_elapsed / config.merge_grow_time, 0.0, 1.0))


func _apply_grow(t: float) -> void:
	# Ease-out: fast at first, gentle at the end — feels like a soft "pop".
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var r := lerpf(_grow_from, radius, eased)
	_circle.radius = r
	_visual.scale = Vector2.ONE * (r / radius)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not is_active:
		return
	var accel := OrbitPhysics.gravity_acceleration(
		state.transform.origin, gravity_center, config.gravity_strength)
	# Apply gravity as a FORCE (not by editing velocity). Godot integrates
	# forces before solving contacts, so a planet resting on the core gets its
	# pull cancelled in the same step, reaches zero velocity and can sleep.
	# Editing velocity here instead left resting planets buzzing forever.
	state.apply_central_force(accel * mass)
	# Speed cap: the single most important guard against "exploding" physics.
	state.linear_velocity = OrbitPhysics.clamp_velocity(state.linear_velocity, config.max_planet_speed)


func _process(_delta: float) -> void:
	# The body may roll, but the lighting should always come from the top-left,
	# so the visual layer cancels the body's rotation.
	_visual.global_rotation = 0.0


# --- Procedural drawing -------------------------------------------------------

const LIGHT_DIR := Vector2(-0.6, -0.8)


func _draw_visual() -> void:
	var c := base_color

	# Soft outer glow: stacked translucent circles approximate a radial gradient.
	var glow_steps := 6
	for i in glow_steps:
		var t := float(i) / glow_steps
		var r := radius * (1.65 - t * 0.6)
		_visual.draw_circle(Vector2.ZERO, r, Color(c, 0.035 + t * 0.02), true, -1.0, true)

	# Body: dark base, then lighter discs shifted toward the light = 3D shading.
	var dark := c.darkened(0.55)
	_visual.draw_circle(Vector2.ZERO, radius, dark, true, -1.0, true)
	var shade_steps := 7
	for i in range(1, shade_steps):
		var t := float(i) / shade_steps
		var r := radius * (1.0 - t * 0.62)
		var offset := LIGHT_DIR * radius * t * 0.38
		_visual.draw_circle(offset, r, dark.lerp(c.lightened(0.18), t), true, -1.0, true)

	# Rim light on the lit side and a thin full outline for crispness.
	_visual.draw_arc(Vector2.ZERO, radius - 0.75, 0.0, TAU, 48, Color(c.lightened(0.5), 0.35), 1.5, true)
	_visual.draw_arc(Vector2.ZERO, radius - 1.0, PI * 1.05, PI * 1.6, 24, Color(1, 1, 1, 0.45), 2.0, true)

	# Larger planets get an elegant tilted orbital ring.
	if (level >= 3 and level % 3 == 0) or level >= 9:
		_draw_ring(c)


func _draw_ring(c: Color) -> void:
	var points := PackedVector2Array()
	var segments := 64
	var rx := radius * 1.55
	var ry := radius * 0.38
	var tilt := -0.35
	for i in segments + 1:
		var a := TAU * i / segments
		points.append(Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
	_visual.draw_polyline(points, Color(c.lightened(0.35), 0.55), 1.5, true)
