class_name Planet
extends RigidBody2D
## A single planet.
##
## Lifecycle:
##   1. setup() is called before adding it to the scene (level + config).
##   2. It waits frozen at the launcher (no physics, no gravity).
##   3. launch() unfreezes it and gives it a velocity.
##   4. It is pulled toward the core (constant force) and speed-capped.
##   5. When merged, consume() removes it; PlanetField spawns the result.

signal launched(planet: Planet)

## Level 0 is the smallest planet. Merging creates a new planet one level up.
var level: int = 0
var radius: float = 20.0
var base_color: Color = Color.WHITE
var config: GameConfig
## Where gravity pulls toward: one position per core (Binary Star has two).
var gravity_centers: Array = [Vector2.ZERO]
## True once launched. Only active planets feel gravity.
var is_active: bool = false
## True once this planet has been used in a merge. A consumed planet is
## ignored by everything (part of the duplicate-merge guard).
var consumed: bool = false
## 0 = launched by the player, 1+ = created by a merge (see MergeRules).
var chain_depth: int = 0
## PlanetField time (seconds) when this planet was created.
var born_time: float = 0.0

## 0..1 progress toward game over caused by this planet (0 = safe).
var danger: float = 0.0
## Accessibility: draw the level number (1..12) on the planet.
var show_number: bool = false:
	set(value):
		if value != show_number:
			show_number = value
			if is_node_ready():
				_overlay.queue_redraw()

var _circle: CircleShape2D
var _was_in_danger: bool = false
var _grow_from: float = 0.0
var _grow_elapsed: float = INF

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _visual: Node2D = $Visual
@onready var _overlay: Node2D = $Visual/Overlay


func setup(p_config: GameConfig, p_level: int, p_gravity_centers: Array) -> void:
	config = p_config
	level = clampi(p_level, 0, config.level_count() - 1)
	radius = config.get_planet_radius(level)
	base_color = config.get_planet_color(level)
	gravity_centers = p_gravity_centers.duplicate()


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

	# Body: one shader quad (shared material -> batched). Rings and the danger
	# ring live on a child overlay that uses the default material.
	_visual.material = PlanetArt.material()
	_visual.draw.connect(func(): PlanetArt.draw_body(_visual, radius, base_color))
	_overlay.draw.connect(_draw_overlay)
	_visual.queue_redraw()
	_overlay.queue_redraw()


## Player launch from the launcher.
func launch(velocity: Vector2) -> void:
	activate(velocity)
	launched.emit(self)


## Starts physics + gravity. Used for launches and for merge results.
func activate(velocity: Vector2) -> void:
	freeze = false
	is_active = true
	linear_velocity = OrbitPhysics.clamp_velocity(velocity, config.max_planet_speed)
	_update_gravity_force()


## Makes a merge result grow from `from_radius` to its real size over
## config.merge_grow_time. Collision and visuals grow together.
func start_grow(from_radius: float) -> void:
	if config.merge_grow_time <= 0.0 or from_radius >= radius:
		return
	_grow_from = from_radius
	_grow_elapsed = 0.0
	_apply_grow(0.0)


## Removes this planet after a merge. Safe to call twice.
## fade = true: shrink and fade out softly instead of disappearing (Zen).
func consume(fade: bool = false) -> void:
	if consumed:
		return
	consumed = true
	is_active = false
	_collision.set_deferred("disabled", true)
	if not fade:
		hide()
		queue_free()
		return
	set_deferred("freeze", true)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_property(_visual, "scale", Vector2.ONE * 0.6, 0.6)
	tween.chain().tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if is_active and not freeze:
		_update_gravity_force()
	if _grow_elapsed < config.merge_grow_time:
		_grow_elapsed += delta
		_apply_grow(clampf(_grow_elapsed / config.merge_grow_time, 0.0, 1.0))


func _apply_grow(t: float) -> void:
	# Ease-out: fast at first, gentle at the end — feels like a soft "pop".
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var r := lerpf(_grow_from, radius, eased)
	_circle.radius = r
	_visual.scale = Vector2.ONE * (r / radius)


## Gravity is a CONSTANT FORCE that we only update when its direction or size
## changes noticeably (>1%).
## - Forces are integrated before contacts are solved, so a resting planet's pull
##   is cancelled in the same step and it reaches exactly zero velocity.
## - Setting a force wakes a sleeping body. Re-applying gravity every step (our
##   Phase 1 approach) therefore kept every planet awake forever. A resting
##   planet's gravity never changes, so now it can fall asleep and cost nothing.
func _update_gravity_force() -> void:
	var accel := OrbitPhysics.gravity_acceleration_multi(global_position, gravity_centers, config.gravity_strength)
	var desired := accel * mass
	var tolerance := desired.length() * 0.01
	if desired.distance_squared_to(constant_force) > tolerance * tolerance:
		constant_force = desired


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Speed cap: the single most important guard against "exploding" physics.
	# Only touch the velocity when needed (writing it would wake the body).
	var max_speed := config.max_planet_speed
	if state.linear_velocity.length_squared() > max_speed * max_speed:
		state.linear_velocity = OrbitPhysics.clamp_velocity(state.linear_velocity, max_speed)


func _process(_delta: float) -> void:
	# The body may roll, but the lighting should always come from the top-left,
	# so the visual layer cancels the body's rotation.
	# Only touch the transform when the body actually rotated.
	if not is_zero_approx(_visual.global_rotation):
		_visual.global_rotation = 0.0
	if danger > 0.0 or _was_in_danger:
		_was_in_danger = danger > 0.0
		_overlay.queue_redraw()  # Only the thin overlay, never the body.


# --- Drawing ------------------------------------------------------------------

func _draw_overlay() -> void:
	PlanetArt.draw_ring(_overlay, radius, base_color, level)
	if show_number:
		PlanetArt.draw_number(_overlay, radius, level)
	if danger > 0.0:
		# Pulsing warning ring: this planet is about to end the game.
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		_overlay.draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 40,
			Color(1, 1, 1, 0.35 + danger * (0.25 + 0.4 * pulse)), 3.0, true)
