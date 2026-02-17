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

	# Mystic Compass — roll twice, pick preferred zone
	if CombatSystem._has_active_equipment(bot, "double_dice_roll"):
		var d6_2 = randi() % 6 + 1
		var d4_2 = randi() % 4 + 1
		var roll2 = d6_2 + d4_2
		# Prefer zone with a deck (for drawing cards)
		var zone1 = ZoneData.get_zone_for_dice_sum(roll, GameState.zone_positions)
		var zone2 = ZoneData.get_zone_for_dice_sum(roll2, GameState.zone_positions)
		var deck1 = GameState.get_deck_for_zone(zone1)
		var deck2 = GameState.get_deck_for_zone(zone2)
		var has_deck1 = deck1 != null and deck1.get_card_count() > 0
		var has_deck2 = deck2 != null and deck2.get_card_count() > 0
		if has_deck2 and not has_deck1:
			roll = roll2
		print("[BotController] %s (Mystic Compass) rolled %d and %d, chose %d" % [bot.display_name, d6 + d4, roll2, roll])

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


## Bot executes zone action: zone effect OR draw, then optional attack/reveal/ability/pass
## @param bot: Bot player executing action
## @param zone: Current zone
func bot_execute_zone_action(bot: Player, zone: String) -> void:
	bot_action_started.emit(bot, "zone_action")

	var zone_data = ZoneData.get_zone_by_id(zone)
	var has_effect: bool = zone_data.has("effect") and zone_data.get("effect", "") != ""
	var deck: DeckManager = GameState.get_deck_for_zone(zone)

	# STEP 1: Zone action (mutually exclusive: effect OR draw)
	if has_effect:
		# Special zone (weird_woods, underworld, altar)
		var effect_result = _execute_bot_zone_effect(bot, zone_data)
		bot_action_completed.emit(bot, "zone_effect", effect_result)
	elif deck != null and deck.get_card_count() > 0:
		# Deck zone (hermit, church, cemetery) — mandatory draw
		_execute_bot_draw_card(bot, zone)

	# STEP 2: Optional action (attack / reveal / ability / pass)
	var decision_engine = AIDecisionEngine.new()
	var context = AIDecisionEngine.build_action_context(bot, GameState.players)
	var optional_actions: Array = [AIDecisionEngine.ACTION_PASS]

	# Can attack if valid targets nearby
	var nearby_targets: Array = context.get("nearby_targets", [])
	if nearby_targets.size() > 0:
		optional_actions.append(AIDecisionEngine.ACTION_ATTACK)

	# Can reveal if not already revealed and not Daniel
	if not bot.is_revealed and bot.character_id != "daniel":
		optional_actions.append(AIDecisionEngine.ACTION_REVEAL)

	# Can use active ability if revealed and not used yet
	if bot.is_revealed and not bot.ability_used and not bot.ability_disabled:
		if bot.character_id in ["franklin", "george", "allie", "ellen", "fuka", "gregor", "wight", "ultra_soul", "agnes", "david"]:
			optional_actions.append(AIDecisionEngine.ACTION_USE_ABILITY)

	# Cursed Sword Masamune — must attack if targets available
	var forced_attack = CombatSystem._has_active_equipment(bot, "forced_attack") and nearby_targets.size() > 0

	# Choose best optional action
	var chosen_action = decision_engine.choose_best_action(bot, optional_actions, context)
	if forced_attack:
		chosen_action = AIDecisionEngine.ACTION_ATTACK

	match chosen_action:
		AIDecisionEngine.ACTION_ATTACK:
			_execute_bot_attack(bot, context)
		AIDecisionEngine.ACTION_REVEAL:
			_execute_bot_reveal(bot)
		AIDecisionEngine.ACTION_USE_ABILITY:
			_execute_bot_ability(bot, context)
		_:
			print("[BotController] %s passes optional action" % bot.display_name)
			bot_action_completed.emit(bot, "zone_action", null)


