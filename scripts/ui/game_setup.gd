## GameSetup - Game setup screen controller
## Handles player count selection and game initialization.
class_name GameSetup
extends Control


# Configuration limits
const MIN_PLAYERS: int = 4
const MAX_PLAYERS: int = 8

# Current setup values
var total_players: int = 4
var human_players: int = 1


@onready var player_count_spinbox: SpinBox = $CenterContainer/VBoxContainer/SettingsContainer/PlayerCountContainer/PlayerCountSpinBox
@onready var human_count_spinbox: SpinBox = $CenterContainer/VBoxContainer/SettingsContainer/HumanCountContainer/HumanCountSpinBox
@onready var expansion_toggle: CheckButton = $CenterContainer/VBoxContainer/SettingsContainer/ExpansionToggleContainer/ExpansionToggle
@onready var player_preview: VBoxContainer = $CenterContainer/VBoxContainer/PlayerPreviewContainer/PlayerPreview


func _ready() -> void:
	# Setup spinbox limits
	player_count_spinbox.min_value = MIN_PLAYERS
	player_count_spinbox.max_value = MAX_PLAYERS
	player_count_spinbox.value = total_players

	human_count_spinbox.min_value = 1
	human_count_spinbox.max_value = total_players
	human_count_spinbox.value = human_players

	# Initialize expansion toggle from UserSettings
	expansion_toggle.button_pressed = UserSettings.include_expansion

	# Connect signals
	player_count_spinbox.value_changed.connect(_on_player_count_changed)
	human_count_spinbox.value_changed.connect(_on_human_count_changed)
	expansion_toggle.toggled.connect(_on_expansion_toggle_toggled)
	$CenterContainer/VBoxContainer/ButtonContainer/StartGameButton.pressed.connect(_on_start_game_pressed)
	$CenterContainer/VBoxContainer/ButtonContainer/BackButton.pressed.connect(_on_back_pressed)

	# Initial preview update
	_update_player_preview()

	print("[GameSetup] Ready")


func _on_player_count_changed(value: float) -> void:
	total_players = int(value)
	# Clamp human players to not exceed total
	human_count_spinbox.max_value = total_players
	if human_players > total_players:
		human_players = total_players
		human_count_spinbox.value = human_players
	_update_player_preview()


func _on_human_count_changed(value: float) -> void:
	human_players = int(value)
	_update_player_preview()


func _on_expansion_toggle_toggled(pressed: bool) -> void:
	AudioManager.play_sfx("button_click")
	UserSettings.set_expansion_enabled(pressed)
	print("[GameSetup] Expansion toggle: %s" % ("ON" if pressed else "OFF"))


func _update_player_preview() -> void:
	# Clear existing preview
	for child in player_preview.get_children():
		child.queue_free()

	# Create player slot indicators
	for i in range(total_players):
		var slot = HBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER

		var icon_label = Label.new()
		var name_label = Label.new()

		if i < human_players:
			icon_label.text = "[H]"
			icon_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Green
			name_label.text = " Player %d (Human)" % (i + 1)
		else:
			icon_label.text = "[B]"
			icon_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))  # Orange
			name_label.text = " Player %d (Bot)" % (i + 1)

		slot.add_child(icon_label)
		slot.add_child(name_label)
		player_preview.add_child(slot)


func _on_start_game_pressed() -> void:
	AudioManager.play_sfx("button_click")
	print("[GameSetup] Starting game with %d players (%d human, %d bots), expansion: %s" % [total_players, human_players, total_players - human_players, "ON" if UserSettings.include_expansion else "OFF"])

	# Initialize players in GameState
	_initialize_players()

	# Assign AI personalities to bots
	var personalities = PersonalityManager.load_personalities()
	if not personalities.is_empty():
		PersonalityManager.assign_personalities_to_bots(GameState.players, personalities)
		print("[GameSetup] Assigned AI personalities to bots")

	# Distribute characters (with expansion preference from UserSettings)
	CharacterDistributor.distribute_characters(GameState.players, total_players, UserSettings.include_expansion)

	# Randomize turn order
	GameState.players.shuffle()
	for i in range(GameState.players.size()):
		GameState.players[i].id = i

	# Transition to game
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME)


func _initialize_players() -> void:
	GameState.reset()

	for i in range(total_players):
		var is_human = i < human_players
		var player_name = "Player %d" % (i + 1)
		if not is_human:
			player_name = "Bot %d" % (i - human_players + 1)

		var player = Player.new(i, player_name, is_human)
		GameState.players.append(player)

	print("[GameSetup] Created %d players" % GameState.players.size())


func _on_back_pressed() -> void:
	AudioManager.play_sfx("button_click")
	print("[GameSetup] Back to main menu")
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)
