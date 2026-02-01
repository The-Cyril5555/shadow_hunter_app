## Test: Turn Management & Action Validation
## Tests for Story 1.8 - Turn Management & Action Validation
extends GutTest


# =============================================================================
# TEST SETUP
# =============================================================================

var validator: ActionValidator
var mock_game_board

func before_each():
	validator = ActionValidator.new()
	mock_game_board = MockGameBoard.new()

	# Setup GameState for tests
	GameState.players = [
		create_mock_player("Player1", true),
		create_mock_player("Player2", true),
		create_mock_player("Player3", false),  # Dead player
		create_mock_player("Player4", true)
	]
	GameState.current_player_index = 0
	GameState.turn_count = 1
	GameState.current_phase = GameState.TurnPhase.MOVEMENT


func create_mock_player(display_name: String, is_alive: bool):
	var player = autofree(Player.new())
	player.display_name = display_name
	player.is_alive = is_alive
	player.position_zone = "hermit"
	player.hp = 10 if is_alive else 0
	player.hp_max = 10
	player.faction = "Hunter"
	return player


# =============================================================================
# ACTION VALIDATION TESTS
# =============================================================================

func test_can_roll_dice_in_movement_phase():
	# GIVEN: MOVEMENT phase, dice not rolled
	GameState.current_phase = GameState.TurnPhase.MOVEMENT
	mock_game_board.has_rolled_this_turn = false

	# WHEN: Validate roll dice
	var result = validator.can_roll_dice(mock_game_board)

	# THEN: Should be valid
	assert_true(result.valid, "Should allow rolling dice in MOVEMENT phase")


func test_cannot_roll_dice_in_action_phase():
	# GIVEN: ACTION phase
	GameState.current_phase = GameState.TurnPhase.ACTION
	mock_game_board.has_rolled_this_turn = false

	# WHEN: Validate roll dice
	var result = validator.can_roll_dice(mock_game_board)

	# THEN: Should be invalid
	assert_false(result.valid, "Should not allow rolling dice in ACTION phase")
	assert_string_contains(result.reason.to_lower(), "mouvement", "Should mention phase restriction")


func test_cannot_roll_dice_twice():
	# GIVEN: MOVEMENT phase, dice already rolled
	GameState.current_phase = GameState.TurnPhase.MOVEMENT
	mock_game_board.has_rolled_this_turn = true

	# WHEN: Validate roll dice
	var result = validator.can_roll_dice(mock_game_board)

	# THEN: Should be invalid
	assert_false(result.valid, "Should not allow rolling dice twice")
	assert_string_contains(result.reason.to_lower(), "déjà", "Should mention already rolled")


func test_can_draw_card_in_action_phase():
	# GIVEN: ACTION phase, not drawn yet, deck available
	GameState.current_phase = GameState.TurnPhase.ACTION
	mock_game_board.has_drawn_this_turn = false
	setup_mock_deck("hermit", 10)

	# WHEN: Validate draw card
	var result = validator.can_draw_card(mock_game_board)

	# THEN: Should be valid
	assert_true(result.valid, "Should allow drawing card in ACTION phase")


func test_cannot_draw_card_in_movement_phase():
	# GIVEN: MOVEMENT phase
	GameState.current_phase = GameState.TurnPhase.MOVEMENT
	mock_game_board.has_drawn_this_turn = false

	# WHEN: Validate draw card
	var result = validator.can_draw_card(mock_game_board)

	# THEN: Should be invalid
	assert_false(result.valid, "Should not allow drawing card in MOVEMENT phase")


func test_cannot_draw_card_twice():
	# GIVEN: ACTION phase, already drawn
	GameState.current_phase = GameState.TurnPhase.ACTION
	mock_game_board.has_drawn_this_turn = true

	# WHEN: Validate draw card
	var result = validator.can_draw_card(mock_game_board)

	# THEN: Should be invalid
	assert_false(result.valid, "Should not allow drawing twice")


func test_can_attack_in_action_phase():
	# GIVEN: ACTION phase, valid targets exist
	GameState.current_phase = GameState.TurnPhase.ACTION
	mock_game_board.mock_valid_targets = [GameState.players[1]]

	# WHEN: Validate attack
	var result = validator.can_attack(mock_game_board)

	# THEN: Should be valid
	assert_true(result.valid, "Should allow attack in ACTION phase with targets")


func test_cannot_attack_without_targets():
	# GIVEN: ACTION phase, no valid targets
	GameState.current_phase = GameState.TurnPhase.ACTION
	mock_game_board.mock_valid_targets = []

	# WHEN: Validate attack
	var result = validator.can_attack(mock_game_board)

	# THEN: Should be invalid
	assert_false(result.valid, "Should not allow attack without targets")


