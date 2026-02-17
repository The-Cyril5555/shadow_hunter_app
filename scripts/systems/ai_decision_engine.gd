## AIDecisionEngine - Strategic decision-making using Utility AI
##
## Evaluates actions using utility scores (0.0 to 1.0) combined with
## personality weights and faction/character awareness
##
## Features:
## - Utility AI scoring for actions
## - Personality-driven decision weighting
## - Faction-aware targeting (never attack revealed allies)
## - Character-specific strategies (Daniel, Unknown, etc.)
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
const ACTION_REVEAL: String = "reveal"
const ACTION_PASS: String = "pass"
const ACTION_USE_ABILITY: String = "use_ability"


# =============================================================================
# PUBLIC METHODS - Decision Evaluation
# =============================================================================

## Evaluate a specific action and return utility score (0.0 to 1.0)
func evaluate_action(bot: Player, action_type: String, context: Dictionary) -> float:
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
		ACTION_REVEAL:
			base_utility = _calculate_reveal_utility(bot, context)
		ACTION_PASS:
			# Pass returns absolute score (no personality weight)
			var pass_score = _calculate_pass_utility(bot, context)
			print("[AIDecisionEngine] %s evaluates pass: score=%.3f" % [bot.display_name, pass_score])
			return pass_score
		ACTION_USE_ABILITY:
			# Ability returns absolute score (no personality weight)
			var ability_score = _calculate_ability_utility(bot, context)
			print("[AIDecisionEngine] %s evaluates use_ability: score=%.3f" % [bot.display_name, ability_score])
			return ability_score
		_:
			push_warning("[AIDecisionEngine] Unknown action type: %s" % action_type)
			return 0.0

	var action_category = _get_action_category(action_type)
	var personality_weight = PersonalityManager.get_decision_weight(bot, action_category)
	var final_score = base_utility * personality_weight

	print("[AIDecisionEngine] %s evaluates %s: base=%.2f, weight=%.2f, final=%.3f" % [
		bot.display_name, action_type, base_utility, personality_weight, final_score
	])

	return final_score


## Choose best action from available options
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
static func build_action_context(bot: Player, players: Array) -> Dictionary:
	var context = {}

	# Bot identity
	context["bot_hp"] = bot.hp
	context["bot_hp_max"] = bot.hp_max
	context["bot_faction"] = bot.faction
	context["bot_character_id"] = bot.character_id
	context["hand_size"] = bot.hand.size()
	context["current_zone"] = bot.position_zone
	context["has_attack_equipment"] = bot.get_attack_damage_bonus() > 0
	context["has_defense_equipment"] = bot.get_defense_bonus() > 0
	context["is_revealed"] = bot.is_revealed
	context["equipment_count"] = bot.equipment.size()

	# Nearby players (same island/group of 2 zones)
	var nearby_allies: Array = []
	var nearby_enemies: Array = []
	var nearby_unknown: Array = []
	var bot_group = ZoneData.get_group_for_zone(bot.position_zone, GameState.zone_positions)

	for player in players:
		if player == bot or not player.is_alive:
			continue
		var player_group = ZoneData.get_group_for_zone(player.position_zone, GameState.zone_positions)
		if player_group != bot_group or bot_group == -1:
			continue
		# Categorize by faction awareness
		if player.is_revealed:
			if _is_ally_static(bot, player):
				nearby_allies.append(player)
			else:
				nearby_enemies.append(player)
		else:
			nearby_unknown.append(player)

	context["nearby_allies"] = nearby_allies
	context["nearby_enemies"] = nearby_enemies
	context["nearby_unknown"] = nearby_unknown
	# Legacy key for compatibility: all attackable nearby players (enemies + unknown)
	context["nearby_targets"] = nearby_enemies + nearby_unknown

	# Weakest enemy HP
	var weakest_hp: int = 99
	for p in nearby_enemies:
		weakest_hp = min(weakest_hp, p.hp)
	for p in nearby_unknown:
		weakest_hp = min(weakest_hp, p.hp)
	context["weakest_enemy_hp"] = weakest_hp if weakest_hp < 99 else 10

	# Global game state
	context["revealed_hunters"] = players.filter(func(p): return p.is_revealed and p.faction == "hunter" and p.is_alive)
	context["revealed_shadows"] = players.filter(func(p): return p.is_revealed and p.faction == "shadow" and p.is_alive)
	context["dead_count"] = players.filter(func(p): return not p.is_alive).size()

	# Defense cards in hand
	var defense_cards = 0
	for card in bot.hand:
		if card.get_effect_type() == "defense":
			defense_cards += 1
	context["defense_cards_in_hand"] = defense_cards

	# Agnes: right neighbor (never attack them — win condition)
	var bot_idx = players.find(bot)
	if bot_idx != -1:
		var right_idx = (bot_idx + 1) % players.size()
		context["right_neighbor_id"] = players[right_idx].id
	else:
		context["right_neighbor_id"] = -1

	# Ultra Soul: players at Underworld (Murder Ray targeting)
	context["players_at_underworld"] = players.filter(
		func(p): return p.position_zone == "underworld" and p.is_alive and p != bot
	).size()

	# Bob: total equipment held by other alive players
	var total_equipment: int = 0
	for p in players:
		if p != bot and p.is_alive:
			total_equipment += p.equipment.size()
	context["total_equipment_in_play"] = total_equipment

	return context


