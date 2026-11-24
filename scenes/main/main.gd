extends Node2D
## Main game scene: owns the config and connects core, launcher and planets.
##
## Responsibilities in Phase 1:
##   - position the core (screen center) and launcher (near bottom)
##   - spawn the next planet after each launch
##   - remove planets that escape far off-screen (safety net)

const PLANET_SCENE := preload("res://scenes/planet/planet.tscn")

@export var config: GameConfig = preload("res://resources/config/default_config.tres")
## Fixed seed for reproducible runs (tests). 0 = random every run.
@export var random_seed: int = 0

var rng := RandomNumberGenerator.new()

@onready var core: GravityCore = $GravityCore
@onready var planets: Node2D = $Planets
@onready var launcher: Launcher = $Launcher
@onready var hint: Label = $HUD/Hint
@onready var reload_timer: Timer = $ReloadTimer


func _enter_tree() -> void:
	# Children's _ready() runs before ours, so configure them here, first.
	var errors := config.validate()
	assert(errors.is_empty(), "Invalid GameConfig: %s" % ", ".join(errors))
	$GravityCore.setup(config)
	$Launcher.setup(config)


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
	_load_next_planet()


## Places everything relative to the visible area. With "expand" stretch
## aspect, taller phones see more vertical space, so we compute positions
## from the actual visible rect rather than hard-coding them.
func _layout() -> void:
	var rect := get_viewport().get_visible_rect()
	core.position = rect.get_center()
	launcher.position = Vector2(rect.get_center().x, rect.end.y - config.launch_offset_from_bottom)
	if launcher.loaded_planet:
		launcher.loaded_planet.global_position = launcher.global_position
	for planet: Planet in planets.get_children():
		planet.gravity_center = core.global_position
	hint.position = Vector2(rect.position.x, rect.end.y - 70.0)
	hint.size.x = rect.size.x


func _load_next_planet() -> void:
	var planet: Planet = PLANET_SCENE.instantiate()
	var level := rng.randi_range(0, config.spawn_max_level)
	planet.setup(config, level, core.global_position)
	planets.add_child(planet)
	launcher.load_planet(planet)


func _on_planet_launched(_planet: Planet) -> void:
	if hint.visible:
		create_tween().tween_property(hint, "modulate:a", 0.0, 0.6)
	reload_timer.start()


func _physics_process(_delta: float) -> void:
	var limit_sq := config.despawn_distance * config.despawn_distance
	for planet: Planet in planets.get_children():
		if planet.is_active and planet.global_position.distance_squared_to(core.global_position) > limit_sq:
			planet.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# Developer shortcut: R restarts the scene (a proper restart flow arrives
	# with the game-over milestone).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
