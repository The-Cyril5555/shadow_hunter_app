## WinConditionChecker - Win condition evaluation system
## Checks faction victories (all enemies dead) and individual neutral conditions.
## Triggered after deaths and equipment changes. Supports context-based checks.
## Pattern: Utility class (RefCounted)
class_name WinConditionChecker
extends RefCounted


# =============================================================================
# STATE - Kill tracking for event-based conditions
# =============================================================================

var _first_kill_player_id: int = -1  # ID of first player to kill someone
var _first_death_player_id: int = -1  # ID of first player to die
var _kill_order: Array[int] = []  # Order of deaths (player IDs)


# =============================================================================
# PUBLIC METHODS
# =============================================================================

## Register a kill for tracking (must be called before check_win_conditions)
func register_kill(killer: Player, victim: Player) -> void:
	if _first_kill_player_id == -1:
		_first_kill_player_id = killer.id
	if _first_death_player_id == -1:
		_first_death_player_id = victim.id
	_kill_order.append(victim.id)
	print("[WinConditionChecker] Kill registered: %s killed %s (deaths: %d)" % [
		killer.display_name, victim.display_name, _kill_order.size()
	])


## Reset tracking state for new game
func reset() -> void:
	_first_kill_player_id = -1
	_first_death_player_id = -1
	_kill_order.clear()


## Main entry point: Check all win conditions
## @param context: Dictionary with event info (event, killer, victim, player)
## Returns: {has_winner, winning_faction, winning_players, game_over}
func check_win_conditions(context: Dictionary = {}) -> Dictionary:
	var result = {
		"has_winner": false,
		"winning_faction": "",
		"winning_players": [],
		"game_over": false
	}

	# 1. Check faction victories
	var faction_winner = ""
	if check_hunter_victory():
		faction_winner = "hunter"
		print("[WinConditionChecker] Hunter victory detected!")
	elif check_shadow_victory():
		faction_winner = "shadow"
		print("[WinConditionChecker] Shadow victory detected!")

	# 2. Check ALL neutral conditions
	var neutral_winners: Array = []
	var neutral_ends_game = false
	for player in GameState.players:
		if player.faction == "neutral" and check_neutral_victory(player, context):
			neutral_winners.append(player)
			# These neutrals actively trigger game end
			if player.character_id in ["daniel", "charles", "bryan", "catherine", "bob", "david"]:
				neutral_ends_game = true
			print("[WinConditionChecker] Neutral player %s won!" % player.display_name)

	# 3. If faction win OR neutral triggers end → game over
	if faction_winner != "" or neutral_ends_game:
		result.game_over = true
		result.has_winner = true
		result.winning_faction = faction_winner if faction_winner != "" else "neutral"

		# Collect ALL faction winners (dead included)
		if faction_winner == "hunter":
			result.winning_players = _get_all_faction_players("hunter")
		elif faction_winner == "shadow":
			result.winning_players = _get_all_faction_players("shadow")

		# Add neutral winners
		for p in neutral_winners:
			if p not in result.winning_players:
				result.winning_players.append(p)

		# Final pass: check passive neutrals (Allie, Agnes, Bryan altar)
		# These only matter when the game is ending
		var end_context = context.duplicate()
		end_context["event"] = "game_ending"
		for player in GameState.players:
			if player.faction == "neutral" and player not in result.winning_players:
				if check_neutral_victory(player, end_context):
					result.winning_players.append(player)
					print("[WinConditionChecker] Passive neutral %s also wins!" % player.display_name)

	return result


# =============================================================================
# FACTION CHECKS
# =============================================================================

## Hunters win when all Shadows are dead
func check_hunter_victory() -> bool:
	var alive_shadows = get_alive_players_by_faction("shadow")
	var alive_hunters = get_alive_players_by_faction("hunter")
	return alive_shadows.is_empty() and not alive_hunters.is_empty()


## Shadows win when all Hunters are dead
func check_shadow_victory() -> bool:
	var alive_hunters = get_alive_players_by_faction("hunter")
	var alive_shadows = get_alive_players_by_faction("shadow")
	return alive_hunters.is_empty() and not alive_shadows.is_empty()


# =============================================================================
# NEUTRAL CHECKS
# =============================================================================

## Check individual neutral win condition based on character_id
func check_neutral_victory(player: Player, context: Dictionary = {}) -> bool:
	if player.faction != "neutral":
		return false

	match player.character_id:
		"allie":
			return _check_allie(player, context)
		"bob":
			return _check_bob(player)
		"charles":
			return _check_charles(player, context)
		"daniel":
			return _check_daniel(player, context)
		"agnes":
			return _check_agnes(player, context)
		"bryan":
			return _check_bryan(player, context)
		"catherine":
			return _check_catherine(player)
		"david":
			return _check_david(player)
		_:
			return player.is_alive  # Fallback for unknown neutrals


