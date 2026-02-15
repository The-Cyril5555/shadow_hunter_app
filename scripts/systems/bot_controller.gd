## BotController - Handles AI bot turn execution
##
## Provides automated turn execution for bot players with intelligent decision-making
## Uses AIDecisionEngine for personality-driven choices
##
## Features:
## - Bot turn detection
## - Automated action sequence (roll → move → zone action)
## - Intelligent decision-making using AIDecisionEngine
## - Personality-driven behavior (aggressive, prudent, balanced)
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

## Bot rolls dice (d6 + d4)
## @param bot: Bot player rolling
## @returns: int - dice roll result (2-10)
func bot_roll_dice(bot: Player) -> int:
	bot_action_started.emit(bot, "roll_dice")

	var d6 = randi() % 6 + 1
	var d4 = randi() % 4 + 1
	var roll = d6 + d4

	bot_action_completed.emit(bot, "roll_dice", roll)
	print("[BotController] %s rolled d6=%d + d4=%d = %d" % [bot.display_name, d6, d4, roll])

	return roll


## Bot moves to zone based on dice roll (direct dice → zone mapping)
## @param bot: Bot player moving
## @param roll: Dice roll result (d6+d4 sum, 2-10)
## @returns: String - target zone id
func bot_move_to_zone(bot: Player, roll: int) -> String:
	bot_action_started.emit(bot, "move")

	# Direct dice → zone mapping
	var target_zone = ZoneData.get_zone_for_dice_sum(roll, GameState.zone_positions)

	if target_zone == "":
		push_warning("[BotController] No zone found for dice sum %d" % roll)
		target_zone = bot.position_zone

	# Update position
	var old_zone = bot.position_zone
	bot.position_zone = target_zone

	# Emit GameState signal for movement (for UI updates, etc.)
	GameState.player_moved.emit(bot, target_zone)

	bot_action_completed.emit(bot, "move", target_zone)
	print("[BotController] %s moved: %s -> %s (roll: %d)" % [bot.display_name, old_zone, target_zone, roll])

	return target_zone


## Bot executes zone action using AIDecisionEngine (draw card or attack)
## @param bot: Bot player executing action
## @param zone: Current zone
func bot_execute_zone_action(bot: Player, zone: String) -> void:
	bot_action_started.emit(bot, "zone_action")

	# Build context for decision-making
	var decision_engine = AIDecisionEngine.new()
	var context = AIDecisionEngine.build_action_context(bot, GameState.players)

	# Determine available actions based on zone and surroundings
	var available_actions: Array = []

	# Can only draw card if zone has a deck
	var deck: DeckManager = GameState.get_deck_for_zone(zone)
	if deck != null and deck.get_card_count() > 0:
		available_actions.append(AIDecisionEngine.ACTION_DRAW_CARD)

	# Check if there are enemies to attack
	var nearby_enemies = context.get("nearby_enemies", [])
	if nearby_enemies.size() > 0:
		available_actions.append(AIDecisionEngine.ACTION_ATTACK)

	# Fallback: if no actions available, just skip
	if available_actions.is_empty():
		print("[BotController] ⚠️ %s has no available actions in zone %s" % [bot.display_name, zone])
		bot_action_completed.emit(bot, "zone_action", null)
		return

	# Choose best action based on personality and context
	var chosen_action = decision_engine.choose_best_action(bot, available_actions, context)

	# Execute chosen action
	match chosen_action:
		AIDecisionEngine.ACTION_ATTACK:
			_execute_bot_attack(bot, nearby_enemies)
		AIDecisionEngine.ACTION_DRAW_CARD:
			_execute_bot_draw_card(bot, zone)
		_:
			push_warning("[BotController] Unknown action chosen: %s" % chosen_action)
			_execute_bot_draw_card(bot, zone)  # Fallback to draw


## Execute bot attack on weakest enemy
## @param bot: Bot attacking
## @param enemies: Array of nearby enemies
func _execute_bot_attack(bot: Player, enemies: Array) -> void:
	# Choose weakest enemy as target
	var target: Player = null
	var lowest_hp = 999

	for enemy in enemies:
		if enemy.hp < lowest_hp:
			lowest_hp = enemy.hp
			target = enemy

	if target == null:
		push_warning("[BotController] No valid target for attack")
		bot_action_completed.emit(bot, "zone_action", null)
		return

	print("[BotController] ⚔️ %s attacking %s (HP: %d)" % [bot.display_name, target.display_name, target.hp])

	# Calculate damage using Shadow Hunters rules: |D6 - D4|
	var combat = CombatSystem.new()
	var result = combat.calculate_attack_damage(bot, target)

	if result.missed:
		print("[BotController] ❌ %s missed! (D6=%d == D4=%d)" % [bot.display_name, result.d6, result.d4])
		bot_action_completed.emit(bot, "zone_action", {"action": "attack", "target": target, "damage": 0, "missed": true})
		return

	var hp_before = target.hp
	combat.apply_damage(bot, target, result.total)

	bot_action_completed.emit(bot, "zone_action", {"action": "attack", "target": target, "damage": result.total, "missed": false})
	print("[BotController] ✅ %s dealt %d damage to %s (HP: %d → %d)" % [
		bot.display_name,
		result.total,
		target.display_name,
		hp_before,
		target.hp
	])


## Execute bot card draw
## @param bot: Bot drawing card
## @param zone: Current zone
func _execute_bot_draw_card(bot: Player, zone: String) -> void:
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
