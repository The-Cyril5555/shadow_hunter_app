## ActiveAbilitySystem - Manages player-triggered active abilities
##
## Handles manual activation, targeting, validation, and effect application
## for character active abilities (Franklin's Lightning, Allie's Mother's Love, etc.)
##
## Features:
## - "Once per game" usage tracking
## - Revelation requirements
## - Phase/zone constraints validation
## - Target selection support
## - 3 trigger types: manual, on_turn_start, on_attack
##
## Pattern: Singleton system attached to GameState
## Usage: GameState.active_ability_system.activate_ability(player, targets)
class_name ActiveAbilitySystem
extends Node


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when ability is successfully activated
signal ability_activated(player: Player, ability_name: String, targets: Array, effect: Dictionary)

## Emitted when ability activation fails validation
signal ability_activation_failed(player: Player, reason: String)


# =============================================================================
# PROPERTIES
# =============================================================================

## Tracks which players have used their "once per game" abilities
## Dict[int, bool] - player_id -> has_used
var _ability_usage_tracker: Dictionary = {}

## Tracks disabled abilities (Ellen's "Chain of Forbidden Curse")
## Dict[int, bool] - player_id -> is_disabled
var _ability_disabled_tracker: Dictionary = {}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	print("[ActiveAbilitySystem] Initialized")


# =============================================================================
# PUBLIC METHODS - Registration
# =============================================================================

## Register a player's active ability for tracking
func register_player_ability(player: Player) -> void:
	if not player or not player.ability_data:
		return

	var ability_type = player.ability_data.get("type", "")
	if ability_type != "active":
		return  # Only register active abilities

	# Initialize usage tracking
	_ability_usage_tracker[player.id] = false
	_ability_disabled_tracker[player.id] = false

	print("[ActiveAbilitySystem] Registered active ability for %s: %s" % [
		player.character_name,
		player.ability_data.get("name", "Unknown")
	])


# =============================================================================
# PUBLIC METHODS - Validation
# =============================================================================

## Check if player can activate their ability
## @returns: Dictionary with {can_activate: bool, reason: String}
func can_activate_ability(player: Player) -> Dictionary:
	if not player or not player.ability_data:
		return {"can_activate": false, "reason": "No ability data"}

	# Check if ability is active type
	if player.ability_data.get("type", "") != "active":
		return {"can_activate": false, "reason": "Not an active ability"}

	# Check if ability is disabled (Ellen's curse)
	if _ability_disabled_tracker.get(player.id, false):
		return {"can_activate": false, "reason": "Ability is permanently disabled"}

	# Check "once per game" constraint
	var usage = player.ability_data.get("usage", "unlimited")
	if usage == "once" and _ability_usage_tracker.get(player.id, false):
		return {"can_activate": false, "reason": "Already used (once per game)"}

	# Check revelation requirement
	var requires_reveal = player.ability_data.get("requires_reveal", false)
	if requires_reveal and not player.is_revealed:
		return {"can_activate": false, "reason": "Must be revealed first"}

	# All checks passed
	return {"can_activate": true, "reason": ""}


# =============================================================================
# PUBLIC METHODS - Activation
# =============================================================================

## Activate a player's active ability with targets
## @param player: Player activating ability
## @param targets: Array of targets (can be empty for self-targeting abilities)
## @returns: bool - true if activation succeeded
func activate_ability(player: Player, targets: Array = []) -> bool:
	# Validate activation
	var validation = can_activate_ability(player)
	if not validation.can_activate:
		ability_activation_failed.emit(player, validation.reason)
		push_warning("[ActiveAbilitySystem] Activation failed for %s: %s" % [
			player.character_name,
			validation.reason
		])
		return false

	# Get ability details
	var ability_name = player.ability_data.get("name", "Unknown")
	var character_id = player.character_id

	# Apply ability effect based on character
	var effect = _apply_ability_effect(player, targets, character_id)

	if not effect.success:
		ability_activation_failed.emit(player, effect.error)
		return false

	# Mark as used if "once per game"
	var usage = player.ability_data.get("usage", "unlimited")
	if usage == "once":
		_ability_usage_tracker[player.id] = true
		player.ability_used = true
		print("[ActiveAbilitySystem] Marked %s's ability as used" % player.character_name)

	# Emit success signal
	ability_activated.emit(player, ability_name, targets, effect)

	print("[ActiveAbilitySystem] %s activated '%s' on %d targets" % [
		player.character_name,
		ability_name,
		targets.size()
	])

	return true


