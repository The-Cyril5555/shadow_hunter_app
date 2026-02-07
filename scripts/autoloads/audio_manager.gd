## AudioManager - Centralized audio management system
##
## Manages sound effect playback with pooled AudioStreamPlayer nodes
## Provides pitch variation, volume control, and audio bus routing
##
## Features:
## - Sound pool system (max 10 concurrent sounds for performance)
## - Pitch variation (±10% randomization to reduce repetition)
## - Audio bus routing (SFX, Music buses)
## - Volume control integrated with UserSettings
## - Sound caching for performance
##
## Pattern: Singleton autoload for global audio management
## Usage: AudioManager.play_sfx("card_draw")
class_name AudioManagerClass
extends Node


# =============================================================================
# CONSTANTS
# =============================================================================

## Maximum number of concurrent sound effects (performance limit)
const MAX_CONCURRENT_SOUNDS: int = 10

## Pitch variation range (±10% = 0.9 to 1.1)
const PITCH_VARIATION: float = 0.1

## Audio bus names
const BUS_MASTER: String = "Master"
const BUS_SFX: String = "SFX"
const BUS_MUSIC: String = "Music"


# =============================================================================
# PROPERTIES
# =============================================================================

## Pool of AudioStreamPlayer nodes for sound effects
var _sound_pool: Array[AudioStreamPlayer] = []

## Cached sound resources (Dict[String, AudioStream])
var _sound_cache: Dictionary = {}

## Active sound count for debugging
var _active_sound_count: int = 0

## Audio bus indices (cached for performance)
var _bus_sfx_index: int = -1
var _bus_music_index: int = -1


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Cache audio bus indices
	_bus_sfx_index = AudioServer.get_bus_index(BUS_SFX)
	_bus_music_index = AudioServer.get_bus_index(BUS_MUSIC)

	if _bus_sfx_index == -1:
		push_error("[AudioManager] SFX bus not found! Create SFX bus in audio bus layout.")
	if _bus_music_index == -1:
		push_error("[AudioManager] Music bus not found! Create Music bus in audio bus layout.")

	# Initialize sound pool
	_initialize_sound_pool()

	# Load initial volume settings from UserSettings (if available)
	_load_volume_settings()

	print("[AudioManager] Initialized with %d sound players in pool" % MAX_CONCURRENT_SOUNDS)


## Initialize pool of AudioStreamPlayer nodes
func _initialize_sound_pool() -> void:
	for i in range(MAX_CONCURRENT_SOUNDS):
		var player = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		player.name = "SFX_Player_%d" % i
		add_child(player)
		_sound_pool.append(player)

		# Connect finished signal for auto-cleanup
		player.finished.connect(_on_sound_finished.bind(player))


## Load volume settings from UserSettings
func _load_volume_settings() -> void:
	# UserSettings may not be ready yet during autoload initialization
	# We'll call this again when needed
	if not has_node("/root/UserSettings"):
		return

	var user_settings = get_node("/root/UserSettings")
	if not user_settings:
		return

	# Apply saved volumes if UserSettings is available
	if user_settings.has_method("get_setting"):
		var master_vol = user_settings.get_setting("master_volume", 1.0)
		var sfx_vol = user_settings.get_setting("sfx_volume", 1.0)
		var music_vol = user_settings.get_setting("music_volume", 0.8)

		set_master_volume(master_vol)
		set_sfx_volume(sfx_vol)
		set_music_volume(music_vol)


# =============================================================================
# PUBLIC METHODS - Sound Playback
# =============================================================================

## Play a sound effect with optional pitch variation
## @param sound_name: Name of the sound file (without extension, e.g., "card_draw")
## @param pitch_variation: Enable pitch randomization (default true)
## @param custom_pitch: Override pitch (1.0 = normal, 0.0 = disabled pitch variation)
## @returns: AudioStreamPlayer if played successfully, null otherwise
func play_sfx(sound_name: String, pitch_variation: bool = true, custom_pitch: float = 0.0) -> AudioStreamPlayer:
	# Get available sound player
	var player = _get_available_player()
	if not player:
		push_warning("[AudioManager] No available sound players (max %d concurrent)" % MAX_CONCURRENT_SOUNDS)
		return null

	# Load sound (from cache or file)
	var sound = _load_sound(sound_name)
	if not sound:
		push_error("[AudioManager] Sound not found: %s" % sound_name)
		return null

	# Configure player
	player.stream = sound

	# Apply pitch variation
	if custom_pitch > 0.0:
		player.pitch_scale = custom_pitch
	elif pitch_variation:
		player.pitch_scale = 1.0 + randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	else:
		player.pitch_scale = 1.0

	# Play sound
	player.play()
	_active_sound_count += 1

	print("[AudioManager] Playing SFX: %s (pitch: %.2f, active: %d)" % [sound_name, player.pitch_scale, _active_sound_count])

	return player


