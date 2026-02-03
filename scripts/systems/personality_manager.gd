## PersonalityManager - Manages AI personality loading and assignment
##
## Provides utilities for loading personality definitions from JSON,
## assigning personalities to bot players, and accessing personality data
##
## Features:
## - Load personalities from JSON
## - Assign personalities to bots (round-robin distribution)
## - Access personality decision weights
## - Display personality information
##
## Pattern: Utility class with static methods
## Usage: PersonalityManager.load_personalities()
class_name PersonalityManager
extends RefCounted


# =============================================================================
# CONSTANTS
# =============================================================================

const PERSONALITIES_PATH: String = "res://data/ai_personalities.json"


# =============================================================================
# PUBLIC METHODS - Loading
# =============================================================================

## Load AI personality definitions from JSON
## @returns: Dictionary - loaded personalities or empty dict on error
static func load_personalities() -> Dictionary:
	var file = FileAccess.open(PERSONALITIES_PATH, FileAccess.READ)
	if file == null:
		push_error("[PersonalityManager] Failed to load ai_personalities.json")
		return {}

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		push_error("[PersonalityManager] JSON parse error: %s" % json.get_error_message())
		return {}

	var data = json.data
	if not data.has("personalities"):
		push_error("[PersonalityManager] No 'personalities' section in JSON")
		return {}

	var personalities = data["personalities"]
	print("[PersonalityManager] Loaded %d AI personalities" % personalities.size())

	return personalities


## Get personality data by ID
## @param personalities: Dictionary of loaded personalities
## @param personality_id: ID of personality to get
## @returns: Dictionary - personality data (defensive copy)
static func get_personality_data(personalities: Dictionary, personality_id: String) -> Dictionary:
	if not personalities.has(personality_id):
		push_warning("[PersonalityManager] Personality ID not found: %s" % personality_id)
		return {}

	return personalities[personality_id].duplicate(true)


# =============================================================================
# PUBLIC METHODS - Assignment
# =============================================================================

## Assign AI personalities to bot players (round-robin distribution)
## @param players: Array of all players
## @param personalities: Dictionary of loaded personalities
static func assign_personalities_to_bots(players: Array, personalities: Dictionary) -> void:
	if personalities.is_empty():
		push_warning("[PersonalityManager] No personalities loaded, cannot assign")
		return

	var personality_ids = personalities.keys()
	var bot_players = []

	# Filter bots
	for player in players:
		if not player.is_human:
			bot_players.append(player)

	if bot_players.is_empty():
		print("[PersonalityManager] No bots to assign personalities")
		return

	# Assign personalities round-robin for balanced distribution
	for i in range(bot_players.size()):
		var bot = bot_players[i]
		var personality_id = personality_ids[i % personality_ids.size()]
		var personality_data = get_personality_data(personalities, personality_id)

		# Store personality in bot (using custom properties since we can't modify Player class here)
		bot.set_meta("personality_id", personality_id)
		bot.set_meta("personality_data", personality_data)

		var display_name = personality_data.get("display_name", personality_id)
		print("[PersonalityManager] %s assigned personality: %s" % [bot.display_name, display_name])


# =============================================================================
# PUBLIC METHODS - Data Access
# =============================================================================

## Get decision weight for action type
## @param player: Player to check
## @param action_type: Action type ("attack", "defense", "risk", "card_draw")
## @returns: float - decision weight (0.0-1.0)
static func get_decision_weight(player: Player, action_type: String) -> float:
	if not player.has_meta("personality_data"):
		return 0.25  # Default balanced weight

	var personality_data = player.get_meta("personality_data")
	var weights = personality_data.get("decision_weights", {})
	return weights.get(action_type, 0.25)


## Get attack preference weight
static func get_attack_weight(player: Player) -> float:
	return get_decision_weight(player, "attack")


## Get defense preference weight
static func get_defense_weight(player: Player) -> float:
	return get_decision_weight(player, "defense")


## Get risk-taking weight
static func get_risk_weight(player: Player) -> float:
	return get_decision_weight(player, "risk")


## Get card draw preference weight
static func get_card_draw_weight(player: Player) -> float:
	return get_decision_weight(player, "card_draw")


## Get full decision weights breakdown
## @param player: Player to check
## @returns: Dictionary - {"attack": float, "defense": float, "risk": float, "card_draw": float}
static func get_all_weights(player: Player) -> Dictionary:
	return {
		"attack": get_attack_weight(player),
		"defense": get_defense_weight(player),
		"risk": get_risk_weight(player),
		"card_draw": get_card_draw_weight(player)
	}


# =============================================================================
# PUBLIC METHODS - Display
# =============================================================================

## Get display name with personality (if bot)
## @param player: Player to get name for
## @param show_personality: Whether to show personality
## @returns: String - display name with optional personality
static func get_display_name_with_personality(player: Player, show_personality: bool = false) -> String:
	if player.is_human or not show_personality:
		return player.display_name

	if not player.has_meta("personality_data"):
		return player.display_name

	var personality_data = player.get_meta("personality_data")
	var personality_name = personality_data.get("display_name", "Unknown")
	return "%s (%s)" % [player.display_name, personality_name]


## Get personality color
## @param player: Player to get color for
## @returns: Color - personality color or white if none
static func get_personality_color(player: Player) -> Color:
	if not player.has_meta("personality_data"):
		return Color.WHITE

	var personality_data = player.get_meta("personality_data")
	var color_hex = personality_data.get("color", "#FFFFFF")
	return Color(color_hex)


## Get personality ID
## @param player: Player to check
## @returns: String - personality ID or empty string
static func get_personality_id(player: Player) -> String:
	if not player.has_meta("personality_id"):
		return ""
	return player.get_meta("personality_id")


## Get personality description
## @param player: Player to check
## @returns: String - personality description
static func get_personality_description(player: Player) -> String:
	if not player.has_meta("personality_data"):
		return "No personality assigned"

	var personality_data = player.get_meta("personality_data")
	return personality_data.get("description", "Unknown personality")


# =============================================================================
# UTILITY METHODS
# =============================================================================

## Get list of all personality IDs
## @param personalities: Dictionary of loaded personalities
## @returns: Array - list of personality IDs
static func get_personality_ids(personalities: Dictionary) -> Array:
	return personalities.keys()


## Validate decision weights (should sum to 1.0)
## @param weights: Dictionary of decision weights
## @returns: bool - true if valid
static func validate_weights(weights: Dictionary) -> bool:
	var total = 0.0
	for weight in weights.values():
		total += weight

	return abs(total - 1.0) < 0.01  # Allow small floating point error
