## Player - Represents a player in the game (human or bot)
## Holds all player state including character, HP, equipment, and position.
class_name Player
extends RefCounted


# Player identification
var id: int
var display_name: String
var is_human: bool

# Character info (assigned during game setup)
var character_id: String = ""
var character_name: String = ""
var faction: String = ""  # "hunter", "shadow", "neutral"

# Health
var hp: int = 0
var hp_max: int = 0

# Equipment (card IDs currently equipped)
var equipment: Array[String] = []

# Status
var is_alive: bool = true
var is_revealed: bool = false

# Board position
var position_zone: String = ""  # Current zone ID


func _init(p_id: int = 0, p_name: String = "", p_is_human: bool = true) -> void:
	id = p_id
	display_name = p_name
	is_human = p_is_human


## Assign a character to this player from character data
func assign_character(char_data: Dictionary) -> void:
	character_id = char_data.get("id", "")
	character_name = char_data.get("name", "Unknown")
	faction = char_data.get("faction", "neutral")
	hp_max = char_data.get("hp_max", 10)
	hp = hp_max
	print("[Player] %s assigned character: %s (%s)" % [display_name, character_name, faction])


## Take damage, returns true if player died
func take_damage(amount: int) -> bool:
	hp = max(0, hp - amount)
	if hp <= 0:
		is_alive = false
		return true
	return false


## Heal player (cannot exceed max HP)
func heal(amount: int) -> void:
	hp = min(hp_max, hp + amount)


## Reveal this player's identity
func reveal() -> void:
	is_revealed = true


## Add equipment card
func add_equipment(card_id: String) -> void:
	equipment.append(card_id)


## Remove equipment card
func remove_equipment(card_id: String) -> bool:
	var idx = equipment.find(card_id)
	if idx >= 0:
		equipment.remove_at(idx)
		return true
	return false


## Serialize player state for saving
func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"is_human": is_human,
		"character_id": character_id,
		"character_name": character_name,
		"faction": faction,
		"hp": hp,
		"hp_max": hp_max,
		"equipment": equipment.duplicate(),
		"is_alive": is_alive,
		"is_revealed": is_revealed,
		"position_zone": position_zone
	}


## Load player state from dictionary
static func from_dict(data: Dictionary) -> Player:
	var player = Player.new(
		data.get("id", 0),
		data.get("display_name", ""),
		data.get("is_human", true)
	)
	player.character_id = data.get("character_id", "")
	player.character_name = data.get("character_name", "")
	player.faction = data.get("faction", "")
	player.hp = data.get("hp", 0)
	player.hp_max = data.get("hp_max", 0)
	player.equipment = data.get("equipment", [])
	player.is_alive = data.get("is_alive", true)
	player.is_revealed = data.get("is_revealed", false)
	player.position_zone = data.get("position_zone", "")
	return player
