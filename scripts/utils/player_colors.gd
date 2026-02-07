## PlayerColors - Consistent player color mapping across all UI components
class_name PlayerColors
extends RefCounted


# 8 distinct colors for players J1-J8
const COLORS: Array[Color] = [
	Color(0.9, 0.2, 0.2),   # J1 - Red
	Color(0.2, 0.5, 0.9),   # J2 - Blue
	Color(0.2, 0.8, 0.2),   # J3 - Green
	Color(0.9, 0.8, 0.1),   # J4 - Yellow
	Color(0.8, 0.4, 0.9),   # J5 - Purple
	Color(0.9, 0.5, 0.1),   # J6 - Orange
	Color(0.1, 0.8, 0.8),   # J7 - Cyan
	Color(0.9, 0.4, 0.6),   # J8 - Pink
]


## Get the color assigned to a player by index
static func get_color(player_id: int) -> Color:
	if player_id >= 0 and player_id < COLORS.size():
		return COLORS[player_id]
	return Color.WHITE


## Get the short label for a player (e.g. "J1", "J2")
static func get_label(player: Player) -> String:
	return "J%d" % (player.id + 1)
