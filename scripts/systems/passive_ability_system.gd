## PassiveAbilitySystem - Manages automatic triggering of passive character abilities
## Subscribes to GameState signals and executes abilities when trigger conditions are met.
class_name PassiveAbilitySystem
extends Node


## Emitted when a passive ability triggers
signal passive_ability_triggered(player: Player, ability_name: String, effect: Dictionary)


## Valid trigger types for passive abilities
const VALID_TRIGGERS = [
	"on_attacked",
	"on_turn_start",
	"on_kill",
	"on_reveal",
	"on_death",
	"on_attack",
	"win_condition"
]


## Registered abilities: {player_id: {trigger: String, player: Player}}
var registered_abilities: Dictionary = {}


func _ready() -> void:
	# Connect to GameState signals
	GameState.damage_dealt.connect(_on_damage_dealt)
	GameState.turn_started.connect(_on_turn_started)
	GameState.player_died.connect(_on_player_died)
	GameState.character_revealed.connect(_on_character_revealed)
	print("[PassiveAbilitySystem] Initialized and listening to game events")


## Register a player's passive ability for automatic triggering
func register_player_ability(player: Player) -> void:
	# Check if player has a passive ability
	if player.ability_data.is_empty():
		return

	var ability_type = player.ability_data.get("type", "")
	if ability_type != "passive":
		return  # Not a passive ability, skip

	var trigger = player.ability_data.get("trigger", "")

	# Validate trigger type
	if trigger not in VALID_TRIGGERS:
		push_warning("[PassiveAbilitySystem] Invalid trigger '%s' for %s - skipping" % [trigger, player.display_name])
		return

	# Register ability
	registered_abilities[player.id] = {
		"trigger": trigger,
		"player": player
	}

	print("[PassiveAbilitySystem] Registered %s's '%s' (trigger: %s)" % [player.display_name, player.ability_data.get("name"), trigger])


## Unregister a player's passive ability (e.g., when player dies)
func unregister_player_ability(player: Player) -> void:
	if registered_abilities.has(player.id):
		var ability_name = player.ability_data.get("name", "Unknown")
		registered_abilities.erase(player.id)
		print("[PassiveAbilitySystem] Unregistered %s's '%s'" % [player.display_name, ability_name])


## Handle damage_dealt signal - triggers "on_attacked" and "on_attack"
func _on_damage_dealt(attacker: Player, victim: Player, amount: int) -> void:
	# Check victim for "on_attacked" trigger
	if registered_abilities.has(victim.id):
		var reg = registered_abilities[victim.id]
		if reg.trigger == "on_attacked":
			execute_ability(victim, {"trigger": "on_attacked", "attacker": attacker, "damage": amount})

	# Check attacker for "on_attack" trigger
	if registered_abilities.has(attacker.id):
		var reg = registered_abilities[attacker.id]
		if reg.trigger == "on_attack":
			execute_ability(attacker, {"trigger": "on_attack", "victim": victim, "damage": amount})


## Handle turn_started signal - triggers "on_turn_start"
func _on_turn_started(player: Player, turn_number: int) -> void:
	if registered_abilities.has(player.id):
		var reg = registered_abilities[player.id]
		if reg.trigger == "on_turn_start":
			execute_ability(player, {"trigger": "on_turn_start", "turn": turn_number})


## Handle player_died signal - triggers "on_kill" (killer) and "on_death" (victim)
func _on_player_died(victim: Player, killer: Player) -> void:
	# Trigger "on_death" for victim BEFORE unregistering
	if registered_abilities.has(victim.id):
		var reg = registered_abilities[victim.id]
		if reg.trigger == "on_death":
			execute_ability(victim, {"trigger": "on_death", "killer": killer})

	# Unregister victim's ability (dead players don't trigger abilities)
	unregister_player_ability(victim)

	# Trigger "on_kill" for killer
	if killer and registered_abilities.has(killer.id):
		var reg = registered_abilities[killer.id]
		if reg.trigger == "on_kill":
			execute_ability(killer, {"trigger": "on_kill", "victim": victim})


