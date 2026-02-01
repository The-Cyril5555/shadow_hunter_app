## CardReveal - Animated card reveal UI
## Shows drawn cards with smooth fade in/out animations using AnimationHelper
## Refactored: Now uses PolishConfig for timing and AnimationHelper for animations
class_name CardReveal
extends Control


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal card_reveal_finished()


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var panel: Panel = $Panel
@onready var card_name_label: Label = $Panel/MarginContainer/VBoxContainer/CardNameLabel
@onready var card_type_label: Label = $Panel/MarginContainer/VBoxContainer/CardTypeLabel
@onready var effect_label: Label = $Panel/MarginContainer/VBoxContainer/EffectLabel
@onready var deck_label: Label = $Panel/MarginContainer/VBoxContainer/DeckLabel


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Start hidden
	modulate.a = 0.0
	visible = false

	# Set initial scale for pop effect
	panel.scale = Vector2(0.8, 0.8)


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show card with animation sequence using AnimationHelper
func show_card(card: Card) -> void:
	# Populate card data
	card_name_label.text = card.name
	card_type_label.text = "Type: %s" % card.type.capitalize()
	effect_label.text = card.get_effect_description()
	deck_label.text = "Deck: %s" % card.deck.capitalize()

	# Make visible
	visible = true

	# Use AnimationHelper for fade in with pop effect
	AnimationHelper.fade_in_with_pop(self, "card_play_animation_duration")

	# Hold for display (using PolishConfig timing)
	var hold_duration = PolishConfig.get_value("card_play_animation_duration", 0.4) * 3.0  # 3x fade duration
	await get_tree().create_timer(hold_duration).timeout

	# Use AnimationHelper for fade out with shrink
	AnimationHelper.fade_out_with_shrink(self, "card_play_animation_duration")

	# Wait for fade out to complete
	await AnimationHelper.await_animation(self, "card_play_animation_duration")

	# Hide and reset
	visible = false
	panel.scale = Vector2(1.0, 1.0)  # Reset for next time
	card_reveal_finished.emit()

	print("[CardReveal] Card reveal animation completed for: %s" % card.name)