## Check if two players are faction allies (static version for context building)
static func _is_ally_static(bot: Player, player: Player) -> bool:
	if bot.faction == "neutral" or player.faction == "neutral":
		return false
	return bot.faction == player.faction


## Check if two players are faction allies (instance version)
func _is_ally(bot: Player, player: Player) -> bool:
	return AIDecisionEngine._is_ally_static(bot, player)


# =============================================================================
# PRIVATE METHODS - Base Utility Calculators
# =============================================================================

## Calculate attack utility — faction-aware, character-specific
func _calculate_attack_utility(bot: Player, context: Dictionary) -> float:
	var nearby_enemies: Array = context.get("nearby_enemies", [])
	var nearby_unknown: Array = context.get("nearby_unknown", [])
	var targets = nearby_enemies + nearby_unknown

	if targets.is_empty():
		return 0.0

	var utility: float = 0.0
	var bot_hp_percent = float(context.get("bot_hp", 10)) / float(context.get("bot_hp_max", 10))
	var has_attack_equipment = context.get("has_attack_equipment", false)
	var character_id: String = context.get("bot_character_id", "")

	# Base utility from target vulnerability (0.0 to 0.4)
	var weakest_hp = context.get("weakest_enemy_hp", 10)
	utility += (1.0 - float(weakest_hp) / 14.0) * 0.4

	# Bonus for confirmed enemies nearby (0.0 to 0.3)
	if nearby_enemies.size() > 0:
		utility += 0.3
	elif nearby_unknown.size() > 0:
		utility += 0.1  # Less confident about attacking unknowns

	# Bot health factor (0.0 to 0.2)
	utility += bot_hp_percent * 0.2

	# Equipment bonus
	if has_attack_equipment:
		utility += 0.15

	# === Character-specific attack modifiers ===
	var dead_count: int = context.get("dead_count", 0)

	match character_id:
		# -- Hunters --
		"emi":
			# Fragile (8HP) — only attack confirmed enemies
			if nearby_enemies.size() > 0:
				utility += 0.15
			else:
				utility -= 0.2
		"franklin":
			# Aggressive hunter, Lightning in reserve
			if nearby_enemies.size() > 0:
				utility += 0.2
			else:
				utility += 0.05
		"george":
			# Tank hunter (14HP) — front-line aggressive
			utility += 0.2
		"ellen":
			# Cautious, prefers identifying curse targets
			if nearby_enemies.size() > 0:
				utility += 0.1
			else:
				utility -= 0.1
		"fuka":
			# Standard hunter, Nurse in reserve
			if nearby_enemies.size() > 0:
				utility += 0.15
		"gregor":
			# Brave with Ghostly Barrier safety net
			utility += 0.15
			if not bot.ability_used and not bot.ability_disabled:
				utility += 0.1

		# -- Shadows --
		"unknown":
			# Deceptive — stay hidden, only attack confirmed hunters
			if not bot.is_revealed:
				utility -= 0.15
			if nearby_enemies.size() > 0:
				utility += 0.2
		"vampire":
			# Ultra-aggressive — Suck Blood heals on attack
			utility += 0.35
			if bot.is_revealed and not bot.ability_disabled:
				utility += 0.1
		"werewolf":
			# Tank shadow (14HP) + Counterattack
			utility += 0.25
		"ultra_soul":
			# Standard shadow, Murder Ray bonus if targets at Underworld
			if nearby_enemies.size() > 0:
				utility += 0.15
			var players_at_underworld: int = context.get("players_at_underworld", 0)
			if players_at_underworld > 0 and bot.is_revealed and not bot.ability_used:
				utility += 0.2
		"valkyrie":
			# No-miss attacks (d4 only) — most reliable attacker
			utility += 0.35
			if bot.is_revealed and not bot.ability_disabled:
				utility += 0.15
		"wight":
			# Passive early, burst after Multiplication
			if dead_count >= 2:
				utility += 0.3
			elif dead_count == 1:
				utility += 0.1
			else:
				utility -= 0.15

		# -- Neutrals --
		"daniel":
			# Provocateur: dead=0 → provoke (attack strong), dead≥1 → must kill
			if dead_count == 0:
				utility += 0.4
			else:
				utility += 0.5  # Pivot: must secure a kill now
		"bob":
			# Steal equipment on 2+ damage
			var equip_count: int = context.get("equipment_count", 0)
			for t in targets:
				if not t.equipment.is_empty():
					utility += 0.2
					break
			if equip_count >= 3:
				utility += 0.15
			var total_equip: int = context.get("total_equipment_in_play", 0)
			if total_equip == 0:
				utility -= 0.2
		"bryan":
			# Kill 13+ HP targets
			for t in targets:
				if t.hp_max >= 13:
					utility += 0.25
					break
		"charles":
			# Late-game assassin: passive until 3+ dead
			if dead_count >= 3:
				utility += 0.45
			elif dead_count == 2:
				utility += 0.1
			else:
				utility -= 0.25
		"catherine":
			# dead=0: kamikaze (die first = win). dead≥1: pivot to survival
			if dead_count == 0:
				utility += 0.35
			else:
				utility -= 0.2
		"allie", "agnes":
			# Pacifists — avoid combat
			utility -= 0.3
		"david":
			# Prefers equipment over combat
			utility -= 0.2

	return clamp(utility, 0.0, 1.0)


