## BotController - Handles AI bot turn execution
##
## Provides automated turn execution for bot players
## MVP: Simple random movement and always draw card
##
## Features:
## - Bot turn detection
## - Automated action sequence (roll → move → zone action)
## - Action delays for human observation
## - Signal-based event notifications
##
## Pattern: Stateless utility class (RefCounted)
## Usage: BotController.new().execute_bot_turn(bot_player)
class_name BotController
extends RefCounted


# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when bot starts an action
signal bot_action_started(bot: Player, action_type: String)

## Emitted when bot completes an action
signal bot_action_completed(bot: Player, action_type: String, result: Variant)

## Emitted when bot turn ends
signal bot_turn_ended(bot: Player)


# =============================================================================
# CONSTANTS
# =============================================================================

const ACTION_DELAY_MIN: float = 0.8  # Minimum delay between actions (seconds)
const ACTION_DELAY_MAX: float = 1.5  # Maximum delay between actions (seconds)


# =============================================================================
# PUBLIC METHODS - Turn Execution
# =============================================================================

## Execute complete bot turn (async)
## @param bot: Bot player to execute turn for
## @param scene_tree: SceneTree for await timers
func execute_bot_turn(bot: Player, scene_tree: SceneTree) -> void:
	if bot.is_human:
		push_warning("[BotController] Attempted to execute bot turn for human player: %s" % bot.display_name)
		return

	# Log bot personality
	var personality_id = PersonalityManager.get_personality_id(bot)
	var personality_name = "Unknown"
	if personality_id != "":
		var personality_data = bot.get_meta("personality_data", {})
		personality_name = personality_data.get("display_name", personality_id)

	print("\n[BotController] ========== %s TURN START ==========" % bot.display_name)
	print("[BotController] Personality: %s" % personality_name)

	# Step 1: Roll dice
	await _action_delay(scene_tree)
	var roll = bot_roll_dice(bot)

	# Step 2: Move to zone
	await _action_delay(scene_tree)
	var zone = bot_move_to_zone(bot, roll)

	# Step 3: Execute zone action (draw card)
	await _action_delay(scene_tree)
	bot_execute_zone_action(bot, zone)

	# Step 4: End turn
	await _action_delay(scene_tree)
	bot_turn_ended.emit(bot)
	print("[BotController] ========== %s TURN END ==========" % bot.display_name)


# =============================================================================
# PUBLIC METHODS - Bot Actions
# =============================================================================

## Bot rolls dice
## @param bot: Bot player rolling
## @returns: int - dice roll result (1-6)
func bot_roll_dice(bot: Player) -> int:
	bot_action_started.emit(bot, "roll_dice")

	var roll = randi() % 6 + 1  # D6: 1-6

	bot_action_completed.emit(bot, "roll_dice", roll)
	print("[BotController] 🎲 %s rolled %d" % [bot.display_name, roll])

	return roll


## Bot moves to zone (with GameState signal emission)
## @param bot: Bot player moving
## @param roll: Dice roll result (currently unused in MVP)
## @returns: String - target zone id
func bot_move_to_zone(bot: Player, roll: int) -> String:
	bot_action_started.emit(bot, "move")

	# Get valid adjacent zones
	var valid_zones = _get_valid_adjacent_zones(bot.position_zone)
	var target_zone = valid_zones.pick_random() if valid_zones.size() > 0 else bot.position_zone

	# Update position
	var old_zone = bot.position_zone
	bot.position_zone = target_zone

	# Emit GameState signal for movement (for UI updates, etc.)
	GameState.player_moved.emit(bot, target_zone)

	bot_action_completed.emit(bot, "move", target_zone)
	print("[BotController] 🚶 %s moved: %s → %s" % [bot.display_name, old_zone, target_zone])

	return target_zone


## Bot executes zone action (draw card from real deck)
## @param bot: Bot player executing action
## @param zone: Current zone
func bot_execute_zone_action(bot: Player, zone: String) -> void:
	bot_action_started.emit(bot, "zone_action")

	print("[BotController] 🃏 %s drawing card from %s zone" % [bot.display_name, zone])

	# Get the appropriate deck from GameState
	var deck: DeckManager = GameState.get_deck_for_zone(zone)

	if deck == null:
		push_warning("[BotController] No deck found for zone: %s" % zone)
		bot_action_completed.emit(bot, "zone_action", null)
		return

	# Draw card from real deck using HandManager
	var card = HandManager.draw_to_hand(bot, deck)

	if card != null:
		bot_action_completed.emit(bot, "zone_action", card)
		print("[BotController] ✅ %s drew: %s (hand: %d cards)" % [bot.display_name, card.name, bot.hand.size()])
	else:
		bot_action_completed.emit(bot, "zone_action", null)
		print("[BotController] ⚠️ %s couldn't draw (deck exhausted)" % bot.display_name)


# =============================================================================
# PRIVATE METHODS - Helpers
# =============================================================================

## Get valid adjacent zones for movement
## @param current_zone: Current zone id
## @returns: Array - list of valid adjacent zone ids
func _get_valid_adjacent_zones(current_zone: String) -> Array:
	# MVP: Simple adjacency (all zones are adjacent to each other)
	# In full implementation, this would use board adjacency data
	var all_zones = ["hermit", "white", "black"]
	all_zones.erase(current_zone)  # Can't stay in same zone
	return all_zones


## Random delay between actions for readability
## @param scene_tree: SceneTree for timer
func _action_delay(scene_tree: SceneTree) -> void:
	var delay = randf_range(ACTION_DELAY_MIN, ACTION_DELAY_MAX)
	await scene_tree.create_timer(delay).timeout


# =============================================================================
# UTILITY METHODS
# =============================================================================

## Check if player is a bot
## @param player: Player to check
## @returns: bool - true if player is a bot
static func is_bot(player: Player) -> bool:
	return not player.is_human


## Get all bot players from list
## @param players: Array of players
## @returns: Array[Player] - bot players only
static func get_bots(players: Array) -> Array[Player]:
	var bots: Array[Player] = []
	for player in players:
		if is_bot(player):
			bots.append(player)
	return bots


## Get all human players from list
## @param players: Array of players
## @returns: Array[Player] - human players only
static func get_humans(players: Array) -> Array[Player]:
	var humans: Array[Player] = []
	for player in players:
		if player.is_human:
			humans.append(player)
	return humans
