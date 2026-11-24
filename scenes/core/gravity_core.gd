class_name GravityCore
extends StaticBody2D
## The gravitational core at the center of the screen.
##
## It is a StaticBody2D: it never moves, but planets collide with it and come
## to rest on it. The pull itself is applied by each Planet (see Planet and
## OrbitPhysics); the core only defines *where* the center is.
## (The boundary ring is drawn by ArenaRing.)
##
## Performance: each visual part is its own child CanvasItem whose drawing is
## cached by Godot. Animation only changes cheap properties (rotation,
## modulate); nothing is re-drawn every frame.


var config: GameConfig

var _time: float = 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _glow: Node2D = $Glow
@onready var _body: Node2D = $Body
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

	_glow.draw.connect(_draw_glow)
	_body.draw.connect(_draw_body)
	_rings.draw.connect(_draw_rings)


func _process(delta: float) -> void:
	_time += delta
	# Slow rotation of the decorative rings; cheap because only the transform changes.
	_rings.rotation = _time * 0.12
	# Gentle "breathing" glow: only the layer's opacity changes, no redraw.
	_glow.modulate.a = 0.8 + 0.2 * sin(_time * 1.6)


func _draw_glow() -> void:
	var r := config.core_radius
	for i in 6:
		var t := float(i) / 6.0
		_glow.draw_circle(Vector2.ZERO, r * (2.4 - t * 1.35), Color(UIStyle.VIOLET, 0.035 + t * 0.035), true, -1.0, true)


func _draw_body() -> void:
	var r := config.core_radius
	_body.draw_circle(Vector2.ZERO, r, UIStyle.SECONDARY, true, -1.0, true)
	for i in range(1, 7):
		var t := float(i) / 7.0
		_body.draw_circle(Vector2.ZERO, r * (1.0 - t * 0.78), UIStyle.SECONDARY.lerp(UIStyle.VIOLET, t * 0.9), true, -1.0, true)
	_body.draw_circle(Vector2.ZERO, r * 0.18, UIStyle.WHITE.lerp(UIStyle.AQUA, 0.3), true, -1.0, true)
	_body.draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(UIStyle.AQUA, 0.65), 2.0, true)


func _draw_rings() -> void:
	var r := config.core_radius
	# Two thin elegant orbital rings with a gap, plus small "satellite" dots.
	_rings.draw_arc(Vector2.ZERO, r * 1.45, 0.2, TAU - 0.6, 96, Color(UIStyle.AQUA, 0.35), 1.2, true)
	_rings.draw_arc(Vector2.ZERO, r * 1.85, PI, PI + TAU - 1.1, 96, Color(UIStyle.VIOLET, 0.28), 1.0, true)
	_rings.draw_circle(Vector2(r * 1.45, 0).rotated(-0.2), 3.0, UIStyle.AQUA, true, -1.0, true)
	_rings.draw_circle(Vector2(r * 1.85, 0).rotated(PI - 0.55), 2.2, UIStyle.VIOLET, true, -1.0, true)