## Execute bot attack with faction-aware target selection
## @param bot: Bot attacking
## @param context: Action context from AIDecisionEngine
func _execute_bot_attack(bot: Player, context: Dictionary) -> void:
	var nearby_enemies: Array = context.get("nearby_enemies", [])
	var nearby_unknown: Array = context.get("nearby_unknown", [])

	# Select target based on character strategy
	var target: Player = _select_attack_target(bot, nearby_enemies, nearby_unknown, context)

	if target == null:
		print("[BotController] %s has no valid attack target — skipping" % bot.display_name)
		bot_action_completed.emit(bot, "zone_action", null)
		return

	print("[BotController] %s attacking %s (HP: %d/%d, revealed: %s)" % [
		bot.display_name, target.display_name, target.hp, target.hp_max,
		"yes" if target.is_revealed else "no"
	])

	# Calculate damage using Shadow Hunters rules: |D6 - D4|
	var combat = CombatSystem.new()
	var result = combat.calculate_attack_damage(bot, target)

	if result.missed:
		print("[BotController] %s missed! (D6=%d == D4=%d)" % [bot.display_name, result.d6, result.d4])
		bot_action_completed.emit(bot, "zone_action", {"action": "attack", "target": target, "damage": 0, "missed": true})
		return

	var hp_before = target.hp
	combat.apply_damage(bot, target, result.total)

	bot_action_completed.emit(bot, "zone_action", {"action": "attack", "target": target, "damage": result.total, "missed": false})
	print("[BotController] %s dealt %d damage to %s (HP: %d -> %d)" % [
		bot.display_name, result.total, target.display_name, hp_before, target.hp
	])


## Select attack target based on character strategy and game state
## Priority: revealed enemies > unknown players (NEVER revealed allies)
## @param bot: Bot attacking
## @param enemies: Revealed enemy players nearby
## @param unknowns: Unrevealed players nearby
## @param context: Action context for game state awareness
## @returns: Player target or null
func _select_attack_target(bot: Player, enemies: Array, unknowns: Array, context: Dictionary = {}) -> Player:
	var character_id: String = bot.character_id
	var dead_count: int = context.get("dead_count", 0)

	# === Character-specific targeting ===
	match character_id:
		"daniel":
			# dead=0: provoke by attacking strongest. dead≥1: must kill, target weakest
			if dead_count == 0:
				return _pick_strongest(enemies, unknowns)
			else:
				return _pick_weakest(enemies, unknowns)
		"bryan":
			# Bryan wants to kill 13+ HP targets for win condition
			var big_target = _pick_hp_max_above(enemies, unknowns, 13)
			if big_target:
				return big_target
			return _pick_weakest(enemies, unknowns)
		"bob":
			# Bob wants to steal equipment — prioritize equipped targets
			var equipped_target = _pick_with_equipment(enemies, unknowns)
			if equipped_target:
				return equipped_target
			return _pick_weakest(enemies, unknowns)
		"agnes":
			# NEVER attack right neighbor (their win = Agnes's win)
			var right_id: int = context.get("right_neighbor_id", -1)
			var safe_enemies = enemies.filter(func(p): return p.id != right_id)
			var safe_unknowns = unknowns.filter(func(p): return p.id != right_id)
			if safe_enemies.is_empty() and safe_unknowns.is_empty():
				return null  # Only right neighbor available — skip attack
			return _pick_weakest(safe_enemies, safe_unknowns)
		"unknown":
			# Prefer confirmed enemies only to maintain cover
			if not enemies.is_empty():
				return _pick_weakest(enemies, [])
			return _pick_weakest([], unknowns)
		"vampire":
			# Target undefended players to maximize Suck Blood heal
			var undefended = _pick_without_defense(enemies, unknowns)
			if undefended:
				return undefended
			return _pick_weakest(enemies, unknowns)
		"catherine":
			# dead=0: kamikaze — attack strongest to provoke death
			# dead≥1: survival — attack weakest to minimize retaliation
			if dead_count == 0:
				return _pick_strongest(enemies, unknowns)
			else:
				return _pick_weakest(enemies, unknowns)
		_:
			# Default: attack revealed enemies first (weakest), then unknowns
			return _pick_weakest(enemies, unknowns)


