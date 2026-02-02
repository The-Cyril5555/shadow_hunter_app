## SettingsMenu - Settings UI controller
## Manages audio volume sliders and accessibility settings
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var music_slider: HSlider = %MusicSlider

@onready var master_value_label: Label = %MasterValueLabel
@onready var sfx_value_label: Label = %SFXValueLabel
@onready var music_value_label: Label = %MusicValueLabel

@onready var reduced_motion_checkbox: CheckBox = %ReducedMotionCheckBox

@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Load current settings into UI
	_load_current_settings()

	# Connect signals
	master_slider.value_changed.connect(_on_master_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)

	reduced_motion_checkbox.toggled.connect(_on_reduced_motion_toggled)

	reset_button.pressed.connect(_on_reset_pressed)
	back_button.pressed.connect(_on_back_pressed)

	print("[SettingsMenu] Settings menu ready")


## Load current UserSettings values into UI controls
func _load_current_settings() -> void:
	# Convert 0.0-1.0 to 0-100 for sliders
	master_slider.value = UserSettings.master_volume * 100.0
	sfx_slider.value = UserSettings.sfx_volume * 100.0
	music_slider.value = UserSettings.music_volume * 100.0

	# Update labels
	master_value_label.text = "%d%%" % master_slider.value
	sfx_value_label.text = "%d%%" % sfx_slider.value
	music_value_label.text = "%d%%" % music_slider.value

	# Load accessibility settings
	reduced_motion_checkbox.button_pressed = UserSettings.reduced_motion_enabled

	print("[SettingsMenu] Loaded settings: Master=%.0f%%, SFX=%.0f%%, Music=%.0f%%, ReducedMotion=%s" % [
		master_slider.value,
		sfx_slider.value,
		music_slider.value,
		reduced_motion_checkbox.button_pressed
	])


# -----------------------------------------------------------------------------
# Volume Slider Handlers
# -----------------------------------------------------------------------------
func _on_master_slider_changed(value: float) -> void:
	# Convert 0-100 to 0.0-1.0
	var volume = value / 100.0
	UserSettings.set_master_volume(volume)

	# Update label
	master_value_label.text = "%d%%" % value

	print("[SettingsMenu] Master volume: %d%%" % value)


func _on_sfx_slider_changed(value: float) -> void:
	var volume = value / 100.0
	UserSettings.set_sfx_volume(volume)

	sfx_value_label.text = "%d%%" % value

	# Play test sound at new volume
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("card_draw")

	print("[SettingsMenu] SFX volume: %d%%" % value)


func _on_music_slider_changed(value: float) -> void:
	var volume = value / 100.0
	UserSettings.set_music_volume(volume)

	music_value_label.text = "%d%%" % value

	print("[SettingsMenu] Music volume: %d%%" % value)


# -----------------------------------------------------------------------------
# Accessibility Handlers
# -----------------------------------------------------------------------------
func _on_reduced_motion_toggled(enabled: bool) -> void:
	UserSettings.set_reduced_motion(enabled)
	print("[SettingsMenu] Reduced motion: %s" % ("ON" if enabled else "OFF"))


# -----------------------------------------------------------------------------
# Button Handlers
# -----------------------------------------------------------------------------
func _on_reset_pressed() -> void:
	# Reset to default values (100% master, 100% SFX, 80% music)
	master_slider.value = 100.0
	sfx_slider.value = 100.0
	music_slider.value = 80.0
	reduced_motion_checkbox.button_pressed = false

	# Apply (triggers value_changed signals)
	UserSettings.set_master_volume(1.0)
	UserSettings.set_sfx_volume(1.0)
	UserSettings.set_music_volume(0.8)
	UserSettings.set_reduced_motion(false)

	# Update labels
	master_value_label.text = "100%"
	sfx_value_label.text = "100%"
	music_value_label.text = "80%"

	print("[SettingsMenu] Settings reset to defaults")


func _on_back_pressed() -> void:
	# Settings are auto-saved by UserSettings, so just go back
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)
	print("[SettingsMenu] Returning to main menu")
