extends Node2D
## Main game scene: owns the config and connects core, launcher, field and HUD.
##
## Responsibilities:
##   - position the core (screen center) and launcher (near bottom)
##   - load the next planet after each launch
##   - turn merge events into score (via ScoreRules) and show feedback

const COLOR_AQUA := Color("#52E5D5")
const COLOR_WHITE := Color("#F5F5FA")

@export var config: GameConfig = preload("res://resources/config/default_config.tres")
## Fixed seed for reproducible runs (tests). 0 = random every run.
@export var random_seed: int = 0

var rng := RandomNumberGenerator.new()
var score: int = 0

@onready var core: GravityCore = $GravityCore
@onready var field: PlanetField = $PlanetField
@onready var launcher: Launcher = $Launcher
@onready var hint: Label = $HUD/Hint
@onready var score_label: Label = $HUD/Score
@onready var reload_timer: Timer = $ReloadTimer


func _enter_tree() -> void:
	# Children's _ready() runs before ours, so configure them here, first.
	var errors := config.validate()
	assert(errors.is_empty(), "Invalid GameConfig: %s" % ", ".join(errors))
	$GravityCore.setup(config)
	$Launcher.setup(config)
	$PlanetField.setup(config)


func _ready() -> void:
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	get_viewport().size_changed.connect(_layout)
	_layout()

	reload_timer.wait_time = config.reload_delay
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_load_next_planet)
	launcher.planet_launched.connect(_on_planet_launched)
	field.planets_merged.connect(_on_planets_merged)
	field.planets_vanished.connect(_on_planets_vanished)
	_set_score(0)
	_load_next_planet()


## Places everything relative to the visible area. With "expand" stretch
## aspect, taller phones see more vertical space, so we compute positions
## from the actual visible rect rather than hard-coding them.
func _layout() -> void:
	var rect := get_viewport().get_visible_rect()
	core.position = rect.get_center()
	field.gravity_center = core.global_position
	launcher.position = Vector2(rect.get_center().x, rect.end.y - config.launch_offset_from_bottom)
	if launcher.loaded_planet:
		launcher.loaded_planet.global_position = launcher.global_position
	hint.position = Vector2(rect.position.x, rect.end.y - 70.0)
	hint.size.x = rect.size.x
	score_label.position = Vector2(rect.position.x, rect.position.y + 70.0)
	score_label.size.x = rect.size.x


func _load_next_planet() -> void:
	var level := rng.randi_range(0, config.spawn_max_level)
	launcher.load_planet(field.spawn_planet(level, launcher.global_position))


func _on_planet_launched(_planet: Planet) -> void:
	if hint.visible:
		create_tween().tween_property(hint, "modulate:a", 0.0, 0.6)
	reload_timer.start()


func _on_planets_merged(planet: Planet, chain_depth: int) -> void:
	var points := ScoreRules.merge_points(
		planet.level, chain_depth, config.merge_base_points, config.chain_bonus)
	_add_score(points, planet.global_position, chain_depth)


func _on_planets_vanished(at: Vector2, _level: int, chain_depth: int) -> void:
	var points := ScoreRules.vanish_points(config.vanish_points, chain_depth, config.chain_bonus)
	_add_score(points, at, chain_depth)


func _add_score(points: int, at: Vector2, chain_depth: int) -> void:
	_set_score(score + points)
	_show_popup(points, at, chain_depth)


func _set_score(value: int) -> void:
	score = value
	score_label.text = str(score)


## Small floating "+points" text. Chains are highlighted in aqua with "×N".
func _show_popup(points: int, at: Vector2, chain_depth: int) -> void:
	var label := Label.new()
	label.text = "+%d" % points
	if chain_depth >= 2:
		label.text += "  ×%d" % chain_depth
	label.add_theme_font_size_override("font_size", 26 if chain_depth < 2 else 30)
	label.add_theme_color_override("font_color", COLOR_AQUA if chain_depth >= 2 else COLOR_WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(200, 40)
	label.position = at - label.size * 0.5
	$HUD.add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	# Developer shortcut: R restarts the scene (a proper restart flow arrives
	# with the game-over milestone).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
