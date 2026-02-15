## AIDecisionEngine - Strategic decision-making using Utility AI
##
## Evaluates actions using utility scores (0.0 to 1.0) combined with
## personality weights to create distinct bot behaviors
##
## Features:
## - Utility AI scoring for actions
## - Personality-driven decision weighting
## - Context-aware evaluation
## - Observable personality differences
##
## Pattern: Stateless utility class (RefCounted)
## Usage: AIDecisionEngine.new().choose_best_action(bot, actions, context)
class_name AIDecisionEngine
extends RefCounted


# =============================================================================
# CONSTANTS - Action Types
# =============================================================================

const ACTION_ATTACK: String = "attack"
const ACTION_DEFEND: String = "defend"
const ACTION_MOVE_SAFE: String = "move_safe"
const ACTION_MOVE_RISKY: String = "move_risky"
const ACTION_DRAW_CARD: String = "draw_card"


# =============================================================================
# PUBLIC METHODS - Decision Evaluation
# =============================================================================

## Evaluate a specific action and return utility score (0.0 to 1.0)
## @param bot: Bot player making the decision
## @param action_type: Type of action to evaluate
## @param context: Game state context dictionary
## @returns: float - final utility score (base × personality weight)
func evaluate_action(bot: Player, action_type: String, context: Dictionary) -> float:
	# Calculate base utility (0.0 to 1.0)
	var base_utility: float = 0.0

	match action_type:
		ACTION_ATTACK:
			base_utility = _calculate_attack_utility(bot, context)
		ACTION_DEFEND:
			base_utility = _calculate_defense_utility(bot, context)
		ACTION_MOVE_SAFE, ACTION_MOVE_RISKY:
			base_utility = _calculate_movement_utility(bot, context, action_type == ACTION_MOVE_RISKY)
		ACTION_DRAW_CARD:
			base_utility = _calculate_card_draw_utility(bot, context)
		_:
			push_warning("[AIDecisionEngine] Unknown action type: %s" % action_type)
			return 0.0

	# Get personality weight for this action category
	var action_category = _get_action_category(action_type)
	var personality_weight = PersonalityManager.get_decision_weight(bot, action_category)

	# Final score = base utility × personality weight
	var final_score = base_utility * personality_weight

	# Debug logging
	print("[AIDecisionEngine] %s evaluates %s: base=%.2f, weight=%.2f, final=%.3f" % [
		bot.display_name,
		action_type,
		base_utility,
		personality_weight,
		final_score
	])

	return final_score


## Choose best action from available options
## @param bot: Bot player making the decision
## @param available_actions: Array of action type strings
## @param context: Game state context dictionary
## @returns: String - best action type
func choose_best_action(bot: Player, available_actions: Array, context: Dictionary) -> String:
	if available_actions.is_empty():
		push_warning("[AIDecisionEngine] No available actions for %s" % bot.display_name)
		return ""

	var best_action: String = ""
	var best_score: float = -1.0

	for action in available_actions:
		var score = evaluate_action(bot, action, context)
		if score > best_score:
			best_score = score
			best_action = action

	print("[AIDecisionEngine] %s chose: %s (score: %.3f)" % [bot.display_name, best_action, best_score])
	return best_action


# =============================================================================
# PUBLIC METHODS - Context Building
# =============================================================================

## Build action context from game state
## @param bot: Bot player to build context for
## @param players: Array of all players
## @returns: Dictionary - context for decision evaluation
static func build_action_context(bot: Player, players: Array) -> Dictionary:
	var context = {}

	# Bot state
	context["bot_hp"] = bot.hp
	context["bot_hp_max"] = bot.hp_max
	context["hand_size"] = bot.hand.size()
	context["current_zone"] = bot.position_zone
	context["has_attack_equipment"] = bot.get_attack_damage_bonus() > 0
	context["has_defense_equipment"] = bot.get_defense_bonus() > 0

	# Nearby enemies (same island/group of 2 zones)
	var nearby_enemies = []
	var weakest_hp = 10
	var bot_group = ZoneData.get_group_for_zone(bot.position_zone, GameState.zone_positions)
	for player in players:
		if player != bot and player.is_alive:
			var player_group = ZoneData.get_group_for_zone(player.position_zone, GameState.zone_positions)
			if player_group == bot_group and bot_group != -1:
				nearby_enemies.append(player)
				weakest_hp = min(weakest_hp, player.hp)

	context["nearby_enemies"] = nearby_enemies
	context["weakest_enemy_hp"] = weakest_hp

	# Defense cards in hand (simplified - count equipment cards)
	var defense_cards = 0
	for card in bot.hand:
		if card.get_effect_type() == "defense":
			defense_cards += 1
	context["defense_cards_in_hand"] = defense_cards

	return context


# =============================================================================
# PRIVATE METHODS - Base Utility Calculators
# =============================================================================

