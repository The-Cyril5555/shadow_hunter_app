## Zone - Visual zone component for game board
## Displays zone information, deck indicator, and player tokens
class_name Zone
extends PanelContainer


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal zone_clicked(zone: Zone)


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var zone_id: String = ""
var zone_name: String = ""
var deck_type: String = ""
var players_here: Array = []
var is_highlighted: bool = false
var zone_color: Color = Color.WHITE


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var deck_label: Label = $VBoxContainer/DeckLabel
@onready var token_container: HBoxContainer = $VBoxContainer/TokenContainer


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Initialize zone with zone data from ZoneData
func setup(zone_data: Dictionary) -> void:
	zone_id = zone_data.get("id", "")
	zone_name = zone_data.get("name", "Unknown Zone")
	deck_type = zone_data.get("deck_type", "")

	# Update labels
	name_label.text = zone_name

	if deck_type != "":
		deck_label.text = "[%s Deck]" % deck_type.capitalize()
		deck_label.visible = true
	else:
		deck_label.visible = false

	# Apply zone color styling
	zone_color = zone_data.get("color", Color.WHITE)
	_apply_zone_style(zone_color)

	print("[Zone] Initialized zone: %s (id: %s)" % [zone_name, zone_id])


## Add a player token to this zone
func add_player_token(player: Player) -> void:
	if player in players_here:
		push_warning("[Zone] Player %s already in zone %s" % [player.display_name, zone_name])
		return

	players_here.append(player)

	# Create and add token visual
	var token = preload("res://scenes/board/player_token.tscn").instantiate()
	token.setup(player)
	token_container.add_child(token)

	print("[Zone] Player %s added to zone %s" % [player.display_name, zone_name])


## Remove a player token from this zone
func remove_player_token(player: Player) -> void:
	if player not in players_here:
		push_warning("[Zone] Player %s not in zone %s" % [player.display_name, zone_name])
		return

	players_here.erase(player)

	# Find and remove the visual token
	for child in token_container.get_children():
		if child.has_method("get_player") and child.get_player() == player:
			child.queue_free()
			break

	print("[Zone] Player %s removed from zone %s" % [player.display_name, zone_name])


## Get all players currently in this zone
func get_players() -> Array:
	return players_here.duplicate()


## Check if a player is in this zone
func has_player(player: Player) -> bool:
	return player in players_here


## Clear all player tokens from this zone
func clear_players() -> void:
	players_here.clear()
	for child in token_container.get_children():
		child.queue_free()


## Set highlight state for this zone
func set_highlight(enabled: bool) -> void:
	is_highlighted = enabled

	if enabled:
		# Add yellow highlight border
		var highlight_style = StyleBoxFlat.new()
		highlight_style.bg_color = zone_color
		highlight_style.set_border_width_all(4)
		highlight_style.border_color = Color(1, 1, 0)  # Yellow highlight
		highlight_style.set_corner_radius_all(5)
		add_theme_stylebox_override("panel", highlight_style)
	else:
		# Remove highlight, restore original
		_apply_zone_style(zone_color)


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

## Apply visual styling to zone panel
func _apply_zone_style(bg_color: Color) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(2)
	style.border_color = Color.BLACK
	style.set_corner_radius_all(5)
	add_theme_stylebox_override("panel", style)


# -----------------------------------------------------------------------------
# Input Handling
# -----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if is_highlighted:
				zone_clicked.emit(self)
				print("[Zone] Zone clicked: %s" % zone_name)
