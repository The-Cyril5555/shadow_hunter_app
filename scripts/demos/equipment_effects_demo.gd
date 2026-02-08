## EquipmentEffectsDemo - Demo for testing equipment effects system
## Tests equipping, unequipping, attack bonuses, and defense reduction
class_name EquipmentEffectsDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var system_label: Label = $VBoxContainer/SystemLabel
@onready var init_players_button: Button = $VBoxContainer/TestButtons/InitPlayersButton
@onready var equip_attacker_button: Button = $VBoxContainer/TestButtons/EquipAttackerButton
@onready var equip_defender_button: Button = $VBoxContainer/TestButtons/EquipDefenderButton
@onready var attack_button: Button = $VBoxContainer/TestButtons/AttackButton
@onready var unequip_button: Button = $VBoxContainer/TestButtons/UnequipButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var combat_log_label: Label = $VBoxContainer/CombatLogLabel
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var attacker: Player = null
var defender: Player = null
var decks: Dictionary = {}  # {"white": DeckManager, "black": DeckManager}
var combat_log: Array[String] = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect buttons
	init_players_button.pressed.connect(_on_init_players_pressed)
	equip_attacker_button.pressed.connect(_on_equip_attacker_pressed)
	equip_defender_button.pressed.connect(_on_equip_defender_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	unequip_button.pressed.connect(_on_unequip_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_status_labels()

	print("[EquipmentEffectsDemo] Demo ready")


# -----------------------------------------------------------------------------
# Test Handlers
# -----------------------------------------------------------------------------
func _on_init_players_pressed() -> void:
	print("\n[Demo] Initializing test players")

	# Create attacker
	attacker = Player.new()
	attacker.display_name = "Attacker"
	attacker.hp = 10
	attacker.hp_max = 10
	attacker.hand = []
	attacker.equipment = []

	# Create defender
	defender = Player.new()
	defender.display_name = "Defender"
	defender.hp = 10
	defender.hp_max = 10
	defender.hand = []
	defender.equipment = []

	# Create test decks for equipment cards
	var white_deck = DeckManager.new()
	white_deck.deck_type = "white"

	var black_deck = DeckManager.new()
	black_deck.deck_type = "black"

	decks = {
		"white": white_deck,
		"black": black_deck
	}

	# Add equipment cards to attacker's hand
	var sword = Card.new()
	sword.from_dict({
		"id": "holy_sword",
		"name": "Holy Sword",
		"deck": "white",
		"type": "equipment",
		"effect": {
			"type": "damage",
			"value": 3,
			"description": "Deal 3 extra damage"
		}
	})
	attacker.hand.append(sword)

	var dagger = Card.new()
	dagger.from_dict({
		"id": "cursed_dagger",
		"name": "Cursed Dagger",
		"deck": "black",
		"type": "equipment",
		"effect": {
			"type": "damage",
			"value": 2,
			"description": "Deal 2 extra damage"
		}
	})
	attacker.hand.append(dagger)

	# Add equipment cards to defender's hand
	var shield = Card.new()
	shield.from_dict({
		"id": "holy_shield",
		"name": "Holy Shield",
		"deck": "white",
		"type": "equipment",
		"effect": {
			"type": "defense",
			"value": 2,
			"description": "Reduce incoming damage by 2"
		}
	})
	defender.hand.append(shield)

	var armor = Card.new()
	armor.from_dict({
		"id": "blessed_armor",
		"name": "Blessed Armor",
		"deck": "white",
		"type": "equipment",
		"effect": {
			"type": "defense",
			"value": 3,
			"description": "Reduce incoming damage by 3"
		}
	})
	defender.hand.append(armor)

	combat_log.clear()
	combat_log.append("Players initialized")
	combat_log.append("Attacker hand: Holy Sword (+3 damage), Cursed Dagger (+2 damage)")
	combat_log.append("Defender hand: Holy Shield (+2 defense), Blessed Armor (+3 defense)")

	print("  Created Attacker: HP %d/%d, hand: %d cards" % [attacker.hp, attacker.hp_max, attacker.hand.size()])
	print("  Created Defender: HP %d/%d, hand: %d cards" % [defender.hp, defender.hp_max, defender.hand.size()])

	_update_status_labels()


func _on_equip_attacker_pressed() -> void:
	if not attacker:
		print("\n[Demo] ❌ No players initialized!")
		return

	if attacker.hand.is_empty():
		combat_log.append("❌ Attacker has no cards in hand to equip")
		_update_status_labels()
		return

	print("\n[Demo] Equipping card for Attacker")

	var card = attacker.hand[0]
	var success = EquipmentManager.equip_from_hand(attacker, card, decks)

	if success:
		combat_log.append("✅ Attacker equipped: %s (+%d %s)" % [card.name, card.get_effect_value(), card.get_effect_type()])
		print("  Equipped: %s" % card.name)
	else:
		combat_log.append("❌ Failed to equip card")
		print("  ❌ Failed to equip!")

	_update_status_labels()


func _on_equip_defender_pressed() -> void:
	if not defender:
		print("\n[Demo] ❌ No players initialized!")
		return

	if defender.hand.is_empty():
		combat_log.append("❌ Defender has no cards in hand to equip")
		_update_status_labels()
		return

	print("\n[Demo] Equipping card for Defender")

	var card = defender.hand[0]
	var success = EquipmentManager.equip_from_hand(defender, card, decks)

	if success:
		combat_log.append("✅ Defender equipped: %s (+%d %s)" % [card.name, card.get_effect_value(), card.get_effect_type()])
		print("  Equipped: %s" % card.name)
	else:
		combat_log.append("❌ Failed to equip card")
		print("  ❌ Failed to equip!")

	_update_status_labels()


func _on_attack_pressed() -> void:
	if not attacker or not defender:
		print("\n[Demo] ❌ No players initialized!")
		return

	print("\n[Demo] Performing attack")

	var combat = CombatSystem.new()

	# Calculate attack damage
	var damage = combat.calculate_attack_damage(attacker, defender)

	combat_log.append("\n⚔️ ATTACK:")
	combat_log.append("  Attack damage: %d (includes equipment bonus)" % damage)

	# Apply damage (with defense reduction)
	var defender_hp_before = defender.hp
	combat.apply_damage(attacker, defender, damage)
	var actual_damage = defender_hp_before - defender.hp

	combat_log.append("  Defender HP: %d → %d (-%d)" % [defender_hp_before, defender.hp, actual_damage])

	if defender.is_alive:
		print("  Defender survived with %d HP" % defender.hp)
	else:
		combat_log.append("  💀 Defender killed!")
		print("  💀 Defender killed!")

	_update_status_labels()


func _on_unequip_pressed() -> void:
	if not attacker:
		print("\n[Demo] ❌ No players initialized!")
		return

	if attacker.equipment.is_empty():
		combat_log.append("❌ Attacker has no equipment to unequip")
		_update_status_labels()
		return

	print("\n[Demo] Unequipping card from Attacker")

	var card = attacker.equipment[0]
	var card_name = card.name
	var success = EquipmentManager.unequip_to_discard(attacker, card, decks)

	if success:
		combat_log.append("✅ Attacker unequipped: %s (discarded)" % card_name)
		print("  Unequipped: %s" % card_name)
	else:
		combat_log.append("❌ Failed to unequip card")
		print("  ❌ Failed to unequip!")

	_update_status_labels()


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_status_labels() -> void:
	if not attacker or not defender:
		status_label.text = "Player Status:\n\nNo players initialized\n\nClick 'Initialize Players' to start"
		combat_log_label.text = "Combat Log: (empty)"
		return

	# Build status text
	var status_text = "Player Status:\n"

	# Attacker status
	status_text += "\n🗡️ ATTACKER:"
	status_text += "\n  HP: %d/%d" % [attacker.hp, attacker.hp_max]
	status_text += "\n  Attack Bonus: +%d" % EquipmentManager.get_total_attack_bonus(attacker)
	status_text += "\n  Hand: %d cards" % attacker.hand.size()
	status_text += "\n  Equipment: %d cards" % attacker.equipment.size()

	if not attacker.equipment.is_empty():
		for card in attacker.equipment:
			status_text += "\n    - %s (+%d %s)" % [card.name, card.get_effect_value(), card.get_effect_type()]

	# Defender status
	status_text += "\n\n🛡️ DEFENDER:"
	status_text += "\n  HP: %d/%d" % [defender.hp, defender.hp_max]
	status_text += "\n  Defense Bonus: +%d" % EquipmentManager.get_total_defense_bonus(defender)
	status_text += "\n  Hand: %d cards" % defender.hand.size()
	status_text += "\n  Equipment: %d cards" % defender.equipment.size()

	if not defender.equipment.is_empty():
		for card in defender.equipment:
			status_text += "\n    - %s (+%d %s)" % [card.name, card.get_effect_value(), card.get_effect_type()]

	status_label.text = status_text

	# Update combat log
	var log_text = "Combat Log:\n"
	if combat_log.is_empty():
		log_text += "\n(no events yet)"
	else:
		# Show last 8 log entries
		var start_idx = max(0, combat_log.size() - 8)
		for i in range(start_idx, combat_log.size()):
			log_text += "\n" + combat_log[i]

	combat_log_label.text = log_text