## Calculate attack utility based on game state
func _calculate_attack_utility(_bot: Player, context: Dictionary) -> float:
	var utility: float = 0.0

	# Check if there are attackable targets
	var nearby_enemies = context.get("nearby_enemies", [])
	if nearby_enemies.is_empty():
		return 0.0  # Can't attack if no enemies

	# Factors that increase attack utility:
	# 1. Low HP targets (easier to eliminate)
	# 2. Bot has high HP (safer to engage)
	# 3. Bot has attack equipment

	var weakest_enemy_hp = context.get("weakest_enemy_hp", 10)
	var bot_hp = context.get("bot_hp", 10)
	var bot_hp_max = context.get("bot_hp_max", 10)
	var bot_hp_percent = float(bot_hp) / float(bot_hp_max)
	var has_attack_equipment = context.get("has_attack_equipment", false)

	# Base utility from target vulnerability (0.0 to 0.5)
	utility += (1.0 - float(weakest_enemy_hp) / 10.0) * 0.5

	# Bonus for bot being healthy (0.0 to 0.3)
	utility += bot_hp_percent * 0.3

	# Bonus for having attack equipment (0.0 to 0.2)
	if has_attack_equipment:
		utility += 0.2

	# Clamp to 0.0-1.0
	utility = clamp(utility, 0.0, 1.0)

	return utility


## Calculate defense utility based on game state
func _calculate_defense_utility(_bot: Player, context: Dictionary) -> float:
	var utility: float = 0.0

	# Factors that increase defense utility:
	# 1. Bot has low HP (needs protection)
	# 2. Nearby threats (enemies in same zone)
	# 3. Has defensive cards available

	var bot_hp = context.get("bot_hp", 10)
	var bot_hp_max = context.get("bot_hp_max", 10)
	var bot_hp_percent = float(bot_hp) / float(bot_hp_max)
	var nearby_threats = context.get("nearby_enemies", []).size()
	var has_defense_cards = context.get("defense_cards_in_hand", 0) > 0

	# High utility when low HP (inverse of HP percent)
	utility += (1.0 - bot_hp_percent) * 0.6

	# Bonus for nearby threats (0.0 to 0.3)
	utility += min(float(nearby_threats) * 0.15, 0.3)

	# Bonus if defensive cards available (0.0 to 0.1)
	if has_defense_cards:
		utility += 0.1

	# Clamp to 0.0-1.0
	utility = clamp(utility, 0.0, 1.0)

	return utility


## Calculate movement utility
func _calculate_movement_utility(_bot: Player, context: Dictionary, is_risky: bool) -> float:
	var utility: float = 0.5  # Base moderate utility

	# Safe movement: higher utility when threatened
	# Risky movement: higher utility when aggressive and healthy

	var bot_hp = context.get("bot_hp", 10)
	var bot_hp_max = context.get("bot_hp_max", 10)
	var bot_hp_percent = float(bot_hp) / float(bot_hp_max)
	var nearby_enemies = context.get("nearby_enemies", []).size()

	if is_risky:
		# Risky movement prefers: high HP, enemies nearby
		utility = bot_hp_percent * 0.5  # Higher HP = more willing to risk
		utility += min(float(nearby_enemies) * 0.2, 0.4)  # More enemies = more exciting
	else:
		# Safe movement prefers: low HP, no threats
		utility = (1.0 - bot_hp_percent) * 0.5  # Lower HP = prefer safety
		utility += 0.3 if nearby_enemies == 0 else 0.0  # Bonus for empty zones

	utility = clamp(utility, 0.0, 1.0)
	return utility


## Calculate card draw utility
func _calculate_card_draw_utility(_bot: Player, context: Dictionary) -> float:
	var utility: float = 0.0

	# Factors that increase card draw utility:
	# 1. Low hand size (need cards)
	# 2. Valuable deck available (white/black cards)
	# 3. No immediate threats

	var hand_size = context.get("hand_size", 0)
	var current_zone = context.get("current_zone", "")
	var nearby_enemies = context.get("nearby_enemies", []).size()

	# High utility when low hand size
	utility += (1.0 - min(float(hand_size) / 5.0, 1.0)) * 0.5

	# Bonus for valuable decks (white/black better than hermit)
	if current_zone in ["white", "black"]:
		utility += 0.3
	elif current_zone == "hermit":
		utility += 0.1

	# Penalty if enemies nearby (prefer action over cards)
	if nearby_enemies > 0:
		utility -= 0.2

	utility = clamp(utility, 0.0, 1.0)
	return utility


# =============================================================================
# PRIVATE METHODS - Helpers
# =============================================================================

## Map action type to personality weight category
func _get_action_category(action_type: String) -> String:
	match action_type:
		ACTION_ATTACK:
			return "attack"
		ACTION_DEFEND:
			return "defense"
		ACTION_MOVE_SAFE, ACTION_MOVE_RISKY:
			return "risk"
		ACTION_DRAW_CARD:
			return "card_draw"
		_:
			return "card_draw"  # Default to balanced
