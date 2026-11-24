class_name NextPreview
extends Node2D
## Shows a queued planet (used for both NEXT and HOLD), special kinds included.

## Preview size in pixels (radius); real sizes would be too big for big levels.
const MAX_RADIUS := 22.0

var config: GameConfig
var level: int = -1
var kind: int = PlanetKind.Kind.NORMAL
## Dim the slot (e.g. HOLD already used this turn).
var dimmed: bool = false:
	set(value):
		dimmed = value
		modulate.a = 0.4 if dimmed else 1.0
var show_number: bool = false:
	set(value):
		show_number = value
		if _overlay:
			_overlay.queue_redraw()

var _body: Node2D
var _overlay: Node2D
var _t: float = 0.0


func setup(p_config: GameConfig) -> void:
	config = p_config


func _ready() -> void:
	_body = Node2D.new()
	_body.material = PlanetArt.material()
	_body.draw.connect(_draw_body)
	add_child(_body)
	# Overlay (rings, special-planet effects, numbers) must be ABOVE the body,
	# and children draw over their parent, so it is a second child.
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## Kept for callers that only know levels.
func show_level(p_level: int) -> void:
	show_piece(p_level, PlanetKind.Kind.NORMAL)


## level -1 = empty slot.
func show_piece(p_level: int, p_kind: int) -> void:
	if p_level == level and p_kind == kind:
		return
	level = p_level
	kind = p_kind
	queue_redraw()
	if _body:
		_body.queue_redraw()
		_overlay.queue_redraw()
	if level >= 0:
		# Small "pop" so the player notices the slot changed.
		scale = Vector2.ONE * 0.6
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if level >= 0 and PlanetArt.kind_animates(kind) and kind != PlanetKind.Kind.COMET:
		_t += delta
		_overlay.queue_redraw()


func _radius() -> float:
	return minf(config.get_planet_radius(PlanetKind.size_level(kind, level)), MAX_RADIUS)


func _color() -> Color:
	return PlanetKind.COLORS.get(kind, config.get_planet_color(level))


func _draw() -> void:
	draw_arc(Vector2.ZERO, MAX_RADIUS + 12.0, 0.0, TAU, 48, Color(UIStyle.WHITE, 0.10), 1.0, true)


func _draw_overlay() -> void:
	if config == null or level < 0:
		return
	var r := _radius()
	if kind != PlanetKind.Kind.NORMAL:
		PlanetArt.draw_kind_overlay(_overlay, kind, r, _t)
	if kind == PlanetKind.Kind.NORMAL or kind == PlanetKind.Kind.ANCHOR:
		PlanetArt.draw_ring(_overlay, r, _color(), level)
		if show_number:
			PlanetArt.draw_number(_overlay, r, level)


func _draw_body() -> void:
	if config == null or level < 0 or kind == PlanetKind.Kind.BLACK_HOLE:
		return
	PlanetArt.draw_body(_body, _radius(), _color())
