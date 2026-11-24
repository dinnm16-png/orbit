extends Node2D
## Main game scene: owns the config and game state, and connects core,
## launcher, field and HUD.
##
## State machine (deliberately tiny):
##   PLAYING   -> launching, merging, scoring, boundary monitoring
##   PAUSED    -> whole tree paused, pause menu shown (also when the app is
##                sent to the background)
##   GAME_OVER -> simulation frozen, input off, overlay shown; restart reloads

enum State { PLAYING, PAUSED, GAME_OVER }

const COLOR_AQUA := Color("#52E5D5")
const COLOR_WHITE := Color("#F5F5FA")
const BURST_SCRIPT := preload("res://scenes/effects/merge_burst.gd")

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

var settings: PlayerSettings
## Safe-area margins (notch, home indicator) in canvas units.
var insets: Dictionary = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

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
@onready var pause_button: PauseButton = $HUD/PauseButton
@onready var pause_menu: PauseMenu = $HUD/PauseMenu
@onready var reload_timer: Timer = $ReloadTimer
@onready var effects: Node2D = $Effects
@onready var feedback: Feedback = $Feedback


func _enter_tree() -> void:
	# Children's _ready() runs before ours, so configure them here, first.
	var errors := config.validate()
	assert(errors.is_empty(), "Invalid GameConfig: %s" % ", ".join(errors))
	$GravityCore.setup(config)
	$Launcher.setup(config)
	$PlanetField.setup(config)
	$NextPreview.setup(config)
	$Feedback.setup(config)


func _ready() -> void:
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	_monitor = BoundaryMonitor.new(
		config.boundary_radius, config.game_over_speed_threshold, config.game_over_grace_time)
	_store = HighScoreStore.new(save_path)
	best_score = _store.load_best()
	settings = PlayerSettings.new(save_path)
	settings.load_settings()
	pause_menu.settings = settings
	_apply_settings()

	get_viewport().size_changed.connect(_layout)
	_layout()

	reload_timer.wait_time = config.reload_delay
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_load_next_planet)
	launcher.planet_launched.connect(_on_planet_launched)
	field.planets_merged.connect(_on_planets_merged)
	field.planets_vanished.connect(_on_planets_vanished)
	game_over_panel.restart_requested.connect(restart)
	pause_button.pressed.connect(pause)
	pause_menu.resume_requested.connect(resume)
	pause_menu.restart_requested.connect(restart)
	pause_menu.settings_changed.connect(_apply_settings)

	_set_score(0)
	next_level = _roll_level()
	_load_next_planet()


## Places everything relative to the visible area. With "expand" stretch
## aspect, taller phones see more vertical space, so we compute positions
## from the actual visible rect rather than hard-coding them.
func _layout() -> void:
	var rect := get_viewport().get_visible_rect()
	insets = SafeArea.current(rect.size)
	var top: float = insets["top"]
	var bottom: float = insets["bottom"]
	core.position = rect.get_center()
	field.gravity_center = core.global_position
	launcher.position = Vector2(rect.get_center().x, rect.end.y - bottom - config.launch_offset_from_bottom)
	if launcher.loaded_planet:
		launcher.loaded_planet.global_position = launcher.global_position
		launcher.loaded_planet.reset_physics_interpolation()
	next_preview.position = launcher.position + Vector2(170.0, 0.0)
	next_label.position = next_preview.position + Vector2(-60.0, -72.0)
	hint.position = Vector2(rect.position.x, rect.end.y - bottom - 70.0)
	hint.size.x = rect.size.x
	score_label.position = Vector2(rect.position.x, rect.position.y + top + 70.0)
	score_label.size.x = rect.size.x
	best_label.position = Vector2(rect.position.x, rect.position.y + top + 150.0)
	best_label.size.x = rect.size.x
	pause_button.position = Vector2(rect.position.x + insets["left"] + 20.0, rect.position.y + top + 20.0)


func _roll_level() -> int:
	return rng.randi_range(0, config.spawn_max_level)


func _load_next_planet() -> void:
	if state != State.PLAYING:
		return
	var level := next_level
	next_level = _roll_level()
	launcher.load_planet(field.spawn_planet(level, launcher.global_position))
	next_preview.show_level(next_level)


func _on_planet_launched(planet: Planet) -> void:
	feedback.on_launch(planet.linear_velocity.length() / config.max_launch_speed)
	if hint.visible:
		create_tween().tween_property(hint, "modulate:a", 0.0, 0.6)
	reload_timer.start()


# --- Scoring -------------------------------------------------------------------

func _on_planets_merged(planet: Planet, chain_depth: int) -> void:
	var points := ScoreRules.merge_points(
		planet.level, chain_depth, config.merge_base_points, config.chain_bonus)
	if _add_score(points, planet.global_position - Vector2(0, planet.radius + 14.0), chain_depth):
		_spawn_burst(planet.global_position, planet.base_color, planet.radius, 1.0)
		feedback.on_merge(planet.level, chain_depth)


func _on_planets_vanished(at: Vector2, level: int, chain_depth: int) -> void:
	var points := ScoreRules.vanish_points(config.vanish_points, chain_depth, config.chain_bonus)
	if _add_score(points, at, chain_depth):
		_spawn_burst(at, COLOR_WHITE, config.get_planet_radius(level), 2.0)
		feedback.on_vanish()


## Returns false when scoring is closed (game over).
func _add_score(points: int, at: Vector2, chain_depth: int) -> bool:
	if state != State.PLAYING:
		return false
	_set_score(score + points)
	_show_popup(points, at, chain_depth)
	return true


func _spawn_burst(at: Vector2, color: Color, radius: float, strength: float) -> void:
	var burst: MergeBurst = BURST_SCRIPT.new()
	burst.setup(color, radius, strength)
	burst.position = at
	effects.add_child(burst)


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
	# Popups live in their own layer, below the pause and game-over overlays.
	$HUD/Popups.add_child(label)
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
	pause_button.visible = false
	launcher.enabled = false
	reload_timer.stop()
	field.freeze_all()
	var is_new_best := score > best_score and _store.submit(score)
	best_score = maxi(best_score, score)
	game_over_panel.present(score, best_score, is_new_best)
	feedback.on_game_over()


## Restarts instantly by reloading the scene: the simplest way to guarantee a
## completely clean state (no leftover planets, timers or tweens).
func restart() -> void:
	get_tree().paused = false
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


# --- Pause & settings ------------------------------------------------------------

func pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	launcher.enabled = false  # Cancels any aim in progress.
	get_tree().paused = true
	pause_menu.open()


func resume() -> void:
	if state != State.PAUSED:
		return
	pause_menu.close()
	get_tree().paused = false
	launcher.enabled = true
	state = State.PLAYING


func _apply_settings() -> void:
	feedback.sound_on = settings.sound
	feedback.haptics_on = settings.haptics
	field.show_numbers = settings.planet_numbers
	next_preview.show_number = settings.planet_numbers


## The OS tells us when the app goes to the background (home button, phone
## call, notification shade...). Pausing then means no game is ever lost
## while the player is away.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_node_ready():
			pause()


func _unhandled_input(event: InputEvent) -> void:
	# Desktop shortcut: R restarts at any time.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		restart()