## Play music track with looping
## @param music_name: Name of the music file (without extension)
## @param loop: Enable looping (default true)
## @returns: AudioStreamPlayer if played successfully, null otherwise
func play_music(music_name: String, loop: bool = true) -> AudioStreamPlayer:
	# TODO: Implement in future story (5.3 or later)
	# For now, just return null
	push_warning("[AudioManager] play_music() not yet implemented (future story)")
	return null


## Stop a specific sound player
func stop_sound(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return

	if player.playing:
		player.stop()
		_active_sound_count -= 1


## Stop all currently playing sounds
func stop_all_sfx() -> void:
	for player in _sound_pool:
		if player.playing:
			player.stop()
	_active_sound_count = 0
	print("[AudioManager] All SFX stopped")


# =============================================================================
# PUBLIC METHODS - Volume Control
# =============================================================================

## Set master volume (0.0 to 1.0)
func set_master_volume(volume: float) -> void:
	var master_bus = AudioServer.get_bus_index(BUS_MASTER)
	if master_bus == -1:
		push_error("[AudioManager] Master bus not found")
		return

	var db = _linear_to_db(volume)
	AudioServer.set_bus_volume_db(master_bus, db)
	print("[AudioManager] Master volume set to %.2f (%.1f dB)" % [volume, db])


## Set SFX volume (0.0 to 1.0)
func set_sfx_volume(volume: float) -> void:
	if _bus_sfx_index == -1:
		push_error("[AudioManager] SFX bus not found")
		return

	var db = _linear_to_db(volume)
	AudioServer.set_bus_volume_db(_bus_sfx_index, db)
	print("[AudioManager] SFX volume set to %.2f (%.1f dB)" % [volume, db])


## Set Music volume (0.0 to 1.0)
func set_music_volume(volume: float) -> void:
	if _bus_music_index == -1:
		push_error("[AudioManager] Music bus not found")
		return

	var db = _linear_to_db(volume)
	AudioServer.set_bus_volume_db(_bus_music_index, db)
	print("[AudioManager] Music volume set to %.2f (%.1f dB)" % [volume, db])


## Mute/unmute SFX bus
func set_sfx_mute(muted: bool) -> void:
	if _bus_sfx_index == -1:
		return
	AudioServer.set_bus_mute(_bus_sfx_index, muted)
	print("[AudioManager] SFX %s" % ("muted" if muted else "unmuted"))


## Mute/unmute Music bus
func set_music_mute(muted: bool) -> void:
	if _bus_music_index == -1:
		return
	AudioServer.set_bus_mute(_bus_music_index, muted)
	print("[AudioManager] Music %s" % ("muted" if muted else "unmuted"))


# =============================================================================
# PRIVATE METHODS - Sound Pool Management
# =============================================================================

## Get an available (not playing) sound player from the pool
func _get_available_player() -> AudioStreamPlayer:
	for player in _sound_pool:
		if not player.playing:
			return player

	# No available players (all 10 are playing)
	return null


## Called when a sound finishes playing
func _on_sound_finished(_player: AudioStreamPlayer) -> void:
	_active_sound_count -= 1
	# Player is automatically returned to pool (no cleanup needed)


# =============================================================================
# PRIVATE METHODS - Sound Loading
# =============================================================================

## Load a sound from cache or file
## @param sound_name: Name without extension or path (e.g., "card_draw")
## @returns: AudioStream resource or null if not found
func _load_sound(sound_name: String) -> AudioStream:
	# Check cache first
	if _sound_cache.has(sound_name):
		return _sound_cache[sound_name]

	# Try to load from assets/audio/sfx/ folder
	var sound_path = "res://assets/audio/sfx/%s.wav" % sound_name

	if not ResourceLoader.exists(sound_path):
		# Try .ogg as fallback
		sound_path = "res://assets/audio/sfx/%s.ogg" % sound_name
		if not ResourceLoader.exists(sound_path):
			push_error("[AudioManager] Sound file not found: %s (tried .wav and .ogg)" % sound_name)
			return null

	# Load and cache
	var sound = load(sound_path) as AudioStream
	if sound:
		_sound_cache[sound_name] = sound
		print("[AudioManager] Loaded and cached sound: %s" % sound_name)

	return sound


# =============================================================================
# UTILITY METHODS
# =============================================================================

## Convert linear volume (0.0-1.0) to decibels (-80dB to 0dB)
func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0  # Mute
	return 20.0 * log(linear) / log(10.0)


## Get current active sound count (for debugging)
func get_active_sound_count() -> int:
	return _active_sound_count


## Get sound pool size
func get_pool_size() -> int:
	return _sound_pool.size()
