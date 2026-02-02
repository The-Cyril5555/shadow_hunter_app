## SettingsDemo - Demo for audio settings and accessibility controls
## Tests volume sliders, persistence, and reduced motion toggle
class_name SettingsDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var settings_menu_container: Control = $SettingsMenuContainer
@onready var open_settings_button: Button = $VBoxContainer/OpenSettingsButton
@onready var test_sfx_button: Button = $VBoxContainer/TestSFXButton
@onready var show_values_button: Button = $VBoxContainer/ShowValuesButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect buttons
	open_settings_button.pressed.connect(_on_open_settings_pressed)
	test_sfx_button.pressed.connect(_on_test_sfx_pressed)
	show_values_button.pressed.connect(_on_show_values_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_status_label()

	print("[SettingsDemo] Demo ready")


# -----------------------------------------------------------------------------
# Button Handlers
# -----------------------------------------------------------------------------
func _on_open_settings_pressed() -> void:
	# Load and instantiate settings menu
	var settings_scene = load("res://scenes/ui/screens/settings_menu.tscn")
	if not settings_scene:
		push_error("[SettingsDemo] Failed to load settings_menu.tscn")
		return

	# Clear existing settings menu if any
	for child in settings_menu_container.get_children():
		child.queue_free()

	# Instantiate new settings menu
	var settings_menu = settings_scene.instantiate()
	settings_menu_container.add_child(settings_menu)

	print("[SettingsDemo] Opened settings menu")


func _on_test_sfx_pressed() -> void:
	# Test SFX at current volume
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("card_draw")
		print("[SettingsDemo] Played test SFX")
	else:
		print("[SettingsDemo] AudioManager.play_sfx not available")


func _on_show_values_pressed() -> void:
	_update_status_label()


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_status_label() -> void:
	var status_text = "Current Settings:\n"
	status_text += "Master Volume: %.0f%%\n" % (UserSettings.master_volume * 100.0)
	status_text += "SFX Volume: %.0f%%\n" % (UserSettings.sfx_volume * 100.0)
	status_text += "Music Volume: %.0f%%\n" % (UserSettings.music_volume * 100.0)
	status_text += "Reduced Motion: %s" % ("ON" if UserSettings.reduced_motion_enabled else "OFF")

	status_label.text = status_text
	print("[SettingsDemo] Status updated")
