## AnimationDemo - Interactive demonstration of AnimationHelper system
## Shows all standard animations with FPS counter and controls
## Used for testing and validating 60 FPS performance
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var fps_label: Label = %FPSLabel
@onready var test_target: Panel = %TestTarget
@onready var reduced_motion_check: CheckBox = %ReducedMotionCheck
@onready var speed_slider: HSlider = %SpeedHSlider
@onready var speed_value: Label = %SpeedValue

# Buttons
@onready var fade_in_button: Button = %FadeInButton
@onready var fade_out_button: Button = %FadeOutButton
@onready var scale_pulse_button: Button = %ScalePulseButton
@onready var scale_pop_button: Button = %ScalePopButton
@onready var slide_in_button: Button = %SlideInButton
@onready var shake_button: Button = %ShakeButton
@onready var fade_pop_button: Button = %FadePopButton
@onready var fade_shrink_button: Button = %FadeShrinkButton


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	print("[AnimationDemo] Demo scene loaded")

	# Initialize test target state
	test_target.modulate.a = 1.0
	test_target.scale = Vector2.ONE

	# Set initial speed slider value
	speed_value.text = "%.1fx" % speed_slider.value


func _process(_delta: float) -> void:
	# Update FPS counter
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


# -----------------------------------------------------------------------------
# Animation Triggers
# -----------------------------------------------------------------------------

## Trigger fade in animation
func _on_fade_in_pressed() -> void:
	print("[AnimationDemo] Testing fade_in")
	AnimationHelper.fade_in(test_target, "card_play_animation_duration")


## Trigger fade out animation
func _on_fade_out_pressed() -> void:
	print("[AnimationDemo] Testing fade_out")
	AnimationHelper.fade_out(test_target, "card_play_animation_duration")


## Trigger scale pulse animation
func _on_scale_pulse_pressed() -> void:
	print("[AnimationDemo] Testing scale_pulse")
	AnimationHelper.scale_pulse(test_target, 1.3, "card_play_animation_duration")


## Trigger scale pop animation
func _on_scale_pop_pressed() -> void:
	print("[AnimationDemo] Testing scale_pop")
	AnimationHelper.scale_pop(test_target, 1.4, "card_play_animation_duration")


## Trigger slide in animation
func _on_slide_in_pressed() -> void:
	print("[AnimationDemo] Testing slide_in")
	AnimationHelper.slide_in(test_target, Vector2(-200, 0), "card_play_animation_duration")


## Trigger shake animation
func _on_shake_pressed() -> void:
	print("[AnimationDemo] Testing shake")
	AnimationHelper.shake(test_target, "shake_intensity", 0.3)


## Trigger fade in with pop combo
func _on_fade_pop_pressed() -> void:
	print("[AnimationDemo] Testing fade_in_with_pop")
	AnimationHelper.fade_in_with_pop(test_target, "card_play_animation_duration")


## Trigger fade out with shrink combo
func _on_fade_shrink_pressed() -> void:
	print("[AnimationDemo] Testing fade_out_with_shrink")
	AnimationHelper.fade_out_with_shrink(test_target, "card_play_animation_duration")


# -----------------------------------------------------------------------------
# Settings Controls
# -----------------------------------------------------------------------------

## Toggle reduced motion mode simulation
func _on_reduced_motion_toggled(toggled_on: bool) -> void:
	print("[AnimationDemo] Reduced motion: %s" % ("ON" if toggled_on else "OFF"))

	# Check if UserSettings exists
	if not has_node("/root/UserSettings"):
		print("[AnimationDemo] WARNING: UserSettings autoload not found - reduced motion not functional")
		return

	# Set reduced motion in UserSettings
	var user_settings = get_node("/root/UserSettings")
	if "reduced_motion_enabled" in user_settings:
		user_settings.reduced_motion_enabled = toggled_on
	else:
		print("[AnimationDemo] WARNING: UserSettings.reduced_motion_enabled property not found")


## Adjust animation speed multiplier
func _on_speed_changed(value: float) -> void:
	speed_value.text = "%.1fx" % value

	# Update PolishConfig animation_speed_multiplier
	PolishConfig.config_data["animation_speed_multiplier"] = value

	print("[AnimationDemo] Animation speed changed to: %.1fx" % value)


## Return to main menu
func _on_back_pressed() -> void:
	print("[AnimationDemo] Returning to main menu")
	get_tree().change_scene_to_file("res://scenes/ui/screens/main_menu.tscn")


# -----------------------------------------------------------------------------
# Test Utilities
# -----------------------------------------------------------------------------

## Reset test target to default state
func _reset_target() -> void:
	test_target.modulate.a = 1.0
	test_target.scale = Vector2.ONE
	test_target.position = Vector2.ZERO
