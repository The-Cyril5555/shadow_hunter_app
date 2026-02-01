## Manual test script for Character Data System (Story 2.1)
## Run this script from Godot Editor to verify all functionality
extends Node


func _ready():
	print("\n========================================")
	print("CHARACTER DATA SYSTEM TEST SUITE")
	print("========================================\n")

	test_all_characters_load()
	test_base_expansion_filtering()
	test_faction_filtering()
	test_faction_filtering_no_expansion()
	test_defensive_copies()
	test_invalid_character_id()
	test_character_distributor_integration()
	test_player_ability_data()
	test_player_serialization()
	test_loading_performance()

	print("\n========================================")
	print("ALL TESTS COMPLETED")
	print("========================================\n")


func test_all_characters_load():
	print("[TEST] All characters load...")
	var all_chars = GameState.get_all_characters()

	assert(all_chars.size() == 20, "✗ FAIL: Expected 20 characters, got %d" % all_chars.size())

	for char_data in all_chars:
		assert(char_data.has("id"), "✗ FAIL: Character missing 'id' field")
		assert(char_data.has("name"), "✗ FAIL: Character missing 'name' field")
		assert(char_data.has("faction"), "✗ FAIL: Character missing 'faction' field")
		assert(char_data.has("hp_max"), "✗ FAIL: Character missing 'hp_max' field")
		assert(char_data.has("ability"), "✗ FAIL: Character missing 'ability' field")

		var ability = char_data.get("ability", {})
		assert(ability.has("name"), "✗ FAIL: Ability missing 'name' field")
		assert(ability.has("type"), "✗ FAIL: Ability missing 'type' field")
		assert(ability.has("trigger"), "✗ FAIL: Ability missing 'trigger' field")

	print("  ✓ PASS: All 20 characters loaded with valid structure\n")


func test_base_expansion_filtering():
	print("[TEST] Base/Expansion filtering...")
	var base_chars = GameState.get_base_characters()
	var expansion_chars = GameState.get_expansion_characters()

	assert(base_chars.size() == 10, "✗ FAIL: Expected 10 base characters, got %d" % base_chars.size())
	assert(expansion_chars.size() == 10, "✗ FAIL: Expected 10 expansion characters, got %d" % expansion_chars.size())

	for char_data in base_chars:
		assert(!char_data.get("is_expansion", false), "✗ FAIL: Base character has is_expansion = true")

	for char_data in expansion_chars:
		assert(char_data.get("is_expansion", false), "✗ FAIL: Expansion character has is_expansion = false")

	print("  ✓ PASS: Base (10) and Expansion (10) filtering works correctly\n")


func test_faction_filtering():
	print("[TEST] Faction filtering...")
	var hunters = GameState.get_characters_by_faction("hunter", true)
	var shadows = GameState.get_characters_by_faction("shadow", true)
	var neutrals = GameState.get_characters_by_faction("neutral", true)

	var total = hunters.size() + shadows.size() + neutrals.size()
	assert(total == 20, "✗ FAIL: Total characters across factions should be 20, got %d" % total)

	print("  Distribution: %d hunters, %d shadows, %d neutrals" % [hunters.size(), shadows.size(), neutrals.size()])

	for char_data in hunters:
		assert(char_data.get("faction", "") == "hunter", "✗ FAIL: Hunter faction mismatch")

	for char_data in shadows:
		assert(char_data.get("faction", "") == "shadow", "✗ FAIL: Shadow faction mismatch")

	for char_data in neutrals:
		assert(char_data.get("faction", "") == "neutral", "✗ FAIL: Neutral faction mismatch")

	print("  ✓ PASS: Faction filtering works correctly\n")


func test_faction_filtering_no_expansion():
	print("[TEST] Faction filtering (base only)...")
	var hunters_base = GameState.get_characters_by_faction("hunter", false)
	var shadows_base = GameState.get_characters_by_faction("shadow", false)
	var neutrals_base = GameState.get_characters_by_faction("neutral", false)

	print("  Base distribution: %d hunters, %d shadows, %d neutrals" % [hunters_base.size(), shadows_base.size(), neutrals_base.size()])

	for char_data in hunters_base:
		assert(!char_data.get("is_expansion", false), "✗ FAIL: Base-only hunter has is_expansion = true")

	for char_data in shadows_base:
		assert(!char_data.get("is_expansion", false), "✗ FAIL: Base-only shadow has is_expansion = true")

	for char_data in neutrals_base:
		assert(!char_data.get("is_expansion", false), "✗ FAIL: Base-only neutral has is_expansion = true")

	print("  ✓ PASS: Faction filtering with expansion exclusion works\n")


