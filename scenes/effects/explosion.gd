class_name Explosion
extends Node2D
## Merge explosion: a bright flash plus glowing sparks (additive blending),
## sized by the planet and the strength of the moment. Frees itself.

var color: Color = Color.WHITE
var radius: float = 20.0
var power: float = 1.0


func setup(p_color: Color, p_radius: float, p_power: float = 1.0) -> void:
	color = p_color
	radius = p_radius
	power = p_power


func _ready() -> void:
	var add := FxTextures.additive()
	# Flash: a soft disc that blooms and fades in a quarter second.
	var flash := Sprite2D.new()
	flash.texture = FxTextures.glow()
	flash.material = add
	flash.modulate = Color(color.lightened(0.5), 0.9)
	var s := radius * 3.2 * (0.8 + 0.3 * power) / 64.0
	flash.scale = Vector2.ONE * s * 0.4
	add_child(flash)
	var t := flash.create_tween().set_parallel(true)
	t.tween_property(flash, "scale", Vector2.ONE * s, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(flash, "modulate:a", 0.0, 0.3)

	# Sparks.
	var p := CPUParticles2D.new()
	p.texture = FxTextures.glow()
	p.material = add
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(clampf(14 + radius * 0.6 * power, 14, 72))
	p.lifetime = 0.55 + 0.25 * power
	p.spread = 180.0
	p.direction = Vector2.UP
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 90.0 + radius
	p.initial_velocity_max = 220.0 + radius * 4.0 * power
	p.damping_min = 160.0
	p.damping_max = 260.0
	# Small, bright sparks (larger ones read as blobs, not sparks).
	p.scale_amount_min = (0.07 + radius / 700.0) * 0.6
	p.scale_amount_max = 0.07 + radius / 700.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.add_point(0.25, Color(color.lightened(0.3), 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(color, 0))
	p.color_ramp = ramp
	p.emitting = true
	add_child(p)
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(queue_free)
