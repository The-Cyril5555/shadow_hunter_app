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
var ability_data: Dictionary = {}  # Full ability data from character JSON

# Health
var hp: int = 0
var hp_max: int = 0

# Equipment (Card instances currently equipped)
var equipment: Array = []  # Array of Card instances

# Hand (Card instances in player's hand)
var hand: Array = []  # Array of Card instances

# Status
var is_alive: bool = true
var is_revealed: bool = false

# Ability tracking
var ability_used: bool = false  # For "once per game" abilities
var ability_disabled: bool = false  # For Ellen's curse effect

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
	ability_data = char_data.get("ability", {}).duplicate(true)  # Store defensive copy of ability data
	print("[Player] %s assigned character: %s (%s, ability: %s)" % [display_name, character_name, faction, ability_data.get("name", "None")])


## Take damage, returns true if player died
func take_damage(amount: int, source: Player = null) -> bool:
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
	AudioManager.play_sfx("reveal_dramatic")
	is_revealed = true


## Equip a card from hand
func equip_card(card: Card) -> void:
	# Remove from hand
	var hand_idx = hand.find(card)
	if hand_idx >= 0:
		hand.remove_at(hand_idx)

	# Add to equipment
	equipment.append(card)
	print("[Player] %s equipped: %s" % [display_name, card.name])


## Add equipment card (legacy compatibility)
func add_equipment(card_id: String) -> void:
	# Deprecated - use equip_card instead
	push_warning("[Player] add_equipment with ID is deprecated, use equip_card with Card instance")


## Remove equipment card
func remove_equipment(card_id: String) -> bool:
	# Find card by ID in equipment
	for i in range(equipment.size()):
		if equipment[i].id == card_id:
			equipment.remove_at(i)
			return true
	return false


## Calculate total attack damage bonus from equipment
func get_attack_damage_bonus() -> int:
	var bonus = 0
	for card in equipment:
		if card.get_effect_type() == "damage":
			bonus += card.get_effect_value()
	return bonus


## Calculate total defense bonus from equipment
func get_defense_bonus() -> int:
	var bonus = 0
	for card in equipment:
		if card.get_effect_type() == "defense":
			bonus += card.get_effect_value()
	return bonus


## Serialize player state for saving
func to_dict() -> Dictionary:
	# Serialize hand cards
	var hand_data = []
	for card in hand:
		hand_data.append(card.to_dict())

	# Serialize equipment cards
	var equipment_data = []
	for card in equipment:
		equipment_data.append(card.to_dict())

	return {
		"id": id,
		"display_name": display_name,
		"is_human": is_human,
		"character_id": character_id,
		"character_name": character_name,
		"faction": faction,
		"ability_data": ability_data,
		"hp": hp,
		"hp_max": hp_max,
		"equipment": equipment_data,
		"hand": hand_data,
		"is_alive": is_alive,
		"is_revealed": is_revealed,
		"ability_used": ability_used,
		"ability_disabled": ability_disabled,
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
	player.ability_data = data.get("ability_data", {})
	player.hp = data.get("hp", 0)
	player.hp_max = data.get("hp_max", 0)
	player.is_alive = data.get("is_alive", true)
	player.is_revealed = data.get("is_revealed", false)
	player.ability_used = data.get("ability_used", false)
	player.ability_disabled = data.get("ability_disabled", false)
	player.position_zone = data.get("position_zone", "")

	# Deserialize equipment cards
	var equipment_data = data.get("equipment", [])
	for card_data in equipment_data:
		var card = Card.new()
		card.from_dict(card_data)
		player.equipment.append(card)

	# Deserialize hand cards
	var hand_data = data.get("hand", [])
	for card_data in hand_data:
		var card = Card.new()
		card.from_dict(card_data)
		player.hand.append(card)

	return player
