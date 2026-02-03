## AIDecisionDemo - Demo for testing AI decision engine
## Tests utility AI scoring with different personalities and game states
class_name AIDecisionDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var system_label: Label = $VBoxContainer/SystemLabel
@onready var setup_scenario_button: Button = $VBoxContainer/TestButtons/SetupScenarioButton
@onready var test_all_personalities_button: Button = $VBoxContainer/TestButtons/TestAllPersonalitiesButton
@onready var test_combat_scenario_button: Button = $VBoxContainer/TestButtons/TestCombatScenarioButton
@onready var test_safety_scenario_button: Button = $VBoxContainer/TestButtons/TestSafetyScenarioButton
@onready var test_card_draw_button: Button = $VBoxContainer/TestButtons/TestCardDrawButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var results_label: Label = $VBoxContainer/ResultsLabel
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var personalities: Dictionary = {}
var decision_engine: AIDecisionEngine = null
var test_bots: Dictionary = {}  # {personality_id: Player}
var results_log: Array[String] = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect buttons
	setup_scenario_button.pressed.connect(_on_setup_scenario_pressed)
	test_all_personalities_button.pressed.connect(_on_test_all_personalities_pressed)
	test_combat_scenario_button.pressed.connect(_on_test_combat_scenario_pressed)
	test_safety_scenario_button.pressed.connect(_on_test_safety_scenario_pressed)
	test_card_draw_button.pressed.connect(_on_test_card_draw_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_status_labels()

	print("[AIDecisionDemo] Demo ready")


# -----------------------------------------------------------------------------
# Test Handlers
# -----------------------------------------------------------------------------
func _on_setup_scenario_pressed() -> void:
	print("\n[Demo] Setting up test scenario")
	results_log.clear()

	# Load personalities
	personalities = PersonalityManager.load_personalities()
	if personalities.is_empty():
		results_log.append("❌ Failed to load personalities!")
		_update_status_labels()
		return

	# Create decision engine
	decision_engine = AIDecisionEngine.new()

	# Create test bots with different personalities
	test_bots.clear()

	for personality_id in personalities.keys():
		var bot = Player.new()
		bot.display_name = "Bot (%s)" % personality_id
		bot.is_human = false
		bot.hp = 7
		bot.max_hp = 10
		bot.position_zone = "white"
		bot.hand = []

		# Assign personality
		PersonalityManager.assign_personalities_to_bots([bot], personalities)

		test_bots[personality_id] = bot

	results_log.append("✅ Setup complete:")
	results_log.append("  Loaded %d personalities" % personalities.size())
	results_log.append("  Created %d test bots" % test_bots.size())
	results_log.append("  Decision engine ready")

	_update_status_labels()


func _on_test_all_personalities_pressed() -> void:
	if not _check_setup():
		return

	print("\n[Demo] Testing all personalities with neutral context")
	results_log.clear()
	results_log.append("🧪 Testing all personalities:")
	results_log.append("Context: Neutral (HP: 70%, No enemies)")

	# Create neutral context
	var context = {
		"bot_hp": 7,
		"bot_hp_max": 10,
		"hand_size": 2,
		"current_zone": "white",
		"nearby_enemies": [],
		"weakest_enemy_hp": 10,
		"has_attack_equipment": false,
		"has_defense_equipment": false,
		"defense_cards_in_hand": 0
	}

	# Available actions
	var actions = [
		AIDecisionEngine.ACTION_ATTACK,
		AIDecisionEngine.ACTION_DEFEND,
		AIDecisionEngine.ACTION_MOVE_SAFE,
		AIDecisionEngine.ACTION_MOVE_RISKY,
		AIDecisionEngine.ACTION_DRAW_CARD
	]

	# Test each personality
	for personality_id in test_bots.keys():
		var bot = test_bots[personality_id]
		results_log.append("\n--- %s ---" % personality_id.to_upper())

		var chosen_action = decision_engine.choose_best_action(bot, actions, context)
		results_log.append("  Best action: %s" % chosen_action)

		# Show all scores
		results_log.append("  All scores:")
		for action in actions:
			var score = decision_engine.evaluate_action(bot, action, context)
			results_log.append("    %s: %.3f" % [action, score])

	_update_status_labels()


func _on_test_combat_scenario_pressed() -> void:
	if not _check_setup():
		return

	print("\n[Demo] Testing combat scenario")
	results_log.clear()
	results_log.append("⚔️ COMBAT SCENARIO:")
	results_log.append("Context: Low HP enemy nearby, bot healthy")

	# Create combat context - vulnerable enemy
	var enemy = Player.new()
	enemy.hp = 3
	enemy.max_hp = 10

	var context = {
		"bot_hp": 9,
		"bot_hp_max": 10,
		"hand_size": 3,
		"current_zone": "black",
		"nearby_enemies": [enemy],
		"weakest_enemy_hp": 3,
		"has_attack_equipment": true,
		"has_defense_equipment": false,
		"defense_cards_in_hand": 0
	}

	var actions = [
		AIDecisionEngine.ACTION_ATTACK,
		AIDecisionEngine.ACTION_DEFEND,
		AIDecisionEngine.ACTION_DRAW_CARD
	]

	# Test each personality
	for personality_id in test_bots.keys():
		var bot = test_bots[personality_id]
		results_log.append("\n%s:" % personality_id.to_upper())

		var chosen = decision_engine.choose_best_action(bot, actions, context)
		results_log.append("  Chose: %s" % chosen)

		for action in actions:
			var score = decision_engine.evaluate_action(bot, action, context)
			results_log.append("    %s: %.3f" % [action, score])

	_update_status_labels()


func _on_test_safety_scenario_pressed() -> void:
	if not _check_setup():
		return

	print("\n[Demo] Testing safety scenario")
	results_log.clear()
	results_log.append("🛡️ SAFETY SCENARIO:")
	results_log.append("Context: Low HP, multiple enemies nearby")

	# Create danger context
	var enemy1 = Player.new()
	enemy1.hp = 8
	var enemy2 = Player.new()
	enemy2.hp = 9

	var context = {
		"bot_hp": 3,
		"bot_hp_max": 10,
		"hand_size": 1,
		"current_zone": "hermit",
		"nearby_enemies": [enemy1, enemy2],
		"weakest_enemy_hp": 8,
		"has_attack_equipment": false,
		"has_defense_equipment": false,
		"defense_cards_in_hand": 1
	}

	var actions = [
		AIDecisionEngine.ACTION_ATTACK,
		AIDecisionEngine.ACTION_DEFEND,
		AIDecisionEngine.ACTION_MOVE_SAFE,
		AIDecisionEngine.ACTION_MOVE_RISKY
	]

	# Test each personality
	for personality_id in test_bots.keys():
		var bot = test_bots[personality_id]
		results_log.append("\n%s:" % personality_id.to_upper())

		var chosen = decision_engine.choose_best_action(bot, actions, context)
		results_log.append("  Chose: %s" % chosen)

		for action in actions:
			var score = decision_engine.evaluate_action(bot, action, context)
			results_log.append("    %s: %.3f" % [action, score])

	_update_status_labels()


func _on_test_card_draw_pressed() -> void:
	if not _check_setup():
		return

	print("\n[Demo] Testing card draw scenario")
	results_log.clear()
	results_log.append("🃏 CARD DRAW SCENARIO:")
	results_log.append("Context: Empty hand, white zone, no threats")

	var context = {
		"bot_hp": 8,
		"bot_hp_max": 10,
		"hand_size": 0,
		"current_zone": "white",
		"nearby_enemies": [],
		"weakest_enemy_hp": 10,
		"has_attack_equipment": false,
		"has_defense_equipment": false,
		"defense_cards_in_hand": 0
	}

	var actions = [
		AIDecisionEngine.ACTION_ATTACK,
		AIDecisionEngine.ACTION_DRAW_CARD,
		AIDecisionEngine.ACTION_MOVE_SAFE
	]

	# Test each personality
	for personality_id in test_bots.keys():
		var bot = test_bots[personality_id]
		results_log.append("\n%s:" % personality_id.to_upper())

		var chosen = decision_engine.choose_best_action(bot, actions, context)
		results_log.append("  Chose: %s" % chosen)

		for action in actions:
			var score = decision_engine.evaluate_action(bot, action, context)
			results_log.append("    %s: %.3f" % [action, score])

	_update_status_labels()


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
func _check_setup() -> bool:
	if test_bots.is_empty() or decision_engine == null:
		results_log.clear()
		results_log.append("❌ Setup not complete!")
		results_log.append("Click 'Setup Test Scenario' first")
		_update_status_labels()
		return false
	return true


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_status_labels() -> void:
	# Update status
	var status_text = "System Status:\n"
	status_text += "\nPersonalities loaded: %s" % ("✓" if not personalities.is_empty() else "✗")
	status_text += "\nTest bots: %d" % test_bots.size()
	status_text += "\nDecision engine: %s" % ("✓" if decision_engine != null else "✗")

	status_label.text = status_text

	# Update results
	var results_text = "Test Results:\n"
	if results_log.is_empty():
		results_text += "\n(no tests run yet)"
	else:
		for line in results_log:
			results_text += "\n" + line

	results_label.text = results_text
