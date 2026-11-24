extends Node2D
## Main game scene: owns the config, the game mode and the game state, and
## connects cores, arena, launcher, field and HUD.
##
## State machine (deliberately tiny):
##   PLAYING   -> launching, merging, scoring, mode rules running
##   PAUSED    -> whole tree paused, pause menu shown (also when the app is
##                sent to the background)
##   GAME_OVER -> simulation frozen, input off, overlay shown
##
## Mode rules (see GameMode) are all handled here, each switched on only by
## its mode's data: time limit, shot limit, shrinking ring, Zen fading, daily
## seed, number of cores.

enum State { PLAYING, PAUSED, GAME_OVER }
enum EndReason { COLLAPSE, TIME, SHOTS }

const COLOR_AQUA := Color("#52E5D5")
const COLOR_WHITE := Color("#F5F5FA")
const BURST_SCRIPT := preload("res://scenes/effects/merge_burst.gd")
const CORE_SCENE := preload("res://scenes/core/gravity_core.tscn")
const MENU_SCENE := "res://scenes/menu/menu.tscn"
const END_TITLES := {
	EndReason.COLLAPSE: "ORBIT COLLAPSED",
	EndReason.TIME: "TIME'S UP",
	EndReason.SHOTS: "OUT OF PLANETS",
}

@export var config: GameConfig = preload("res://resources/config/default_config.tres")
## The mode to play. Left empty, the mode chosen in the menu (Session) is used.
@export var mode: GameMode
## Fixed seed for reproducible runs (tests). 0 = random every run.
@export var random_seed: int = 0
## Where scores and settings are stored. Tests use a separate file.
@export var save_path: String = "user://orbit_save.cfg"

var rng := RandomNumberGenerator.new()
var state: State = State.PLAYING
var end_reason: EndReason = EndReason.COLLAPSE
var score: int = 0
var best_score: int = 0
## Level of the planet that will be loaded after the current one.
var next_level: int = 0
var settings: PlayerSettings
## Safe-area margins (notch, home indicator) in canvas units.
var insets: Dictionary = {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}

## All cores (Binary Star has two). `core` is the first one.
var cores: Array[GravityCore] = []
var arena_center: Vector2 = Vector2.ZERO
## Current ring radius (shrinks in Collapse).
var arena_radius: float = 300.0
var base_arena_radius: float = 300.0
## Blitz: seconds remaining.
var time_left: float = 0.0
## Limited Shots: planets remaining (including the one loaded).
var shots_left: int = 0
var shots_fired: int = 0
## Daily Orbit: today's key, e.g. "2026-11-24".
var date_key: String = ""

var _fade: ColorRect
var _leaving: bool = false
var _monitor: BoundaryMonitor
var _store: HighScoreStore
var _since_last_shot: float = 0.0
var _status_text: String = ""

@onready var core: GravityCore = $GravityCore
@onready var arena: ArenaRing = $Arena
@onready var field: PlanetField = $PlanetField
@onready var launcher: Launcher = $Launcher
@onready var next_preview: NextPreview = $NextPreview
@onready var hint: Label = $HUD/Hint
@onready var score_label: Label = $HUD/Score
@onready var best_label: Label = $HUD/Best
@onready var status_label: Label = $HUD/Status
@onready var next_label: Label = $HUD/NextLabel
@onready var game_over_panel: GameOverPanel = $HUD/GameOver
@onready var pause_button: PauseButton = $HUD/PauseButton
@onready var pause_menu: PauseMenu = $HUD/PauseMenu
@onready var reload_timer: Timer = $ReloadTimer
@onready var effects: Node2D = $Effects
@onready var feedback: Feedback = $Feedback


func _enter_tree() -> void:
	if mode == null:
		mode = Session.current_mode()
	# Each mode gets its own copy of the config (never edit the shared file).
	config = mode.apply_to(config)
	var errors := config.validate()
	assert(errors.is_empty(), "Invalid GameConfig: %s" % ", ".join(errors))
	# Children's _ready() runs before ours, so configure them here, first.
	$GravityCore.setup(config)
	$Launcher.setup(config)
	$PlanetField.setup(config)
	$NextPreview.setup(config)
	$Feedback.setup(config)


func _ready() -> void:
	date_key = DailySeed.today_key()
	if random_seed != 0:
		rng.seed = random_seed
	elif mode.daily_seed:
		rng.seed = DailySeed.seed_for(date_key)
	else:
		rng.randomize()

	cores.append(core)
	for i in range(1, mode.core_count):
		var extra: GravityCore = CORE_SCENE.instantiate()
		extra.setup(config)
		add_child(extra)
		move_child(extra, core.get_index() + 1)
		cores.append(extra)

	base_arena_radius = config.boundary_radius
	arena_radius = base_arena_radius
	arena.base_radius = base_arena_radius
	arena.radius = arena_radius
	arena.accent = mode.accent
	time_left = mode.time_limit
	shots_left = mode.shot_limit

	_monitor = BoundaryMonitor.new(
		arena_radius, config.game_over_speed_threshold, config.game_over_grace_time)
	_store = HighScoreStore.new(save_path, mode.best_key(date_key))
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
	game_over_panel.menu_requested.connect(go_to_menu)
	pause_button.pressed.connect(pause)
	pause_menu.resume_requested.connect(resume)
	pause_menu.restart_requested.connect(restart)
	pause_menu.menu_requested.connect(go_to_menu)
	pause_menu.settings_changed.connect(_apply_settings)

	_set_score(0)
	next_level = _roll_level()
	_load_next_planet()
	_update_status()

	# Soft fade-in from the menu (top of the HUD, ignores input).
	_fade = UIStyle.fade_rect(1.0)
	_fade.process_mode = Node.PROCESS_MODE_ALWAYS
	$HUD.add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.4)


