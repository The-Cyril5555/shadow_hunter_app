## GameBoard - Main game board controller
## Manages the game board, player displays, and game flow.
class_name GameBoard
extends Control


@onready var player_list: VBoxContainer = $MarginContainer/VBoxContainer/PlayerListContainer/PlayerList
@onready var current_player_label: Label = $MarginContainer/VBoxContainer/StatusContainer/CurrentPlayerLabel
@onready var turn_label: Label = $MarginContainer/VBoxContainer/StatusContainer/TurnLabel


func _ready() -> void:
	print("[GameBoard] Initializing game board")

	# Initialize game state
	GameState.turn_count = 1
	GameState.current_player_index = 0
	GameState.game_in_progress = true

	_update_display()
	_display_players()

	print("[GameBoard] Game started with %d players" % GameState.players.size())


func _display_players() -> void:
	# Clear existing display
	for child in player_list.get_children():
		child.queue_free()

	# Create player info cards
	for i in range(GameState.players.size()):
		var player = GameState.players[i]
		var player_card = _create_player_card(player, i == GameState.current_player_index)
		player_list.add_child(player_card)


func _create_player_card(player: Player, is_current: bool) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 60)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)

	# Player type indicator
	var type_label = Label.new()
	if player.is_human:
		type_label.text = "[H]"
		type_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	else:
		type_label.text = "[B]"
		type_label.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))
	hbox.add_child(type_label)

	# Player name
	var name_label = Label.new()
	name_label.text = player.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_current:
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	hbox.add_child(name_label)

	# Character info (hidden for other players in real game, shown here for debug)
	var char_label = Label.new()
	if player.is_revealed or player.is_human:
		char_label.text = "%s (%s)" % [player.character_name, player.faction.capitalize()]
	else:
		char_label.text = "???"
	char_label.add_theme_color_override("font_color", _get_faction_color(player.faction))
	hbox.add_child(char_label)

	# HP
	var hp_label = Label.new()
	hp_label.text = "HP: %d/%d" % [player.hp, player.hp_max]
	hbox.add_child(hp_label)

	panel.add_child(hbox)

	# Highlight current player
	if is_current:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.3, 1.0)
		style.border_color = Color(1.0, 1.0, 0.3, 1.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		panel.add_theme_stylebox_override("panel", style)

	return panel


func _get_faction_color(faction: String) -> Color:
	match faction:
		"hunter":
			return Color(0.3, 0.6, 1.0)  # Blue
		"shadow":
			return Color(0.8, 0.2, 0.2)  # Red
		"neutral":
			return Color(0.7, 0.7, 0.7)  # Gray
	return Color.WHITE


func _update_display() -> void:
	var current_player = GameState.get_current_player()
	if current_player:
		current_player_label.text = "Current Player: %s" % current_player.display_name
	turn_label.text = "Turn: %d" % GameState.turn_count


func _on_end_turn_pressed() -> void:
	# Move to next player
	GameState.current_player_index = (GameState.current_player_index + 1) % GameState.players.size()

	# Increment turn count if we wrapped around
	if GameState.current_player_index == 0:
		GameState.turn_count += 1

	_update_display()
	_display_players()

	print("[GameBoard] Turn ended. Now: %s, Turn %d" % [GameState.get_current_player().display_name, GameState.turn_count])


func _on_back_to_menu_pressed() -> void:
	GameState.reset()
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)
