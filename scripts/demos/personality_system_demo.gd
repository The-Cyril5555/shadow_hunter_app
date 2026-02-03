## PersonalitySystemDemo - Demo for testing AI personality system
## Tests personality loading, assignment, weight access, and display
class_name PersonalitySystemDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var system_label: Label = $VBoxContainer/SystemLabel
@onready var load_personalities_button: Button = $VBoxContainer/TestButtons/LoadPersonalitiesButton
@onready var create_bots_button: Button = $VBoxContainer/TestButtons/CreateBotsButton
@onready var assign_personalities_button: Button = $VBoxContainer/TestButtons/AssignPersonalitiesButton
@onready var test_weights_button: Button = $VBoxContainer/TestButtons/TestWeightsButton
@onready var test_display_button: Button = $VBoxContainer/TestButtons/TestDisplayButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var details_label: Label = $VBoxContainer/DetailsLabel
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var personalities: Dictionary = {}
var test_bots: Array[Player] = []
var details_log: Array[String] = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect buttons
	load_personalities_button.pressed.connect(_on_load_personalities_pressed)
	create_bots_button.pressed.connect(_on_create_bots_pressed)
	assign_personalities_button.pressed.connect(_on_assign_personalities_pressed)
	test_weights_button.pressed.connect(_on_test_weights_pressed)
	test_display_button.pressed.connect(_on_test_display_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_status_labels()

	print("[PersonalitySystemDemo] Demo ready")


# -----------------------------------------------------------------------------
# Test Handlers
# -----------------------------------------------------------------------------
func _on_load_personalities_pressed() -> void:
	print("\n[Demo] Loading personalities from JSON")
	details_log.clear()

	personalities = PersonalityManager.load_personalities()

	if personalities.is_empty():
		details_log.append("❌ Failed to load personalities!")
	else:
		details_log.append("✅ Loaded %d personalities:" % personalities.size())

		for personality_id in personalities.keys():
			var data = personalities[personality_id]
			var display_name = data.get("display_name", personality_id)
			var description = data.get("description", "")
			var color = data.get("color", "#FFFFFF")

			details_log.append("\n🎭 %s (%s)" % [display_name, personality_id])
			details_log.append("  Color: %s" % color)
			details_log.append("  %s" % description)

			var weights = data.get("decision_weights", {})
			details_log.append("  Weights:")
			details_log.append("    Attack: %.2f" % weights.get("attack", 0.0))
			details_log.append("    Defense: %.2f" % weights.get("defense", 0.0))
			details_log.append("    Risk: %.2f" % weights.get("risk", 0.0))
			details_log.append("    Card Draw: %.2f" % weights.get("card_draw", 0.0))

			# Validate weights
			var is_valid = PersonalityManager.validate_weights(weights)
			details_log.append("    Valid (sums to 1.0): %s" % ("✓" if is_valid else "✗"))

	_update_status_labels()


func _on_create_bots_pressed() -> void:
	print("\n[Demo] Creating test bots")

	test_bots.clear()

	# Create 4 bots
	for i in range(4):
		var bot = Player.new()
		bot.display_name = "Bot %d" % (i + 1)
		bot.is_human = false
		bot.position_zone = ["hermit", "white", "black", "hermit"][i]
		test_bots.append(bot)

	details_log.clear()
	details_log.append("✅ Created %d bot players:" % test_bots.size())

	for bot in test_bots:
		details_log.append("  - %s (zone: %s)" % [bot.display_name, bot.position_zone])

	_update_status_labels()


func _on_assign_personalities_pressed() -> void:
	if personalities.is_empty():
		details_log.clear()
		details_log.append("❌ No personalities loaded!")
		details_log.append("Click 'Load Personalities' first")
		_update_status_labels()
		return

	if test_bots.is_empty():
		details_log.clear()
		details_log.append("❌ No bots created!")
		details_log.append("Click 'Create Test Bots' first")
		_update_status_labels()
		return

	print("\n[Demo] Assigning personalities to bots")

	PersonalityManager.assign_personalities_to_bots(test_bots, personalities)

	details_log.clear()
	details_log.append("✅ Assigned personalities:")

	for bot in test_bots:
		var personality_id = PersonalityManager.get_personality_id(bot)
		var personality_name = bot.get_meta("personality_data").get("display_name", "Unknown")
		var color = PersonalityManager.get_personality_color(bot)

		details_log.append("\n%s:" % bot.display_name)
		details_log.append("  Personality: %s (%s)" % [personality_name, personality_id])
		details_log.append("  Color: %s" % color.to_html())
		details_log.append("  %s" % PersonalityManager.get_personality_description(bot))

	# Show distribution
	details_log.append("\n📊 Distribution:")
	var counts = {}
	for bot in test_bots:
		var pid = PersonalityManager.get_personality_id(bot)
		counts[pid] = counts.get(pid, 0) + 1

	for pid in counts.keys():
		details_log.append("  %s: %d bots" % [pid, counts[pid]])

	_update_status_labels()


func _on_test_weights_pressed() -> void:
	if test_bots.is_empty():
		details_log.clear()
		details_log.append("❌ No bots created!")
		_update_status_labels()
		return

	print("\n[Demo] Testing decision weights")

	details_log.clear()
	details_log.append("⚖️ Decision Weights:")

	for bot in test_bots:
		var personality_id = PersonalityManager.get_personality_id(bot)
		if personality_id.is_empty():
			details_log.append("\n%s: No personality" % bot.display_name)
			continue

		var personality_name = bot.get_meta("personality_data").get("display_name", "Unknown")
		details_log.append("\n%s (%s):" % [bot.display_name, personality_name])

		var weights = PersonalityManager.get_all_weights(bot)
		details_log.append("  Attack:    %.2f (%.0f%%)" % [weights["attack"], weights["attack"] * 100])
		details_log.append("  Defense:   %.2f (%.0f%%)" % [weights["defense"], weights["defense"] * 100])
		details_log.append("  Risk:      %.2f (%.0f%%)" % [weights["risk"], weights["risk"] * 100])
		details_log.append("  Card Draw: %.2f (%.0f%%)" % [weights["card_draw"], weights["card_draw"] * 100])

		var total = weights["attack"] + weights["defense"] + weights["risk"] + weights["card_draw"]
		details_log.append("  Total: %.3f %s" % [total, "✓" if abs(total - 1.0) < 0.01 else "✗ ERROR"])

	_update_status_labels()


func _on_test_display_pressed() -> void:
	if test_bots.is_empty():
		details_log.clear()
		details_log.append("❌ No bots created!")
		_update_status_labels()
		return

	print("\n[Demo] Testing display names")

	details_log.clear()
	details_log.append("👁️ Display Names:")

	details_log.append("\n📴 With personality HIDDEN:")
	for bot in test_bots:
		var name = PersonalityManager.get_display_name_with_personality(bot, false)
		details_log.append("  %s" % name)

	details_log.append("\n📺 With personality SHOWN:")
	for bot in test_bots:
		var name = PersonalityManager.get_display_name_with_personality(bot, true)
		var color = PersonalityManager.get_personality_color(bot)
		details_log.append("  %s [color: %s]" % [name, color.to_html()])

	_update_status_labels()


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_status_labels() -> void:
	# Update status
	var status_text = "System Status:\n"
	status_text += "\nPersonalities loaded: %s" % ("✓" if not personalities.is_empty() else "✗")
	status_text += "\nBots created: %d" % test_bots.size()

	var assigned_count = 0
	for bot in test_bots:
		if PersonalityManager.get_personality_id(bot) != "":
			assigned_count += 1

	status_text += "\nPersonalities assigned: %d/%d" % [assigned_count, test_bots.size()]

	status_label.text = status_text

	# Update details
	var details_text = "Details:\n"
	if details_log.is_empty():
		details_text += "\n(no information yet)"
	else:
		for line in details_log:
			details_text += "\n" + line

	details_label.text = details_text
