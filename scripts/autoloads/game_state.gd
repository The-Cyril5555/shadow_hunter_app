## GameState - Global game state singleton (Autoload)
## Manages core game state and emits events for event-driven architecture.
## Pattern: Hybrid State Management (Singleton Autoload)
class_name GameStateClass
extends Node


# =============================================================================
# ENUMS
# =============================================================================

## Turn phases for game flow management
enum TurnPhase {
	MOVEMENT,  ## Roll dice and move character
	ACTION,    ## Draw card, attack, or pass
	END        ## Cleanup and advance to next player
}


# =============================================================================
# SIGNALS - Core events for event-driven architecture
# =============================================================================

## Emitted when turn phase changes
signal phase_changed(new_phase: TurnPhase)

## Emitted when damage is dealt to a player
signal damage_dealt(attacker, victim, amount: int)

## Emitted when a character is revealed (voluntarily or forced)
signal character_revealed(player, character, faction: String)

## Emitted when a player dies
signal player_died(player, killer)

## Emitted when win condition is met (before game_over)
signal win_condition_met(faction: String, winning_players: Array)

## Emitted when the game ends
signal game_over(winning_faction: String)

## Emitted when a turn starts
signal turn_started(player, turn_number: int)

## Emitted when a turn ends
signal turn_ended(player, turn_number: int)

## Emitted on critical errors
signal error_occurred(error_code: String, message: String)

## Emitted when equipment is equipped
signal equipment_equipped(player, card: Card)

## Emitted when equipment is discarded
signal equipment_discarded(player, card: Card)

## Emitted when a player moves to a new zone
signal player_moved(player, zone_id: String)


# =============================================================================
# GAME STATE
# =============================================================================

## True when playing an online network game
var is_network_game: bool = false

## Index of the local player in network mode (-1 = server only, no local player)
var my_network_player_index: int = -1

## All players in the game (human and bot)
var players: Array = []  # Will be Array[Player] when Player class exists

## Index of the current player in the players array
var current_player_index: int = 0

## Current turn number (starts at 1)
var turn_count: int = 0

## Current turn phase
var current_phase: TurnPhase = TurnPhase.MOVEMENT

## Log of all game actions for replay/debugging
var game_log: Array[Dictionary] = []

## Whether a game is currently in progress
var game_in_progress: bool = false


# =============================================================================
# DECK REFERENCES (set during game initialization)
# =============================================================================

## Hermit deck manager
var hermit_deck: DeckManager = null

## White (Church) deck manager
var white_deck: DeckManager = null

## Black (Cemetery) deck manager
var black_deck: DeckManager = null

## Zone positions — zone_ids ordered by board position (shuffled each game)
var zone_positions: Array = []


# =============================================================================
# DATA REFERENCES (loaded at startup)
# =============================================================================

## All character data loaded from JSON
var characters_data: Dictionary = {}

## All card data loaded from JSON
var cards_data: Dictionary = {}

## AI personality configurations
var ai_personalities: Dictionary = {}

## Win condition checker instance
var win_checker: WinConditionChecker = null

## Stored win result (preserved for game over screen)
var last_win_result: Dictionary = {}

## Passive ability system instance
var passive_ability_system: PassiveAbilitySystem = null

## Active ability system instance
var active_ability_system: ActiveAbilitySystem = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Load character data from JSON
	_load_characters()

	# Load card data from JSON
	_load_cards()

	# Load AI personalities from JSON
	_load_personalities()

	# Initialize win condition checker
	win_checker = WinConditionChecker.new()

	# Connect to signals for win detection
	player_died.connect(_on_player_died_check_win)
	equipment_equipped.connect(_on_equipment_check_win)

	# Initialize passive ability system
	passive_ability_system = PassiveAbilitySystem.new()
	add_child(passive_ability_system)  # Add as child for signal access

	# Initialize active ability system
	active_ability_system = ActiveAbilitySystem.new()
	add_child(active_ability_system)

	print("[GameState] Initialized")


# =============================================================================
# HELPER METHODS
# =============================================================================

## Get the current player
func get_current_player():
	if players.is_empty():
		return null
	return players[current_player_index]


## Get deck manager for a specific zone
func get_deck_for_zone(zone_id: String) -> DeckManager:
	match zone_id:
		"hermit":
			return hermit_deck
		"church":
			return white_deck
		"cemetery":
			return black_deck
		_:
			return null  # Zones without decks (underworld, weird_woods, altar)


