## GameOver - Game Over screen controller
## Displays victory/defeat screen with winning faction and all player reveals.
class_name GameOver
extends Control


# =============================================================================
# REFERENCES
# =============================================================================

@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var faction_banner: HBoxContainer = $CenterContainer/VBoxContainer/FactionBanner
@onready var faction_label: Label = $CenterContainer/VBoxContainer/FactionBanner/FactionLabel
@onready var winners_container: VBoxContainer = $CenterContainer/VBoxContainer/WinnersContainer
@onready var scoreboard_label: Label = $CenterContainer/VBoxContainer/ScoreboardLabel
@onready var players_container: VBoxContainer = $CenterContainer/VBoxContainer/PlayersContainer
@onready var return_menu_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/ReturnMenuButton
@onready var play_again_button: Button = $CenterContainer/VBoxContainer/ButtonsContainer/PlayAgainButton


# =============================================================================
# PROPERTIES
# =============================================================================

var winning_faction: String = ""
var winning_players: Array = []


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect button signals
	return_menu_button.pressed.connect(_on_return_menu_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)

	# Display game over screen
	_display_results()

	print("[GameOver] Game Over screen displayed")


# =============================================================================
# DISPLAY METHODS
# =============================================================================

func _display_results() -> void:
	# Get victory data from GameState (passed via game_over signal)
	# For now, determine from current game state
	var win_result = _determine_winner()

	winning_faction = win_result.winning_faction
	winning_players = win_result.winning_players

	# Set title
	if not winning_faction.is_empty():
		title_label.text = "VICTOIRE!"
	else:
		title_label.text = "PARTIE TERMINÉE"

	# Set faction banner
	if not winning_faction.is_empty():
		faction_label.text = "%s gagnent!" % _get_faction_name_plural(winning_faction)
		_set_faction_banner_color(winning_faction)
	else:
		faction_banner.visible = false

	# Display winners
	_display_winners()

	# Display all players (scoreboard)
	_display_all_players()


func _determine_winner() -> Dictionary:
	# Use WinConditionChecker to determine winner
	var checker = WinConditionChecker.new()
	return checker.check_win_conditions()


func _get_faction_name_plural(faction: String) -> String:
	match faction:
		"Hunter":
			return "Les Hunters"
		"Shadow":
			return "Les Shadows"
		"Neutral":
			return "Les Neutres"
		_:
			return faction


func _set_faction_banner_color(faction: String) -> void:
	var color = Color.WHITE
	match faction:
		"Hunter":
			color = Color(0.3, 0.7, 1.0)  # Blue
		"Shadow":
			color = Color(0.8, 0.2, 0.2)  # Red
		"Neutral":
			color = Color(0.7, 0.7, 0.3)  # Yellow

	faction_label.add_theme_color_override("font_color", color)


func _display_winners() -> void:
	# Clear existing winners
	for child in winners_container.get_children():
		child.queue_free()

	# Add each winner
	for player in winning_players:
		var winner_card = _create_winner_card(player)
		winners_container.add_child(winner_card)

	print("[GameOver] Displayed %d winners" % winning_players.size())


func _create_winner_card(player: Player) -> HBoxContainer:
	var card = HBoxContainer.new()

	# Player name
	var name_label = Label.new()
	name_label.text = player.display_name
	name_label.theme_override_font_sizes.font_size = 20
	name_label.theme_override_colors.font_color = Color(1.0, 0.9, 0.3)
	card.add_child(name_label)

	# Character name (revealed)
	var character_label = Label.new()
	character_label.text = " - %s (%s)" % [player.character_name, player.faction]
	character_label.theme_override_font_sizes.font_size = 18
	character_label.theme_override_colors.font_color = Color(0.8, 0.8, 0.8)
	card.add_child(character_label)

	return card


func _display_all_players() -> void:
	# Clear existing player cards
	for child in players_container.get_children():
		child.queue_free()

	# Display all players (reveal all identities)
	for player in GameState.players:
		var player_card = _create_player_reveal_card(player)
		players_container.add_child(player_card)

	print("[GameOver] Revealed all %d players" % GameState.players.size())


func _create_player_reveal_card(player: Player) -> HBoxContainer:
	var card = HBoxContainer.new()
	card.theme_override_constants.separation = 15

	# Status icon
	var status_label = Label.new()
	status_label.text = "[✓]" if player.is_alive else "[X]"
	status_label.theme_override_font_sizes.font_size = 16
	status_label.theme_override_colors.font_color = Color(0.3, 1.0, 0.3) if player.is_alive else Color(0.5, 0.5, 0.5)
	card.add_child(status_label)

	# Player name
	var name_label = Label.new()
	name_label.text = player.display_name
	name_label.theme_override_font_sizes.font_size = 16
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(name_label)

	# Character + Faction
	var character_label = Label.new()
	character_label.text = "%s (%s)" % [player.character_name, player.faction]
	character_label.theme_override_font_sizes.font_size = 16
	var faction_color = _get_faction_color(player.faction)
	character_label.theme_override_colors.font_color = faction_color
	card.add_child(character_label)

	# HP
	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [player.hp, player.hp_max]
	hp_label.theme_override_font_sizes.font_size = 16
	hp_label.theme_override_colors.font_color = Color(0.8, 0.8, 0.8)
	card.add_child(hp_label)

	return card


func _get_faction_color(faction: String) -> Color:
	match faction:
		"Hunter":
			return Color(0.3, 0.7, 1.0)  # Blue
		"Shadow":
			return Color(0.8, 0.2, 0.2)  # Red
		"Neutral":
			return Color(0.7, 0.7, 0.3)  # Yellow
		_:
			return Color.WHITE


# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_return_menu_pressed() -> void:
	print("[GameOver] Returning to main menu")

	# Reset game state
	GameState.reset()

	# Transition to main menu
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


func _on_play_again_pressed() -> void:
	print("[GameOver] Starting new game")

	# Reset game state
	GameState.reset()

	# Transition back to game setup
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME_SETUP)
