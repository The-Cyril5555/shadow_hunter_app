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
	"on_death",
	"on_attack",
	"on_attack_hit",
	"on_movement",
	"on_hermit_card",
	"on_character_death",
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


## Handle player_died signal - triggers "on_kill" (killer), "on_death" (victim), "on_character_death" (observers)
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

	# Trigger "on_character_death" for all observers (e.g. Daniel's "Scream")
	for player_id in registered_abilities:
		var reg = registered_abilities[player_id]
		if reg.trigger == "on_character_death":
			execute_ability(reg.player, {"trigger": "on_character_death", "victim": victim, "killer": killer})


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
		"emi":
			_execute_emi_ability(player, trigger_context)
		"bob":
			_execute_bob_ability(player, trigger_context)
		"charles":
			_execute_charles_ability(player, trigger_context)
		"daniel":
			_execute_daniel_ability(player, trigger_context)
		_:
			push_warning("[PassiveAbilitySystem] No implementation for %s's ability" % player.character_id)

	# Emit signal for UI/Audio feedback
	passive_ability_triggered.emit(player, ability_name, trigger_context)


## Werewolf: "Counterattack" - After being attacked, can counterattack immediately
## NOTE: Handled in game_board._check_werewolf_counterattack()
func _execute_werewolf_ability(_player: Player, _context: Dictionary) -> void:
	pass  # Handled in game_board.gd combat flow


## Catherine: "Stigmata" - Heal 1 HP at turn start
func _execute_catherine_ability(player: Player, context: Dictionary) -> void:
	if context.trigger == "on_turn_start":
		if player.hp < player.hp_max:
			player.heal(1)
			print("[PassiveAbilitySystem] Catherine healed 1 HP at turn start")


## Vampire: "Suck Blood" - Heal 2 HP when attacking and dealing damage
## NOTE: Handled directly in CombatSystem.apply_damage() for correct timing
func _execute_vampire_ability(_player: Player, _context: Dictionary) -> void:
	pass  # Handled in combat_system.gd


## Valkyrie: "Horn of War Outbreak" - Use d4 only for attacks (no miss)
## NOTE: Handled in CombatSystem.calculate_attack_damage() and DiceRollPopup._handle_combat_result()
func _execute_valkyrie_ability(_player: Player, _context: Dictionary) -> void:
	pass  # Handled in combat_system.gd + dice_roll_popup.gd


## Bryan: "My GOD!!!" - Must reveal when killing characters with HP ≤ 12
func _execute_bryan_ability(player: Player, context: Dictionary) -> void:
	if context.trigger == "on_kill":
		var victim = context.get("victim")
		if victim and victim.hp_max <= 12:
			if not player.is_revealed:
				player.reveal()
				GameState.character_revealed.emit(player, player.ability_data, player.faction)
				print("[PassiveAbilitySystem] Bryan forced to reveal after killing %s" % victim.character_name)


## Unknown: "Deceit" - May lie about identity when given a Hermit Card
## NOTE: Requires Hermit card flow integration - deferred
func _execute_unknown_ability(_player: Player, _context: Dictionary) -> void:
	pass  # Handled via Hermit card resolution flow


## Emi: "Teleport" - May move to paired area instead of rolling dice
## NOTE: Requires movement system integration - deferred
func _execute_emi_ability(_player: Player, _context: Dictionary) -> void:
	pass  # Handled via movement flow


## Bob: "Robbery" - Steal equipment instead of dealing damage (if 2+ damage)
## NOTE: Requires combat choice UI - deferred
func _execute_bob_ability(_player: Player, _context: Dictionary) -> void:
	pass  # Handled via combat resolution flow


## Charles: "Bloody Feast" - After attack, may attack again for 2 self-damage
## NOTE: Handled in game_board._check_charles_reattack()
func _execute_charles_ability(_player: Player, _context: Dictionary) -> void:
	pass  # Handled in game_board.gd combat flow


## Daniel: "Scream" - Must reveal when another character dies
## NOTE: Requires auto-reveal trigger on player_died signal
func _execute_daniel_ability(player: Player, context: Dictionary) -> void:
	if context.trigger == "on_character_death":
		if not player.is_revealed:
			player.reveal()
			GameState.character_revealed.emit(player, player.ability_data, player.faction)
			print("[PassiveAbilitySystem] Daniel forced to reveal after a character died")
