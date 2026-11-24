class_name GameConfig
extends Resource
## Every tunable gameplay number lives here, in one place.
##
## Why a Resource? Godot can save it as a .tres file and edit it in the
## Inspector. That lets us tweak game feel without touching code, and later
## create alternative configs (e.g. for difficulty modes or A/B playtests).
## The active config is res://resources/config/default_config.tres.

const MAX_LEVELS := 12

@export_group("Gravity")
## Acceleration toward the core in pixels/second². Constant magnitude: it does
## NOT grow as planets get closer, which keeps the simulation stable.
@export var gravity_strength: float = 1100.0
## Hard speed limit for any planet (pixels/second). Prevents runaway physics.
@export var max_planet_speed: float = 1300.0

@export_group("Planet physics")
## How quickly planets lose speed (higher = they settle faster).
@export var planet_linear_damp: float = 0.8
## How quickly planets stop spinning.
@export var planet_angular_damp: float = 3.0
@export_range(0.0, 1.0) var planet_friction: float = 0.5
@export_range(0.0, 1.0) var planet_bounce: float = 0.08
## Mass is proportional to area: mass = (radius / reference)². Bigger planets
## push smaller ones around, which feels physically "right".
@export var mass_reference_radius: float = 24.0

@export_group("Core")
@export var core_radius: float = 54.0
## Radius of the playable zone around the core. In a later milestone, planets
## that stay outside this ring will trigger game over.
@export var boundary_radius: float = 300.0

@export_group("Launcher")
## Distance of the launch point from the bottom edge of the screen.
@export var launch_offset_from_bottom: float = 180.0
## Drags shorter than this are treated as "cancel" (prevents accidental shots).
@export var min_drag_distance: float = 28.0
## Drag length that gives full launch power.
@export var max_drag_distance: float = 280.0
@export var max_launch_speed: float = 1150.0
## Seconds before the next planet is ready after a launch.
@export var reload_delay: float = 0.45
## Planets that fly further than this from the core are removed (safety net).
@export var despawn_distance: float = 1600.0

@export_group("Planets")
## Radius of each level, from level 0 (smallest) to level 11 (largest).
@export var planet_radii: PackedFloat32Array = PackedFloat32Array([
	18.0, 24.0, 31.0, 38.0, 46.0, 54.0, 63.0, 72.0, 82.0, 93.0, 105.0, 118.0,
])
## Base color of each level. Derived from the ORBIT palette (violet → aqua → white).
@export var planet_colors: PackedColorArray = PackedColorArray([
	Color("#6E5BD9"), Color("#917AFF"), Color("#B08CFF"), Color("#7A9BFF"),
	Color("#52B8E5"), Color("#52E5D5"), Color("#7FF0C8"), Color("#C2F5E0"),
	Color("#FFB8E0"), Color("#FFD27A"), Color("#E8E4FF"), Color("#F5F5FA"),
])
## Launches pick a random level from 0 to this value (inclusive).
@export var spawn_max_level: int = 2


func level_count() -> int:
	return mini(planet_radii.size(), planet_colors.size())


func get_planet_radius(level: int) -> float:
	return planet_radii[clampi(level, 0, level_count() - 1)]


func get_planet_color(level: int) -> Color:
	return planet_colors[clampi(level, 0, level_count() - 1)]


## Returns a list of problems. An empty list means the config is valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if planet_radii.size() != planet_colors.size():
		errors.append("planet_radii and planet_colors must have the same length")
	if level_count() < 1 or level_count() > MAX_LEVELS:
		errors.append("level count must be between 1 and %d" % MAX_LEVELS)
	for i in range(1, planet_radii.size()):
		if planet_radii[i] <= planet_radii[i - 1]:
			errors.append("planet_radii must be strictly increasing (index %d)" % i)
	if spawn_max_level < 0 or spawn_max_level >= level_count():
		errors.append("spawn_max_level out of range")
	if gravity_strength <= 0.0:
		errors.append("gravity_strength must be positive")
	if max_planet_speed <= 0.0 or max_launch_speed <= 0.0:
		errors.append("speeds must be positive")
	if max_launch_speed > max_planet_speed:
		errors.append("max_launch_speed must not exceed max_planet_speed")
	if min_drag_distance >= max_drag_distance:
		errors.append("min_drag_distance must be smaller than max_drag_distance")
	if core_radius >= boundary_radius:
		errors.append("core_radius must be smaller than boundary_radius")
	return errors