## Calculate defense utility
func _calculate_defense_utility(_bot: Player, context: Dictionary) -> float:
	var utility: float = 0.0
	var bot_hp_percent = float(context.get("bot_hp", 10)) / float(context.get("bot_hp_max", 10))
	var nearby_threats = context.get("nearby_enemies", []).size() + context.get("nearby_unknown", []).size()
	var has_defense_cards = context.get("defense_cards_in_hand", 0) > 0

	utility += (1.0 - bot_hp_percent) * 0.6
	utility += min(float(nearby_threats) * 0.15, 0.3)
	if has_defense_cards:
		utility += 0.1

	return clamp(utility, 0.0, 1.0)


## Calculate movement utility
func _calculate_movement_utility(_bot: Player, context: Dictionary, is_risky: bool) -> float:
	var utility: float = 0.5
	var bot_hp_percent = float(context.get("bot_hp", 10)) / float(context.get("bot_hp_max", 10))
	var nearby_threats = context.get("nearby_enemies", []).size() + context.get("nearby_unknown", []).size()

	if is_risky:
		utility = bot_hp_percent * 0.5
		utility += min(float(nearby_threats) * 0.2, 0.4)
	else:
		utility = (1.0 - bot_hp_percent) * 0.5
		utility += 0.3 if nearby_threats == 0 else 0.0

	return clamp(utility, 0.0, 1.0)


