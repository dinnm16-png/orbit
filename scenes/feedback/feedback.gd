class_name Feedback
extends Node
## All non-visual feedback (sound + haptics) in one place.
## Gameplay code only says WHAT happened (launch, merge...), never HOW it
## should feel, so sound/haptics can be tuned or disabled independently.

const VOICES := 6

## Generated sounds, shared across restarts (static = lives for the app run).
static var _sounds: Dictionary = {}
static var _generating: bool = false

var config: GameConfig
## Player settings (pause menu). Both must be on for sound/haptics to play.
var sound_on: bool = true
var haptics_on: bool = true

var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _haptics_available: bool = false


func setup(p_config: GameConfig) -> void:
	config = p_config


func _ready() -> void:
	# Vibration only exists on phones; on desktop the call would do nothing.
	_haptics_available = OS.has_feature("mobile")
	# Generating sounds takes ~0.1 s on a desktop CPU and could take several
	# times that on a budget phone. Doing it lazily would freeze the game at the
	# first merge, so we generate everything on a background thread at startup.
	# Until it finishes, sounds are simply skipped (silent), never blocking.
	if _sounds.is_empty() and not _generating:
		_generating = true
		WorkerThreadPool.add_task(_generate_sounds)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = config.sound_volume_db
		add_child(player)
		_players.append(player)


## Runs on a worker thread: builds every sound, then hands them to the main
## thread in one step (no shared data is touched while generating).
static func _generate_sounds() -> void:
	var result := {}
	result["launch"] = ToneSynth.whoosh()
	for level in range(1, GameConfig.MAX_LEVELS):
		result["merge_%d" % level] = ToneSynth.bell(ToneSynth.merge_frequency(level), 0.7)
	result["vanish"] = ToneSynth.chord([523.25, 659.25, 783.99, 1046.5], 1.4)
	result["game_over"] = ToneSynth.chord([220.0, 261.63, 329.63], 1.6, 2.2)
	_store_sounds.call_deferred(result)


static func _store_sounds(result: Dictionary) -> void:
	_sounds = result
	_generating = false


static func sounds_ready() -> bool:
	return not _sounds.is_empty()


func on_launch(power: float) -> void:
	_play("launch", lerpf(0.9, 1.15, power), -6.0)
	_vibrate(8, 0.25)


func on_merge(new_level: int, chain_depth: int) -> void:
	_play("merge_%d" % clampi(new_level, 1, GameConfig.MAX_LEVELS - 1), 1.0, 0.0)
	# Bigger merges and chains feel stronger, but always short and subtle.
	_vibrate(12 + 2 * new_level, clampf(0.25 + 0.06 * new_level + 0.1 * (chain_depth - 1), 0.0, 1.0))


func on_vanish() -> void:
	_play("vanish", 1.0, 0.0)
	_vibrate(40, 0.8)


func on_game_over() -> void:
	_play("game_over", 1.0, -2.0)
	_vibrate(60, 0.6)


func _play(sound: String, pitch: float, extra_db: float) -> void:
	if not (config.sound_enabled and sound_on) or not _sounds.has(sound):
		return
	var stream: AudioStream = _sounds[sound]
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = config.sound_volume_db + extra_db
	player.play()


func _vibrate(duration_ms: int, amplitude: float) -> void:
	if config.haptics_enabled and haptics_on and _haptics_available:
		Input.vibrate_handheld(duration_ms, amplitude)
