## Test script for Board & Zone Initialization
## Manual test to verify Story 1.3 implementation
extends Node


func _ready() -> void:
	print("\n=== Board & Zone Initialization Test ===\n")

	# Test 1: Zone Data Configuration
	print("Test 1: Zone Data Configuration")
	test_zone_data()

	# Test 2: Deck Initialization
	print("\nTest 2: Deck Initialization")
	test_deck_initialization()

	# Test 3: Zone Count
	print("\nTest 3: Zone Count")
	test_zone_count()

	print("\n=== All Tests Complete ===\n")
	get_tree().quit()


func test_zone_data() -> void:
	var zones = ZoneData.ZONES

	assert(zones.size() == 6, "Should have 6 zones")
	print("✓ Zone count: %d" % zones.size())

	# Verify zone IDs
	var expected_ids = ["hermit", "church", "cemetery", "weird_woods", "underworld", "altar"]
	for i in range(zones.size()):
		assert(zones[i].id == expected_ids[i], "Zone ID mismatch")
	print("✓ All zone IDs correct")

	# Verify zones with decks
	var zones_with_decks = ZoneData.get_zones_with_decks()
	assert(zones_with_decks.size() == 3, "Should have 3 zones with decks")
	print("✓ Zones with decks: %d" % zones_with_decks.size())

	# Verify zones without decks
	var zones_without_decks = ZoneData.get_zones_without_decks()
	assert(zones_without_decks.size() == 3, "Should have 3 zones without decks")
	print("✓ Zones without decks: %d" % zones_without_decks.size())


func test_deck_initialization() -> void:
	# Initialize decks
	GameState.initialize_decks()

	# Verify Hermit deck (2 cards × 2 copies = 4 total)
	assert(GameState.hermit_deck.size() == 4, "Hermit deck should have 4 cards")
	print("✓ Hermit deck: %d cards" % GameState.hermit_deck.size())

	# Verify White deck (3 + 2 copies = 5 total)
	assert(GameState.white_deck.size() == 5, "White deck should have 5 cards")
	print("✓ White deck: %d cards" % GameState.white_deck.size())

	# Verify Black deck (3 + 2 copies = 5 total)
	assert(GameState.black_deck.size() == 5, "Black deck should have 5 cards")
	print("✓ Black deck: %d cards" % GameState.black_deck.size())


func test_zone_count() -> void:
	var zone_count = ZoneData.get_zone_count()
	assert(zone_count == 6, "Zone count should be 6")
	print("✓ Zone count method: %d" % zone_count)

	# Test get_zone_by_id
	var hermit_zone = ZoneData.get_zone_by_id("hermit")
	assert(hermit_zone.name == "Hermit's Cabin", "Hermit zone name mismatch")
	print("✓ get_zone_by_id works correctly")