func test_end_turn_always_allowed():
	# GIVEN: Any phase
	for phase in [GameState.TurnPhase.MOVEMENT, GameState.TurnPhase.ACTION, GameState.TurnPhase.END]:
		GameState.current_phase = phase

		# WHEN: Validate end turn
		var result = validator.can_end_turn()

		# THEN: Should always be valid
		assert_true(result.valid, "End turn should be allowed in any phase")


# =============================================================================
# DEAD PLAYER SKIP TESTS
# =============================================================================

func test_advance_phase_skips_dead_players():
	# GIVEN: Current player index 2 (dead), next player index 3 (alive)
	GameState.current_player_index = 2
	GameState.current_phase = GameState.TurnPhase.END
	var initial_turn = GameState.turn_count

	# WHEN: Advance phase from END
	GameState.advance_phase()

	# THEN: Should skip dead player and move to next alive player
	assert_eq(GameState.current_player_index, 3, "Should skip dead player (index 2) to alive player (index 3)")
	assert_eq(GameState.current_phase, GameState.TurnPhase.MOVEMENT, "Should reset to MOVEMENT phase")


func test_advance_phase_wraps_around_and_increments_turn():
	# GIVEN: Last player's turn ending
	GameState.current_player_index = 3
	GameState.current_phase = GameState.TurnPhase.END
	var initial_turn = GameState.turn_count

	# WHEN: Advance phase from END
	GameState.advance_phase()

	# THEN: Should wrap to first player and increment turn
	assert_eq(GameState.current_player_index, 0, "Should wrap to first player")
	assert_eq(GameState.turn_count, initial_turn + 1, "Should increment turn count")


func test_advance_phase_skips_multiple_dead_players():
	# GIVEN: Multiple dead players in sequence
	GameState.players[0].is_alive = false
	GameState.players[1].is_alive = false
	GameState.players[2].is_alive = false
	GameState.current_player_index = 3
	GameState.current_phase = GameState.TurnPhase.END

	# WHEN: Advance phase from END
	GameState.advance_phase()

	# THEN: Should skip all dead players and wrap to first alive (index 3)
	assert_eq(GameState.current_player_index, 3, "Should skip all dead players")

	# Cleanup
	GameState.players[0].is_alive = true
	GameState.players[1].is_alive = true


# =============================================================================
# PHASE TRANSITION TESTS
# =============================================================================

func test_phase_transition_movement_to_action():
	# GIVEN: MOVEMENT phase
	GameState.current_phase = GameState.TurnPhase.MOVEMENT

	# WHEN: Advance phase
	GameState.advance_phase()

	# THEN: Should move to ACTION
	assert_eq(GameState.current_phase, GameState.TurnPhase.ACTION, "Should advance MOVEMENT → ACTION")


func test_phase_transition_action_to_end():
	# GIVEN: ACTION phase
	GameState.current_phase = GameState.TurnPhase.ACTION

	# WHEN: Advance phase
	GameState.advance_phase()

	# THEN: Should move to END
	assert_eq(GameState.current_phase, GameState.TurnPhase.END, "Should advance ACTION → END")


func test_phase_transition_end_to_movement_next_player():
	# GIVEN: END phase
	GameState.current_phase = GameState.TurnPhase.END
	var initial_player_index = GameState.current_player_index

	# WHEN: Advance phase
	GameState.advance_phase()

	# THEN: Should move to MOVEMENT and next player
	assert_eq(GameState.current_phase, GameState.TurnPhase.MOVEMENT, "Should advance END → MOVEMENT")
	assert_ne(GameState.current_player_index, initial_player_index, "Should move to next player")


# =============================================================================
# HELPER METHODS
# =============================================================================

func setup_mock_deck(zone_id: String, card_count: int):
	var deck = DeckManager.new()
	deck.deck_type = zone_id
	# Add mock cards
	for i in range(card_count):
		var card = Card.new()
		card.name = "TestCard%d" % i
		deck.draw_pile.append(card)

	# Assign to GameState
	match zone_id:
		"hermit":
			GameState.hermit_deck = deck
		"church":
			GameState.white_deck = deck
		"cemetery":
			GameState.black_deck = deck


# =============================================================================
# MOCK CLASSES
# =============================================================================

class MockGameBoard:
	var has_drawn_this_turn: bool = false
	var has_rolled_this_turn: bool = false
	var last_dice_sum: int = 0
	var mock_valid_targets: Array = []

	func get_valid_targets() -> Array:
		return mock_valid_targets