## Calculate reveal utility — character-specific strategies
func _calculate_reveal_utility(bot: Player, context: Dictionary) -> float:
	if bot.is_revealed:
		return 0.0

	var character_id: String = context.get("bot_character_id", "")
	var bot_hp_percent = float(context.get("bot_hp", 10)) / float(context.get("bot_hp_max", 10))
	var nearby_enemies: Array = context.get("nearby_enemies", [])
	var bot_faction: String = context.get("bot_faction", "")

	# === Characters that should NEVER reveal ===
	if character_id == "daniel":
		return 0.0  # Cannot voluntarily reveal
	if character_id == "unknown":
		return 0.0  # Power is deception — never reveal

	var utility: float = 0.0

	# === Near-death reveal for Hunters/Shadows (signal allies) ===
	if bot_hp_percent <= 0.3 and bot_faction != "neutral":
		utility += 0.6

	# === Character-specific reveal logic ===
	match character_id:
		# -- Hunters --
		"emi":
			# Reveal early for teleport ability
			utility += 0.3
		"franklin", "george":
			# Reveal when enemy identified nearby (active damage ability)
			if nearby_enemies.size() > 0:
				utility += 0.5
			else:
				utility += 0.1
		"ellen":
			# Reveal when enemy Shadow ability is dangerous
			var revealed_shadows: Array = context.get("revealed_shadows", [])
			if revealed_shadows.size() > 0:
				utility += 0.4
			else:
				utility += 0.1
		"fuka":
			# Reveal to heal allies (Dynamite Nurse)
			var allies: Array = context.get("nearby_allies", [])
			for ally in allies:
				if float(ally.hp) / float(ally.hp_max) < 0.5:
					utility += 0.5
					break
			utility += 0.1
		"gregor":
			# Reveal when HP low for Ghostly Barrier
			if bot_hp_percent < 0.5:
				utility += 0.4
			else:
				utility += 0.05

		# -- Shadows --
		"vampire":
			# Reveal when HP low (Suck Blood heals on attack)
			if bot_hp_percent < 0.6:
				utility += 0.3
			if nearby_enemies.size() > 0:
				utility += 0.2
		"werewolf":
			# Reveal to deter attacks (Counterattack passive)
			if nearby_enemies.size() > 0:
				utility += 0.3
			if bot_hp_percent < 0.5:
				utility += 0.2
		"ultra_soul":
			# Reveal for Murder Ray (needs Underworld zone)
			utility += 0.2
		"valkyrie":
			# Reveal for Horn of War (d4 attack instead of |d6-d4|)
			if nearby_enemies.size() > 0:
				utility += 0.4
			else:
				utility += 0.1
		"wight":
			# Reveal late for Multiplication (extra turns = dead count)
			var dead_count: int = context.get("dead_count", 0)
			if dead_count >= 2:
				utility += 0.5
			else:
				utility += 0.05

		# -- Neutrals --
		"allie":
			# Reveal when HP critical for Mother's Love (full heal)
			if bot_hp_percent <= 0.3:
				utility += 0.7
			else:
				utility += 0.0
		"bob":
			# Reveal when close to win (3+ equipment)
			var equip_count: int = context.get("equipment_count", 0)
			if equip_count >= 3:
				utility += 0.5
			else:
				utility += 0.05
		"charles":
			# Stay hidden until 3+ dead
			var dead_count: int = context.get("dead_count", 0)
			if dead_count >= 3:
				utility += 0.4
			else:
				utility += 0.0
		"agnes":
			# Stay low profile
			utility += 0.05
		"bryan":
			# Reveal is passive (on kill) — low voluntary reveal
			utility += 0.05
		"catherine":
			# Survive — reveal only if critical
			if bot_hp_percent <= 0.25:
				utility += 0.3
			else:
				utility += 0.0
		"david":
			# Stay hidden, collect equipment
			utility += 0.05

	return clamp(utility, 0.0, 1.0)