## Disable a player's ability permanently (Ellen's curse effect)
func disable_ability(player: Player) -> void:
	_ability_disabled_tracker[player.id] = true
	player.ability_disabled = true
	print("[ActiveAbilitySystem] Disabled ability for %s" % player.character_name)


# =============================================================================
# PRIVATE METHODS - Ability Effects
# =============================================================================

## Apply the specific effect for each character's ability
## @returns: Dictionary with {success: bool, effect_type: String, error: String}
func _apply_ability_effect(player: Player, targets: Array, character_id: String) -> Dictionary:
	match character_id:
		"franklin":
			return _apply_franklin_lightning(player, targets)

		"george":
			return _apply_george_demolish(player, targets)

		"allie":
			return _apply_allie_mothers_love(player)

		"ellen":
			return _apply_ellen_curse(player, targets)

		"fuka":
			return _apply_fuka_dynamite_nurse(player, targets)

		"gregor":
			return _apply_gregor_ghostly_barrier(player)

		"wight":
			return _apply_wight_multiplication(player)

		"ultra_soul":
			return _apply_ultra_soul_murder_ray(player)

		"agnes":
			return _apply_agnes_capriccio(player)

		"david":
			return _apply_david_grave_digger(player, targets)

		_:
			return {
				"success": false,
				"effect_type": "unknown",
				"error": "Ability not implemented for character: %s" % character_id
			}


## Franklin "Lightning" - Once per game, roll d6 to damage a target
func _apply_franklin_lightning(player: Player, targets: Array) -> Dictionary:
	if targets.size() != 1:
		return {"success": false, "effect_type": "damage", "error": "Requires exactly 1 target"}

	var target = targets[0] as Player
	if not target:
		return {"success": false, "effect_type": "damage", "error": "Invalid target"}

	# Roll d6 for damage
	var damage = randi() % 6 + 1
	target.take_damage(damage, player)

	print("[ActiveAbilitySystem] Franklin's Lightning dealt %d damage (d6) to %s" % [damage, target.character_name])

	return {
		"success": true,
		"effect_type": "damage",
		"damage": damage,
		"dice": "d6"
	}


## George "Demolish" - Once per game, roll d4 to damage a target
func _apply_george_demolish(player: Player, targets: Array) -> Dictionary:
	if targets.size() != 1:
		return {"success": false, "effect_type": "damage", "error": "Requires exactly 1 target"}

	var target = targets[0] as Player
	if not target:
		return {"success": false, "effect_type": "damage", "error": "Invalid target"}

	# Roll d4 for damage
	var damage = randi() % 4 + 1
	target.take_damage(damage, player)

	print("[ActiveAbilitySystem] George's Demolish dealt %d damage (d4) to %s" % [damage, target.character_name])

	return {
		"success": true,
		"effect_type": "damage",
		"damage": damage,
		"dice": "d4"
	}


## Allie "Mother's Love" - Once per game, fully heal all damage
func _apply_allie_mothers_love(player: Player) -> Dictionary:
	var old_hp = player.hp
	player.hp = player.hp_max

	print("[ActiveAbilitySystem] Allie's Mother's Love: healed from %d to %d HP" % [old_hp, player.hp])

	return {
		"success": true,
		"effect_type": "full_heal",
		"old_hp": old_hp,
		"new_hp": player.hp
	}


## Ellen "Chain of Forbidden Curse" - Permanently disable target's ability
func _apply_ellen_curse(player: Player, targets: Array) -> Dictionary:
	if targets.size() != 1:
		return {"success": false, "effect_type": "disable", "error": "Requires exactly 1 target"}

	var target = targets[0] as Player
	if not target:
		return {"success": false, "effect_type": "disable", "error": "Invalid target"}

	# Disable target's ability
	disable_ability(target)

	print("[ActiveAbilitySystem] Ellen disabled %s's ability permanently" % target.character_name)

	return {
		"success": true,
		"effect_type": "disable",
		"disabled_player": target.character_name
	}


