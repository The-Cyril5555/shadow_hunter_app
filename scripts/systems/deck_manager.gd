## DeckManager - Manages a single deck (draw pile + discard pile)
## Handles drawing cards, reshuffling, and deck state
class_name DeckManager
extends RefCounted


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal card_drawn(card: Card)
signal deck_reshuffled()
signal deck_exhausted()


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var deck_type: String = ""  # "hermit", "white", "black"
var draw_pile: Array = []   # Array of Card instances
var discard_pile: Array = []


# -----------------------------------------------------------------------------
# Initialization
# -----------------------------------------------------------------------------

## Initialize deck from card data
func initialize_from_data(cards_data: Array) -> void:
	for card_data in cards_data:
		for i in range(card_data.get("copies_in_deck", 1)):
			var card = Card.new()
			card.from_dict(card_data)
			draw_pile.append(card)

	shuffle_draw_pile()
	print("[DeckManager] Initialized %s deck: %d cards" % [deck_type, draw_pile.size()])


## Shuffle the draw pile
func shuffle_draw_pile() -> void:
	draw_pile.shuffle()
	AudioManager.play_sfx("card_shuffle")


# -----------------------------------------------------------------------------
# Card Drawing
# -----------------------------------------------------------------------------

## Draw a card from the deck
func draw_card() -> Card:
	# If draw pile empty, reshuffle discard into draw pile
	if draw_pile.is_empty():
		reshuffle_discard_into_deck()

	# If still empty after reshuffle, deck is exhausted
	if draw_pile.is_empty():
		push_warning("[DeckManager] Deck %s exhausted" % deck_type)
		deck_exhausted.emit()
		return null

	var card = draw_pile.pop_front()
	AudioManager.play_sfx("card_draw")
	card_drawn.emit(card)
	return card


## Reshuffle discard pile back into draw pile
func reshuffle_discard_into_deck() -> void:
	if discard_pile.is_empty():
		return

	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()

	AudioManager.play_sfx("card_shuffle")
	deck_reshuffled.emit()
	print("[DeckManager] Reshuffled %s deck: %d cards" % [deck_type, draw_pile.size()])


## Add card to discard pile
func discard_card(card: Card) -> void:
	discard_pile.append(card)


# -----------------------------------------------------------------------------
# Getters
# -----------------------------------------------------------------------------

## Get total card count (draw pile only, for display)
func get_card_count() -> int:
	return draw_pile.size()


## Get discard pile count
func get_discard_count() -> int:
	return discard_pile.size()
