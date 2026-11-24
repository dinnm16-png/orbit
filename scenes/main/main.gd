extends Node2D
## Main game scene: owns the config and game state, and connects core,
## launcher, field and HUD.
##
## State machine (deliberately tiny):
##   PLAYING   -> launching, merging, scoring, boundary monitoring
##   GAME_OVER -> simulation frozen, input off, overlay shown; restart reloads

enum State { PLAYING, GAME_OVER }

const COLOR_AQUA := Color("#52E5D5")
const COLOR_WHITE := Color("#F5F5FA")

@export var config: GameConfig = preload("res://resources/config/default_config.tres")
## Fixed seed for reproducible runs (tests). 0 = random every run.
@export var random_seed: int = 0
## Where the best score is stored. Tests use a separate file.
@export var save_path: String = "user://orbit_save.cfg"

var rng := RandomNumberGenerator.new()
var state: State = State.PLAYING
var score: int = 0
var best_score: int = 0
## Level of the planet that will be loaded after the current one.
var next_level: int = 0

var _monitor: BoundaryMonitor
var _store: HighScoreStore

@onready var core: GravityCore = $GravityCore
@onready var field: PlanetField = $PlanetField
@onready var launcher: Launcher = $Launcher
@onready var next_preview: NextPreview = $NextPreview
@onready var hint: Label = $HUD/Hint
@onready var score_label: Label = $HUD/Score
@onready var best_label: Label = $HUD/Best
@onready var next_label: Label = $HUD/NextLabel
@onready var game_over_panel: GameOverPanel = $HUD/GameOver
@onready var reload_timer: Timer = $ReloadTimer


func _enter_tree() -> void:
	# Children's _ready() runs before ours, so configure them here, first.
	var errors := config.validate()
	assert(errors.is_empty(), "Invalid GameConfig: %s" % ", ".join(errors))
	$GravityCore.setup(config)
	$Launcher.setup(config)
	$PlanetField.setup(config)
	$NextPreview.setup(config)


func _ready() -> void:
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	_monitor = BoundaryMonitor.new(
		config.boundary_radius, config.game_over_speed_threshold, config.game_over_grace_time)
	_store = HighScoreStore.new(save_path)
	best_score = _store.load_best()

	get_viewport().size_changed.connect(_layout)
	_layout()

	reload_timer.wait_time = config.reload_delay
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_load_next_planet)
	launcher.planet_launched.connect(_on_planet_launched)
	field.planets_merged.connect(_on_planets_merged)
	field.planets_vanished.connect(_on_planets_vanished)
	game_over_panel.restart_requested.connect(restart)

	_set_score(0)
	next_level = _roll_level()
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
	next_preview.position = launcher.position + Vector2(170.0, 0.0)
	next_label.position = next_preview.position + Vector2(-60.0, -72.0)
	hint.position = Vector2(rect.position.x, rect.end.y - 70.0)
	hint.size.x = rect.size.x
	score_label.position = Vector2(rect.position.x, rect.position.y + 70.0)
	score_label.size.x = rect.size.x
	best_label.position = Vector2(rect.position.x, rect.position.y + 150.0)
	best_label.size.x = rect.size.x


func _roll_level() -> int:
	return rng.randi_range(0, config.spawn_max_level)


func _load_next_planet() -> void:
	if state != State.PLAYING:
		return
	var level := next_level
	next_level = _roll_level()
	launcher.load_planet(field.spawn_planet(level, launcher.global_position))
	next_preview.show_level(next_level)


func _on_planet_launched(_planet: Planet) -> void:
	if hint.visible:
		create_tween().tween_property(hint, "modulate:a", 0.0, 0.6)
	reload_timer.start()


# --- Scoring -------------------------------------------------------------------

func _on_planets_merged(planet: Planet, chain_depth: int) -> void:
	var points := ScoreRules.merge_points(
		planet.level, chain_depth, config.merge_base_points, config.chain_bonus)
	_add_score(points, planet.global_position, chain_depth)


func _on_planets_vanished(at: Vector2, _level: int, chain_depth: int) -> void:
	var points := ScoreRules.vanish_points(config.vanish_points, chain_depth, config.chain_bonus)
	_add_score(points, at, chain_depth)


func _add_score(points: int, at: Vector2, chain_depth: int) -> void:
	if state != State.PLAYING:
		return
	_set_score(score + points)
	_show_popup(points, at, chain_depth)


func _set_score(value: int) -> void:
	score = value
	score_label.text = str(score)
	best_label.text = "BEST  %d" % maxi(best_score, score) if best_score > 0 else ""


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
	$HUD.move_child(game_over_panel, -1)  # Overlay always stays on top.
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


# --- Game over -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	var samples := []
	var planets := field.get_active_planets()
	for planet in planets:
		samples.append({
			"id": planet.get_instance_id(),
			"distance": planet.global_position.distance_to(core.global_position),
			"speed": planet.linear_velocity.length(),
		})
	var result := _monitor.update(samples, delta)
	var progress: Dictionary = result["progress"]
	for planet in planets:
		planet.danger = progress.get(planet.get_instance_id(), 0.0)
	core.danger = result["max_progress"]
	if result["game_over"]:
		_game_over()


func _game_over() -> void:
	if state == State.GAME_OVER:
		return  # Guard: game over can only happen once per game.
	state = State.GAME_OVER
	launcher.enabled = false
	reload_timer.stop()
	field.freeze_all()
	var is_new_best := score > best_score and _store.submit(score)
	best_score = maxi(best_score, score)
	game_over_panel.present(score, best_score, is_new_best)


## Restarts instantly by reloading the scene: the simplest way to guarantee a
## completely clean state (no leftover planets, timers or tweens).
func restart() -> void:
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	# Desktop shortcut: R restarts at any time.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		restart()