## Pick weakest target — prefer revealed enemies over unknowns
func _pick_weakest(enemies: Array, unknowns: Array) -> Player:
	var pool: Array = enemies if not enemies.is_empty() else unknowns
	if pool.is_empty():
		return null

	var target: Player = pool[0]
	for p in pool:
		if p.hp < target.hp:
			target = p
	return target


## Pick strongest target (Daniel strategy)
func _pick_strongest(enemies: Array, unknowns: Array) -> Player:
	var pool: Array = enemies + unknowns
	if pool.is_empty():
		return null

	var target: Player = pool[0]
	for p in pool:
		if p.hp > target.hp:
			target = p
	return target


## Pick target with hp_max >= threshold (Bryan strategy)
func _pick_hp_max_above(enemies: Array, unknowns: Array, threshold: int) -> Player:
	# Prefer revealed enemies with high HP max
	for p in enemies:
		if p.hp_max >= threshold:
			return p
	# Then unknowns (less certain but worth trying)
	for p in unknowns:
		if p.hp_max >= threshold:
			return p
	return null


## Pick target with equipment (Bob strategy)
func _pick_with_equipment(enemies: Array, unknowns: Array) -> Player:
	for p in enemies:
		if not p.equipment.is_empty():
			return p
	for p in unknowns:
		if not p.equipment.is_empty():
			return p
	return null


## Pick target without defense equipment (Vampire strategy — maximize heal)
func _pick_without_defense(enemies: Array, unknowns: Array) -> Player:
	for p in enemies:
		if p.get_defense_bonus() == 0:
			return p
	for p in unknowns:
		if p.get_defense_bonus() == 0:
			return p
	return null


## Execute bot zone effect (Weird Woods / Underworld / Altar)
## @param bot: Bot activating zone effect
## @param zone_data: Zone dictionary from ZoneData
## @returns: Dictionary with effect result for game_board
func _execute_bot_zone_effect(bot: Player, zone_data: Dictionary) -> Dictionary:
	var effect_type: String = zone_data.get("effect", "")
	print("[BotController] %s activates zone effect: %s" % [bot.display_name, effect_type])

	match effect_type:
		"damage_or_heal":
			return _bot_weird_woods_choice(bot)
		"choose_deck":
			return _bot_underworld_choice(bot)
		"steal_equipment":
			return _bot_altar_choice(bot)

	return {"type": effect_type, "skipped": true}


## Weird Woods: damage 2 to any player OR heal 1 to any player
func _bot_weird_woods_choice(bot: Player) -> Dictionary:
	var dead_count: int = GameState.players.filter(func(p): return not p.is_alive).size()
	var bot_hp_percent: float = float(bot.hp) / float(bot.hp_max)
	var targets = GameState.players.filter(func(p): return p != bot and p.is_alive)

	# Pacifists and low-HP bots heal themselves
	if bot.character_id in ["allie", "agnes", "david"] or bot_hp_percent < 0.5:
		print("[BotController] %s heals self at Weird Woods" % bot.display_name)
		return {"type": "damage_or_heal", "target": bot, "action": "heal"}

	# Daniel/Catherine(kamikaze) damage strongest to provoke
	if bot.character_id == "daniel" or (bot.character_id == "catherine" and dead_count == 0):
		if not targets.is_empty():
			var strongest = targets[0]
			for p in targets:
				if p.hp > strongest.hp:
					strongest = p
			print("[BotController] %s damages %s at Weird Woods" % [bot.display_name, strongest.display_name])
			return {"type": "damage_or_heal", "target": strongest, "action": "damage"}

	# Default: damage weakest enemy or unknown
	var best_target: Player = null
	# Prefer revealed enemies
	for p in targets:
		if p.is_revealed and not AIDecisionEngine._is_ally_static(bot, p):
			if best_target == null or p.hp < best_target.hp:
				best_target = p
	# Fallback to any non-ally
	if best_target == null:
		for p in targets:
			if not p.is_revealed or not AIDecisionEngine._is_ally_static(bot, p):
				if best_target == null or p.hp < best_target.hp:
					best_target = p

	if best_target:
		print("[BotController] %s damages %s at Weird Woods" % [bot.display_name, best_target.display_name])
		return {"type": "damage_or_heal", "target": best_target, "action": "damage"}

	# No valid target — heal self
	print("[BotController] %s heals self at Weird Woods (no target)" % bot.display_name)
	return {"type": "damage_or_heal", "target": bot, "action": "heal"}


