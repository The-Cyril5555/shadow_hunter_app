## Card - Represents a single card entity
## Manages card properties and provides serialization for save/load
class_name Card
extends RefCounted


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var id: String = ""
var name: String = ""
var deck: String = ""  # "hermit", "white", "black"
var type: String = ""  # "instant", "equipment", "vision"
var effect: Dictionary = {}
var copies_in_deck: int = 1


# -----------------------------------------------------------------------------
# Serialization
# -----------------------------------------------------------------------------

## Create card from dictionary (from JSON)
func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "Unknown Card")
	deck = data.get("deck", "")
	type = data.get("type", "instant")
	effect = data.get("effect", {})
	copies_in_deck = data.get("copies_in_deck", 1)


## Convert card to dictionary (for save/load)
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"deck": deck,
		"type": type,
		"effect": effect,
		"copies_in_deck": copies_in_deck
	}


# -----------------------------------------------------------------------------
# Helper Methods
# -----------------------------------------------------------------------------

## Get formatted effect description
func get_effect_description() -> String:
	return effect.get("description", "No effect")


## Get effect type
func get_effect_type() -> String:
	return effect.get("type", "")


## Get effect value
func get_effect_value() -> int:
	return effect.get("value", 0)
