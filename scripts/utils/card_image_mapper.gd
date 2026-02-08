## CardImageMapper - Maps card, zone and character IDs to image file paths
## Loads mappings from data/card_image_map.json with texture caching
class_name CardImageMapper
extends RefCounted


const IMAGE_MAP_PATH = "res://data/card_image_map.json"

static var _data: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return

	var file = FileAccess.open(IMAGE_MAP_PATH, FileAccess.READ)
	if file == null:
		push_warning("[CardImageMapper] Cannot open %s" % IMAGE_MAP_PATH)
		_loaded = true
		return

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_warning("[CardImageMapper] JSON parse error: %s" % json.get_error_message())
		_loaded = true
		return

	_data = json.data
	_loaded = true
	print("[CardImageMapper] Loaded image mappings")


## Get image path for a Card entity
static func get_card_image_path(card) -> String:
	_ensure_loaded()
	var card_images: Dictionary = _data.get("card_images", {})
	return card_images.get(card.id, "")


## Get card back image path for a deck type (hermit, white, black)
static func get_card_back_path(deck_type: String) -> String:
	_ensure_loaded()
	var card_backs: Dictionary = _data.get("card_backs", {})
	return card_backs.get(deck_type, "")


## Get zone illustration path for a zone ID
static func get_zone_image_path(zone_id: String) -> String:
	_ensure_loaded()
	var zone_images: Dictionary = _data.get("zone_images", {})
	return zone_images.get(zone_id, "")


## Get HP score card image path for a variant key
static func get_hp_score_card_path(variant: String) -> String:
	_ensure_loaded()
	var hp_cards: Dictionary = _data.get("hp_score_cards", {})
	return hp_cards.get(variant, "")


## Get character card image path for a character ID
static func get_character_image_path(character_id: String) -> String:
	_ensure_loaded()
	var char_images: Dictionary = _data.get("character_images", {})
	return char_images.get(character_id, "")


## Load and cache a texture from path, returns null if not found
static func load_texture(path: String) -> Texture2D:
	if path == "":
		return null

	if _texture_cache.has(path):
		return _texture_cache[path]

	if not ResourceLoader.exists(path):
		return null

	var texture = load(path) as Texture2D
	if texture != null:
		_texture_cache[path] = texture

	return texture
