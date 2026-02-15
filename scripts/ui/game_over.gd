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
	if not winning_players.is_empty():
		title_label.text = "VICTOIRE!"
	else:
		title_label.text = "PARTIE TERMINÉE"

	# Set faction banner
	if not winning_faction.is_empty():
		# Check if there are also neutral winners alongside faction
		var has_neutral_winners = winning_players.any(func(p): return p.faction == "neutral")
		if has_neutral_winners and winning_faction != "neutral":
			faction_label.text = "%s gagnent! (+ Neutres)" % _get_faction_name_plural(winning_faction)
		else:
			faction_label.text = "%s gagnent!" % _get_faction_name_plural(winning_faction)
		_set_faction_banner_color(winning_faction)
	else:
		faction_banner.visible = false

	# Display winners
	_display_winners()

	# Display game statistics
	_display_statistics()

	# Display all players (scoreboard)
	_display_all_players()


func _determine_winner() -> Dictionary:
	# Use stored result from when the game actually ended (preserves event context)
	if not GameState.last_win_result.is_empty():
		return GameState.last_win_result
	# Fallback: re-calculate (only works for faction victories and passive neutrals)
	return GameState.win_checker.check_win_conditions({"event": "game_ending"})


func _get_faction_name_plural(faction: String) -> String:
	match faction:
		"hunter":
			return "Les Hunters"
		"shadow":
			return "Les Shadows"
		"neutral":
			return "Les Neutres"
		_:
			return faction.capitalize()


func _set_faction_banner_color(faction: String) -> void:
	var color = Color.WHITE
	match faction:
		"hunter":
			color = Color(0.3, 0.7, 1.0)  # Blue
		"shadow":
			color = Color(0.8, 0.2, 0.2)  # Red
		"neutral":
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
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	card.add_child(name_label)

	# Character name (revealed)
	var character_label = Label.new()
	character_label.text = " - %s (%s)" % [player.character_name, player.faction]
	character_label.add_theme_font_size_override("font_size", 18)
	character_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
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
	card.add_theme_constant_override("separation", 15)

	# Status icon
	var status_label = Label.new()
	status_label.text = "[✓]" if player.is_alive else "[X]"
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if player.is_alive else Color(0.5, 0.5, 0.5))
	card.add_child(status_label)

	# Player name
	var name_label = Label.new()
	name_label.text = player.display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(name_label)

	# Character + Faction
	var character_label = Label.new()
	character_label.text = "%s (%s)" % [player.character_name, player.faction]
	character_label.add_theme_font_size_override("font_size", 16)
	var faction_color = _get_faction_color(player.faction)
	character_label.add_theme_color_override("font_color", faction_color)
	card.add_child(character_label)

	# HP
	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [player.hp, player.hp_max]
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	card.add_child(hp_label)

	# Winner badge
	if player in winning_players:
		var badge = Label.new()
		badge.text = "GAGNANT"
		badge.add_theme_font_size_override("font_size", 14)
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		card.add_child(badge)

	return card


func _get_faction_color(faction: String) -> Color:
	match faction:
		"hunter":
			return Color(0.3, 0.7, 1.0)  # Blue
		"shadow":
			return Color(0.8, 0.2, 0.2)  # Red
		"neutral":
			return Color(0.7, 0.7, 0.3)  # Yellow
		_:
			return Color.WHITE


func _display_statistics() -> void:
	# Use the scoreboard label to display stats
	var stats = GameState.get_game_statistics()

	var stats_text = "--- STATISTIQUES ---\n"
	stats_text += "Tours joués: %d\n" % stats.turns_played
	stats_text += "Attaques: %d | Dégâts totaux: %d\n" % [stats.total_attacks, stats.total_damage]
	stats_text += "Morts: %d | Équipements: %d\n" % [stats.total_deaths, stats.equipment_equipped]

	# Find MVP (most damage dealt)
	var mvp_name = ""
	var mvp_damage = 0
	for player_name in stats.player_stats:
		var ps = stats.player_stats[player_name]
		if ps.damage_dealt > mvp_damage:
			mvp_damage = ps.damage_dealt
			mvp_name = player_name

	if mvp_name != "":
		stats_text += "\nMVP: %s (%d dégâts)" % [mvp_name, mvp_damage]

	scoreboard_label.text = stats_text

	print("[GameOver] Statistics displayed: %d turns, %d attacks" % [stats.turns_played, stats.total_attacks])


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