## Fuka "Dynamite Nurse" - Set any character's damage to exactly 7 points
func _apply_fuka_dynamite_nurse(player: Player, targets: Array) -> Dictionary:
	if targets.size() != 1:
		return {"success": false, "effect_type": "damage_set", "error": "Requires exactly 1 target"}

	var target = targets[0] as Player
	if not target:
		return {"success": false, "effect_type": "damage_set", "error": "Invalid target"}

	# Set damage to exactly 7: hp = hp_max - 7
	var old_hp = target.hp
	var new_hp = target.hp_max - 7
	target.hp = max(0, new_hp)

	print("[ActiveAbilitySystem] Fuka set %s's damage to 7 (HP: %d -> %d)" % [
		target.character_name, old_hp, target.hp
	])

	return {
		"success": true,
		"effect_type": "damage_set",
		"target": target.character_name,
		"old_hp": old_hp,
		"new_hp": target.hp
	}


## Gregor "Ghostly Barrier" - Prevent all damage until next turn
func _apply_gregor_ghostly_barrier(player: Player) -> Dictionary:
	player.set_meta("shielded", true)

	print("[ActiveAbilitySystem] Gregor activated Ghostly Barrier (shielded until next turn)")

	return {
		"success": true,
		"effect_type": "shield",
	}


## Wight "Multiplication" - Gain extra turns equal to dead character count
func _apply_wight_multiplication(player: Player) -> Dictionary:
	var dead_count = 0
	for p in GameState.players:
		if p.hp <= 0 and p.id != player.id:
			dead_count += 1

	player.set_meta("extra_turns", dead_count)

	print("[ActiveAbilitySystem] Wight gains %d extra turns (%d dead characters)" % [
		dead_count, dead_count
	])

	return {
		"success": true,
		"effect_type": "extra_turns",
		"extra_turns": dead_count
	}


## Ultra Soul "Murder Ray" - Inflict 3 damage to all characters at the Underworld
func _apply_ultra_soul_murder_ray(player: Player) -> Dictionary:
	var hit_players: Array = []
	for p in GameState.players:
		if p.position_zone == "underworld" and p.id != player.id and p.hp > 0:
			p.take_damage(3, player)
			hit_players.append(p.character_name if p.is_revealed else PlayerColors.get_label(p))

	print("[ActiveAbilitySystem] Ultra Soul's Murder Ray hit %d players at Underworld" % hit_players.size())

	return {
		"success": true,
		"effect_type": "area_damage",
		"damage": 3,
		"hit_count": hit_players.size(),
		"hit_players": hit_players
	}


## Agnes "Capriccio" - Swap attack target direction (right neighbor -> left)
func _apply_agnes_capriccio(player: Player) -> Dictionary:
	player.set_meta("capriccio_active", true)

	print("[ActiveAbilitySystem] Agnes activated Capriccio (target direction swapped)")

	return {
		"success": true,
		"effect_type": "target_swap",
	}


## David "Grave Digger" - Obtain an equipment card from discard piles
## @param targets: Array with a single Card element (chosen equipment from discard)
func _apply_david_grave_digger(player: Player, targets: Array) -> Dictionary:
	if targets.size() != 1:
		return {"success": false, "effect_type": "equip_discard", "error": "Requires exactly 1 equipment card"}

	var card = targets[0]
	if not card or not card is Card:
		return {"success": false, "effect_type": "equip_discard", "error": "Invalid card"}

	# Equip the card directly
	player.equipment.append(card)

	print("[ActiveAbilitySystem] David equipped %s from discard" % card.name)

	return {
		"success": true,
		"effect_type": "equip_discard",
		"card_name": card.name
	}


# =============================================================================
# UTILITY METHODS
# =============================================================================

## Check if player has used their ability (for UI display)
func has_used_ability(player: Player) -> bool:
	return _ability_usage_tracker.get(player.id, false)


## Check if player's ability is disabled (for UI display)
func is_ability_disabled(player: Player) -> bool:
	return _ability_disabled_tracker.get(player.id, false)


## Reset all ability usage (for new game)
func reset_all_abilities() -> void:
	_ability_usage_tracker.clear()
	_ability_disabled_tracker.clear()
	print("[ActiveAbilitySystem] Reset all ability usage")
