## UserSettings - User preferences persistence autoload (Singleton)
## Manages user settings like expansion toggle, persisted in user://settings.json
extends Node
class_name UserSettingsClass


# Signals
signal expansion_toggle_changed(include_expansion: bool)
signal volume_changed(volume_type: String, value: float)


# Settings properties
var include_expansion: bool = true  # Default: full roster (base + expansion)

# Audio settings
var master_volume: float = 1.0  # 0.0 to 1.0
var sfx_volume: float = 1.0     # 0.0 to 1.0
var music_volume: float = 0.8   # 0.0 to 1.0 (default slightly lower)


func _ready() -> void:
	load_settings()
	print("[UserSettings] Initialized")


## Load settings from user://settings.json with graceful fallback to defaults
func load_settings() -> void:
	var file = FileAccess.open("user://settings.json", FileAccess.READ)
	if file == null:
		print("[UserSettings] No settings file found - using defaults")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_warning("[UserSettings] Failed to parse settings JSON - using defaults: %s" % json.get_error_message())
		return

	var data = json.data

	# Validate and load include_expansion
	if data.has("include_expansion"):
		if typeof(data.include_expansion) == TYPE_BOOL:
			include_expansion = data.include_expansion
		else:
			push_warning("[UserSettings] Invalid type for include_expansion (expected bool) - using default")

	# Validate and load audio volumes
	if data.has("master_volume"):
		if typeof(data.master_volume) == TYPE_FLOAT or typeof(data.master_volume) == TYPE_INT:
			master_volume = clamp(float(data.master_volume), 0.0, 1.0)
		else:
			push_warning("[UserSettings] Invalid type for master_volume - using default")

	if data.has("sfx_volume"):
		if typeof(data.sfx_volume) == TYPE_FLOAT or typeof(data.sfx_volume) == TYPE_INT:
			sfx_volume = clamp(float(data.sfx_volume), 0.0, 1.0)
		else:
			push_warning("[UserSettings] Invalid type for sfx_volume - using default")

	if data.has("music_volume"):
		if typeof(data.music_volume) == TYPE_FLOAT or typeof(data.music_volume) == TYPE_INT:
			music_volume = clamp(float(data.music_volume), 0.0, 1.0)
		else:
			push_warning("[UserSettings] Invalid type for music_volume - using default")

	print("[UserSettings] Loaded settings: include_expansion=%s, volumes=(M:%.2f, SFX:%.2f, Music:%.2f)" % [include_expansion, master_volume, sfx_volume, music_volume])


## Save settings to user://settings.json
func save_settings() -> void:
	var data = {
		"include_expansion": include_expansion,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume
	}

	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file == null:
		push_error("[UserSettings] Failed to save settings - could not open file for writing")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("[UserSettings] Settings saved: include_expansion=%s, volumes=(M:%.2f, SFX:%.2f, Music:%.2f)" % [include_expansion, master_volume, sfx_volume, music_volume])


## Set expansion enabled state (with auto-save and signal emission)
func set_expansion_enabled(enabled: bool) -> void:
	if include_expansion == enabled:
		return  # No change - skip save and signal

	include_expansion = enabled
	save_settings()
	expansion_toggle_changed.emit(include_expansion)
	print("[UserSettings] Expansion toggle changed: %s" % enabled)


## Set master volume (with auto-save, signal emission, and AudioManager update)
func set_master_volume(value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	if abs(master_volume - value) < 0.01:
		return  # No significant change

	master_volume = value
	save_settings()
	AudioManager.set_master_volume(master_volume)
	volume_changed.emit("master", master_volume)
	print("[UserSettings] Master volume changed: %.2f" % master_volume)


## Set SFX volume (with auto-save, signal emission, and AudioManager update)
func set_sfx_volume(value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	if abs(sfx_volume - value) < 0.01:
		return  # No significant change

	sfx_volume = value
	save_settings()
	AudioManager.set_sfx_volume(sfx_volume)
	volume_changed.emit("sfx", sfx_volume)
	print("[UserSettings] SFX volume changed: %.2f" % sfx_volume)


## Set music volume (with auto-save, signal emission, and AudioManager update)
func set_music_volume(value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	if abs(music_volume - value) < 0.01:
		return  # No significant change

	music_volume = value
	save_settings()
	AudioManager.set_music_volume(music_volume)
	volume_changed.emit("music", music_volume)
	print("[UserSettings] Music volume changed: %.2f" % music_volume)


## Generic getter for settings (for compatibility)
func get_setting(key: String, default_value):
	match key:
		"master_volume":
			return master_volume
		"sfx_volume":
			return sfx_volume
		"music_volume":
			return music_volume
		"include_expansion":
			return include_expansion
		_:
			push_warning("[UserSettings] Unknown setting key: %s - returning default" % key)
			return default_value
