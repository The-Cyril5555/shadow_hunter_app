## HandManager - Manages player hand operations
##
## Provides utilities for adding cards to hand, discarding from hand,
## and managing hand state across the game
##
## Features:
## - Add card to player hand
## - Discard card from hand to appropriate deck
## - Signal-based hand change notifications
## - Integration with DeckManager for discard routing
##
## Pattern: Utility class or system attached to GameState
## Usage: HandManager.add_to_hand(player, card), HandManager.discard_from_hand(player, card, decks)
class_name HandManager
extends RefCounted


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a player's hand changes (card added or removed)
signal hand_changed(player: Player, card: Card, action: String)


# =============================================================================
# PUBLIC METHODS - Add to Hand
# =============================================================================

## Add a card to a player's hand
## @param player: Player to add card to
## @param card: Card to add
## @returns: bool - true if added successfully
static func add_to_hand(player: Player, card: Card) -> bool:
	if not player or not card:
		push_error("[HandManager] Invalid player or card")
		return false

	# Add to hand array
	player.hand.append(card)

	print("[HandManager] Added '%s' to %s's hand (now %d cards)" % [
		card.name,
		player.display_name,
		player.hand.size()
	])

	return true


## Draw a card from a deck and add to player's hand
## @param player: Player to draw for
## @param deck_manager: DeckManager to draw from
## @returns: Card - the drawn card, or null if deck exhausted
static func draw_to_hand(player: Player, deck_manager: DeckManager) -> Card:
	if not player or not deck_manager:
		push_error("[HandManager] Invalid player or deck_manager")
		return null

	var card = deck_manager.draw_card()
	if card:
		add_to_hand(player, card)

	return card


# =============================================================================
# PUBLIC METHODS - Discard from Hand
# =============================================================================

## Discard a card from player's hand to appropriate deck discard pile
## @param player: Player discarding card
## @param card: Card to discard
## @param decks: Dictionary with deck_managers {"hermit": DeckManager, "white": DeckManager, "black": DeckManager}
## @returns: bool - true if discarded successfully
static func discard_from_hand(player: Player, card: Card, decks: Dictionary) -> bool:
	if not player or not card:
		push_error("[HandManager] Invalid player or card")
		return false

	# Check card is in player's hand
	var card_index = player.hand.find(card)
	if card_index == -1:
		push_warning("[HandManager] Card '%s' not in %s's hand" % [card.name, player.display_name])
		return false

	# Remove from hand
	player.hand.remove_at(card_index)

	# Determine which deck to discard to based on card.deck
	var deck_type = card.deck  # "hermit", "white", or "black"
	var deck_manager = decks.get(deck_type)

	if not deck_manager:
		push_error("[HandManager] No deck manager found for deck type: %s" % deck_type)
		return false

	# Add to deck's discard pile
	deck_manager.discard_card(card)

	print("[HandManager] Discarded '%s' from %s's hand to %s deck (hand: %d cards)" % [
		card.name,
		player.display_name,
		deck_type,
		player.hand.size()
	])

	return true


# =============================================================================
# PUBLIC METHODS - Hand Queries
# =============================================================================

## Get number of cards in player's hand
static func get_hand_size(player: Player) -> int:
	if not player:
		return 0
	return player.hand.size()


## Check if player has any cards in hand
static func has_cards(player: Player) -> bool:
	return get_hand_size(player) > 0


## Get all cards of a specific type from hand
static func get_cards_by_type(player: Player, card_type: String) -> Array[Card]:
	var matching_cards: Array[Card] = []

	if not player:
		return matching_cards

	for card in player.hand:
		if card.type == card_type:
			matching_cards.append(card)

	return matching_cards


## Get all equipment cards from hand
static func get_equipment_cards(player: Player) -> Array[Card]:
	return get_cards_by_type(player, "equipment")


# =============================================================================
# UTILITY METHODS
# =============================================================================

## Clear all cards from hand (for testing/reset)
static func clear_hand(player: Player) -> void:
	if not player:
		return

	var card_count = player.hand.size()
	player.hand.clear()

	print("[HandManager] Cleared %s's hand (%d cards removed)" % [
		player.display_name,
		card_count
	])
