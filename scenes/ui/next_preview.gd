class_name NextPreview
extends Node2D
## Shows the planet that will be loaded after the current one.

const COLOR_WHITE := Color("#F5F5FA")
## Preview size in pixels (radius); real sizes would be too big for big levels.
const MAX_RADIUS := 22.0

var config: GameConfig
var level: int = -1
var show_number: bool = false:
	set(value):
		show_number = value
		queue_redraw()


func setup(p_config: GameConfig) -> void:
	config = p_config


func show_level(p_level: int) -> void:
	if p_level == level:
		return
	level = p_level
	queue_redraw()
	if _body:
		_body.queue_redraw()
	# Small "pop" so the player notices the queue advanced.
	scale = Vector2.ONE * 0.6
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


var _body: Node2D


func _ready() -> void:
	# The planet is drawn by a child using the shared planet shader.
	_body = Node2D.new()
	_body.material = PlanetArt.material()
	_body.draw.connect(_draw_body)
	add_child(_body)


func _draw() -> void:
	draw_arc(Vector2.ZERO, MAX_RADIUS + 12.0, 0.0, TAU, 48, Color(COLOR_WHITE, 0.10), 1.0, true)
	if config == null or level < 0:
		return
	var r := minf(config.get_planet_radius(level), MAX_RADIUS)
	PlanetArt.draw_ring(self, r, config.get_planet_color(level), level)
	if show_number:
		PlanetArt.draw_number(self, r, level)


func _draw_body() -> void:
	if config == null or level < 0:
		return
	var r := minf(config.get_planet_radius(level), MAX_RADIUS)
	PlanetArt.draw_body(_body, r, config.get_planet_color(level))