## Places everything relative to the visible area. With "expand" stretch
## aspect, taller phones see more vertical space, so we compute positions
## from the actual visible rect rather than hard-coding them.
func _layout() -> void:
	var rect := get_viewport().get_visible_rect()
	insets = SafeArea.current(rect.size)
	var top: float = insets["top"]
	var bottom: float = insets["bottom"]
	arena_center = rect.get_center()
	arena.position = arena_center
	var centers := []
	for i in cores.size():
		var offset := 0.0
		if cores.size() > 1:
			offset = lerpf(-0.5, 0.5, float(i) / (cores.size() - 1)) * mode.core_spacing
		cores[i].position = arena_center + Vector2(offset, 0.0)
		centers.append(cores[i].global_position)
	field.gravity_centers = centers
	field.arena_center = arena_center
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
	status_label.position = Vector2(rect.position.x, rect.position.y + top + 182.0)
	status_label.size.x = rect.size.x
	pause_button.position = Vector2(rect.position.x + insets["left"] + 20.0, rect.position.y + top + 20.0)


func _roll_level() -> int:
	return rng.randi_range(0, config.spawn_max_level)


func _load_next_planet() -> void:
	if state != State.PLAYING:
		return
	if mode.has_shot_limit() and shots_left <= 0:
		return
	var level := next_level
	next_level = _roll_level()
	launcher.load_planet(field.spawn_planet(level, launcher.global_position))
	# With a shot limit, the last planet has no "next".
	var has_next := not mode.has_shot_limit() or shots_left > 1
	next_preview.show_level(next_level if has_next else -1)


func _on_planet_launched(planet: Planet) -> void:
	feedback.on_launch(planet.linear_velocity.length() / config.max_launch_speed)
	if hint.visible:
		create_tween().tween_property(hint, "modulate:a", 0.0, 0.6)
	shots_fired += 1
	_since_last_shot = 0.0
	if mode.has_shot_limit():
		shots_left -= 1
	if not mode.has_shot_limit() or shots_left > 0:
		reload_timer.start()
	_update_status()


# --- Scoring -------------------------------------------------------------------

func _on_planets_merged(planet: Planet, chain_depth: int) -> void:
	var points := ScoreRules.merge_points(
		planet.level, chain_depth, config.merge_base_points, config.chain_bonus)
	if _add_score(points, planet.global_position - Vector2(0, planet.radius + 14.0), chain_depth):
		_spawn_burst(planet.global_position, planet.base_color, planet.radius, 1.0)
		feedback.on_merge(planet.level, chain_depth)
		_apply_merge_mode_rules(planet, chain_depth)


func _on_planets_vanished(at: Vector2, level: int, chain_depth: int) -> void:
	var points := ScoreRules.vanish_points(config.vanish_points, chain_depth, config.chain_bonus)
	if _add_score(points, at, chain_depth):
		_spawn_burst(at, COLOR_WHITE, config.get_planet_radius(level), 2.0)
		feedback.on_vanish()


## Blitz: chains add time. Collapse: merges push the ring back out.
func _apply_merge_mode_rules(planet: Planet, chain_depth: int) -> void:
	if mode.is_timed() and chain_depth >= 2 and mode.time_bonus_per_chain > 0.0:
		# Flat bonus per chained merge. (Scaling it by depth made long chains
		# add time faster than it ran out — measured with tools/balance.gd.)
		var bonus := mode.time_bonus_per_chain
		time_left += bonus
		_show_text_popup("+%.1fs" % bonus, planet.global_position - Vector2(0, planet.radius + 46.0), COLOR_AQUA)
	if mode.shrink_relief_per_level > 0.0:
		arena_radius = minf(base_arena_radius, arena_radius + mode.shrink_relief_per_level * planet.level)


## Returns false when scoring is closed (game over).
func _add_score(points: int, at: Vector2, chain_depth: int) -> bool:
	if state != State.PLAYING:
		return false
	_set_score(score + points)
	var text := "+%d" % points
	if chain_depth >= 2:
		text += "  ×%d" % chain_depth
	_show_text_popup(text, at, COLOR_AQUA if chain_depth >= 2 else COLOR_WHITE, 30 if chain_depth >= 2 else 26)
	return true


func _spawn_burst(at: Vector2, color: Color, radius: float, strength: float) -> void:
	var burst: MergeBurst = BURST_SCRIPT.new()
	burst.setup(color, radius, strength)
	burst.position = at
	effects.add_child(burst)


