## EquipmentManager - Manages equipment operations
##
## Provides utilities for equipping cards, unequipping cards,
## and managing equipment state
##
## Features:
## - Equip cards from hand
## - Unequip cards to discard pile
## - Query equipment bonuses
## - Signal-based equipment change notifications
##
## Pattern: Utility class with static methods
## Usage: EquipmentManager.equip_from_hand(player, card, decks)
class_name EquipmentManager
extends RefCounted


# =============================================================================
# PUBLIC METHODS - Equip/Unequip
# =============================================================================

## Equip a card from player's hand
## @param player: Player equipping the card
## @param card: Card to equip (must be type "equipment")
## @returns: bool - true if equipped successfully
static func equip_from_hand(player: Player, card: Card) -> bool:
	if not player or not card:
		push_error("[EquipmentManager] Invalid player or card")
		return false

	# Validate card type
	if card.type != "equipment":
		push_warning("[EquipmentManager] Cannot equip non-equipment card: %s" % card.name)
		return false

	# Check card is in player's hand
	var card_index = player.hand.find(card)
	if card_index == -1:
		push_warning("[EquipmentManager] Card '%s' not in %s's hand" % [card.name, player.display_name])
		return false

	# Remove from hand
	player.hand.remove_at(card_index)

	# Add to equipment
	player.equipment.append(card)

	print("[EquipmentManager] %s equipped '%s' (+%d %s)" % [
		player.display_name,
		card.name,
		card.get_effect_value(),
		card.get_effect_type()
	])

	return true


## Unequip a card and discard to appropriate deck
## @param player: Player unequipping the card
## @param card: Card to unequip
## @param decks: Dictionary with deck_managers {deck_type: DeckManager}
## @returns: bool - true if unequipped successfully
static func unequip_to_discard(player: Player, card: Card, decks: Dictionary) -> bool:
	if not player or not card:
		push_error("[EquipmentManager] Invalid player or card")
		return false

	# Check card is in player's equipment
	var card_index = player.equipment.find(card)
	if card_index == -1:
		push_warning("[EquipmentManager] Card '%s' not equipped on %s" % [card.name, player.display_name])
		return false

	# Remove from equipment
	player.equipment.remove_at(card_index)

	# Determine which deck to discard to based on card.deck
	var deck_type = card.deck  # "hermit", "white", or "black"
	var deck_manager = decks.get(deck_type)

	if not deck_manager:
		push_error("[EquipmentManager] No deck manager found for deck type: %s" % deck_type)
		return false

	# Add to deck's discard pile
	deck_manager.discard_card(card)

	print("[EquipmentManager] %s unequipped '%s' (discarded to %s deck)" % [
		player.display_name,
		card.name,
		deck_type
	])

	return true


# =============================================================================
# PUBLIC METHODS - Equipment Queries
# =============================================================================

## Get total attack damage bonus from equipment
## @param player: Player to check
## @returns: int - total attack bonus
static func get_total_attack_bonus(player: Player) -> int:
	if not player:
		return 0
	return player.get_attack_damage_bonus()


## Get total defense bonus from equipment
## @param player: Player to check
## @returns: int - total defense bonus
static func get_total_defense_bonus(player: Player) -> int:
	if not player:
		return 0
	return player.get_defense_bonus()


## Get breakdown of equipment bonuses by effect type
## @param player: Player to check
## @returns: Dictionary - {"damage": int, "defense": int, "heal": int}
static func get_equipment_breakdown(player: Player) -> Dictionary:
	var breakdown = {
		"damage": 0,
		"defense": 0,
		"heal": 0
	}

	if not player:
		return breakdown

	for card in player.equipment:
		var effect_type = card.get_effect_type()
		var effect_value = card.get_effect_value()

		if breakdown.has(effect_type):
			breakdown[effect_type] += effect_value

	return breakdown


## Get all equipment cards by effect type
## @param player: Player to check
## @param effect_type: Effect type to filter ("damage", "defense", "heal")
## @returns: Array[Card] - matching equipment cards
static func get_equipment_by_type(player: Player, effect_type: String) -> Array[Card]:
	var matching_cards: Array[Card] = []

	if not player:
		return matching_cards

	for card in player.equipment:
		if card.get_effect_type() == effect_type:
			matching_cards.append(card)

	return matching_cards


## Check if player has any equipment
static func has_equipment(player: Player) -> bool:
	if not player:
		return false
	return player.equipment.size() > 0


## Get equipment count
static func get_equipment_count(player: Player) -> int:
	if not player:
		return 0
	return player.equipment.size()
