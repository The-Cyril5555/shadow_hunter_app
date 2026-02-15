## PlayerColors - Consistent player color mapping across all UI components
class_name PlayerColors
extends RefCounted


# 8 distinct colors for players (1-8)
const COLORS: Array[Color] = [
	Color(0.9, 0.2, 0.2),   # 1 - Red
	Color(0.2, 0.5, 0.9),   # 2 - Blue
	Color(0.2, 0.8, 0.2),   # 3 - Green
	Color(0.9, 0.8, 0.1),   # 4 - Yellow
	Color(0.8, 0.4, 0.9),   # 5 - Purple
	Color(0.9, 0.5, 0.1),   # 6 - Orange
	Color(0.1, 0.8, 0.8),   # 7 - Cyan
	Color(0.9, 0.4, 0.6),   # 8 - Pink
]


## Get the color assigned to a player by index
static func get_color(player_id: int) -> Color:
	if player_id >= 0 and player_id < COLORS.size():
		return COLORS[player_id]
	return Color.WHITE


## Get the short label for a player (e.g. "J1" for human, "B1" for bot)
static func get_label(player: Player) -> String:
	if player.is_human:
		return "J%d" % (player.id + 1)
	return "B%d" % (player.id + 1)