## Handle character_revealed signal - triggers "on_reveal"
func _on_character_revealed(player: Player, character: Dictionary, faction: String) -> void:
	if registered_abilities.has(player.id):
		var reg = registered_abilities[player.id]
		if reg.trigger == "on_reveal":
			execute_ability(player, {"trigger": "on_reveal", "character": character, "faction": faction})


## Execute a passive ability effect
func execute_ability(player: Player, trigger_context: Dictionary) -> void:
	var ability_name = player.ability_data.get("name", "Unknown")
	print("[PassiveAbilitySystem] Executing %s's '%s' (trigger: %s)" % [player.display_name, ability_name, trigger_context.trigger])

	# Dispatch to character-specific ability implementation
	match player.character_id:
		"werewolf":
			_execute_werewolf_ability(player, trigger_context)
		"catherine":
			_execute_catherine_ability(player, trigger_context)
		"vampire":
			_execute_vampire_ability(player, trigger_context)
		"valkyrie":
			_execute_valkyrie_ability(player, trigger_context)
		"bryan":
			_execute_bryan_ability(player, trigger_context)
		"unknown":
			_execute_unknown_ability(player, trigger_context)
		_:
			push_warning("[PassiveAbilitySystem] No implementation for %s's ability" % player.character_id)

	# Emit signal for UI/Audio feedback
	passive_ability_triggered.emit(player, ability_name, trigger_context)


## Werewolf: "Unearthly Speed" - After killing, heal 2 damage
func _execute_werewolf_ability(player: Player, context: Dictionary) -> void:
	if context.trigger == "on_kill":
		var victim = context.get("victim")
		# Check if victim was Hunter or Neutral
		if victim and victim.faction in ["hunter", "neutral"]:
			player.heal(2)
			print("[PassiveAbilitySystem] Werewolf healed 2 HP after killing %s" % victim.faction)


## Catherine: "Stigmata" - Heal 1 HP at turn start
func _execute_catherine_ability(player: Player, context: Dictionary) -> void:
	if context.trigger == "on_turn_start":
		if player.hp < player.hp_max:
			player.heal(1)
			print("[PassiveAbilitySystem] Catherine healed 1 HP at turn start")


## Vampire: "Bloodthirst" - At turn start, damage 1 to any player and heal 1
## NOTE: This is actually an ACTIVE ability (once per game), but has on_turn_start trigger
## Placeholder implementation - Story 2.4 will handle "once per game" constraint
func _execute_vampire_ability(_player: Player, _context: Dictionary) -> void:
	push_warning("[PassiveAbilitySystem] Vampire 'Bloodthirst' requires targeting - deferred to Story 2.4")


## Valkyrie: "Horn of War Outbreak" - Use 4-sided die for attacks
## NOTE: This modifies attack mechanics, not a triggered effect
## Story 2.4 or combat system will handle dice modification
func _execute_valkyrie_ability(_player: Player, _context: Dictionary) -> void:
	# This ability is passive but affects attack mechanics, not a triggered effect
	# Implementation deferred to combat system enhancement
	pass


## Bryan: "My GOD!!!" - Must reveal when killing characters with HP ≤ 12
func _execute_bryan_ability(player: Player, context: Dictionary) -> void:
	if context.trigger == "on_kill":
		var victim = context.get("victim")
		if victim and victim.hp_max <= 12:
			if not player.is_revealed:
				player.reveal()
				GameState.character_revealed.emit(player, player.ability_data, player.faction)
				print("[PassiveAbilitySystem] Bryan forced to reveal after killing %s" % victim.character_name)


## Unknown: "Copy" - Copy another revealed player's ability on reveal
## NOTE: Complex ability requiring UI to select target - deferred to Story 2.4
func _execute_unknown_ability(_player: Player, _context: Dictionary) -> void:
	push_warning("[PassiveAbilitySystem] Unknown 'Copy' requires targeting - deferred to Story 2.4")
