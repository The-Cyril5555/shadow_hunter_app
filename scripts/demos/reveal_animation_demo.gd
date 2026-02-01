## RevealAnimationDemo - Interactive demo for character reveal animations
## Tests all 5 stages of the dramatic reveal sequence
class_name RevealAnimationDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var card_panel: Panel = $CenterContainer/CardPanel
@onready var card_label: Label = $CenterContainer/CardPanel/CardLabel
@onready var character_name_label: Label = $CenterContainer/CardPanel/CharacterName
@onready var faction_label: Label = $CenterContainer/CardPanel/FactionLabel

@onready var reveal_button: Button = $VBoxContainer/RevealButton
@onready var reduced_motion_toggle: CheckButton = $VBoxContainer/ReducedMotionToggle
@onready var character_select: OptionButton = $VBoxContainer/CharacterSelect
@onready var back_button: Button = $VBoxContainer/BackButton

@onready var status_label: Label = $VBoxContainer/StatusLabel


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var current_player: Player = null
var is_revealing: bool = false


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Setup character selection
	_setup_character_select()

	# Connect buttons
	reveal_button.pressed.connect(_on_reveal_pressed)
	reduced_motion_toggle.toggled.connect(_on_reduced_motion_toggled)
	character_select.item_selected.connect(_on_character_selected)
	back_button.pressed.connect(_on_back_pressed)

	# Initialize with first character
	_on_character_selected(0)

	print("[RevealAnimationDemo] Demo ready")


# -----------------------------------------------------------------------------
# Character Selection
# -----------------------------------------------------------------------------
func _setup_character_select() -> void:
	character_select.clear()

	# Add sample characters for testing
	character_select.add_item("Allie (Hunter)")
	character_select.add_item("Bob (Shadow)")
	character_select.add_item("Charles (Neutral)")
	character_select.add_item("Daniel (Hunter)")
	character_select.add_item("Ellen (Shadow)")

	character_select.selected = 0


func _on_character_selected(index: int) -> void:
	# Create sample player based on selection
	current_player = Player.new(index, "Player_%d" % index, true)

	# Assign character data based on selection
	match index:
		0:  # Allie (Hunter)
			current_player.character_id = "allie"
			current_player.character_name = "Allie"
			current_player.faction = "hunter"
			current_player.hp_max = 12
			current_player.hp = 12
		1:  # Bob (Shadow)
			current_player.character_id = "bob"
			current_player.character_name = "Bob"
			current_player.faction = "shadow"
			current_player.hp_max = 11
			current_player.hp = 11
		2:  # Charles (Neutral)
			current_player.character_id = "charles"
			current_player.character_name = "Charles"
			current_player.faction = "neutral"
			current_player.hp_max = 10
			current_player.hp = 10
		3:  # Daniel (Hunter)
			current_player.character_id = "daniel"
			current_player.character_name = "Daniel"
			current_player.faction = "hunter"
			current_player.hp_max = 13
			current_player.hp = 13
		4:  # Ellen (Shadow)
			current_player.character_id = "ellen"
			current_player.character_name = "Ellen"
			current_player.faction = "shadow"
			current_player.hp_max = 12
			current_player.hp = 12

	_update_card_display()


# -----------------------------------------------------------------------------
# Card Display
# -----------------------------------------------------------------------------
func _update_card_display() -> void:
	if current_player:
		card_label.text = "?"
		character_name_label.text = current_player.character_name
		faction_label.text = "Faction: %s" % current_player.faction.capitalize()

		# Color code by faction
		match current_player.faction:
			"hunter":
				card_panel.modulate = Color(0.8, 0.9, 1.0)  # Light blue
			"shadow":
				card_panel.modulate = Color(0.9, 0.8, 0.8)  # Light red
			"neutral":
				card_panel.modulate = Color(0.9, 0.9, 0.9)  # Gray


# -----------------------------------------------------------------------------
# Reveal Animation
# -----------------------------------------------------------------------------
func _on_reveal_pressed() -> void:
	if is_revealing:
		status_label.text = "Reveal already in progress..."
		return

	if not current_player:
		status_label.text = "No character selected"
		return

	is_revealing = true
	reveal_button.disabled = true
	status_label.text = "Starting reveal sequence..."

	# Call AnimationOrchestrator
	await AnimationOrchestrator.play_reveal_sequence(current_player, card_panel, get_tree())

	# After reveal, update card to show character
	card_label.text = current_player.character_name[0]  # First letter
	character_name_label.text = "%s REVEALED!" % current_player.character_name

	is_revealing = false
	reveal_button.disabled = false
	status_label.text = "Reveal complete! Duration: %.2fs" % AnimationOrchestrator.get_reveal_sequence_duration()

	print("[RevealAnimationDemo] Reveal sequence completed for %s" % current_player.character_name)


# -----------------------------------------------------------------------------
# Settings
# -----------------------------------------------------------------------------
func _on_reduced_motion_toggled(enabled: bool) -> void:
	UserSettings.set_reduced_motion(enabled)
	status_label.text = "Reduced Motion: %s" % ("ON" if enabled else "OFF")


# -----------------------------------------------------------------------------
# Navigation
# -----------------------------------------------------------------------------
func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)
