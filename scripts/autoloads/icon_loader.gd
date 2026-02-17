## IconLoader - Centralized icon loading system
## Loads and provides access to pixel art UI icons
class_name IconLoaderClass
extends Node


# =============================================================================
# PROPERTIES
# =============================================================================

var icons: Dictionary = {}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_icons()


# =============================================================================
# PUBLIC METHODS
# =============================================================================

## Get an icon by ID, returns null if not found
func get_icon(id: String) -> Texture2D:
	return icons.get(id, null)


# =============================================================================
# PRIVATE METHODS
# =============================================================================

func _load_icons() -> void:
	var icon_names = [
		"reveal", "ability", "attack", "end_turn",
		"resume", "save", "load", "quit",
		"roll_dice", "heal", "steal", "cancel"
	]

	for icon_name in icon_names:
		var path = "res://assets/sprites/icons/%s.png" % icon_name
		var texture = load(path) as Texture2D
		if texture:
			icons[icon_name] = texture
			print("[IconLoader] Loaded: %s" % icon_name)
		else:
			push_warning("[IconLoader] Failed to load: %s" % path)

	print("[IconLoader] Loaded %d icons" % icons.size())