func test_defensive_copies():
	print("[TEST] Defensive copies prevent mutation...")
	var char1 = GameState.get_character("alice")
	var original_name = char1.get("name", "")

	char1["name"] = "MUTATED"

	var char2 = GameState.get_character("alice")

	assert(char2.get("name", "") == original_name, "✗ FAIL: Character data was mutated")
	assert(char2.get("name", "") != "MUTATED", "✗ FAIL: Mutation persisted")

	print("  ✓ PASS: Defensive copies prevent external mutation\n")


func test_invalid_character_id():
	print("[TEST] Invalid character ID handling...")
	var invalid_char = GameState.get_character("nonexistent_character_id_xyz")

	assert(invalid_char.size() == 0, "✗ FAIL: Invalid character ID should return empty dictionary")

	print("  ✓ PASS: Invalid character ID returns empty dictionary\n")


func test_character_distributor_integration():
	print("[TEST] CharacterDistributor integration...")
	var players = []
	for i in range(4):
		var player = Player.new(i, "Player %d" % i, true)
		players.append(player)

	CharacterDistributor.distribute_characters(players, 4, false)

	for player in players:
		assert(player.character_id != "", "✗ FAIL: Player has no character_id")
		assert(player.character_name != "", "✗ FAIL: Player has no character_name")
		assert(player.faction != "", "✗ FAIL: Player has no faction")
		assert(player.hp_max > 0, "✗ FAIL: Player has invalid hp_max")
		assert(player.hp == player.hp_max, "✗ FAIL: Player HP doesn't match hp_max")
		assert(!player.ability_data.is_empty(), "✗ FAIL: Player has no ability_data")

		print("  - %s assigned: %s (%s, %s)" % [player.display_name, player.character_name, player.faction, player.ability_data.get("name", "Unknown")])

	print("  ✓ PASS: CharacterDistributor integration works\n")


func test_player_ability_data():
	print("[TEST] Player ability_data storage...")
	var char_data = GameState.get_character("alice")
	assert(!char_data.is_empty(), "✗ FAIL: Could not load alice character")

	var player = Player.new(1, "Test Player", true)
	player.assign_character(char_data)

	assert(!player.ability_data.is_empty(), "✗ FAIL: Player has no ability_data")
	assert(player.ability_data.has("name"), "✗ FAIL: Ability missing 'name'")
	assert(player.ability_data.has("type"), "✗ FAIL: Ability missing 'type'")
	assert(player.ability_data.has("trigger"), "✗ FAIL: Ability missing 'trigger'")

	print("  Ability: %s (type: %s, trigger: %s)" % [player.ability_data.get("name", ""), player.ability_data.get("type", ""), player.ability_data.get("trigger", "")])
	print("  ✓ PASS: Player stores ability_data correctly\n")


func test_player_serialization():
	print("[TEST] Player serialization with ability_data...")
	var char_data = GameState.get_character("alice")
	assert(!char_data.is_empty(), "✗ FAIL: Could not load alice character")

	var player1 = Player.new(1, "Test Player", true)
	player1.assign_character(char_data)

	var serialized = player1.to_dict()
	assert(serialized.has("ability_data"), "✗ FAIL: Serialized player missing 'ability_data'")

	var player2 = Player.from_dict(serialized)
	assert(!player2.ability_data.is_empty(), "✗ FAIL: Deserialized player has no ability_data")
	assert(player2.ability_data.get("name", "") == player1.ability_data.get("name", ""), "✗ FAIL: Ability name mismatch after deserialization")

	print("  ✓ PASS: Player serialization preserves ability_data\n")


func test_loading_performance():
	print("[TEST] Loading performance...")
	var start_time = Time.get_ticks_usec()

	for i in range(100):
		var chars = GameState.get_all_characters()

	var end_time = Time.get_ticks_usec()
	var elapsed_ms = (end_time - start_time) / 1000.0

	print("  Performance: 100 loads in %.2f ms (%.2f ms avg)" % [elapsed_ms, elapsed_ms / 100.0])

	assert(elapsed_ms < 100.0, "✗ FAIL: Loading too slow (%.2f ms)" % elapsed_ms)

	print("  ✓ PASS: Performance is acceptable\n")
