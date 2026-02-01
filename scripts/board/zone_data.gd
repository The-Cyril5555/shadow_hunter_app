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

# Zone adjacency map (which zones connect to which)
const ZONE_ADJACENCY = {
	"hermit": ["church", "weird_woods"],
	"church": ["hermit", "cemetery", "altar"],
	"cemetery": ["church", "underworld", "weird_woods"],
	"weird_woods": ["hermit", "cemetery", "underworld"],
	"underworld": ["cemetery", "weird_woods", "altar"],
	"altar": ["church", "underworld"]
}


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


## Get all zones reachable from start_zone within max_distance steps
## Uses BFS (Breadth-First Search) algorithm
static func get_reachable_zones(start_zone_id: String, max_distance: int) -> Array[String]:
	var reachable: Array[String] = []
	var visited: Dictionary = {}
	var queue: Array = []

	# Start BFS
	queue.append({"zone_id": start_zone_id, "distance": 0})
	visited[start_zone_id] = true

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_zone_id = current.zone_id
		var current_distance = current.distance

		# Add to reachable if within range (excluding start zone itself)
		if current_distance > 0 and current_distance <= max_distance:
			reachable.append(current_zone_id)

		# Explore neighbors if we haven't reached max distance
		if current_distance < max_distance:
			if ZONE_ADJACENCY.has(current_zone_id):
				for neighbor_id in ZONE_ADJACENCY[current_zone_id]:
					if not visited.has(neighbor_id):
						visited[neighbor_id] = true
						queue.append({"zone_id": neighbor_id, "distance": current_distance + 1})

	return reachable


## Get distance between two zones (returns -1 if not connected)
static func get_distance_between_zones(from_zone_id: String, to_zone_id: String) -> int:
	if from_zone_id == to_zone_id:
		return 0

	var visited: Dictionary = {}
	var queue: Array = []

	queue.append({"zone_id": from_zone_id, "distance": 0})
	visited[from_zone_id] = true

	while queue.size() > 0:
		var current = queue.pop_front()
		var current_zone_id = current.zone_id
		var current_distance = current.distance

		if current_zone_id == to_zone_id:
			return current_distance

		if ZONE_ADJACENCY.has(current_zone_id):
			for neighbor_id in ZONE_ADJACENCY[current_zone_id]:
				if not visited.has(neighbor_id):
					visited[neighbor_id] = true
					queue.append({"zone_id": neighbor_id, "distance": current_distance + 1})

	return -1  # Not connected
