## ActiveAbilitySystem - Manages player-triggered active abilities
##
## Handles manual activation, targeting, validation, and effect application
## for character active abilities (Franklin's Leadership, Vampire's Bloodthirst, etc.)
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
	_ability_usage_tracker[player.player_id] = false
	_ability_disabled_tracker[player.player_id] = false

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
	if _ability_disabled_tracker.get(player.player_id, false):
		return {"can_activate": false, "reason": "Ability is permanently disabled"}

	# Check "once per game" constraint
	var usage = player.ability_data.get("usage", "unlimited")
	if usage == "once" and _ability_usage_tracker.get(player.player_id, false):
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
		_ability_usage_tracker[player.player_id] = true
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
	_ability_disabled_tracker[player.player_id] = true
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
			return _apply_franklin_leadership(player, targets)

		"george":
			return _apply_george_demolition(player, targets)

		"vampire":
			return _apply_vampire_bloodthirst(player, targets)

		"emi":
			return _apply_emi_blessed(player)

		"ellen":
			return _apply_ellen_curse(player, targets)

		_:
			return {
				"success": false,
				"effect_type": "unknown",
				"error": "Ability not implemented for character: %s" % character_id
			}


## Franklin "Leadership" - Move any player to self's zone
func _apply_franklin_leadership(player: Player, targets: Array) -> Dictionary:
	if targets.size() != 1:
		return {"success": false, "effect_type": "movement", "error": "Requires exactly 1 target"}

	var target = targets[0] as Player
	if not target:
		return {"success": false, "effect_type": "movement", "error": "Invalid target"}

	# Move target to Franklin's zone
	var old_zone = target.position_zone
	target.position_zone = player.position_zone

	print("[ActiveAbilitySystem] Franklin moved %s from %s to %s" % [
		target.character_name,
		old_zone,
		player.current_zone
	])

	return {
		"success": true,
		"effect_type": "movement",
		"moved_player": target.character_name,
		"from_zone": old_zone,
		"to_zone": player.current_zone
	}


## George "Demolition" - Deal 3 damage to player in same zone, take 2 self-damage
func _apply_george_demolition(player: Player, targets: Array) -> Dictionary:
	if targets.size() != 1:
		return {"success": false, "effect_type": "damage", "error": "Requires exactly 1 target"}

	var target = targets[0] as Player
	if not target:
		return {"success": false, "effect_type": "damage", "error": "Invalid target"}

	# Check same zone
	if target.position_zone != player.position_zone:
		return {"success": false, "effect_type": "damage", "error": "Target must be in same zone"}

	# Apply damage
	target.take_damage(3, player)
	player.take_damage(2, player)  # Self-damage

	print("[ActiveAbilitySystem] George dealt 3 damage to %s and took 2 self-damage" % target.character_name)

	return {
		"success": true,
		"effect_type": "damage",
		"target_damage": 3,
		"self_damage": 2
	}


## Vampire "Bloodthirst" - Deal 1 damage to any player, heal 1
func _apply_vampire_bloodthirst(player: Player, targets: Array) -> Dictionary:
	if targets.size() != 1:
		return {"success": false, "effect_type": "damage_heal", "error": "Requires exactly 1 target"}

	var target = targets[0] as Player
	if not target:
		return {"success": false, "effect_type": "damage_heal", "error": "Invalid target"}

	# Deal damage and heal
	target.take_damage(1, player)
	player.heal(1)

	print("[ActiveAbilitySystem] Vampire dealt 1 damage to %s and healed 1 HP" % target.character_name)

	return {
		"success": true,
		"effect_type": "damage_heal",
		"damage": 1,
		"heal": 1
	}


## Emi "Blessed" - Add +1 damage to attack (handled by combat system)
func _apply_emi_blessed(player: Player) -> Dictionary:
	# This ability is actually triggered during combat
	# Return success as a confirmation that the bonus will be applied
	print("[ActiveAbilitySystem] Emi's Blessed activated (+1 damage this attack)")

	return {
		"success": true,
		"effect_type": "damage_boost",
		"damage_bonus": 1
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


# =============================================================================
# UTILITY METHODS
# =============================================================================

## Check if player has used their ability (for UI display)
func has_used_ability(player: Player) -> bool:
	return _ability_usage_tracker.get(player.player_id, false)


## Check if player's ability is disabled (for UI display)
func is_ability_disabled(player: Player) -> bool:
	return _ability_disabled_tracker.get(player.player_id, false)


## Reset all ability usage (for new game)
func reset_all_abilities() -> void:
	_ability_usage_tracker.clear()
	_ability_disabled_tracker.clear()
	print("[ActiveAbilitySystem] Reset all ability usage")
