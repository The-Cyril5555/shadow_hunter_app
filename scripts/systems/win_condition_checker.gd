## WinConditionChecker - Win condition evaluation system
## Centralized win detection triggered after player death.
## Pattern: Utility class (RefCounted) - stateless win evaluation logic
class_name WinConditionChecker
extends RefCounted


# =============================================================================
# WIN CONDITION CHECK METHODS
# =============================================================================

## Main entry point: Check all win conditions
## Returns: Dictionary with {has_winner: bool, winning_faction: String, winning_players: Array, game_over: bool}
func check_win_conditions() -> Dictionary:
	var result = {
		"has_winner": false,
		"winning_faction": "",
		"winning_players": [],
		"game_over": false
	}

	# Check faction victories first
	if check_hunter_victory():
		result.has_winner = true
		result.winning_faction = "Hunter"
		result.winning_players = get_alive_players_by_faction("Hunter")
		result.game_over = true
		print("[WinConditionChecker] Hunter victory detected!")

	elif check_shadow_victory():
		result.has_winner = true
		result.winning_faction = "Shadow"
		result.winning_players = get_alive_players_by_faction("Shadow")
		result.game_over = true
		print("[WinConditionChecker] Shadow victory detected!")

	# Check Neutral win conditions (can win alongside faction)
	for player in GameState.players:
		if player.faction == "Neutral" and check_neutral_victory(player):
			result.has_winner = true
			result.winning_players.append(player)
			print("[WinConditionChecker] Neutral player %s won!" % player.display_name)
			# Neutral can win WITH faction, so don't set game_over here
			# Let faction victory determine game_over

	return result


## Check if Hunters have won (all Shadows dead)
func check_hunter_victory() -> bool:
	var alive_shadows = get_alive_players_by_faction("Shadow")
	var alive_hunters = get_alive_players_by_faction("Hunter")

	# Hunters win if ALL Shadows dead AND at least 1 Hunter alive
	return alive_shadows.is_empty() and not alive_hunters.is_empty()


## Check if Shadows have won (all Hunters dead)
func check_shadow_victory() -> bool:
	var alive_hunters = get_alive_players_by_faction("Hunter")
	var alive_shadows = get_alive_players_by_faction("Shadow")

	# Shadows win if ALL Hunters dead AND at least 1 Shadow alive
	return alive_hunters.is_empty() and not alive_shadows.is_empty()


## Check Neutral player win condition (data-driven)
func check_neutral_victory(player: Player) -> bool:
	if player.faction != "Neutral":
		return false

	# For MVP: Neutral wins if alive when faction victory occurs
	# Future: Load win condition from characters_data
	# var character_data = GameState.characters_data.get(player.character_id, {})
	# var win_condition = character_data.get("win_condition", {})

	# Default: survive until end
	return player.is_alive


# =============================================================================
# HELPER METHODS
# =============================================================================

## Get all alive players of specific faction
func get_alive_players_by_faction(faction: String) -> Array:
	var alive_players = []
	for player in GameState.players:
		if player.faction == faction and player.is_alive:
			alive_players.append(player)
	return alive_players


## Get count of alive players by faction (for logging/debugging)
func get_faction_status() -> Dictionary:
	return {
		"alive_hunters": get_alive_players_by_faction("Hunter").size(),
		"alive_shadows": get_alive_players_by_faction("Shadow").size(),
		"alive_neutrals": get_alive_players_by_faction("Neutral").size()
	}
