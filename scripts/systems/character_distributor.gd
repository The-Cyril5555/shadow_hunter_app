## CharacterDistributor - Handles character distribution for game setup (Autoload)
## Loads characters from JSON and distributes them according to faction rules.
class_name CharacterDistributorClass
extends Node


# Character data loaded from JSON
var characters_data: Dictionary = {}
var faction_distribution: Dictionary = {}

# Cached character lists by faction
var hunters: Array[Dictionary] = []
var shadows: Array[Dictionary] = []
var neutrals: Array[Dictionary] = []


func _ready() -> void:
	_load_characters()
	print("[CharacterDistributor] Initialized with %d characters" % characters_data.size())


func _load_characters() -> void:
	var file = FileAccess.open("res://data/characters.json", FileAccess.READ)
	if file == null:
		push_error("[CharacterDistributor] Failed to load characters.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("[CharacterDistributor] JSON parse error: %s" % json.get_error_message())
		return

	var data = json.data
	characters_data = data.get("characters", {})
	faction_distribution = data.get("faction_distribution", {})

	# Cache characters by faction
	for char_id in characters_data:
		var char_data = characters_data[char_id]
		match char_data.get("faction", ""):
			"hunter":
				hunters.append(char_data)
			"shadow":
				shadows.append(char_data)
			"neutral":
				neutrals.append(char_data)

	print("[CharacterDistributor] Loaded: %d hunters, %d shadows, %d neutrals" % [hunters.size(), shadows.size(), neutrals.size()])


## Distribute characters to players according to faction rules
func distribute_characters(players: Array, player_count: int) -> void:
	var distribution = _get_distribution(player_count)
	if distribution.is_empty():
		push_error("[CharacterDistributor] No distribution rules for %d players" % player_count)
		return

	var hunter_count = distribution.get("hunter", 0)
	var shadow_count = distribution.get("shadow", 0)
	var neutral_count = distribution.get("neutral", 0)

	print("[CharacterDistributor] Distributing for %d players: %d hunters, %d shadows, %d neutrals" % [player_count, hunter_count, shadow_count, neutral_count])

	# Create pool of characters to assign
	var character_pool: Array[Dictionary] = []

	# Add required number from each faction
	var shuffled_hunters = hunters.duplicate()
	shuffled_hunters.shuffle()
	for i in range(min(hunter_count, shuffled_hunters.size())):
		character_pool.append(shuffled_hunters[i])

	var shuffled_shadows = shadows.duplicate()
	shuffled_shadows.shuffle()
	for i in range(min(shadow_count, shuffled_shadows.size())):
		character_pool.append(shuffled_shadows[i])

	var shuffled_neutrals = neutrals.duplicate()
	shuffled_neutrals.shuffle()
	for i in range(min(neutral_count, shuffled_neutrals.size())):
		character_pool.append(shuffled_neutrals[i])

	# Shuffle the entire pool
	character_pool.shuffle()

	# Assign to players
	for i in range(min(players.size(), character_pool.size())):
		players[i].assign_character(character_pool[i])

	print("[CharacterDistributor] Distribution complete")


## Get faction distribution for a player count
func _get_distribution(player_count: int) -> Dictionary:
	var key = str(player_count)
	if faction_distribution.has(key):
		return faction_distribution[key]
	return {}


## Get a character by ID
func get_character(char_id: String) -> Dictionary:
	return characters_data.get(char_id, {})


## Get all characters of a faction
func get_characters_by_faction(faction: String) -> Array[Dictionary]:
	match faction:
		"hunter":
			return hunters.duplicate()
		"shadow":
			return shadows.duplicate()
		"neutral":
			return neutrals.duplicate()
	return []