## Underworld Gate: choose which deck to draw from
func _bot_underworld_choice(bot: Player) -> Dictionary:
	var deck_type: String = "white"  # Default

	match bot.character_id:
		"unknown", "ellen":
			deck_type = "hermit"  # Deceit synergy / info gathering
		"david":
			deck_type = "white"  # Win condition = white equipment
		"george", "franklin", "werewolf", "valkyrie", "vampire":
			deck_type = "black"  # Aggressive fighters want attack equipment
		_:
			# Hunters → white (heal/equip), Shadows → black (weapons), Neutrals → white
			if bot.faction == "shadow":
				deck_type = "black"
			else:
				deck_type = "white"

	print("[BotController] %s chooses %s deck at Underworld" % [bot.display_name, deck_type])
	return {"type": "choose_deck", "deck_type": deck_type}


## Erstwhile Altar: steal equipment from any player
func _bot_altar_choice(bot: Player) -> Dictionary:
	var targets_with_equip: Array = []
	for p in GameState.players:
		if p != bot and p.is_alive and not p.equipment.is_empty():
			targets_with_equip.append(p)

	if targets_with_equip.is_empty():
		print("[BotController] %s skips Altar (no equipment to steal)" % bot.display_name)
		return {"type": "steal_equipment", "skipped": true}

	# Prefer stealing from revealed enemies
	var best_target: Player = null
	for p in targets_with_equip:
		if p.is_revealed and not AIDecisionEngine._is_ally_static(bot, p):
			if best_target == null or p.equipment.size() > best_target.equipment.size():
				best_target = p

	# Fallback: steal from anyone with most equipment
	if best_target == null:
		best_target = targets_with_equip[0]
		for p in targets_with_equip:
			if p.equipment.size() > best_target.equipment.size():
				best_target = p

	# Pick best equipment card from target (first attack, then defense, then any)
	var stolen_card: Card = best_target.equipment[0]
	for card in best_target.equipment:
		if card.get_effect_type() == "attack_bonus":
			stolen_card = card
			break
		elif card.get_effect_type() == "defense_bonus" and stolen_card.get_effect_type() != "attack_bonus":
			stolen_card = card

	print("[BotController] %s steals %s from %s at Altar" % [bot.display_name, stolen_card.name, best_target.display_name])
	return {"type": "steal_equipment", "target": best_target, "card": stolen_card}


## Execute bot reveal
## @param bot: Bot revealing character
func _execute_bot_reveal(bot: Player) -> void:
	print("[BotController] %s reveals character: %s (%s)" % [bot.display_name, bot.character_name, bot.faction])
	bot.reveal()
	GameState.character_revealed.emit(bot, bot.ability_data, bot.faction)
	bot_action_completed.emit(bot, "zone_action", {"action": "reveal"})


## Execute bot card draw with card type handling
## @param bot: Bot drawing card
## @param zone: Current zone
func _execute_bot_draw_card(bot: Player, zone: String) -> void:
	print("[BotController] %s drawing card from %s zone" % [bot.display_name, zone])

	var deck: DeckManager = GameState.get_deck_for_zone(zone)
	if deck == null:
		push_warning("[BotController] No deck found for zone: %s" % zone)
		bot_action_completed.emit(bot, "zone_action", null)
		return

	var card = HandManager.draw_to_hand(bot, deck)
	if card == null:
		print("[BotController] %s couldn't draw (deck exhausted)" % bot.display_name)
		bot_action_completed.emit(bot, "zone_action", null)
		return

	print("[BotController] %s drew: %s (type: %s)" % [bot.display_name, card.name, card.type])

	match card.type:
		"vision":
			# Vision cards: auto-resolve with target selection
			var vision_result = _execute_bot_vision_card(bot, card, deck)
			bot_action_completed.emit(bot, "vision", vision_result)
		"equipment":
			# Equipment: auto-equip if possible
			if _should_bot_equip(bot, card):
				bot.hand.erase(card)
				bot.equipment.append(card)
				GameState.equipment_equipped.emit(bot, card)
				print("[BotController] %s equips %s" % [bot.display_name, card.name])
				bot_action_completed.emit(bot, "zone_action", card)
			else:
				print("[BotController] %s keeps %s in hand" % [bot.display_name, card.name])
				bot_action_completed.emit(bot, "zone_action", card)
		_:
			# Instant cards: handled by game_board via bot_action_completed
			bot_action_completed.emit(bot, "zone_action", card)