## Get character data by ID (returns defensive copy)
func get_character(character_id: String) -> Dictionary:
	if not characters_data.has(character_id):
		push_warning("[GameState] Character ID not found: %s" % character_id)
		return {}
	return characters_data[character_id].duplicate(true)


## Get all characters (returns defensive copy)
func get_all_characters() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for char_id in characters_data:
		all.append(characters_data[char_id].duplicate(true))
	return all


## Get base characters only (is_expansion = false)
func get_base_characters() -> Array[Dictionary]:
	var base: Array[Dictionary] = []
	for char_id in characters_data:
		var char_data = characters_data[char_id]
		if not char_data.get("is_expansion", false):
			base.append(char_data.duplicate(true))
	return base


## Get expansion characters only (is_expansion = true)
func get_expansion_characters() -> Array[Dictionary]:
	var expansion: Array[Dictionary] = []
	for char_id in characters_data:
		var char_data = characters_data[char_id]
		if char_data.get("is_expansion", false):
			expansion.append(char_data.duplicate(true))
	return expansion


## Get all characters of a faction (with optional expansion filtering)
func get_characters_by_faction(faction: String, include_expansion: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for char_id in characters_data:
		var char_data = characters_data[char_id]

		# Check faction match
		if char_data.get("faction", "") != faction:
			continue

		# Check expansion flag if filtering
		if not include_expansion and char_data.get("is_expansion", false):
			continue

		result.append(char_data.duplicate(true))

	return result


## Log a game action
func log_action(action_type: String, data: Dictionary = {}) -> void:
	var log_entry = {
		"turn": turn_count,
		"timestamp": Time.get_unix_time_from_system(),
		"type": action_type,
		"data": data
	}
	game_log.append(log_entry)


## Compute game statistics from the action log
func get_game_statistics() -> Dictionary:
	var stats = {
		"turns_played": turn_count,
		"total_attacks": 0,
		"total_damage": 0,
		"total_deaths": 0,
		"cards_drawn": 0,
		"equipment_equipped": 0,
		"player_stats": {}  # Per-player stats
	}

	# Initialize per-player stats
	for player in players:
		stats.player_stats[player.display_name] = {
			"attacks_made": 0,
			"damage_dealt": 0,
			"cards_drawn": 0,
			"kills": 0,
		}

	# Process game log
	for entry in game_log:
		var data = entry.get("data", {})
		match entry.get("type", ""):
			"attack_performed":
				stats.total_attacks += 1
				stats.total_damage += data.get("damage", 0)
				var attacker = data.get("attacker", "")
				if stats.player_stats.has(attacker):
					stats.player_stats[attacker].attacks_made += 1
					stats.player_stats[attacker].damage_dealt += data.get("damage", 0)
					if data.get("target_died", false):
						stats.player_stats[attacker].kills += 1
				if data.get("target_died", false):
					stats.total_deaths += 1
			"card_effect_applied":
				stats.cards_drawn += 1
				var player_name = data.get("player", "")
				if stats.player_stats.has(player_name):
					stats.player_stats[player_name].cards_drawn += 1
			"equipment_equipped":
				stats.equipment_equipped += 1

	return stats


## Advance to the next turn phase
func advance_phase() -> void:
	if not game_in_progress:
		return
	match current_phase:
		TurnPhase.MOVEMENT:
			current_phase = TurnPhase.ACTION
			print("[GameState] Phase: MOVEMENT → ACTION")
		TurnPhase.ACTION:
			current_phase = TurnPhase.END
			print("[GameState] Phase: ACTION → END")
		TurnPhase.END:
			# Emit turn ended signal for current player
			var current_player = get_current_player()
			if current_player:
				turn_ended.emit(current_player, turn_count)

			# Wight "Multiplication" — replay turn if extra turns remaining
			if current_player and current_player.get_meta("extra_turns", 0) > 0:
				var remaining = current_player.get_meta("extra_turns") - 1
				current_player.set_meta("extra_turns", remaining)
				current_phase = TurnPhase.MOVEMENT
				print("[GameState] Wight extra turn (%d remaining) for %s" % [remaining, current_player.display_name])
				turn_started.emit(current_player, turn_count)
				phase_changed.emit(current_phase)
				return

			# Concealed Knowledge — replay turn once
			if current_player and current_player.get_meta("extra_turn", false):
				current_player.set_meta("extra_turn", false)
				current_phase = TurnPhase.MOVEMENT
				print("[GameState] Concealed Knowledge extra turn for %s" % current_player.display_name)
				turn_started.emit(current_player, turn_count)
				phase_changed.emit(current_phase)
				return

			# Move to next alive player (skip dead players)
			var attempts = 0
			var found_alive_player = false

			while attempts < players.size():
				current_player_index = (current_player_index + 1) % players.size()
				attempts += 1

				# Check if this player is alive
				if players[current_player_index].is_alive:
					found_alive_player = true
					break

			# Check if all players are dead (game over scenario)
			if not found_alive_player:
				push_error("[GameState] No alive players found - game should be over!")
				error_occurred.emit("NO_ALIVE_PLAYERS", "All players are dead")
				return

			# Increment turn count if we wrapped around to player 0
			if current_player_index == 0:
				turn_count += 1

			# Reset to movement phase
			current_phase = TurnPhase.MOVEMENT

			var next_player = get_current_player()
			print("[GameState] Phase: END → MOVEMENT (Next player: %s, Turn %d)" % [next_player.display_name if next_player else "Unknown", turn_count])

			# Emit turn started signal
			turn_started.emit(next_player, turn_count)

	# Emit phase change signal
	phase_changed.emit(current_phase)


## Reset game state for a new game
func reset() -> void:
	players.clear()
	current_player_index = 0
	turn_count = 0
	current_phase = TurnPhase.MOVEMENT
	game_log.clear()
	game_in_progress = false
	hermit_deck = null
	white_deck = null
	black_deck = null
	zone_positions.clear()
	last_win_result = {}
	if win_checker:
		win_checker.reset()
	print("[GameState] Reset complete")


## Convert full game state to dictionary for saving
func to_dict() -> Dictionary:
	# Serialize players
	var players_data = []
	for player in players:
		players_data.append(player.to_dict())

	# Serialize decks
	var decks_data = {}
	if hermit_deck:
		decks_data["hermit"] = hermit_deck.to_dict()
	if white_deck:
		decks_data["white"] = white_deck.to_dict()
	if black_deck:
		decks_data["black"] = black_deck.to_dict()

	return {
		"version": 1,
		"current_player_index": current_player_index,
		"turn_count": turn_count,
		"current_phase": current_phase,
		"game_in_progress": game_in_progress,
		"game_log": game_log,
		"players": players_data,
		"decks": decks_data,
		"zone_positions": zone_positions,
	}


## Load full game state from dictionary
func from_dict(data: Dictionary) -> void:
	current_player_index = data.get("current_player_index", 0)
	turn_count = data.get("turn_count", 0)
	current_phase = data.get("current_phase", TurnPhase.MOVEMENT)
	game_in_progress = data.get("game_in_progress", false)
	game_log = data.get("game_log", [])
	zone_positions = data.get("zone_positions", [])

	# Restore players
	players.clear()
	for player_data in data.get("players", []):
		var player = Player.from_dict(player_data)
		players.append(player)

	# Restore decks
	var decks_data = data.get("decks", {})
	if decks_data.has("hermit"):
		hermit_deck = DeckManager.new()
		hermit_deck.from_dict(decks_data["hermit"])
	if decks_data.has("white"):
		white_deck = DeckManager.new()
		white_deck.from_dict(decks_data["white"])
	if decks_data.has("black"):
		black_deck = DeckManager.new()
		black_deck.from_dict(decks_data["black"])


## Check win conditions after player death
func _on_player_died_check_win(victim: Player, killer: Player) -> void:
	print("[GameState] Checking win conditions after %s died" % victim.display_name)

	# Register the kill for tracking (first kill, first death, kill order)
	win_checker.register_kill(killer, victim)

	# Check with kill context
	var context = {"event": "kill", "killer": killer, "victim": victim}
	check_all_win_conditions(context)


## Check win conditions after equipment change
func _on_equipment_check_win(player: Player, _card: Card) -> void:
	print("[GameState] Checking win conditions after %s equipment change" % player.display_name)
	var context = {"event": "equipment_change", "player": player}
	check_all_win_conditions(context)


## Generic win condition check — called from multiple triggers
func check_all_win_conditions(context: Dictionary = {}) -> void:
	var result = win_checker.check_win_conditions(context)

	if result.has_winner:
		print("[GameState] Winner detected! Faction: %s, Players: %d" % [result.winning_faction, result.winning_players.size()])

		# Emit win condition met signal
		win_condition_met.emit(result.winning_faction, result.winning_players)

		# Log victory
		log_action("victory", {
			"winning_faction": result.winning_faction,
			"winning_players": result.winning_players.map(func(p): return p.display_name),
			"turn": turn_count
		})

		# If game is over, store result and emit signal
		if result.game_over:
			last_win_result = result
			game_in_progress = false
			print("[GameState] Game Over! %s faction wins!" % result.winning_faction)
			game_over.emit(result.winning_faction)


## Validate character data structure
func _validate_character(char_data: Dictionary) -> bool:
	# Check required field: id
	if not char_data.has("id"):
		push_warning("[GameState] Character missing 'id' field")
		return false

	var char_id = char_data.get("id", "unknown")

	# Check required field: name
	if not char_data.has("name"):
		push_warning("[GameState] Character %s missing 'name'" % char_id)
		return false

	# Check required field: faction
	if not char_data.has("faction"):
		push_warning("[GameState] Character %s missing 'faction'" % char_id)
		return false

	# Validate faction value
	var faction = char_data.get("faction", "")
	if faction not in ["hunter", "shadow", "neutral"]:
		push_warning("[GameState] Character %s has invalid faction: %s" % [char_id, faction])
		return false

	# Check required field: hp_max
	if not char_data.has("hp_max"):
		push_warning("[GameState] Character %s missing 'hp_max'" % char_id)
		return false

	# Validate hp_max value
	var hp_max = char_data.get("hp_max", 0)
	if hp_max <= 0:
		push_warning("[GameState] Character %s has invalid hp_max: %d" % [char_id, hp_max])
		return false

	# Check required field: ability
	if not char_data.has("ability"):
		push_warning("[GameState] Character %s missing 'ability'" % char_id)
		return false

	# Validate ability structure
	var ability = char_data.get("ability", {})
	if not ability.has("name"):
		push_warning("[GameState] Character %s ability missing 'name'" % char_id)
		return false
	if not ability.has("type"):
		push_warning("[GameState] Character %s ability missing 'type'" % char_id)
		return false
	if not ability.has("trigger"):
		push_warning("[GameState] Character %s ability missing 'trigger'" % char_id)
		return false

	# All validation passed
	return true


## Load character data from JSON
func _load_characters() -> void:
	var file = FileAccess.open("res://data/characters.json", FileAccess.READ)
	if file == null:
		push_error("[GameState] Failed to load characters.json")
		error_occurred.emit("CHARACTER_LOAD_FAILED", "Could not open characters.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("[GameState] JSON parse error in characters.json: %s" % json.get_error_message())
		error_occurred.emit("CHARACTER_PARSE_FAILED", json.get_error_message())
		return

	var data = json.data
	if not data.has("characters"):
		push_error("[GameState] No 'characters' section in characters.json")
		return

	var raw_characters = data.get("characters", {})

	# Validate and load only valid characters
	var valid_count = 0
	var invalid_count = 0
	var base_count = 0
	var expansion_count = 0
	var hunter_count = 0
	var shadow_count = 0
	var neutral_count = 0

	for char_id in raw_characters:
		var char_data = raw_characters[char_id]

		# Validate character
		if not _validate_character(char_data):
			push_warning("[GameState] Skipping invalid character: %s" % char_id)
			invalid_count += 1
			continue

		# Add to characters_data
		characters_data[char_id] = char_data

		# Count by expansion flag
		if char_data.get("is_expansion", false):
			expansion_count += 1
		else:
			base_count += 1

		# Count by faction
		match char_data.get("faction", ""):
			"hunter":
				hunter_count += 1
			"shadow":
				shadow_count += 1
			"neutral":
				neutral_count += 1

		valid_count += 1

	if invalid_count > 0:
		push_warning("[GameState] Skipped %d invalid characters" % invalid_count)

	print("[GameState] Loaded %d characters (%d base, %d expansion)" % [valid_count, base_count, expansion_count])
	print("[GameState] Faction breakdown: %d hunters, %d shadows, %d neutrals" % [hunter_count, shadow_count, neutral_count])


## Load card data from JSON
func _load_cards() -> void:
	var file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if file == null:
		push_error("[GameState] Failed to load cards.json")
		error_occurred.emit("CARD_LOAD_FAILED", "Could not open cards.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("[GameState] JSON parse error in cards.json: %s" % json.get_error_message())
		error_occurred.emit("CARD_PARSE_FAILED", json.get_error_message())
		return

	var data = json.data
	if not data.has("decks"):
		push_error("[GameState] No 'decks' section in cards.json")
		return

	var decks = data.get("decks", {})

	# Process each deck
	var total_cards = 0
	var hermit_count = 0
	var white_count = 0
	var black_count = 0

	for deck_name in decks:
		var deck_data = decks[deck_name]
		var cards = deck_data.get("cards", [])

		for card_data in cards:
			# Validate card
			if not _validate_card(card_data):
				push_warning("[GameState] Skipping invalid card in %s deck" % deck_name)
				continue

			# Add to cards_data
			var card_id = card_data.get("id", "")
			cards_data[card_id] = card_data

			# Count by deck
			match deck_name:
				"hermit":
					hermit_count += 1
				"white":
					white_count += 1
				"black":
					black_count += 1

			total_cards += 1

	print("[GameState] Loaded %d cards (%d hermit, %d white, %d black)" % [total_cards, hermit_count, white_count, black_count])


## Load AI personality data from JSON
func _load_personalities() -> void:
	var personalities = PersonalityManager.load_personalities()
	if personalities.is_empty():
		push_warning("[GameState] No AI personalities loaded")
	else:
		print("[GameState] Loaded %d AI personalities" % personalities.size())


## Validate card data structure
func _validate_card(card_data: Dictionary) -> bool:
	# Check required field: id
	if not card_data.has("id"):
		push_warning("[GameState] Card missing 'id' field")
		return false

	var card_id = card_data.get("id", "unknown")

	# Check required field: name
	if not card_data.has("name"):
		push_warning("[GameState] Card %s missing 'name'" % card_id)
		return false

	# Check required field: deck
	if not card_data.has("deck"):
		push_warning("[GameState] Card %s missing 'deck'" % card_id)
		return false

	# Validate deck value
	var deck = card_data.get("deck", "")
	if deck not in ["hermit", "white", "black"]:
		push_warning("[GameState] Card %s has invalid deck: %s" % [card_id, deck])
		return false

	# Check required field: type
	if not card_data.has("type"):
		push_warning("[GameState] Card %s missing 'type'" % card_id)
		return false

	# Validate type value
	var type = card_data.get("type", "")
	if type not in ["equipment", "instant", "vision"]:
		push_warning("[GameState] Card %s has invalid type: %s" % [card_id, type])
		return false

	# Check copies_in_deck
	var copies = card_data.get("copies_in_deck", 1)
	if copies <= 0:
		push_warning("[GameState] Card %s has invalid copies_in_deck: %d" % [card_id, copies])
		return false

	# Check effect structure
	if not card_data.has("effect"):
		push_warning("[GameState] Card %s missing 'effect'" % card_id)
		return false

	var effect = card_data.get("effect", {})
	if not effect.has("type") or not effect.has("description"):
		push_warning("[GameState] Card %s has malformed effect" % card_id)
		return false

	# All validation passed
	return true


## Get card data by ID (returns defensive copy)
func get_card_data(card_id: String) -> Dictionary:
	if not cards_data.has(card_id):
		push_warning("[GameState] Card ID not found: %s" % card_id)
		return {}
	return cards_data[card_id].duplicate(true)


## Get all cards from a specific deck
func get_cards_by_deck(deck_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for card_id in cards_data:
		var card_data = cards_data[card_id]
		if card_data.get("deck", "") == deck_name:
			result.append(card_data.duplicate(true))

	return result


## Get all cards of a specific type
func get_cards_by_type(card_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for card_id in cards_data:
		var card_data = cards_data[card_id]
		if card_data.get("type", "") == card_type:
			result.append(card_data.duplicate(true))

	return result


## Shuffle and assign zone positions for this game
func setup_zone_positions() -> void:
	zone_positions = ZoneData.shuffle_zone_positions()
	print("[GameState] Zone positions: %s" % str(zone_positions))


## Initialize card decks from JSON data
func initialize_decks() -> void:
	# Load card data from JSON
	var cards_file = FileAccess.open("res://data/cards.json", FileAccess.READ)
	if cards_file == null:
		push_error("[GameState] Failed to load cards.json")
		return

	var json = JSON.new()
	var error = json.parse(cards_file.get_as_text())
	cards_file.close()

	if error != OK:
		push_error("[GameState] JSON parse error in cards.json: " + json.get_error_message())
		return

	var data = json.data
	if not data.has("decks"):
		push_error("[GameState] No 'decks' section in cards.json")
		return

	# Initialize Hermit deck
	if data.decks.has("hermit"):
		hermit_deck = DeckManager.new()
		hermit_deck.deck_type = "hermit"
		hermit_deck.initialize_from_data(data.decks.hermit.cards)

	# Initialize White deck
	if data.decks.has("white"):
		white_deck = DeckManager.new()
		white_deck.deck_type = "white"
		white_deck.initialize_from_data(data.decks.white.cards)

	# Initialize Black deck
	if data.decks.has("black"):
		black_deck = DeckManager.new()
		black_deck.deck_type = "black"
		black_deck.initialize_from_data(data.decks.black.cards)
