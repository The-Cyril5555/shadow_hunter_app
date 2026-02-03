## CharacterRevelationDemo - Demo for character revelation system
## Tests voluntary revelation, forced revelation, and queueing
class_name CharacterRevelationDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var system_label: Label = $VBoxContainer/SystemLabel
@onready var reveal_player1_button: Button = $VBoxContainer/TestButtons/RevealPlayer1Button
@onready var reveal_player2_button: Button = $VBoxContainer/TestButtons/RevealPlayer2Button
@onready var force_reveal_player3_button: Button = $VBoxContainer/TestButtons/ForceRevealPlayer3Button
@onready var reveal_all_button: Button = $VBoxContainer/TestButtons/RevealAllButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var revelation_system: CharacterRevelationSystem = null
var test_players: Array[Player] = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Create revelation system
	revelation_system = CharacterRevelationSystem.new()
	add_child(revelation_system)

	# Connect signals
	revelation_system.revelation_started.connect(_on_revelation_started)
	revelation_system.revelation_completed.connect(_on_revelation_completed)
	revelation_system.revelation_rejected.connect(_on_revelation_rejected)

	# Create test players
	_create_test_players()

	# Connect buttons
	reveal_player1_button.pressed.connect(_on_reveal_player1_pressed)
	reveal_player2_button.pressed.connect(_on_reveal_player2_pressed)
	force_reveal_player3_button.pressed.connect(_on_force_reveal_player3_pressed)
	reveal_all_button.pressed.connect(_on_reveal_all_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_status_label()

	print("[CharacterRevelationDemo] Demo ready with %d test players" % test_players.size())


## Create test players with different characters
func _create_test_players() -> void:
	# Player 1: Franklin (Hunter, hidden)
	var franklin = Player.new(1, "Player 1", true)
	franklin.assign_character({
		"id": "franklin",
		"name": "Franklin",
		"faction": "hunter",
		"hp_max": 12,
		"ability": {
			"type": "active",
			"name": "Leadership",
			"trigger": "manual"
		}
	})
	franklin.is_revealed = false
	test_players.append(franklin)

	# Player 2: Vampire (Shadow, hidden)
	var vampire = Player.new(2, "Player 2", true)
	vampire.assign_character({
		"id": "vampire",
		"name": "Vampire",
		"faction": "shadow",
		"hp_max": 13,
		"ability": {
			"type": "active",
			"name": "Bloodthirst",
			"trigger": "on_turn_start"
		}
	})
	vampire.is_revealed = false
	test_players.append(vampire)

	# Player 3: Emi (Hunter, hidden)
	var emi = Player.new(3, "Player 3", true)
	emi.assign_character({
		"id": "emi",
		"name": "Emi",
		"faction": "hunter",
		"hp_max": 11,
		"ability": {
			"type": "active",
			"name": "Blessed",
			"trigger": "on_attack"
		}
	})
	emi.is_revealed = false
	test_players.append(emi)

	# Player 4: George (Hunter, already revealed)
	var george = Player.new(4, "Player 4", true)
	george.assign_character({
		"id": "george",
		"name": "George",
		"faction": "hunter",
		"hp_max": 14,
		"ability": {
			"type": "active",
			"name": "Demolition",
			"trigger": "manual"
		}
	})
	george.is_revealed = true  # Already revealed
	test_players.append(george)


# -----------------------------------------------------------------------------
# Test Handlers
# -----------------------------------------------------------------------------
func _on_reveal_player1_pressed() -> void:
	var player = test_players[0]  # Franklin

	print("\n[Demo] Requesting voluntary revelation for %s" % player.character_name)
	print("  Currently revealed: %s" % player.is_revealed)

	var success = revelation_system.reveal_character(player, true)

	if success:
		print("  Revelation initiated!")
	else:
		print("  Revelation rejected!")

	_update_status_label()


func _on_reveal_player2_pressed() -> void:
	var player = test_players[1]  # Vampire

	print("\n[Demo] Requesting voluntary revelation for %s" % player.character_name)
	print("  Currently revealed: %s" % player.is_revealed)

	var success = revelation_system.reveal_character(player, true)

	if success:
		print("  Revelation initiated!")
	else:
		print("  Revelation rejected!")

	_update_status_label()


func _on_force_reveal_player3_pressed() -> void:
	var player = test_players[2]  # Emi

	print("\n[Demo] Forcing revelation for %s (simulating death)" % player.character_name)
	print("  Currently revealed: %s" % player.is_revealed)

	revelation_system.force_reveal(player)

	_update_status_label()


func _on_reveal_all_pressed() -> void:
	print("\n[Demo] Revealing all hidden players (testing queue)")

	var revealed_count = 0
	for player in test_players:
		if not player.is_revealed:
			revelation_system.reveal_character(player, false)
			revealed_count += 1

	print("  Queued %d revelations" % revealed_count)
	print("  Pending in queue: %d" % revelation_system.get_pending_count())

	_update_status_label()


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------
func _on_revelation_started(player: Player, voluntary: bool) -> void:
	print("[Demo] 🎬 Revelation Started:")
	print("  Player: %s (%s)" % [player.display_name, player.character_name])
	print("  Faction: %s" % player.faction)
	print("  Voluntary: %s" % voluntary)
	print("  Ability: %s" % player.ability_data.get("name", "None"))

	_update_status_label()


func _on_revelation_completed(player: Player, voluntary: bool) -> void:
	print("[Demo] ✅ Revelation Completed:")
	print("  Player: %s (%s)" % [player.display_name, player.character_name])
	print("  Now revealed: %s" % player.is_revealed)

	_update_status_label()


func _on_revelation_rejected(player: Player, reason: String) -> void:
	print("[Demo] ❌ Revelation Rejected:")
	print("  Player: %s (%s)" % [player.display_name, player.character_name])
	print("  Reason: %s" % reason)

	_update_status_label()


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_status_label() -> void:
	var status_text = "Player States:\n"

	for player in test_players:
		status_text += "\n%s:\n" % player.display_name
		status_text += "  Character: %s (%s)\n" % [
			player.character_name,
			player.faction if player.is_revealed else "HIDDEN"
		]
		status_text += "  Revealed: %s\n" % ("✅" if player.is_revealed else "❌")
		status_text += "  Ability: %s" % (
			player.ability_data.get("name", "None") if player.is_revealed else "???"
		)

	status_text += "\n\nSystem State:\n"
	status_text += "  Currently revealing: %s\n" % ("Yes" if revelation_system.is_revealing() else "No")
	status_text += "  Pending in queue: %d" % revelation_system.get_pending_count()

	status_label.text = status_text
