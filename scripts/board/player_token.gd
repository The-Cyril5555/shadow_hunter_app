## PlayerToken - Visual representation of a player on the board
## Shows player name and type indicator ([H] or [B])
class_name PlayerToken
extends PanelContainer


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var player: Player = null


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var type_indicator: Label = $HBoxContainer/TypeIndicator
@onready var name_label: Label = $HBoxContainer/NameLabel


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Initialize token with player data
func setup(p: Player) -> void:
	player = p

	# Set type indicator ([H] or [B])
	if player.is_human:
		type_indicator.text = "[H]"
		type_indicator.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))  # Green
	else:
		type_indicator.text = "[B]"
		type_indicator.add_theme_color_override("font_color", Color(0.8, 0.5, 0.2))  # Orange

	# Set player name
	name_label.text = player.display_name

	# Apply styling
	_apply_token_style()


## Get the player associated with this token
func get_player() -> Player:
	return player


## Mark token as dead (grayed out)
func mark_as_dead() -> void:
	# Change type indicator to skull or X
	type_indicator.text = "[X]"
	type_indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))  # Gray

	# Gray out name
	name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))  # Light gray

	# Make token semi-transparent
	modulate = Color(1.0, 1.0, 1.0, 0.5)

	print("[PlayerToken] Marked %s as dead" % player.display_name)


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

## Apply visual styling to token
func _apply_token_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", style)
