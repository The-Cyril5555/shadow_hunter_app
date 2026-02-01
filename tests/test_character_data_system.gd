## Test suite for Character Data System (Story 2.1)
## Tests character loading, filtering, defensive copies, and CharacterDistributor integration
extends GutTest


func before_all():
	# Ensure GameState autoload is initialized
	if not has_node("/root/GameState"):
		push_warning("[Test] GameState autoload not found - some tests may fail")


## Test that all 20 characters load correctly from JSON
func test_all_characters_load():
	var all_chars = GameState.get_all_characters()

	assert_eq(all_chars.size(), 20, "Should load exactly 20 characters")

	# Verify each character has required fields
	for char_data in all_chars:
		assert_has(char_data, "id", "Character should have 'id' field")
		assert_has(char_data, "name", "Character should have 'name' field")
		assert_has(char_data, "faction", "Character should have 'faction' field")
		assert_has(char_data, "hp_max", "Character should have 'hp_max' field")
		assert_has(char_data, "ability", "Character should have 'ability' field")

		# Verify ability structure
		var ability = char_data.get("ability", {})
		assert_has(ability, "name", "Ability should have 'name' field")
		assert_has(ability, "type", "Ability should have 'type' field")
		assert_has(ability, "trigger", "Ability should have 'trigger' field")


## Test base/expansion character filtering
func test_base_expansion_filtering():
	var base_chars = GameState.get_base_characters()
	var expansion_chars = GameState.get_expansion_characters()

	assert_eq(base_chars.size(), 10, "Should have exactly 10 base characters")
	assert_eq(expansion_chars.size(), 10, "Should have exactly 10 expansion characters")

	# Verify base characters have is_expansion = false
	for char_data in base_chars:
		assert_false(char_data.get("is_expansion", false), "Base character should have is_expansion = false")

	# Verify expansion characters have is_expansion = true
	for char_data in expansion_chars:
		assert_true(char_data.get("is_expansion", false), "Expansion character should have is_expansion = true")


## Test faction-based filtering
func test_faction_filtering():
	var hunters = GameState.get_characters_by_faction("hunter", true)
	var shadows = GameState.get_characters_by_faction("shadow", true)
	var neutrals = GameState.get_characters_by_faction("neutral", true)

	# Verify all factions are represented
	assert_gt(hunters.size(), 0, "Should have at least one hunter")
	assert_gt(shadows.size(), 0, "Should have at least one shadow")
	assert_gt(neutrals.size(), 0, "Should have at least one neutral")

	# Verify total equals 20
	var total = hunters.size() + shadows.size() + neutrals.size()
	assert_eq(total, 20, "Total characters across factions should be 20")

	# Verify each character has correct faction
	for char_data in hunters:
		assert_eq(char_data.get("faction", ""), "hunter", "Hunter faction character should have faction = 'hunter'")

	for char_data in shadows:
		assert_eq(char_data.get("faction", ""), "shadow", "Shadow faction character should have faction = 'shadow'")

	for char_data in neutrals:
		assert_eq(char_data.get("faction", ""), "neutral", "Neutral faction character should have faction = 'neutral'")


## Test faction filtering with expansion exclusion
func test_faction_filtering_no_expansion():
	var hunters_base = GameState.get_characters_by_faction("hunter", false)
	var shadows_base = GameState.get_characters_by_faction("shadow", false)
	var neutrals_base = GameState.get_characters_by_faction("neutral", false)

	# Verify all returned characters are base game
	for char_data in hunters_base:
		assert_false(char_data.get("is_expansion", false), "Base-only hunter should have is_expansion = false")

	for char_data in shadows_base:
		assert_false(char_data.get("is_expansion", false), "Base-only shadow should have is_expansion = false")

	for char_data in neutrals_base:
		assert_false(char_data.get("is_expansion", false), "Base-only neutral should have is_expansion = false")


## Test defensive copies prevent mutation
func test_defensive_copies():
	var char1 = GameState.get_character("alice")
	var original_name = char1.get("name", "")

	# Mutate the returned dictionary
	char1["name"] = "MUTATED"

	# Get the character again
	var char2 = GameState.get_character("alice")

	# Verify original data is unchanged
	assert_eq(char2.get("name", ""), original_name, "Character data should not be mutated")
	assert_ne(char2.get("name", ""), "MUTATED", "Mutation should not persist")


## Test invalid character ID handling
func test_invalid_character_id():
	var invalid_char = GameState.get_character("nonexistent_character_id")

	# Should return empty dictionary
	assert_eq(invalid_char.size(), 0, "Invalid character ID should return empty dictionary")


## Test integration with CharacterDistributor
func test_character_distributor_integration():
	# Create mock players
	var players = []
	for i in range(4):
		var player = Player.new(i, "Player %d" % i, true)
		players.append(player)

	# Distribute characters (4 players, base game only)
	CharacterDistributor.distribute_characters(players, 4, false)

	# Verify each player has a character assigned
	for player in players:
		assert_ne(player.character_id, "", "Player should have character_id assigned")
		assert_ne(player.character_name, "", "Player should have character_name assigned")
		assert_ne(player.faction, "", "Player should have faction assigned")
		assert_gt(player.hp_max, 0, "Player should have hp_max > 0")
		assert_eq(player.hp, player.hp_max, "Player HP should equal hp_max initially")
		assert_false(player.ability_data.is_empty(), "Player should have ability_data")


## Test Player ability_data storage
func test_player_ability_data():
	var char_data = GameState.get_character("alice")
	if char_data.is_empty():
		fail_test("Could not load alice character for testing")
		return

	var player = Player.new(1, "Test Player", true)
	player.assign_character(char_data)

	# Verify ability data is stored
	assert_false(player.ability_data.is_empty(), "Player should have ability_data after assignment")
	assert_has(player.ability_data, "name", "Ability data should have 'name' field")
	assert_has(player.ability_data, "type", "Ability data should have 'type' field")
	assert_has(player.ability_data, "trigger", "Ability data should have 'trigger' field")


## Test Player serialization with ability_data
func test_player_serialization():
	var char_data = GameState.get_character("alice")
	if char_data.is_empty():
		fail_test("Could not load alice character for testing")
		return

	# Create and assign character
	var player1 = Player.new(1, "Test Player", true)
	player1.assign_character(char_data)

	# Serialize
	var serialized = player1.to_dict()

	# Verify ability_data is in serialized output
	assert_has(serialized, "ability_data", "Serialized player should have 'ability_data' field")

	# Deserialize
	var player2 = Player.from_dict(serialized)

	# Verify ability_data is restored
	assert_false(player2.ability_data.is_empty(), "Deserialized player should have ability_data")
	assert_eq(player2.ability_data.get("name", ""), player1.ability_data.get("name", ""), "Ability name should match after deserialization")


## Test performance - loading characters should be fast
func test_loading_performance():
	var start_time = Time.get_ticks_usec()

	# Get all characters 100 times
	for i in range(100):
		var chars = GameState.get_all_characters()

	var end_time = Time.get_ticks_usec()
	var elapsed_ms = (end_time - start_time) / 1000.0

	# Should complete in under 100ms
	assert_lt(elapsed_ms, 100.0, "Loading characters 100 times should take < 100ms")

	print("[Test] Performance: 100 loads in %.2f ms" % elapsed_ms)
