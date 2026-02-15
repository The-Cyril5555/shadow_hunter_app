## Zone - Visual zone component for game board
## Displays zone as a card image with player tokens overlaid.
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
var zone_description: String = ""
var dice_range: Array = []
var players_here: Array = []
var is_highlighted: bool = false


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var zone_background: TextureRect = $ZoneBackground
@onready var token_container: HBoxContainer = $VBoxContainer/TokenContainer
@onready var dice_label: Label = $VBoxContainer/DiceLabel


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Initialize zone with zone data from ZoneData
func setup(zone_data: Dictionary, position_dice_range: Array = []) -> void:
	zone_id = zone_data.get("id", "")
	zone_name = zone_data.get("name", "Unknown Zone")
	deck_type = zone_data.get("deck_type", "")
	zone_description = zone_data.get("description", "")
	dice_range = position_dice_range

	# Load zone card image as primary visual
	var img_path = CardImageMapper.get_zone_image_path(zone_id)
	var texture = CardImageMapper.load_texture(img_path)
	if texture != null:
		zone_background.texture = texture
		zone_background.visible = true
	else:
		zone_background.visible = false

	# Show dice range label
	if dice_range.size() > 0:
		dice_label.text = ZoneData.format_dice_range(dice_range)
		dice_label.visible = true
	else:
		dice_label.visible = false

	# Apply card style
	_apply_zone_style()

	# Set tooltip
	_update_tooltip()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	print("[Zone] Initialized zone: %s (dice: %s)" % [zone_name, ZoneData.format_dice_range(dice_range)])


## Add a player token to this zone
func add_player_token(player: Player) -> void:
	if player in players_here:
		push_warning("[Zone] Player %s already in zone %s" % [player.display_name, zone_name])
		return

	players_here.append(player)

	# Create and add token visual
	var token = preload("res://scenes/board/player_token.tscn").instantiate()
	token_container.add_child(token)
	token.setup(player)

	_update_tooltip()


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

	_update_tooltip()


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
		var highlight_style = StyleBoxFlat.new()
		highlight_style.bg_color = Color(0.95, 0.93, 0.85, 0.95)
		highlight_style.set_border_width_all(4)
		highlight_style.border_color = Color(1, 1, 0)
		highlight_style.set_corner_radius_all(8)
		highlight_style.content_margin_left = 4
		highlight_style.content_margin_right = 4
		highlight_style.content_margin_top = 4
		highlight_style.content_margin_bottom = 4
		add_theme_stylebox_override("panel", highlight_style)
	else:
		_apply_zone_style()


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

## Update tooltip with current zone state
func _update_tooltip() -> void:
	var text = zone_name
	if dice_range.size() > 0:
		text += " [%s]" % ZoneData.format_dice_range(dice_range)
	if deck_type != "":
		text += "\nDeck: %s" % deck_type.capitalize()
	if zone_description != "":
		text += "\n%s" % zone_description
	if players_here.size() > 0:
		text += "\n\nJoueurs (%d):" % players_here.size()
		for p in players_here:
			text += "\n  %s" % p.display_name
	tooltip_text = text


## Apply visual styling to zone panel (card style)
func _apply_zone_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.88, 0.82, 0.9)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.45, 0.35)
	style.set_corner_radius_all(8)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)


# -----------------------------------------------------------------------------
# Input Handling
# -----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			zone_clicked.emit(self)
