## GameState - Global game state singleton (Autoload)
## Manages core game state and emits events for event-driven architecture.
## Pattern: Hybrid State Management (Singleton Autoload)
class_name GameStateClass
extends Node


# =============================================================================
# SIGNALS - Core events for event-driven architecture
# =============================================================================

## Emitted when a player plays a card
signal card_played(player, card, target)

## Emitted when damage is dealt to a player
signal damage_dealt(attacker, victim, amount: int)

## Emitted when a character is revealed (voluntarily or forced)
signal character_revealed(player, character, faction: String)

## Emitted when a player dies
signal player_died(player, killer)

## Emitted when the game ends
signal game_over(winning_faction: String)

## Emitted when a turn starts
signal turn_started(player, turn_number: int)

## Emitted when a turn ends
signal turn_ended(player, turn_number: int)

## Emitted on critical errors
signal error_occurred(error_code: String, message: String)


# =============================================================================
# GAME STATE
# =============================================================================

## All players in the game (human and bot)
var players: Array = []  # Will be Array[Player] when Player class exists

## Index of the current player in the players array
var current_player_index: int = 0

## Current turn number (starts at 1)
var turn_count: int = 0

## Log of all game actions for replay/debugging
var game_log: Array[Dictionary] = []

## Whether a game is currently in progress
var game_in_progress: bool = false


# =============================================================================
# DECK REFERENCES (set during game initialization)
# =============================================================================

## Reference to Hermit deck manager
var hermit_deck = null  # DeckManager

## Reference to White (Church) deck manager
var white_deck = null  # DeckManager

## Reference to Black (Cemetery) deck manager
var black_deck = null  # DeckManager


# =============================================================================
# DATA REFERENCES (loaded at startup)
# =============================================================================

## All character data loaded from JSON
var characters_data: Dictionary = {}

## All card data loaded from JSON
var cards_data: Dictionary = {}

## AI personality configurations
var ai_personalities: Dictionary = {}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	print("[GameState] Initialized")


# =============================================================================
# HELPER METHODS
# =============================================================================

## Get the current player
func get_current_player():
	if players.is_empty():
		return null
	return players[current_player_index]


## Log a game action
func log_action(action_type: String, data: Dictionary = {}) -> void:
	var log_entry = {
		"turn": turn_count,
		"timestamp": Time.get_unix_time_from_system(),
		"type": action_type,
		"data": data
	}
	game_log.append(log_entry)


## Reset game state for a new game
func reset() -> void:
	players.clear()
	current_player_index = 0
	turn_count = 0
	game_log.clear()
	game_in_progress = false
	hermit_deck = null
	white_deck = null
	black_deck = null
	print("[GameState] Reset complete")


## Convert state to dictionary for saving
func to_dict() -> Dictionary:
	return {
		"current_player_index": current_player_index,
		"turn_count": turn_count,
		"game_in_progress": game_in_progress,
		"game_log": game_log,
		# Players and decks serialized separately
	}


## Load state from dictionary
func from_dict(data: Dictionary) -> void:
	current_player_index = data.get("current_player_index", 0)
	turn_count = data.get("turn_count", 0)
	game_in_progress = data.get("game_in_progress", false)
	game_log = data.get("game_log", [])
