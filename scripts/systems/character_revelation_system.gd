## CharacterRevelationSystem - Manages character revelation (voluntary and forced)
##
## Handles the dramatic moment when a character's identity is revealed,
## either voluntarily or forced by death/abilities
##
## Features:
## - Voluntary revelation request
## - Forced revelation on death
## - Revelation animation sequence
## - Queue management for multiple simultaneous revelations
## - Integration with PassiveAbilitySystem (on_reveal triggers)
##
## Pattern: System attached to GameState or as standalone
## Usage: revelation_system.reveal_character(player, voluntary)
class_name CharacterRevelationSystem
extends Node


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when revelation sequence starts
signal revelation_started(player: Player, voluntary: bool)

## Emitted when revelation sequence completes
signal revelation_completed(player: Player, voluntary: bool)

## Emitted when revelation is rejected (validation failed)
signal revelation_rejected(player: Player, reason: String)


# =============================================================================
# PROPERTIES
# =============================================================================

## Queue of pending revelations to process sequentially
var _revelation_queue: Array = []

## Currently playing revelation (to prevent overlaps)
var _current_revelation: Player = null

## Reference to AnimationOrchestrator for reveal sequences
var _animation_orchestrator: AnimationOrchestrator = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# AnimationOrchestrator is a static class, no instance needed
	print("[CharacterRevelationSystem] Initialized")


# =============================================================================
# PUBLIC METHODS - Revelation Requests
# =============================================================================

## Request character revelation (voluntary or forced)
## @param player: Player to reveal
## @param voluntary: true if player chose to reveal, false if forced (death, ability)
## @returns: bool - true if revelation initiated, false if rejected
func reveal_character(player: Player, voluntary: bool = true) -> bool:
	# Validate revelation
	var validation = _validate_revelation(player)
	if not validation.can_reveal:
		revelation_rejected.emit(player, validation.reason)
		push_warning("[CharacterRevelationSystem] Revelation rejected for %s: %s" % [
			player.character_name,
			validation.reason
		])
		return false

	# Add to queue
	_revelation_queue.append({
		"player": player,
		"voluntary": voluntary
	})

	print("[CharacterRevelationSystem] Queued revelation for %s (voluntary: %s)" % [
		player.character_name,
		voluntary
	])

	# Process queue if not currently revealing
	if _current_revelation == null:
		_process_next_revelation()

	return true


## Force revelation (used for death, Bryan's ability, etc.)
func force_reveal(player: Player) -> void:
	reveal_character(player, false)


# =============================================================================
# PRIVATE METHODS - Validation
# =============================================================================

## Validate if player can be revealed
func _validate_revelation(player: Player) -> Dictionary:
	if not player:
		return {"can_reveal": false, "reason": "Invalid player"}

	# Check if already revealed
	if player.is_revealed:
		return {"can_reveal": false, "reason": "Already revealed"}

	# Check if character assigned
	if player.character_id == "":
		return {"can_reveal": false, "reason": "No character assigned"}

	# All checks passed
	return {"can_reveal": true, "reason": ""}


# =============================================================================
# PRIVATE METHODS - Revelation Processing
# =============================================================================

## Process next revelation in queue
func _process_next_revelation() -> void:
	if _revelation_queue.is_empty():
		_current_revelation = null
		return

	# Get next revelation
	var revelation_data = _revelation_queue.pop_front()
	var player = revelation_data.player
	var voluntary = revelation_data.voluntary

	_current_revelation = player

	# Start revelation sequence
	revelation_started.emit(player, voluntary)

	print("[CharacterRevelationSystem] Starting revelation for %s (voluntary: %s)" % [
		player.character_name,
		voluntary
	])

	# Play revelation sequence
	_play_revelation_sequence(player, voluntary)


## Play the revelation animation sequence
func _play_revelation_sequence(player: Player, voluntary: bool) -> void:
	# Set player as revealed BEFORE animation
	player.reveal()

	# Emit GameState signal for passive ability triggers
	if GameState.has_signal("character_revealed"):
		GameState.character_revealed.emit(player, player.ability_data, player.faction)

	# For now, just use a simple timer instead of full animation
	# In production, would call AnimationOrchestrator.play_reveal_sequence()
	await get_tree().create_timer(1.5).timeout

	# Revelation complete
	_on_revelation_complete(player, voluntary)


## Called when revelation sequence completes
func _on_revelation_complete(player: Player, voluntary: bool) -> void:
	revelation_completed.emit(player, voluntary)

	print("[CharacterRevelationSystem] Revelation completed for %s" % player.character_name)

	# Process next in queue
	_current_revelation = null
	_process_next_revelation()


# =============================================================================
# UTILITY METHODS
# =============================================================================

## Check if revelation is currently in progress
func is_revealing() -> bool:
	return _current_revelation != null


## Get number of pending revelations
func get_pending_count() -> int:
	return _revelation_queue.size()


## Clear revelation queue (emergency use only)
func clear_queue() -> void:
	_revelation_queue.clear()
	_current_revelation = null
	print("[CharacterRevelationSystem] Queue cleared")
