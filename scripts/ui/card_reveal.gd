## CardReveal - Animated card reveal UI
## Shows drawn cards with fade-in animation, waits for player to click Continue
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
@onready var card_image: TextureRect = $Panel/MarginContainer/VBoxContainer/CardImage
@onready var card_name_label: Label = $Panel/MarginContainer/VBoxContainer/CardNameLabel
@onready var card_type_label: Label = $Panel/MarginContainer/VBoxContainer/CardTypeLabel
@onready var effect_label: Label = $Panel/MarginContainer/VBoxContainer/EffectLabel
@onready var deck_label: Label = $Panel/MarginContainer/VBoxContainer/DeckLabel
@onready var continue_button: Button = $Panel/MarginContainer/VBoxContainer/ContinueButton


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	modulate.a = 0.0
	visible = false
	panel.scale = Vector2(0.8, 0.8)
	continue_button.pressed.connect(_on_continue_pressed)


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show card and wait for player to click Continue
func show_card(card: Card) -> void:
	# Load card image
	var texture = CardImageMapper.load_texture(CardImageMapper.get_card_image_path(card))
	if texture != null:
		card_image.texture = texture
		card_image.visible = true
	else:
		card_image.visible = false

	# Populate card data
	card_name_label.text = card.name
	card_type_label.text = "Type: %s" % card.type.capitalize()
	effect_label.text = card.get_effect_description()
	deck_label.text = "Deck: %s" % card.deck.capitalize()

	# Show with fade-in animation
	visible = true
	continue_button.visible = true
	AnimationHelper.fade_in_with_pop(self, "card_play_animation_duration")

	# Wait for player to click Continue
	await card_reveal_finished


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------

func _on_continue_pressed() -> void:
	# Fade out
	AnimationHelper.fade_out_with_shrink(self, "card_play_animation_duration")
	await AnimationHelper.await_animation(self, "card_play_animation_duration")

	# Hide and reset
	visible = false
	panel.scale = Vector2(1.0, 1.0)
	card_reveal_finished.emit()
