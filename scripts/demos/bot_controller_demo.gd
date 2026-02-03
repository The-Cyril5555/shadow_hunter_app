## BotControllerDemo - Demo for testing bot controller system
## Tests bot turn execution, action sequence, and delays
class_name BotControllerDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var system_label: Label = $VBoxContainer/SystemLabel
@onready var init_players_button: Button = $VBoxContainer/TestButtons/InitPlayersButton
@onready var execute_bot_turn_button: Button = $VBoxContainer/TestButtons/ExecuteBotTurnButton
@onready var execute_3_turns_button: Button = $VBoxContainer/TestButtons/Execute3TurnsButton
@onready var test_utilities_button: Button = $VBoxContainer/TestButtons/TestUtilitiesButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var action_log_label: Label = $VBoxContainer/ActionLogLabel
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var test_players: Array[Player] = []
var bot_controller: BotController = null
var action_log: Array[String] = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect buttons
	init_players_button.pressed.connect(_on_init_players_pressed)
	execute_bot_turn_button.pressed.connect(_on_execute_bot_turn_pressed)
	execute_3_turns_button.pressed.connect(_on_execute_3_turns_pressed)
	test_utilities_button.pressed.connect(_on_test_utilities_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_status_labels()

	print("[BotControllerDemo] Demo ready")


# -----------------------------------------------------------------------------
# Test Handlers
# -----------------------------------------------------------------------------
func _on_init_players_pressed() -> void:
	print("\n[Demo] Initializing test players")

	# Clear previous
	test_players.clear()
	action_log.clear()

	# Create mixed human/bot players
	var human1 = Player.new()
	human1.display_name = "Human 1"
	human1.is_human = true
	human1.position_zone = "hermit"
	human1.hand = []
	test_players.append(human1)

	var bot1 = Player.new()
	bot1.display_name = "Bot 1"
	bot1.is_human = false
	bot1.position_zone = "white"
	bot1.hand = []
	test_players.append(bot1)

	var human2 = Player.new()
	human2.display_name = "Human 2"
	human2.is_human = true
	human2.position_zone = "black"
	human2.hand = []
	test_players.append(human2)

	var bot2 = Player.new()
	bot2.display_name = "Bot 2"
	bot2.is_human = false
	bot2.position_zone = "hermit"
	bot2.hand = []
	test_players.append(bot2)

	# Create bot controller
	bot_controller = BotController.new()

	# Connect signals
	bot_controller.bot_action_started.connect(_on_bot_action_started)
	bot_controller.bot_action_completed.connect(_on_bot_action_completed)
	bot_controller.bot_turn_ended.connect(_on_bot_turn_ended)

	action_log.append("✅ Initialized 4 players (2 humans, 2 bots)")
	action_log.append("  - Human 1 (hermit zone)")
	action_log.append("  - Bot 1 (white zone)")
	action_log.append("  - Human 2 (black zone)")
	action_log.append("  - Bot 2 (hermit zone)")

	print("  Created %d players (%d humans, %d bots)" % [
		test_players.size(),
		BotController.get_humans(test_players).size(),
		BotController.get_bots(test_players).size()
	])

	_update_status_labels()


func _on_execute_bot_turn_pressed() -> void:
	if test_players.is_empty():
		action_log.append("❌ No players initialized!")
		_update_status_labels()
		return

	# Find first bot
	var bot = null
	for player in test_players:
		if BotController.is_bot(player):
			bot = player
			break

	if not bot:
		action_log.append("❌ No bots available!")
		_update_status_labels()
		return

	print("\n[Demo] Executing bot turn for %s" % bot.display_name)
	action_log.append("\n🤖 Executing turn for: %s" % bot.display_name)
	_update_status_labels()

	# Execute bot turn
	await bot_controller.execute_bot_turn(bot, get_tree())

	action_log.append("  Turn complete!")
	_update_status_labels()


func _on_execute_3_turns_pressed() -> void:
	if test_players.is_empty():
		action_log.append("❌ No players initialized!")
		_update_status_labels()
		return

	var bots = BotController.get_bots(test_players)
	if bots.is_empty():
		action_log.append("❌ No bots available!")
		_update_status_labels()
		return

	print("\n[Demo] Executing 3 bot turns")
	action_log.append("\n🎮 Executing 3 bot turns...")
	_update_status_labels()

	# Execute 3 turns (cycling through bots)
	for i in range(3):
		var bot = bots[i % bots.size()]
		action_log.append("\n🤖 Turn %d: %s" % [i + 1, bot.display_name])
		_update_status_labels()

		await bot_controller.execute_bot_turn(bot, get_tree())

	action_log.append("\n✅ All 3 turns complete!")
	_update_status_labels()


func _on_test_utilities_pressed() -> void:
	if test_players.is_empty():
		action_log.append("❌ No players initialized!")
		_update_status_labels()
		return

	print("\n[Demo] Testing utility methods")
	action_log.append("\n🔧 Testing utility methods:")

	# Test is_bot
	for player in test_players:
		var is_bot = BotController.is_bot(player)
		action_log.append("  %s: %s" % [player.display_name, "BOT" if is_bot else "HUMAN"])

	# Test get_bots and get_humans
	var bots = BotController.get_bots(test_players)
	var humans = BotController.get_humans(test_players)

	action_log.append("\n📊 Statistics:")
	action_log.append("  Total players: %d" % test_players.size())
	action_log.append("  Bots: %d" % bots.size())
	action_log.append("  Humans: %d" % humans.size())

	action_log.append("\n🤖 Bot players:")
	for bot in bots:
		action_log.append("  - %s (zone: %s, hand: %d)" % [bot.display_name, bot.position_zone, bot.hand.size()])

	action_log.append("\n👤 Human players:")
	for human in humans:
		action_log.append("  - %s (zone: %s, hand: %d)" % [human.display_name, human.position_zone, human.hand.size()])

	_update_status_labels()


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------
func _on_bot_action_started(bot: Player, action_type: String) -> void:
	var action_name = _get_action_display_name(action_type)
	action_log.append("  ⏳ %s..." % action_name)
	_update_status_labels()
	print("[Demo] Bot action started: %s" % action_type)


func _on_bot_action_completed(bot: Player, action_type: String, result: Variant) -> void:
	var action_name = _get_action_display_name(action_type)
	var result_text = _format_action_result(action_type, result)
	action_log.append("  ✅ %s %s" % [action_name, result_text])
	_update_status_labels()
	print("[Demo] Bot action completed: %s → %s" % [action_type, result])


func _on_bot_turn_ended(bot: Player) -> void:
	action_log.append("  🏁 Turn ended")
	_update_status_labels()
	print("[Demo] Bot turn ended: %s" % bot.display_name)


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_status_labels() -> void:
	if test_players.is_empty():
		status_label.text = "Player Status:\n\nNo players initialized\n\nClick 'Initialize Players' to start"
		action_log_label.text = "Action Log: (empty)"
		return

	# Build status text
	var status_text = "Player Status:\n"

	for player in test_players:
		var player_type = "🤖 BOT" if BotController.is_bot(player) else "👤 HUMAN"
		status_text += "\n%s %s:" % [player_type, player.display_name]
		status_text += "\n  Zone: %s" % player.position_zone
		status_text += "\n  Hand: %d cards" % player.hand.size()

	status_label.text = status_text

	# Update action log
	var log_text = "Action Log:\n"
	if action_log.is_empty():
		log_text += "\n(no events yet)"
	else:
		# Show last 12 log entries
		var start_idx = max(0, action_log.size() - 12)
		for i in range(start_idx, action_log.size()):
			log_text += "\n" + action_log[i]

	action_log_label.text = log_text


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _get_action_display_name(action_type: String) -> String:
	match action_type:
		"roll_dice":
			return "Rolling dice"
		"move":
			return "Moving"
		"zone_action":
			return "Drawing card"
		_:
			return action_type


func _format_action_result(action_type: String, result: Variant) -> String:
	match action_type:
		"roll_dice":
			return "→ rolled %d" % result
		"move":
			return "→ moved to %s" % result
		"zone_action":
			if result != null:
				return "→ drew card"
			else:
				return "→ no card available"
		_:
			return str(result)