## Resolve vision card for bot: pick target, check condition, return result
## @param bot: Bot who drew the vision card
## @param card: Vision card
## @param deck: Source deck (for discard)
## @returns: Dictionary with vision result for game_board
func _execute_bot_vision_card(bot: Player, card: Card, deck: DeckManager) -> Dictionary:
	var effect: Dictionary = card.effect if card.effect is Dictionary else {}
	var action: String = effect.get("action", "")
	var targets: Array = GameState.players.filter(func(p): return p != bot and p.is_alive)

	if targets.is_empty():
		print("[BotController] %s has no vision target" % bot.display_name)
		return {"card": card, "deck": deck, "skipped": true}

	# Pick best target based on card effect and bot strategy
	var target: Player = _pick_vision_target(bot, effect, targets)

	# Check condition
	var condition_met: bool = _check_vision_condition(target, effect)

	print("[BotController] %s uses vision on %s — condition %s" % [
		bot.display_name, target.display_name, "met" if condition_met else "not met"
	])

	return {"card": card, "deck": deck, "target": target, "condition_met": condition_met}


## Pick best target for vision card based on effect action
func _pick_vision_target(bot: Player, effect: Dictionary, targets: Array) -> Player:
	var action: String = effect.get("action", "")

	match action:
		"damage_target":
			# Target a likely enemy
			for t in targets:
				if t.is_revealed and not AIDecisionEngine._is_ally_static(bot, t):
					return t
			# Fallback: unknown player
			return targets[randi() % targets.size()]
		"heal_drawer", "heal_or_damage":
			# Target someone likely to match condition (maximize chance of heal)
			var condition_factions: Array = effect.get("condition_factions", [])
			# If bot knows target's faction, pick matching one
			for t in targets:
				if t.is_revealed and t.faction in condition_factions:
					return t
			# Unknown: random guess
			return targets[randi() % targets.size()]
		"give_equipment_or_damage":
			# Target enemy with equipment (force them to give it)
			for t in targets:
				if t.is_revealed and not AIDecisionEngine._is_ally_static(bot, t) and not t.equipment.is_empty():
					return t
			for t in targets:
				if not t.equipment.is_empty():
					return t
			return targets[randi() % targets.size()]
		"reveal_to_drawer":
			# Target unknown player (info gathering)
			for t in targets:
				if not t.is_revealed:
					return t
			return targets[0]
		"steal_equipment":
			# Target player with best equipment
			for t in targets:
				if not t.equipment.is_empty():
					return t
			return targets[randi() % targets.size()]
		_:
			return targets[randi() % targets.size()]


## Check if vision condition is met for target
func _check_vision_condition(target: Player, effect: Dictionary) -> bool:
	var condition_type: String = effect.get("condition_type", "")
	var condition_factions: Array = effect.get("condition_factions", [])

	if condition_type != "":
		var cond_value: int = effect.get("condition_value", 0)
		match condition_type:
			"hp_max_lte":
				return target.hp_max <= cond_value
			"hp_max_gte":
				return target.hp_max >= cond_value
	elif not condition_factions.is_empty():
		return target.faction in condition_factions

	return false