## Calculate card draw utility — zone-aware
func _calculate_card_draw_utility(bot: Player, context: Dictionary) -> float:
	var utility: float = 0.0
	var hand_size: int = context.get("hand_size", 0)
	var current_zone: String = context.get("current_zone", "")
	var nearby_threats: int = context.get("nearby_enemies", []).size() + context.get("nearby_unknown", []).size()
	var character_id: String = context.get("bot_character_id", "")

	# Base: hand size factor
	utility += (1.0 - min(float(hand_size) / 5.0, 1.0)) * 0.5

	# Zone deck quality — use ZoneData to get proper deck_type
	var zone_info = ZoneData.get_zone_by_id(current_zone)
	var deck_type: String = zone_info.get("deck_type", "")
	if deck_type in ["white", "black"]:
		utility += 0.3
	elif deck_type == "hermit":
		utility += 0.1

	# Penalty if enemies nearby
	if nearby_threats > 0:
		utility -= 0.2

	# Character-specific draw bonuses
	match character_id:
		"david":
			# David wants equipment — draw a lot
			utility += 0.3
		"allie", "agnes", "catherine":
			# Passive players prefer drawing
			utility += 0.15

	return clamp(utility, 0.0, 1.0)


## Calculate pass utility — character-specific decision to do nothing
## Returns absolute score (not weighted by personality)
func _calculate_pass_utility(bot: Player, context: Dictionary) -> float:
	var character_id: String = context.get("bot_character_id", "")
	var dead_count: int = context.get("dead_count", 0)
	var nearby_enemies: Array = context.get("nearby_enemies", [])
	var total_equip: int = context.get("total_equipment_in_play", 0)

	match character_id:
		# -- Hunters --
		"emi":
			# Fragile, passes often
			return 0.3
		"franklin":
			# Sometimes passes if no confirmed target
			return 0.15
		"george":
			# Tank, rarely passes
			return 0.1
		"ellen":
			# Prefers observing
			return 0.25
		"fuka":
			# Moderate, waits for the right moment
			return 0.2
		"gregor":
			# Brave but not reckless
			return 0.15

		# -- Shadows --
		"unknown":
			# Discreet while hidden, less so when revealed
			return 0.3 if not bot.is_revealed else 0.15
		"vampire":
			# Almost never passes — attack = heal
			return 0.05
		"werewolf":
			# Aggressive tank
			return 0.1
		"ultra_soul":
			# Moderate
			return 0.2
		"valkyrie":
			# No-miss fighter, almost never passes
			return 0.05
		"wight":
			# Passive early, never passes late
			return 0.35 if dead_count < 2 else 0.05

		# -- Neutrals --
		"daniel":
			# Never passes: dead=0 provoke, dead≥1 must kill
			return 0.05 if dead_count == 0 else 0.0
		"bob":
			# Active if loot available, passive otherwise
			return 0.15 if total_equip > 0 else 0.3
		"bryan":
			# Patient sniper — passes if no 13+ HP target nearby
			var has_big_target: bool = false
			for t in nearby_enemies + context.get("nearby_unknown", []):
				if t.hp_max >= 13:
					has_big_target = true
					break
			return 0.2 if has_big_target else 0.35
		"charles":
			# Waits for 3+ dead, then never passes
			return 0.4 if dead_count < 3 else 0.05
		"catherine":
			# Kamikaze early (low pass), survival late (high pass)
			return 0.1 if dead_count == 0 else 0.4
		"allie":
			# Avoids conflict
			return 0.4
		"agnes":
			# Avoids conflict
			return 0.4
		"david":
			# Avoids combat, seeks equipment
			return 0.4
		_:
			return 0.2


