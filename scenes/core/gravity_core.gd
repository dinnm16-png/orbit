class_name GravityCore
extends StaticBody2D
## The gravitational core at the center of the screen.
##
## It is a StaticBody2D: it never moves, but planets collide with it and come
## to rest on it. The pull itself is applied by each Planet (see Planet and
## OrbitPhysics); the core only defines *where* the center is.
## It also draws the playable boundary ring (the future game-over line).

const COLOR_VIOLET := Color("#917AFF")
const COLOR_AQUA := Color("#52E5D5")
const COLOR_WHITE := Color("#F5F5FA")
const COLOR_SECONDARY := Color("#171B30")

var config: GameConfig
## 0..1: how close the game is to ending. Brightens and pulses the boundary.
var danger: float = 0.0

var _time: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _rings: Node2D = $Rings


func setup(p_config: GameConfig) -> void:
	config = p_config


func _ready() -> void:
	assert(config != null, "GravityCore.setup() must be called before adding to the tree")
	var circle := CircleShape2D.new()
	circle.radius = config.core_radius
	_collision.shape = circle

	var material := PhysicsMaterial.new()
	material.friction = 0.8
	material.bounce = 0.0
	physics_material_override = material

	_rings.draw.connect(_draw_rings)


func _process(delta: float) -> void:
	_time += delta
	# Slow rotation of the decorative rings; cheap because only the transform changes.
	_rings.rotation = _time * 0.12
	# Gentle "breathing" glow on the core body.
	queue_redraw()


func _draw() -> void:
	var r := config.core_radius
	var pulse := 0.5 + 0.5 * sin(_time * 1.6)

	# Boundary of the playable zone: faint filled disc + thin outline.
	var b := config.boundary_radius
	draw_circle(Vector2.ZERO, b, Color(COLOR_SECONDARY, 0.35), true, -1.0, true)
	draw_arc(Vector2.ZERO, b, 0.0, TAU, 160, Color(COLOR_VIOLET, 0.22), 1.5, true)
	if danger > 0.0:
		# Warning: the ring pulses toward white, faster as time runs out.
		var warn := 0.5 + 0.5 * sin(_time * (8.0 + 10.0 * danger))
		var ring := COLOR_VIOLET.lerp(COLOR_WHITE, danger)
		# Never fully fades: even at the pulse's low point the warning stays visible.
		draw_arc(Vector2.ZERO, b, 0.0, TAU, 160, Color(ring, 0.35 + danger * (0.3 + 0.35 * warn)), 3.0, true)

	# Core glow.
	for i in 8:
		var t := float(i) / 8.0
		var gr := r * (2.4 - t * 1.35)
		draw_circle(Vector2.ZERO, gr, Color(COLOR_VIOLET, 0.025 + t * 0.03 + pulse * 0.01), true, -1.0, true)

	# Core body: dark sphere with a bright aqua/violet heart.
	draw_circle(Vector2.ZERO, r, COLOR_SECONDARY, true, -1.0, true)
	for i in range(1, 7):
		var t := float(i) / 7.0
		var cr := r * (1.0 - t * 0.78)
		draw_circle(Vector2.ZERO, cr, COLOR_SECONDARY.lerp(COLOR_VIOLET, t * 0.9), true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 0.18, COLOR_WHITE.lerp(COLOR_AQUA, 0.3), true, -1.0, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(COLOR_AQUA, 0.55 + pulse * 0.2), 2.0, true)


func _draw_rings() -> void:
	var r := config.core_radius
	# Two thin elegant orbital rings with a gap, plus small "satellite" dots.
	_rings.draw_arc(Vector2.ZERO, r * 1.45, 0.2, TAU - 0.6, 96, Color(COLOR_AQUA, 0.35), 1.2, true)
	_rings.draw_arc(Vector2.ZERO, r * 1.85, PI, PI + TAU - 1.1, 96, Color(COLOR_VIOLET, 0.28), 1.0, true)
	_rings.draw_circle(Vector2(r * 1.45, 0).rotated(-0.2), 3.0, COLOR_AQUA, true, -1.0, true)
	_rings.draw_circle(Vector2(r * 1.85, 0).rotated(PI - 0.55), 2.2, COLOR_VIOLET, true, -1.0, true)