## Allie: "You're not dead when the game is over."
func _check_allie(player: Player, context: Dictionary) -> bool:
	# Only wins passively when game is ending
	if context.get("event") != "game_ending":
		return false
	return player.is_alive


## Bob: "You have 5 or more equipment cards."
func _check_bob(player: Player) -> bool:
	return player.is_alive and player.equipment.size() >= 5


## Charles: "At the time you kill another character, the total dead is 3+."
func _check_charles(player: Player, context: Dictionary) -> bool:
	if context.get("event") != "kill" or context.get("killer") != player:
		return false
	if not player.is_alive:
		return false
	var dead_count = GameState.players.filter(func(p): return not p.is_alive).size()
	return dead_count >= 3


## Daniel: "You must be the first player to kill, or be killed."
func _check_daniel(player: Player, context: Dictionary) -> bool:
	var event = context.get("event", "")

	# First to kill someone
	if event == "kill" and context.get("killer") == player:
		return _first_kill_player_id == player.id

	# First to be killed
	if event == "kill" and context.get("victim") == player:
		return _first_death_player_id == player.id

	return false


## Agnes: "When the game is over, if the player to your immediate right wins, you also win."
func _check_agnes(player: Player, context: Dictionary) -> bool:
	if context.get("event") != "game_ending":
		return false

	# Capriccio: left neighbor instead of right
	var direction = -1 if player.get_meta("capriccio_active", false) else 1
	var neighbor = _get_neighbor(player, direction)
	if neighbor == null:
		return false

	# Prevent infinite loop if neighbor is also Agnes
	if neighbor.character_id == "agnes":
		return false

	return _player_wins(neighbor)


## Bryan: "Kill a 13+ HP character directly, or be on Altar when game ends."
func _check_bryan(player: Player, context: Dictionary) -> bool:
	var event = context.get("event", "")

	# Kill a character with 13+ HP through direct attack
	if event == "kill" and context.get("killer") == player:
		var victim: Player = context.get("victim")
		if victim and victim.hp_max >= 13:
			return true

	# Or be on Altar when game ends
	if event == "game_ending":
		return player.is_alive and player.position_zone == "altar"

	return false


## Catherine: "Die first, or be one of the last two characters standing."
func _check_catherine(player: Player) -> bool:
	# First to die
	if not player.is_alive and _first_death_player_id == player.id:
		return true

	# Last 2 standing
	var alive_count = GameState.players.filter(func(p): return p.is_alive).size()
	return player.is_alive and alive_count <= 2


## David: "Equip 3+ specific White cards: Spear of Longinus, Holy Robe, Silver Rosary, Talisman."
func _check_david(player: Player) -> bool:
	if not player.is_alive:
		return false
	var target_cards = ["spear_of_longinus", "holy_robe", "silver_rosary", "talisman"]
	var count = 0
	for card in player.equipment:
		if card.id in target_cards:
			count += 1
	return count >= 3


# =============================================================================
# HELPERS
# =============================================================================

## Get all alive players of a faction
func get_alive_players_by_faction(faction: String) -> Array:
	return GameState.players.filter(func(p): return p.faction == faction and p.is_alive)


## Get ALL players of a faction (dead included — for faction victory)
func _get_all_faction_players(faction: String) -> Array:
	return GameState.players.filter(func(p): return p.faction == faction)


## Get neighbor player in seating order
func _get_neighbor(player: Player, direction: int) -> Player:
	var idx = GameState.players.find(player)
	if idx == -1:
		return null
	var neighbor_idx = (idx + direction + GameState.players.size()) % GameState.players.size()
	return GameState.players[neighbor_idx]


## Check if a player currently fulfills their win condition (for Agnes)
func _player_wins(player: Player) -> bool:
	if player.faction == "hunter":
		return check_hunter_victory()
	elif player.faction == "shadow":
		return check_shadow_victory()
	elif player.faction == "neutral":
		# Check with game_ending context for passive neutrals
		return check_neutral_victory(player, {"event": "game_ending"})
	return false


## Get faction status for debugging
func get_faction_status() -> Dictionary:
	return {
		"alive_hunters": get_alive_players_by_faction("hunter").size(),
		"alive_shadows": get_alive_players_by_faction("shadow").size(),
		"alive_neutrals": get_alive_players_by_faction("neutral").size()
	}