func _set_score(value: int) -> void:
	score = value
	score_label.text = str(score)
	var best := maxi(best_score, score)
	var label := mode.title.to_upper()
	if mode.daily_seed:
		label = "DAILY · " + DailySeed.pretty(date_key).to_upper()
	best_label.text = label + ("   ·   BEST  %d" % best if best > 0 else "")


## Small floating text (score, bonus time...). Lives in its own layer, below
## the pause and game-over overlays.
func _show_text_popup(text: String, at: Vector2, color: Color, font_size: int = 26) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(220, 40)
	label.position = at - label.size * 0.5
	$HUD/Popups.add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


## Mode-specific status line under the score (timer, planets left...).
func _update_status() -> void:
	var text := ""
	if mode.is_timed():
		var s := int(ceil(time_left))
		text = "%d:%02d" % [s / 60, s % 60]
	elif mode.has_shot_limit():
		text = "%d %s LEFT" % [shots_left, "PLANET" if shots_left == 1 else "PLANETS"]
	if text != _status_text:
		_status_text = text
		status_label.text = text
	# Last 10 seconds of Blitz: the timer turns aqua.
	var urgent := mode.is_timed() and time_left <= 10.0
	status_label.add_theme_color_override("font_color", COLOR_AQUA if urgent else Color(COLOR_WHITE, 0.7))


# --- Mode rules each physics step ---------------------------------------------

func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return

	if mode.is_timed():
		time_left = maxf(time_left - delta, 0.0)
		_update_status()
		if time_left <= 0.0:
			_end(EndReason.TIME)
			return

	if mode.boundary_shrink_per_sec > 0.0:
		arena_radius = maxf(mode.boundary_min_radius, arena_radius - mode.boundary_shrink_per_sec * delta)
	arena.radius = arena_radius
	_monitor.boundary_radius = arena_radius

	var samples := []
	var planets := field.get_active_planets()
	for planet in planets:
		samples.append({
			"id": planet.get_instance_id(),
			"distance": planet.global_position.distance_to(arena_center),
			"speed": planet.linear_velocity.length(),
		})
	var result := _monitor.update(samples, delta)
	var progress: Dictionary = result["progress"]

	if mode.fade_outside_boundary:
		# Zen: no warning, no game over — stranded planets just fade away.
		for planet in planets:
			var p: float = progress.get(planet.get_instance_id(), 0.0)
			planet.modulate.a = 1.0 - 0.6 * p
			if p >= 1.0:
				planet.consume(true)
		arena.danger = 0.0
	else:
		for planet in planets:
			planet.danger = progress.get(planet.get_instance_id(), 0.0)
		arena.danger = result["max_progress"]
		if mode.game_over_on_boundary and result["game_over"]:
			_end(EndReason.COLLAPSE)
			return

	if mode.has_shot_limit() and shots_left <= 0 and launcher.loaded_planet == null:
		# Out of planets: end once everything has settled (or after 6 s).
		_since_last_shot += delta
		var settled := true
		for planet in planets:
			if planet.linear_velocity.length() > config.game_over_speed_threshold:
				settled = false
				break
		if _since_last_shot > 1.5 and (settled or _since_last_shot > 6.0):
			_end(EndReason.SHOTS)


# --- Game end ------------------------------------------------------------------

## Kept for tests and older callers: the classic "orbit collapsed" ending.
func _game_over() -> void:
	_end(EndReason.COLLAPSE)


func _end(reason: EndReason) -> void:
	if state == State.GAME_OVER:
		return  # Guard: a game can only end once.
	state = State.GAME_OVER
	end_reason = reason
	pause_button.visible = false
	launcher.enabled = false
	reload_timer.stop()
	field.freeze_all()
	var is_new_best := score > best_score and _store.submit(score)
	best_score = maxi(best_score, score)
	var mode_title := mode.title
	if mode.daily_seed:
		mode_title += " · " + DailySeed.pretty(date_key)
	game_over_panel.present(score, best_score, is_new_best, END_TITLES[reason], mode_title)
	feedback.on_game_over()


## Restarts instantly by reloading the scene: the simplest way to guarantee a
## completely clean state (no leftover planets, timers or tweens).
func restart() -> void:
	get_tree().paused = false
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()


func go_to_menu() -> void:
	if _leaving:
		return
	get_tree().paused = false
	if get_tree().current_scene != self or not ResourceLoader.exists(MENU_SCENE):
		return
	_leaving = true
	$HUD.move_child(_fade, -1)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.25)
	t.tween_callback(func(): get_tree().change_scene_to_file(MENU_SCENE))


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
## while the player is away. Android's back button pauses too.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_node_ready():
			pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if state == State.PLAYING:
			pause()
		elif state == State.PAUSED:
			resume()
		else:
			go_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	# Desktop shortcuts: R restarts, Esc pauses/resumes.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			restart()
		elif event.keycode == KEY_ESCAPE:
			if state == State.PLAYING:
				pause()
			elif state == State.PAUSED:
				resume()
