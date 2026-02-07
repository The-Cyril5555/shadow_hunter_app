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

## Bot rolls dice
## @param bot: Bot player rolling
## @returns: int - dice roll result (1-6)
func bot_roll_dice(bot: Player) -> int:
	bot_action_started.emit(bot, "roll_dice")

	var roll = randi() % 6 + 1  # D6: 1-6

	bot_action_completed.emit(bot, "roll_dice", roll)
	print("[BotController] 🎲 %s rolled %d" % [bot.display_name, roll])

	return roll


## Bot moves to zone using AIDecisionEngine (with GameState signal emission)
## @param bot: Bot player moving
## @param roll: Dice roll result (currently unused in MVP)
## @returns: String - target zone id
func bot_move_to_zone(bot: Player, _roll: int) -> String:
	bot_action_started.emit(bot, "move")

	# Build context for decision-making
	var decision_engine = AIDecisionEngine.new()
	var context = AIDecisionEngine.build_action_context(bot, GameState.players)

	# Decide between safe and risky movement
	var movement_actions = [
		AIDecisionEngine.ACTION_MOVE_SAFE,
		AIDecisionEngine.ACTION_MOVE_RISKY
	]
	var chosen_movement = decision_engine.choose_best_action(bot, movement_actions, context)

	# Get valid adjacent zones
	var valid_zones = _get_valid_adjacent_zones(bot.position_zone)

	# Choose zone based on decision using ZoneData deck_type classification
	var target_zone = bot.position_zone
	if valid_zones.size() > 0:
		if chosen_movement == AIDecisionEngine.ACTION_MOVE_SAFE:
			# Safe movement: prefer zones with white/hermit decks (beneficial/vision)
			var available_safe = []
			for zone_id in valid_zones:
				var zone_data = ZoneData.get_zone_by_id(zone_id)
				if zone_data.get("deck_type", "") in ["white", "hermit"]:
					available_safe.append(zone_id)
			target_zone = available_safe.pick_random() if available_safe.size() > 0 else valid_zones.pick_random()
		else:
			# Risky movement: prefer zones with black deck (harmful cards)
			var risky_zones = []
			for zone_id in valid_zones:
				var zone_data = ZoneData.get_zone_by_id(zone_id)
				if zone_data.get("deck_type", "") == "black":
					risky_zones.append(zone_id)
			target_zone = risky_zones.pick_random() if risky_zones.size() > 0 else valid_zones.pick_random()

	# Update position
	var old_zone = bot.position_zone
	bot.position_zone = target_zone

	# Emit GameState signal for movement (for UI updates, etc.)
	GameState.player_moved.emit(bot, target_zone)

	bot_action_completed.emit(bot, "move", target_zone)
	print("[BotController] 🚶 %s moved: %s → %s (%s)" % [bot.display_name, old_zone, target_zone, chosen_movement])

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

	# Calculate and apply damage (using base damage + equipment bonuses)
	var base_damage = 1  # Base attack damage
	var attack_bonus = bot.get_attack_damage_bonus()
	var total_damage = base_damage + attack_bonus

	# Use CombatSystem instance to apply damage
	var combat = CombatSystem.new()
	combat.apply_damage(bot, target, total_damage)

	bot_action_completed.emit(bot, "zone_action", {"action": "attack", "target": target, "damage": total_damage})
	print("[BotController] ✅ %s dealt %d damage to %s (HP: %d → %d)" % [
		bot.display_name,
		total_damage,
		target.display_name,
		target.hp + total_damage,  # before
		target.hp  # after
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

## Get valid adjacent zones for movement using ZoneData adjacency map
## @param current_zone: Current zone id
## @returns: Array - list of valid adjacent zone ids
func _get_valid_adjacent_zones(current_zone: String) -> Array:
	if ZoneData.ZONE_ADJACENCY.has(current_zone):
		return ZoneData.ZONE_ADJACENCY[current_zone].duplicate()
	push_warning("[BotController] No adjacency data for zone: %s" % current_zone)
	return []


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
