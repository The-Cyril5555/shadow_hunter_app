## UserSettings - User preferences persistence autoload (Singleton)
## Manages user settings like expansion toggle, persisted in user://settings.json
extends Node
class_name UserSettingsClass


# Signals
signal expansion_toggle_changed(include_expansion: bool)
signal volume_changed(volume_type: String, value: float)
signal accessibility_changed(setting: String, value)
signal locale_changed(new_locale: String)
signal fullscreen_changed(enabled: bool)


# Settings properties
var include_expansion: bool = true  # Default: full roster (base + expansion)

# Audio settings
var master_volume: float = 1.0  # 0.0 to 1.0
var sfx_volume: float = 1.0     # 0.0 to 1.0
var music_volume: float = 0.8   # 0.0 to 1.0 (default slightly lower)

# Accessibility settings
var reduced_motion_enabled: bool = false  # Disable/reduce animations
var colorblind_mode: String = "none"  # "none", "deuteranopia", "protanopia", "tritanopia"
var text_size: String = "medium"  # "small" (12px), "medium" (16px), "large" (20px)

# Localization
var locale: String = "fr"  # "fr" or "en"

# Display
var fullscreen: bool = false

# Text size pixel mappings
const TEXT_SIZE_MAP: Dictionary = {
	"small": 12,
	"medium": 16,
	"large": 20,
}

# Colorblind-friendly symbols for factions (Okabe-Ito palette)
const COLORBLIND_SYMBOLS: Dictionary = {
	"hunter": "△",
	"shadow": "◇",
	"neutral": "○",
}

const COLORBLIND_MODES: Array[String] = ["none", "deuteranopia", "protanopia", "tritanopia"]
const TEXT_SIZES: Array[String] = ["small", "medium", "large"]
const LOCALES: Array[String] = ["fr", "en"]


func _ready() -> void:
	load_settings()
	apply_fullscreen()
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

	# Validate and load accessibility settings
	if data.has("reduced_motion_enabled"):
		if typeof(data.reduced_motion_enabled) == TYPE_BOOL:
			reduced_motion_enabled = data.reduced_motion_enabled
		else:
			push_warning("[UserSettings] Invalid type for reduced_motion_enabled - using default")

	if data.has("colorblind_mode"):
		if typeof(data.colorblind_mode) == TYPE_STRING and data.colorblind_mode in COLORBLIND_MODES:
			colorblind_mode = data.colorblind_mode
		else:
			push_warning("[UserSettings] Invalid colorblind_mode - using default")

	if data.has("text_size"):
		if typeof(data.text_size) == TYPE_STRING and data.text_size in TEXT_SIZES:
			text_size = data.text_size
		else:
			push_warning("[UserSettings] Invalid text_size - using default")

	if data.has("locale"):
		if typeof(data.locale) == TYPE_STRING and data.locale in LOCALES:
			locale = data.locale
		else:
			push_warning("[UserSettings] Invalid locale - using default")

	if data.has("fullscreen"):
		if typeof(data.fullscreen) == TYPE_BOOL:
			fullscreen = data.fullscreen
		else:
			push_warning("[UserSettings] Invalid type for fullscreen - using default")

	print("[UserSettings] Loaded settings: expansion=%s, colorblind=%s, text=%s, locale=%s" % [include_expansion, colorblind_mode, text_size, locale])


## Save settings to user://settings.json
func save_settings() -> void:
	var data = {
		"include_expansion": include_expansion,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"reduced_motion_enabled": reduced_motion_enabled,
		"colorblind_mode": colorblind_mode,
		"text_size": text_size,
		"locale": locale,
		"fullscreen": fullscreen,
	}

	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file == null:
		push_error("[UserSettings] Failed to save settings - could not open file for writing")
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()


## Set expansion enabled state (with auto-save and signal emission)
func set_expansion_enabled(enabled: bool) -> void:
	if include_expansion == enabled:
		return
	include_expansion = enabled
	save_settings()
	expansion_toggle_changed.emit(include_expansion)
	print("[UserSettings] Expansion toggle changed: %s" % enabled)


