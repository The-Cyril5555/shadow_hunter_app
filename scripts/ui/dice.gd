## Dice - Dice rolling component for Shadow Hunter
## Displays two D6 dice with roll animation and results
## Refactored: Now uses PolishConfig for timing and AnimationHelper for rotations
class_name Dice
extends Control


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal dice_rolled(sum: int)


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var dice1_result: int = 0
var dice2_result: int = 0
var is_rolling: bool = false


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var dice1_container: Control = $HBoxContainer/Dice1Container
@onready var dice2_container: Control = $HBoxContainer/Dice2Container
@onready var dice1_label: Label = $HBoxContainer/Dice1Container/DiceLabel
@onready var dice2_label: Label = $HBoxContainer/Dice2Container/DiceLabel
@onready var result_label: Label = $ResultLabel


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Roll the dice with animation using PolishConfig timing
func roll() -> void:
	if is_rolling:
		return  # Prevent double-rolling

	is_rolling = true

	# Play dice roll sound
	AudioManager.play_sfx("dice_roll")

	# Generate random results (1-6)
	dice1_result = randi() % 6 + 1
	dice2_result = randi() % 6 + 1

	# Clear previous results during roll
	result_label.text = "Rolling..."

	# Get dice roll duration from PolishConfig
	var roll_duration = PolishConfig.get_duration("dice_roll_duration")
	var half_duration = roll_duration * 0.5

	# Animate dice 1 with scale pulse during rotation
	var tween1 = create_tween()
	tween1.set_parallel(false)
	tween1.tween_property(dice1_container, "rotation_degrees", 720, roll_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	tween1.parallel().tween_property(dice1_container, "scale", Vector2(1.2, 1.2), half_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	tween1.tween_property(dice1_container, "scale", Vector2(1.0, 1.0), half_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	# Animate dice 2 (slightly offset timing for variety)
	var tween2 = create_tween()
	tween2.set_parallel(false)
	tween2.tween_property(dice2_container, "rotation_degrees", 720, roll_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	tween2.parallel().tween_property(dice2_container, "scale", Vector2(1.2, 1.2), half_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	tween2.tween_property(dice2_container, "scale", Vector2(1.0, 1.0), half_duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	# Wait for animation to finish
	await tween1.finished

	# Play dice land sound
	AudioManager.play_sfx("dice_land")

	# Reset rotation for clean display
	dice1_container.rotation_degrees = 0
	dice2_container.rotation_degrees = 0

	# Update dice faces
	dice1_label.text = str(dice1_result)
	dice2_label.text = str(dice2_result)

	# Display sum
	var sum = dice1_result + dice2_result
	result_label.text = "Total: %d" % sum

	is_rolling = false

	# Emit signal
	dice_rolled.emit(sum)

	print("[Dice] Rolled %d + %d = %d" % [dice1_result, dice2_result, sum])


## Get current dice results
func get_results() -> Dictionary:
	return {
		"dice1": dice1_result,
		"dice2": dice2_result,
		"sum": dice1_result + dice2_result
	}


## Reset dice display
func reset() -> void:
	dice1_result = 0
	dice2_result = 0
	dice1_label.text = "?"
	dice2_label.text = "?"
	result_label.text = "Ready to roll"
	is_rolling = false


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	reset()
