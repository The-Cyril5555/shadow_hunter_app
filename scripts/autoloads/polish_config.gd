## PolishConfig - Centralized animation and polish settings autoload
##
## Loads timing values from data/polish_config.json and provides global access
## Supports hot-reloading for rapid iteration during development
## Handles reduced motion mode and global animation multipliers
##
## Pattern: Singleton autoload for global configuration
## Usage: PolishConfig.get_duration("card_flip_duration")
extends Node


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------

## Emitted when config is reloaded (hot-reload or initialization)
signal config_changed()


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------

## Configuration data loaded from JSON
var config_data: Dictionary = {}

## Path to the polish configuration file
var config_file_path: String = "res://data/polish_config.json"


# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------

func _ready() -> void:
	load_config()
	print("[PolishConfig] Loaded %d configuration values" % config_data.size())

	# Hot-reload support in debug builds
	if OS.is_debug_build():
		print("[PolishConfig] Hot-reload enabled - Press F5 to reload config")


## Load polish configuration from JSON file
func load_config() -> void:
	var file = FileAccess.open(config_file_path, FileAccess.READ)
	if file == null:
		push_error("[PolishConfig] Failed to load polish_config.json at: %s" % config_file_path)
		_load_defaults()
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("[PolishConfig] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		_load_defaults()
		return

	config_data = json.data
	config_changed.emit()
	print("[PolishConfig] Configuration loaded successfully")


## Reload configuration (for hot-reloading during development)
## Triggered by F5 key in debug builds
func reload_config() -> void:
	print("[PolishConfig] Reloading configuration...")
	load_config()


## Handle input for hot-reload (F5 key in debug mode)
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_F5:
		reload_config()


# -----------------------------------------------------------------------------
# Getters - Public API
# -----------------------------------------------------------------------------

## Get raw configuration value by key with optional default
## @param key: Configuration key to retrieve
## @param default: Default value if key doesn't exist
## @returns: Configuration value or default
func get_value(key: String, default: Variant = 0.0) -> Variant:
	return config_data.get(key, default)


## Get animation duration with speed multiplier applied
## Also applies reduced motion slowdown if enabled
## @param key: Duration key from polish_config.json
## @returns: Final duration with all multipliers applied
func get_duration(key: String) -> float:
	var base_duration = get_value(key, 1.0)
	var speed_mult = get_value("animation_speed_multiplier", 1.0)
	var final_duration = base_duration * speed_mult

	# Apply reduced motion if enabled (check if UserSettings exists)
	if _is_reduced_motion_enabled():
		var slowdown = get_value("reduced_motion_tween_slowdown", 0.3)
		final_duration *= slowdown

	return final_duration


## Get shake intensity with reduced motion support
## @param key: Shake intensity key (defaults to "shake_intensity")
## @returns: Shake intensity with reduced motion adjustment
func get_shake_intensity(key: String = "shake_intensity") -> float:
	var intensity = get_value(key, 0.05)

	# Reduce shake in reduced motion mode
	if _is_reduced_motion_enabled():
		intensity *= 0.5

	return intensity


## Get particle count with multiplier and reduced motion support
## @param base_count: Base number of particles
## @returns: Final particle count with all multipliers applied
func get_particle_count(base_count: int) -> int:
	var multiplier = get_value("particle_count_multiplier", 1.0)
	var count = int(base_count * multiplier)

	# Reduce particles in reduced motion mode
	if _is_reduced_motion_enabled():
		var reduction = get_value("reduced_motion_particle_reduction", 0.7)
		count = int(count * reduction)

	return count


# -----------------------------------------------------------------------------
# Private Helpers
# -----------------------------------------------------------------------------

## Check if reduced motion mode is enabled
## Safely checks for UserSettings autoload existence (Story 5.6 dependency)
## @returns: true if reduced motion is enabled, false otherwise
func _is_reduced_motion_enabled() -> bool:
	# Check if UserSettings autoload exists (will be created in Story 5.6)
	if not has_node("/root/UserSettings"):
		return false

	var user_settings = get_node("/root/UserSettings")
	if not "reduced_motion_enabled" in user_settings:
		return false

	return user_settings.reduced_motion_enabled


## Load default configuration values as fallback
## Used when polish_config.json is missing or invalid
func _load_defaults() -> void:
	config_data = {
		"shake_intensity": 0.05,
		"particle_count_multiplier": 1.0,
		"animation_speed_multiplier": 1.0,

		"reveal_buildup_duration": 0.5,
		"card_flip_duration": 0.8,
		"reveal_explosion_duration": 1.0,
		"reveal_pause_duration": 0.7,
		"reveal_shake_intensity": 0.08,

		"damage_shake_intensity": 0.03,
		"attack_animation_duration": 0.6,
		"damage_particle_count": 25,
		"card_play_animation_duration": 0.4,
		"dice_roll_duration": 1.2,

		"reduced_motion_particle_reduction": 0.7,
		"reduced_motion_tween_slowdown": 0.3
	}
	push_warning("[PolishConfig] Using default configuration values")
	config_changed.emit()
