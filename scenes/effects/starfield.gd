class_name Starfield
extends Node2D
## Deep background: a slowly turning field of stars. It turns faster as the
## Orbit stage rises, so higher scores literally feel faster. Drawn once;
## only the node's rotation changes per frame.

var speed: float = 0.012          # radians per second (Main raises it per stage)
var _boost: float = 0.0           # short "warp" after a stage up


func _ready() -> void:
	z_index = -10


func warp() -> void:
	_boost = 0.6


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	_boost = maxf(_boost - real * 0.5, 0.0)
	rotation += (speed + _boost) * delta


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in 170:
		var r := sqrt(rng.randf()) * 1050.0
		var p := Vector2.from_angle(rng.randf() * TAU) * r
		var z := rng.randf()
		# Not antialiased on purpose: antialiased circles are not batched (one
		# draw call each, ~340 calls measured); 1-2 px stars look the same.
		draw_rect(Rect2(p - Vector2.ONE * (0.6 + z), Vector2.ONE * (1.2 + z * 2.0)), Color(UIStyle.WHITE, 0.06 + z * 0.3))