## Set master volume (with auto-save, signal emission, and AudioManager update)
func set_master_volume(value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	if abs(master_volume - value) < 0.01:
		return
	master_volume = value
	save_settings()
	AudioManager.set_master_volume(master_volume)
	volume_changed.emit("master", master_volume)


## Set SFX volume (with auto-save, signal emission, and AudioManager update)
func set_sfx_volume(value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	if abs(sfx_volume - value) < 0.01:
		return
	sfx_volume = value
	save_settings()
	AudioManager.set_sfx_volume(sfx_volume)
	volume_changed.emit("sfx", sfx_volume)


## Set music volume (with auto-save, signal emission, and AudioManager update)
func set_music_volume(value: float) -> void:
	value = clamp(value, 0.0, 1.0)
	if abs(music_volume - value) < 0.01:
		return
	music_volume = value
	save_settings()
	AudioManager.set_music_volume(music_volume)
	volume_changed.emit("music", music_volume)


## Set reduced motion enabled
func set_reduced_motion(enabled: bool) -> void:
	if reduced_motion_enabled == enabled:
		return
	reduced_motion_enabled = enabled
	save_settings()
	accessibility_changed.emit("reduced_motion", enabled)
	print("[UserSettings] Reduced motion: %s" % enabled)


## Set colorblind mode
func set_colorblind_mode(mode: String) -> void:
	if mode not in COLORBLIND_MODES:
		push_warning("[UserSettings] Invalid colorblind mode: %s" % mode)
		return
	if colorblind_mode == mode:
		return
	colorblind_mode = mode
	save_settings()
	accessibility_changed.emit("colorblind_mode", mode)
	print("[UserSettings] Colorblind mode: %s" % mode)


## Set text size
func set_text_size(size: String) -> void:
	if size not in TEXT_SIZES:
		push_warning("[UserSettings] Invalid text size: %s" % size)
		return
	if text_size == size:
		return
	text_size = size
	save_settings()
	accessibility_changed.emit("text_size", size)
	print("[UserSettings] Text size: %s" % size)


## Set locale
func set_locale(new_locale: String) -> void:
	if new_locale not in LOCALES:
		push_warning("[UserSettings] Invalid locale: %s" % new_locale)
		return
	if locale == new_locale:
		return
	locale = new_locale
	save_settings()
	locale_changed.emit(locale)
	print("[UserSettings] Locale: %s" % locale)


## Get the current text size in pixels
func get_text_size_px() -> int:
	return TEXT_SIZE_MAP.get(text_size, 16)


## Check if colorblind mode is active
func is_colorblind_active() -> bool:
	return colorblind_mode != "none"


## Get faction display with colorblind symbol if needed
func get_faction_display(faction: String) -> String:
	if is_colorblind_active():
		var symbol = COLORBLIND_SYMBOLS.get(faction, "")
		return "%s %s" % [symbol, faction.capitalize()]
	return faction.capitalize()


## Set fullscreen mode
func set_fullscreen(enabled: bool) -> void:
	if fullscreen == enabled:
		return
	fullscreen = enabled
	save_settings()
	apply_fullscreen()
	fullscreen_changed.emit(fullscreen)


## Apply fullscreen setting to the window
func apply_fullscreen() -> void:
	var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_MAXIMIZED
	DisplayServer.window_set_mode(mode)


## Generic getter for settings
func get_setting(key: String, default_value):
	match key:
		"master_volume": return master_volume
		"sfx_volume": return sfx_volume
		"music_volume": return music_volume
		"include_expansion": return include_expansion
		"reduced_motion_enabled": return reduced_motion_enabled
		"colorblind_mode": return colorblind_mode
		"text_size": return text_size
		"locale": return locale
		_:
			push_warning("[UserSettings] Unknown setting key: %s" % key)
			return default_value
