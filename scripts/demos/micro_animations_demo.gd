## MicroAnimationsDemo - Demo for micro-animations and polish effects
## Tests hover, press, breathing, floating, and rotation animations
class_name MicroAnimationsDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var hover_button: Button = $VBoxContainer/DemoButtons/HoverButton
@onready var press_button: Button = $VBoxContainer/DemoButtons/PressButton
@onready var breathing_panel: Panel = $VBoxContainer/IdleDemo/BreathingPanel
@onready var floating_panel: Panel = $VBoxContainer/IdleDemo/FloatingPanel
@onready var rotation_panel: Panel = $VBoxContainer/IdleDemo/RotationPanel

@onready var reduced_motion_toggle: CheckButton = $VBoxContainer/ReducedMotionToggle
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var breathing_tween: Tween = null
var floating_tween: Tween = null
var rotation_tween: Tween = null


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect buttons
	hover_button.mouse_entered.connect(_on_hover_button_mouse_entered)
	hover_button.mouse_exited.connect(_on_hover_button_mouse_exited)
	press_button.pressed.connect(_on_press_button_pressed)

	reduced_motion_toggle.toggled.connect(_on_reduced_motion_toggled)
	back_button.pressed.connect(_on_back_pressed)

	# Start idle animations
	_start_idle_animations()

	print("[MicroAnimationsDemo] Demo ready")


# -----------------------------------------------------------------------------
# Hover Effects
# -----------------------------------------------------------------------------
func _on_hover_button_mouse_entered() -> void:
	AnimationHelper.hover_in(hover_button)
	print("[Demo] Hover in")


func _on_hover_button_mouse_exited() -> void:
	AnimationHelper.hover_out(hover_button)
	print("[Demo] Hover out")


# -----------------------------------------------------------------------------
# Press Effect
# -----------------------------------------------------------------------------
func _on_press_button_pressed() -> void:
	AnimationHelper.press_effect(press_button)
	print("[Demo] Press effect")


# -----------------------------------------------------------------------------
# Idle Animations
# -----------------------------------------------------------------------------
func _start_idle_animations() -> void:
	# Stop existing animations
	_stop_idle_animations()

	# Start breathing (scale pulse)
	breathing_tween = AnimationHelper.start_breathing(breathing_panel)

	# Start floating (vertical movement)
	floating_tween = AnimationHelper.start_floating(floating_panel, 0.5)

	# Start gentle rotation
	rotation_tween = AnimationHelper.start_gentle_rotation(rotation_panel, true)

	print("[Demo] Started idle animations")


func _stop_idle_animations() -> void:
	AnimationHelper.stop_idle_animation(breathing_tween)
	AnimationHelper.stop_idle_animation(floating_tween)
	AnimationHelper.stop_idle_animation(rotation_tween)

	# Reset to default state
	if is_instance_valid(breathing_panel):
		breathing_panel.scale = Vector2.ONE
	if is_instance_valid(floating_panel):
		floating_panel.position.y = 200  # Reset to original Y
	if is_instance_valid(rotation_panel):
		rotation_panel.rotation_degrees = 0.0


# -----------------------------------------------------------------------------
# Settings
# -----------------------------------------------------------------------------
func _on_reduced_motion_toggled(enabled: bool) -> void:
	UserSettings.set_reduced_motion(enabled)

	# Restart idle animations (will be null if reduced motion)
	_start_idle_animations()

	print("[Demo] Reduced motion: %s" % ("ON" if enabled else "OFF"))


# -----------------------------------------------------------------------------
# Navigation
# -----------------------------------------------------------------------------
func _on_back_pressed() -> void:
	_stop_idle_animations()
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)
