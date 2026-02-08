## ZoneData - Zone configuration for Shadow Hunter board
## Defines the 6 zones with their properties and deck associations
class_name ZoneData
extends RefCounted


# -----------------------------------------------------------------------------
# Constants - Zone Definitions
# -----------------------------------------------------------------------------
const ZONES: Array[Dictionary] = [
	{
		"id": "hermit",
		"name": "Hermit's Cabin",
		"deck_type": "hermit",
		"color": Color(0.6, 0.5, 0.3),
		"description": "Draw from Hermit deck (Vision cards)"
	},
	{
		"id": "church",
		"name": "Church",
		"deck_type": "white",
		"color": Color(0.9, 0.9, 0.9),
		"description": "Draw from White deck (Beneficial cards)"
	},
	{
		"id": "cemetery",
		"name": "Cemetery",
		"deck_type": "black",
		"color": Color(0.2, 0.2, 0.2),
		"description": "Draw from Black deck (Harmful cards)"
	},
	{
		"id": "weird_woods",
		"name": "Weird Woods",
		"deck_type": "",
		"color": Color(0.2, 0.5, 0.2),
		"description": "No deck available"
	},
	{
		"id": "underworld",
		"name": "Underworld Gate",
		"deck_type": "",
		"color": Color(0.5, 0.2, 0.5),
		"description": "No deck available"
	},
	{
		"id": "altar",
		"name": "Erstwhile Altar",
		"deck_type": "",
		"color": Color(0.7, 0.6, 0.4),
		"description": "No deck available"
	}
]

# Board positions — each has a dice range and belongs to a group (triangle adjacency)
const BOARD_POSITIONS: Array[Dictionary] = [
	{"position": 0, "dice_range": [2, 3], "group": 0},
	{"position": 1, "dice_range": [4, 5], "group": 0},
	{"position": 2, "dice_range": [6],    "group": 1},
	{"position": 3, "dice_range": [7],    "group": 1},
	{"position": 4, "dice_range": [8, 9], "group": 2},
	{"position": 5, "dice_range": [10],   "group": 2},
]


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Get zone data by ID
static func get_zone_by_id(zone_id: String) -> Dictionary:
	for zone in ZONES:
		if zone.id == zone_id:
			return zone
	push_error("[ZoneData] Zone not found: " + zone_id)
	return {}


## Get all zones with a specific deck type
static func get_zones_by_deck_type(deck_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone in ZONES:
		if zone.deck_type == deck_type:
			result.append(zone)
	return result


## Get zones with decks (non-empty deck_type)
static func get_zones_with_decks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone in ZONES:
		if zone.deck_type != "":
			result.append(zone)
	return result


## Get zones without decks (empty deck_type)
static func get_zones_without_decks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone in ZONES:
		if zone.deck_type == "":
			result.append(zone)
	return result


## Get count of zones
static func get_zone_count() -> int:
	return ZONES.size()


## Shuffle zone IDs into random positions on the board
## Returns: Array of zone_id strings ordered by board position (0-5)
static func shuffle_zone_positions() -> Array:
	var zone_ids: Array = []
	for zone in ZONES:
		zone_ids.append(zone.id)
	zone_ids.shuffle()
	return zone_ids


## Get the zone ID at the position matching a dice sum
## zone_positions: ordered Array of zone_id strings (from shuffle_zone_positions)
## Returns: zone_id string, or "" if no match
static func get_zone_for_dice_sum(dice_sum: int, zone_positions: Array) -> String:
	for pos_data in BOARD_POSITIONS:
		if dice_sum in pos_data.dice_range:
			var idx: int = pos_data.position
			if idx < zone_positions.size():
				return zone_positions[idx]
	return ""


## Get the dice range for a given board position index
static func get_dice_range_for_position(position: int) -> Array:
	if position >= 0 and position < BOARD_POSITIONS.size():
		return BOARD_POSITIONS[position].dice_range
	return []


## Get the group index for a given board position
static func get_group_for_position(position: int) -> int:
	if position >= 0 and position < BOARD_POSITIONS.size():
		return BOARD_POSITIONS[position].group
	return -1


## Format dice range as display string (e.g. "2-3", "6", "8-9")
static func format_dice_range(dice_range: Array) -> String:
	if dice_range.size() == 0:
		return ""
	if dice_range.size() == 1:
		return str(dice_range[0])
	return "%d-%d" % [dice_range[0], dice_range[-1]]
