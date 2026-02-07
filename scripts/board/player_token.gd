## PlayerToken - Colored player label on the game board
## Shows "J1", "J2", etc. in the player's assigned color.
class_name PlayerToken
extends Label


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var player: Player = null


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Initialize token with player data
func setup(p: Player) -> void:
	player = p
	text = PlayerColors.get_label(p)
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color", PlayerColors.get_color(p.id))
	_update_tooltip()


## Get the player associated with this token
func get_player() -> Player:
	return player


## Mark token as dead (grayed out)
func mark_as_dead() -> void:
	modulate = Color(1, 1, 1, 0.35)
	_update_tooltip()


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

## Update tooltip with current player info
func _update_tooltip() -> void:
	if player == null:
		return
	var type_str = "Humain" if player.is_human else "Bot"
	var tip = "%s (%s)" % [player.display_name, type_str]
	tip += "\nHP: %d/%d" % [player.hp, player.hp_max]

	if player.character_name != "" and player.is_revealed:
		tip += "\nPersonnage: %s" % player.character_name
		tip += "\nFaction: %s" % player.faction.capitalize()

	if player.equipment.size() > 0:
		tip += "\n\nÉquipement:"
		for card in player.equipment:
			tip += "\n  %s (+%d)" % [card.name, card.get_effect_value()]

	if not player.is_alive:
		tip = "%s (Mort)" % player.display_name

	tooltip_text = tip
