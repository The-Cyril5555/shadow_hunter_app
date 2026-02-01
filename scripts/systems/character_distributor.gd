## CharacterDistributor - Handles character distribution for game setup (Autoload)
## Distributes characters from GameState according to faction rules.
class_name CharacterDistributorClass
extends Node


# Faction distribution rules loaded from JSON
var faction_distribution: Dictionary = {}


func _ready() -> void:
	_load_faction_distribution()
	print("[CharacterDistributor] Initialized")


## Load faction distribution rules from JSON
func _load_faction_distribution() -> void:
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
	faction_distribution = data.get("faction_distribution", {})

	print("[CharacterDistributor] Loaded faction distribution rules for %d player counts" % faction_distribution.size())


## Distribute characters to players according to faction rules
func distribute_characters(players: Array, player_count: int, include_expansion: bool = true) -> void:
	var distribution = _get_distribution(player_count)
	if distribution.is_empty():
		push_error("[CharacterDistributor] No distribution rules for %d players" % player_count)
		return

	var hunter_count = distribution.get("hunter", 0)
	var shadow_count = distribution.get("shadow", 0)
	var neutral_count = distribution.get("neutral", 0)

	print("[CharacterDistributor] Distributing for %d players: %d hunters, %d shadows, %d neutrals (expansion: %s)" % [player_count, hunter_count, shadow_count, neutral_count, "yes" if include_expansion else "no"])

	# Create pool of characters to assign
	var character_pool: Array[Dictionary] = []

	# Get characters from GameState by faction
	var available_hunters = GameState.get_characters_by_faction("hunter", include_expansion)
	var available_shadows = GameState.get_characters_by_faction("shadow", include_expansion)
	var available_neutrals = GameState.get_characters_by_faction("neutral", include_expansion)

	# Add required number from each faction
	var shuffled_hunters = available_hunters.duplicate()
	shuffled_hunters.shuffle()
	for i in range(min(hunter_count, shuffled_hunters.size())):
		character_pool.append(shuffled_hunters[i])

	var shuffled_shadows = available_shadows.duplicate()
	shuffled_shadows.shuffle()
	for i in range(min(shadow_count, shuffled_shadows.size())):
		character_pool.append(shuffled_shadows[i])

	var shuffled_neutrals = available_neutrals.duplicate()
	shuffled_neutrals.shuffle()
	for i in range(min(neutral_count, shuffled_neutrals.size())):
		character_pool.append(shuffled_neutrals[i])

	# Shuffle the entire pool
	character_pool.shuffle()

	# Assign to players
	for i in range(min(players.size(), character_pool.size())):
		players[i].assign_character(character_pool[i])

	# Register passive abilities after character assignment
	for player in players:
		GameState.passive_ability_system.register_player_ability(player)

	print("[CharacterDistributor] Distribution complete")


## Get faction distribution for a player count
func _get_distribution(player_count: int) -> Dictionary:
	var key = str(player_count)
	if faction_distribution.has(key):
		return faction_distribution[key]
	return {}


## Get a character by ID (delegates to GameState)
func get_character(char_id: String) -> Dictionary:
	return GameState.get_character(char_id)


## Get all characters of a faction (delegates to GameState)
func get_characters_by_faction(faction: String, include_expansion: bool = true) -> Array[Dictionary]:
	return GameState.get_characters_by_faction(faction, include_expansion)
