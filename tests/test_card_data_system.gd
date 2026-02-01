## Test: Card Data System
## Tests card loading from JSON, validation, and retrieval methods
extends Node

# Test configuration
var test_results: Array[Dictionary] = []
var tests_passed: int = 0
var tests_failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("CARD DATA SYSTEM TESTS")
	print("=".repeat(60) + "\n")

	# Run all tests
	test_cards_loaded()
	test_get_card_by_id()
	test_get_cards_by_deck_hermit()
	test_get_cards_by_deck_white()
	test_get_cards_by_deck_black()
	test_get_cards_by_type_equipment()
	test_get_cards_by_type_instant()
	test_get_cards_by_type_vision()
	test_defensive_copy()
	test_invalid_card_id()
	test_card_entity_creation()

	# Print summary
	print_summary()

	# Exit after short delay
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func test_cards_loaded() -> void:
	var test_name = "Cards should be loaded from JSON"
	var cards_count = GameState.cards_data.size()

	if cards_count > 0:
		record_pass(test_name, "Loaded %d cards" % cards_count)
	else:
		record_fail(test_name, "No cards loaded, expected > 0")


func test_get_card_by_id() -> void:
	var test_name = "get_card_data() should return correct card"
	var card = GameState.get_card_data("hermit_vision_1")

	if card.is_empty():
		record_fail(test_name, "Card 'hermit_vision_1' not found")
		return

	if card.get("id") == "hermit_vision_1" and card.get("deck") == "hermit":
		record_pass(test_name, "Card data correct: %s (deck: %s)" % [card.get("name"), card.get("deck")])
	else:
		record_fail(test_name, "Card data incorrect")


func test_get_cards_by_deck_hermit() -> void:
	var test_name = "get_cards_by_deck('hermit') should return hermit cards"
	var hermit_cards = GameState.get_cards_by_deck("hermit")

	if hermit_cards.size() == 0:
		record_fail(test_name, "No hermit cards returned")
		return

	var all_hermit = true
	for card in hermit_cards:
		if card.get("deck") != "hermit":
			all_hermit = false
			break

	if all_hermit:
		record_pass(test_name, "Found %d hermit cards, all valid" % hermit_cards.size())
	else:
		record_fail(test_name, "Non-hermit cards in result")


func test_get_cards_by_deck_white() -> void:
	var test_name = "get_cards_by_deck('white') should return white cards"
	var white_cards = GameState.get_cards_by_deck("white")

	if white_cards.size() == 0:
		record_fail(test_name, "No white cards returned")
		return

	var all_white = true
	for card in white_cards:
		if card.get("deck") != "white":
			all_white = false
			break

	if all_white:
		record_pass(test_name, "Found %d white cards, all valid" % white_cards.size())
	else:
		record_fail(test_name, "Non-white cards in result")


func test_get_cards_by_deck_black() -> void:
	var test_name = "get_cards_by_deck('black') should return black cards"
	var black_cards = GameState.get_cards_by_deck("black")

	if black_cards.size() == 0:
		record_fail(test_name, "No black cards returned")
		return

	var all_black = true
	for card in black_cards:
		if card.get("deck") != "black":
			all_black = false
			break

	if all_black:
		record_pass(test_name, "Found %d black cards, all valid" % black_cards.size())
	else:
		record_fail(test_name, "Non-black cards in result")


func test_get_cards_by_type_equipment() -> void:
	var test_name = "get_cards_by_type('equipment') should return equipment cards"
	var equipment_cards = GameState.get_cards_by_type("equipment")

	var all_equipment = true
	for card in equipment_cards:
		if card.get("type") != "equipment":
			all_equipment = false
			break

	if equipment_cards.size() > 0 and all_equipment:
		record_pass(test_name, "Found %d equipment cards, all valid" % equipment_cards.size())
	else:
		record_fail(test_name, "No equipment cards or invalid types")


func test_get_cards_by_type_instant() -> void:
	var test_name = "get_cards_by_type('instant') should return instant cards"
	var instant_cards = GameState.get_cards_by_type("instant")

	var all_instant = true
	for card in instant_cards:
		if card.get("type") != "instant":
			all_instant = false
			break

	if instant_cards.size() > 0 and all_instant:
		record_pass(test_name, "Found %d instant cards, all valid" % instant_cards.size())
	else:
		record_fail(test_name, "No instant cards or invalid types")


func test_get_cards_by_type_vision() -> void:
	var test_name = "get_cards_by_type('vision') should return vision cards"
	var vision_cards = GameState.get_cards_by_type("vision")

	var all_vision = true
	for card in vision_cards:
		if card.get("type") != "vision":
			all_vision = false
			break

	if vision_cards.size() > 0 and all_vision:
		record_pass(test_name, "Found %d vision cards, all valid" % vision_cards.size())
	else:
		record_fail(test_name, "No vision cards or invalid types")


func test_defensive_copy() -> void:
	var test_name = "get_card_data() should return defensive copy"
	var card = GameState.get_card_data("white_heal_1")

	if card.is_empty():
		record_fail(test_name, "Card 'white_heal_1' not found")
		return

	var original_name = card.get("name", "")
	card["name"] = "MODIFIED"

	var card2 = GameState.get_card_data("white_heal_1")
	var name2 = card2.get("name", "")

	if name2 != "MODIFIED" and name2 == original_name:
		record_pass(test_name, "Defensive copy working - original unchanged")
	else:
		record_fail(test_name, "Original card was mutated! name2=%s" % name2)


func test_invalid_card_id() -> void:
	var test_name = "get_card_data() should return empty dict for invalid ID"
	var card = GameState.get_card_data("nonexistent_card_xyz")

	if card.is_empty():
		record_pass(test_name, "Empty dict returned for invalid ID")
	else:
		record_fail(test_name, "Should return empty dict, got: %s" % card)


func test_card_entity_creation() -> void:
	var test_name = "Card entity should instantiate from card_data"
	var card_data = GameState.get_card_data("black_damage_1")

	if card_data.is_empty():
		record_fail(test_name, "Card 'black_damage_1' not found")
		return

	var card = Card.new()
	card.from_dict(card_data)

	if card.id == "black_damage_1" and card.deck == "black" and card.type == "instant":
		record_pass(test_name, "Card entity created: %s (%s, %s)" % [card.name, card.deck, card.type])
	else:
		record_fail(test_name, "Card entity has incorrect properties")


func record_pass(test_name: String, details: String = "") -> void:
	tests_passed += 1
	test_results.append({"name": test_name, "status": "PASS", "details": details})
	print("[PASS] %s" % test_name)
	if details != "":
		print("       %s" % details)


func record_fail(test_name: String, reason: String = "") -> void:
	tests_failed += 1
	test_results.append({"name": test_name, "status": "FAIL", "reason": reason})
	print("[FAIL] %s" % test_name)
	if reason != "":
		print("       Reason: %s" % reason)


func print_summary() -> void:
	print("\n" + "=".repeat(60))
	print("TEST SUMMARY")
	print("=".repeat(60))
	print("Total: %d | Passed: %d | Failed: %d" % [tests_passed + tests_failed, tests_passed, tests_failed])

	if tests_failed == 0:
		print("\n✓ ALL TESTS PASSED!")
	else:
		print("\n✗ SOME TESTS FAILED")

	print("=".repeat(60) + "\n")
