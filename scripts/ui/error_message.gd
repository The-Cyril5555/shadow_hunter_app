## ErrorMessage - Error message display UI component
## Shows error messages to the user with auto-hide and animation.
## Refactored: Now uses AnimationHelper for fade animations with shake feedback
## Pattern: UI Component
class_name ErrorMessage
extends PanelContainer


# =============================================================================
# PROPERTIES
# =============================================================================

@onready var message_label: Label = $MarginContainer/MessageLabel
@onready var hide_timer: Timer = $HideTimer

## Duration before auto-hiding (seconds)
const AUTO_HIDE_DURATION: float = 3.0


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0

	# Setup timer
	hide_timer.wait_time = AUTO_HIDE_DURATION
	hide_timer.one_shot = true
	hide_timer.timeout.connect(_on_hide_timer_timeout)

	print("[ErrorMessage] Initialized")


# =============================================================================
# PUBLIC METHODS
# =============================================================================

## Show an error message to the user with AnimationHelper
func show_error(message: String) -> void:
	# Set message text
	message_label.text = message

	# Show panel
	visible = true

	# Fade in using AnimationHelper with shake feedback
	AnimationHelper.fade_in(self, "card_play_animation_duration")

	# Add shake effect for error emphasis
	AnimationHelper.shake(self, "damage_shake_intensity", 0.2)

	# Start auto-hide timer
	hide_timer.start()

	print("[ErrorMessage] Showing error: %s" % message)


## Hide the error message using AnimationHelper
func hide_message() -> void:
	# Fade out using AnimationHelper
	AnimationHelper.fade_out(self, "card_play_animation_duration")

	# Wait for animation to complete
	await AnimationHelper.await_animation(self, "card_play_animation_duration")

	# Hide panel
	visible = false

	print("[ErrorMessage] Hidden")


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Called when auto-hide timer expires
func _on_hide_timer_timeout() -> void:
	hide_message()