## Calculate ability utility — character-specific, returns absolute score
## Only called when bot is revealed, ability not used, and not disabled
func _calculate_ability_utility(bot: Player, context: Dictionary) -> float:
	var character_id: String = context.get("bot_character_id", "")
	var bot_hp_percent: float = float(context.get("bot_hp", 10)) / float(context.get("bot_hp_max", 10))
	var nearby_enemies: Array = context.get("nearby_enemies", [])
	var nearby_unknown: Array = context.get("nearby_unknown", [])
	var dead_count: int = context.get("dead_count", 0)

	match character_id:
		"franklin":
			# Lightning (d6 damage) — use when enemy with low HP nearby
			if nearby_enemies.size() > 0:
				var weakest_hp: int = context.get("weakest_enemy_hp", 10)
				if weakest_hp <= 4:
					return 0.8  # High chance of kill
				return 0.5
			if nearby_unknown.size() > 0:
				return 0.3
			return 0.1  # No nearby target, save for later

		"george":
			# Demolish (d4 damage) — similar but weaker
			if nearby_enemies.size() > 0:
				var weakest_hp: int = context.get("weakest_enemy_hp", 10)
				if weakest_hp <= 3:
					return 0.7
				return 0.4
			if nearby_unknown.size() > 0:
				return 0.25
			return 0.1

		"allie":
			# Mother's Love (full heal) — use when HP critical
			if bot_hp_percent <= 0.3:
				return 0.85  # Life-saving
			if bot_hp_percent <= 0.5:
				return 0.5
			return 0.05  # No need to heal yet

		"ellen":
			# Curse (disable ability) — use on dangerous revealed Shadow
			var revealed_shadows: Array = context.get("revealed_shadows", [])
			for shadow in revealed_shadows:
				if not shadow.ability_used and not shadow.ability_disabled:
					# Dangerous shadow with active ability
					if shadow.character_id in ["vampire", "valkyrie", "werewolf", "wight"]:
						return 0.7
					return 0.5
			return 0.1  # No good curse target

		"fuka":
			# Dynamite Nurse (set damage to 7) — use on heavily damaged ally
			var nearby_allies: Array = context.get("nearby_allies", [])
			for ally in nearby_allies:
				var ally_damage: int = ally.hp_max - ally.hp
				if ally_damage > 7:
					return 0.7  # Heal ally by reducing damage to 7
			# Can also use on enemy to set damage to 7
			for enemy in nearby_enemies:
				var enemy_damage: int = enemy.hp_max - enemy.hp
				if enemy_damage < 5:
					return 0.5  # Force more damage on enemy
			return 0.15

		"gregor":
			# Ghostly Barrier (shield until next turn) — use when low HP and threatened
			if bot_hp_percent <= 0.4 and (nearby_enemies.size() + nearby_unknown.size()) > 0:
				return 0.75
			if bot_hp_percent <= 0.5:
				return 0.4
			return 0.1

		"wight":
			# Multiplication (extra turns = dead count) — use when dead_count high
			if dead_count >= 3:
				return 0.85
			if dead_count >= 2:
				return 0.65
			if dead_count == 1:
				return 0.3
			return 0.05  # No dead = useless

		"ultra_soul":
			# Murder Ray (3 damage to all at Underworld) — unlimited use
			var players_at_underworld: int = context.get("players_at_underworld", 0)
			if players_at_underworld >= 2:
				return 0.8
			if players_at_underworld == 1:
				return 0.5
			return 0.0  # No targets at Underworld

		"agnes":
			# Capriccio (swap target direction) — use if right neighbor is losing
			# Niche: only useful if left neighbor is winning instead
			return 0.15  # Rarely worth using early

		"david":
			# Grave Digger (equipment from discard) — use if discard has good equipment
			var has_discard_equipment: bool = false
			for deck in [GameState.hermit_deck, GameState.white_deck, GameState.black_deck]:
				if deck and deck.get_discard_count() > 0:
					# Check if any discarded card is equipment
					for card in deck.discard_pile:
						if card.type == "equipment":
							has_discard_equipment = true
							break
				if has_discard_equipment:
					break
			if has_discard_equipment:
				return 0.55
			return 0.05

		_:
			return 0.1


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
		ACTION_REVEAL:
			return "reveal"
		_:
			return "card_draw"