## Execute bot active ability with automatic target selection
## @param bot: Bot using ability
## @param context: Action context from AIDecisionEngine
func _execute_bot_ability(bot: Player, context: Dictionary) -> void:
	var check = GameState.active_ability_system.can_activate_ability(bot)
	if not check.can_activate:
		print("[BotController] %s cannot use ability: %s" % [bot.display_name, check.reason])
		bot_action_completed.emit(bot, "zone_action", null)
		return

	var char_id: String = bot.character_id
	var targets: Array = []
	var nearby_enemies: Array = context.get("nearby_enemies", [])
	var nearby_unknown: Array = context.get("nearby_unknown", [])
	var nearby_allies: Array = context.get("nearby_allies", [])

	match char_id:
		"franklin", "george":
			# Pick weakest enemy nearby for damage ability
			var target = _pick_weakest(nearby_enemies, nearby_unknown)
			if target == null:
				# Fallback to any alive non-ally
				var all_others = GameState.players.filter(func(p): return p != bot and p.is_alive)
				if not all_others.is_empty():
					target = all_others[0]
			if target:
				targets = [target]
			else:
				print("[BotController] %s has no ability target" % bot.display_name)
				bot_action_completed.emit(bot, "zone_action", null)
				return

		"allie":
			# Mother's Love: no target needed (self-heal)
			targets = []

		"ellen":
			# Curse: target revealed Shadow with active ability
			var best_target: Player = null
			var revealed_shadows: Array = context.get("revealed_shadows", [])
			for shadow in revealed_shadows:
				if not shadow.ability_used and not shadow.ability_disabled:
					if shadow.character_id in ["vampire", "valkyrie", "werewolf", "wight"]:
						best_target = shadow
						break
					if best_target == null:
						best_target = shadow
			if best_target:
				targets = [best_target]
			else:
				print("[BotController] %s has no valid curse target" % bot.display_name)
				bot_action_completed.emit(bot, "zone_action", null)
				return

		"fuka":
			# Dynamite Nurse: set damage to 7 — prefer damaged ally, then enemy
			var best_target: Player = null
			# Heal ally: find one with damage > 7
			for ally in nearby_allies:
				if (ally.hp_max - ally.hp) > 7:
					best_target = ally
					break
			# Harm enemy: find one with damage < 5
			if best_target == null:
				for enemy in nearby_enemies:
					if (enemy.hp_max - enemy.hp) < 5:
						best_target = enemy
						break
			# Fallback: any alive player
			if best_target == null:
				var others = GameState.players.filter(func(p): return p != bot and p.is_alive)
				if not others.is_empty():
					best_target = others[0]
			if best_target:
				targets = [best_target]
			else:
				bot_action_completed.emit(bot, "zone_action", null)
				return

		"gregor":
			# Ghostly Barrier: no target needed (self-shield)
			targets = []

		"wight":
			# Multiplication: no target needed (extra turns)
			targets = []

		"ultra_soul":
			# Murder Ray: targets all at Underworld (handled by active_ability_system)
			var underworld_players = GameState.players.filter(
				func(p): return p.position_zone == "underworld" and p.is_alive and p != bot
			)
			targets = underworld_players

		"agnes":
			# Capriccio: no target needed (swap direction)
			targets = []

		"david":
			# Grave Digger: pick best equipment from discard piles
			var best_card: Card = null
			for deck in [GameState.white_deck, GameState.black_deck, GameState.hermit_deck]:
				if deck == null:
					continue
				for card in deck.discard_pile:
					if card.type == "equipment":
						if best_card == null:
							best_card = card
						elif card.get_effect_type() == "attack_bonus":
							best_card = card  # Prefer attack equipment
			if best_card:
				targets = [best_card]
			else:
				print("[BotController] %s has no equipment in discard piles" % bot.display_name)
				bot_action_completed.emit(bot, "zone_action", null)
				return

		_:
			bot_action_completed.emit(bot, "zone_action", null)
			return

	# Activate ability through the system
	var success = GameState.active_ability_system.activate_ability(bot, targets)
	if success:
		print("[BotController] %s used ability: %s" % [bot.display_name, bot.ability_data.get("name", "Unknown")])
		bot_action_completed.emit(bot, "zone_action", {"action": "ability", "character_id": char_id, "targets": targets})
	else:
		print("[BotController] %s ability activation failed" % bot.display_name)
		bot_action_completed.emit(bot, "zone_action", null)


## Decide if bot should equip a drawn equipment card
func _should_bot_equip(_bot: Player, _card: Card) -> bool:
	# Always keep equipment (even faction-restricted — effect just won't apply)
	return true


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
