## ActiveAbilityDemo - Demo for testing active ability system
## Tests ability activation, targeting, validation, and effects
class_name ActiveAbilityDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var ability_system_label: Label = $VBoxContainer/AbilitySystemLabel
@onready var test_franklin_button: Button = $VBoxContainer/TestButtons/TestFranklinButton
@onready var test_george_button: Button = $VBoxContainer/TestButtons/TestGeorgeButton
@onready var test_vampire_button: Button = $VBoxContainer/TestButtons/TestVampireButton
@onready var test_emi_button: Button = $VBoxContainer/TestButtons/TestEmiButton
@onready var test_ellen_button: Button = $VBoxContainer/TestButtons/TestEllenButton
@onready var test_validation_button: Button = $VBoxContainer/TestButtons/TestValidationButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var ability_system: ActiveAbilitySystem = null
var test_players: Array[Player] = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Create ability system
	ability_system = ActiveAbilitySystem.new()
	add_child(ability_system)

	# Connect signals
	ability_system.ability_activated.connect(_on_ability_activated)
	ability_system.ability_activation_failed.connect(_on_ability_activation_failed)

	# Create test players
	_create_test_players()

	# Connect buttons
	test_franklin_button.pressed.connect(_on_test_franklin_pressed)
	test_george_button.pressed.connect(_on_test_george_pressed)
	test_vampire_button.pressed.connect(_on_test_vampire_pressed)
	test_emi_button.pressed.connect(_on_test_emi_pressed)
	test_ellen_button.pressed.connect(_on_test_ellen_pressed)
	test_validation_button.pressed.connect(_on_test_validation_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_status_label()

	print("[ActiveAbilityDemo] Demo ready with %d test players" % test_players.size())


## Create test players with active abilities
func _create_test_players() -> void:
	# Player 1: Franklin (Hunter, Leadership)
	var franklin = Player.new(1, "Player 1 (Franklin)", true)
	franklin.assign_character({
		"id": "franklin",
		"name": "Franklin",
		"faction": "hunter",
		"hp_max": 12,
		"ability": {
			"type": "active",
			"name": "Leadership",
			"trigger": "manual",
			"usage": "once",
			"requires_reveal": false
		}
	})
	franklin.position_zone = "church"
	franklin.is_revealed = true
	test_players.append(franklin)
	ability_system.register_player_ability(franklin)

	# Player 2: George (Hunter, Demolition)
	var george = Player.new(2, "Player 2 (George)", true)
	george.assign_character({
		"id": "george",
		"name": "George",
		"faction": "hunter",
		"hp_max": 14,
		"ability": {
			"type": "active",
			"name": "Demolition",
			"trigger": "manual",
			"usage": "unlimited",
			"requires_reveal": false
		}
	})
	george.position_zone = "church"
	george.is_revealed = true
	test_players.append(george)
	ability_system.register_player_ability(george)

	# Player 3: Vampire (Shadow, Bloodthirst)
	var vampire = Player.new(3, "Player 3 (Vampire)", true)
	vampire.assign_character({
		"id": "vampire",
		"name": "Vampire",
		"faction": "shadow",
		"hp_max": 13,
		"ability": {
			"type": "active",
			"name": "Bloodthirst",
			"trigger": "on_turn_start",
			"usage": "once",
			"requires_reveal": true
		}
	})
	vampire.position_zone = "cemetery"
	vampire.is_revealed = true
	test_players.append(vampire)
	ability_system.register_player_ability(vampire)

	# Player 4: Emi (Hunter, Blessed)
	var emi = Player.new(4, "Player 4 (Emi)", true)
	emi.assign_character({
		"id": "emi",
		"name": "Emi",
		"faction": "hunter",
		"hp_max": 11,
		"ability": {
			"type": "active",
			"name": "Blessed",
			"trigger": "on_attack",
			"usage": "unlimited",
			"requires_reveal": false
		}
	})
	emi.position_zone = "hermit"
	emi.is_revealed = true
	test_players.append(emi)
	ability_system.register_player_ability(emi)

	# Player 5: Ellen (Shadow, Chain of Forbidden Curse)
	var ellen = Player.new(5, "Player 5 (Ellen)", true)
	ellen.assign_character({
		"id": "ellen",
		"name": "Ellen",
		"faction": "shadow",
		"hp_max": 12,
		"ability": {
			"type": "active",
			"name": "Chain of Forbidden Curse",
			"trigger": "manual",
			"usage": "once",
			"requires_reveal": true
		}
	})
	ellen.position_zone = "cemetery"
	ellen.is_revealed = true
	test_players.append(ellen)
	ability_system.register_player_ability(ellen)


# -----------------------------------------------------------------------------
# Test Handlers
# -----------------------------------------------------------------------------
func _on_test_franklin_pressed() -> void:
	var franklin = test_players[0]
	var target = test_players[1]  # George

	print("\n[Demo] Testing Franklin's Leadership:")
	print("  Franklin zone: %s" % franklin.position_zone)
	print("  Target (George) zone before: %s" % target.position_zone)

	# Activate ability
	var success = ability_system.activate_ability(franklin, [target])

	if success:
		print("  Target (George) zone after: %s" % target.position_zone)
	else:
		print("  Activation failed!")

	_update_status_label()


func _on_test_george_pressed() -> void:
	var george = test_players[1]
	var target = test_players[0]  # Franklin (same zone)

	print("\n[Demo] Testing George's Demolition:")
	print("  George HP before: %d" % george.hp)
	print("  Target (Franklin) HP before: %d" % target.hp)

	# Activate ability
	var success = ability_system.activate_ability(george, [target])

	if success:
		print("  George HP after: %d (-2 self-damage)" % george.hp)
		print("  Target (Franklin) HP after: %d (-3 damage)" % target.hp)
	else:
		print("  Activation failed!")

	_update_status_label()


func _on_test_vampire_pressed() -> void:
	var vampire = test_players[2]
	var target = test_players[0]  # Franklin

	print("\n[Demo] Testing Vampire's Bloodthirst:")
	print("  Vampire HP before: %d" % vampire.hp)
	print("  Target (Franklin) HP before: %d" % target.hp)

	# Activate ability
	var success = ability_system.activate_ability(vampire, [target])

	if success:
		print("  Vampire HP after: %d (+1 heal)" % vampire.hp)
		print("  Target (Franklin) HP after: %d (-1 damage)" % target.hp)
	else:
		print("  Activation failed!")

	_update_status_label()


func _on_test_emi_pressed() -> void:
	var emi = test_players[3]

	print("\n[Demo] Testing Emi's Blessed:")

	# Activate ability (no targets)
	var success = ability_system.activate_ability(emi, [])

	if success:
		print("  Blessed activated! (+1 damage bonus)")
	else:
		print("  Activation failed!")

	_update_status_label()


func _on_test_ellen_pressed() -> void:
	var ellen = test_players[4]
	var target = test_players[0]  # Franklin

	print("\n[Demo] Testing Ellen's Chain of Forbidden Curse:")
	print("  Target (Franklin) ability_disabled before: %s" % target.ability_disabled)

	# Activate ability
	var success = ability_system.activate_ability(ellen, [target])

	if success:
		print("  Target (Franklin) ability_disabled after: %s" % target.ability_disabled)
	else:
		print("  Activation failed!")

	_update_status_label()


func _on_test_validation_pressed() -> void:
	print("\n[Demo] Testing Validation:")

	# Test 1: Try to activate Franklin's ability twice (once per game)
	var franklin = test_players[0]
	print("  Test 1: Franklin's ability (once per game)")
	print("    Used: %s" % ability_system.has_used_ability(franklin))

	var validation = ability_system.can_activate_ability(franklin)
	print("    Can activate: %s" % validation.can_activate)
	if not validation.can_activate:
		print("    Reason: %s" % validation.reason)

	# Test 2: Try to activate disabled ability
	var target = test_players[0]
	if target.ability_disabled:
		print("  Test 2: Franklin's ability (disabled by Ellen)")
		validation = ability_system.can_activate_ability(target)
		print("    Can activate: %s" % validation.can_activate)
		if not validation.can_activate:
			print("    Reason: %s" % validation.reason)

	_update_status_label()


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------
func _on_ability_activated(player: Player, ability_name: String, targets: Array, effect: Dictionary) -> void:
	print("[Demo] ✅ Ability Activated:")
	print("  Player: %s" % player.character_name)
	print("  Ability: %s" % ability_name)
	print("  Targets: %d" % targets.size())
	print("  Effect: %s" % effect)


func _on_ability_activation_failed(player: Player, reason: String) -> void:
	print("[Demo] ❌ Activation Failed:")
	print("  Player: %s" % player.character_name)
	print("  Reason: %s" % reason)


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_status_label() -> void:
	var status_text = "Player States:\n"

	for player in test_players:
		status_text += "\n%s (%s):\n" % [player.display_name, player.character_name]
		status_text += "  HP: %d/%d | Zone: %s\n" % [player.hp, player.hp_max, player.position_zone]
		status_text += "  Used: %s | Disabled: %s" % [
			ability_system.has_used_ability(player),
			ability_system.is_ability_disabled(player)
		]

	status_label.text = status_text
