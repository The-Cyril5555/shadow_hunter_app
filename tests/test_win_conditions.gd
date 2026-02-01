## Test: Win Condition Detection
## Tests for Story 1.9 - Win Condition Detection
extends GutTest


# =============================================================================
# TEST SETUP
# =============================================================================

var win_checker: WinConditionChecker

func before_each():
	win_checker = WinConditionChecker.new()

	# Setup GameState with test players
	GameState.players = [
		create_mock_player("Hunter1", "Hunter", true),
		create_mock_player("Hunter2", "Hunter", true),
		create_mock_player("Shadow1", "Shadow", true),
		create_mock_player("Shadow2", "Shadow", true),
		create_mock_player("Neutral1", "Neutral", true)
	]


func create_mock_player(display_name: String, faction: String, is_alive: bool):
	var player = autofree(Player.new())
	player.display_name = display_name
	player.faction = faction
	player.is_alive = is_alive
	player.hp = 10 if is_alive else 0
	player.hp_max = 10
	player.character_name = "Test %s" % faction
	player.character_id = display_name.to_lower()
	return player


# =============================================================================
# HUNTER VICTORY TESTS
# =============================================================================

func test_hunter_victory_when_all_shadows_dead():
	# GIVEN: All Shadows dead, Hunters alive
	GameState.players[2].is_alive = false  # Shadow1 dead
	GameState.players[3].is_alive = false  # Shadow2 dead

	# WHEN: Check win conditions
	var result = win_checker.check_win_conditions()

	# THEN: Hunters should win
	assert_true(result.has_winner, "Should have a winner")
	assert_eq(result.winning_faction, "Hunter", "Hunters should win")
	assert_eq(result.winning_players.size(), 2, "Should have 2 winning Hunters")
	assert_true(result.game_over, "Game should be over")


func test_hunter_victory_requires_at_least_one_hunter_alive():
	# GIVEN: All Shadows dead, but ALL players dead
	for player in GameState.players:
		player.is_alive = false

	# WHEN: Check win conditions
	var result = win_checker.check_win_conditions()

	# THEN: No winner (all dead)
	assert_false(result.has_winner, "Should have no winner if all dead")
	assert_eq(result.winning_faction, "", "No faction should win")


# =============================================================================
# SHADOW VICTORY TESTS
# =============================================================================

func test_shadow_victory_when_all_hunters_dead():
	# GIVEN: All Hunters dead, Shadows alive
	GameState.players[0].is_alive = false  # Hunter1 dead
	GameState.players[1].is_alive = false  # Hunter2 dead

	# WHEN: Check win conditions
	var result = win_checker.check_win_conditions()

	# THEN: Shadows should win
	assert_true(result.has_winner, "Should have a winner")
	assert_eq(result.winning_faction, "Shadow", "Shadows should win")
	assert_eq(result.winning_players.size(), 2, "Should have 2 winning Shadows")
	assert_true(result.game_over, "Game should be over")


func test_shadow_victory_requires_at_least_one_shadow_alive():
	# GIVEN: All Hunters dead, but Shadows also dead
	GameState.players[0].is_alive = false  # Hunter1 dead
	GameState.players[1].is_alive = false  # Hunter2 dead
	GameState.players[2].is_alive = false  # Shadow1 dead
	GameState.players[3].is_alive = false  # Shadow2 dead

	# WHEN: Check win conditions
	var result = win_checker.check_win_conditions()

	# THEN: No faction winner
	assert_false(result.game_over, "Game should not be over if both factions dead")


# =============================================================================
# NEUTRAL VICTORY TESTS
# =============================================================================

func test_neutral_wins_if_alive_when_faction_wins():
	# GIVEN: Hunters win, Neutral alive
	GameState.players[2].is_alive = false  # Shadow1 dead
	GameState.players[3].is_alive = false  # Shadow2 dead
	GameState.players[4].is_alive = true   # Neutral alive

	# WHEN: Check win conditions
	var result = win_checker.check_win_conditions()

	# THEN: Both Hunters AND Neutral should win
	assert_true(result.has_winner, "Should have a winner")
	assert_eq(result.winning_faction, "Hunter", "Hunter faction should win")
	assert_eq(result.winning_players.size(), 3, "Should have 2 Hunters + 1 Neutral")

	# Check Neutral is in winners
	var neutral_won = false
	for player in result.winning_players:
		if player.faction == "Neutral":
			neutral_won = true
			break
	assert_true(neutral_won, "Neutral should be in winners list")


func test_neutral_does_not_win_if_dead():
	# GIVEN: Hunters win, Neutral dead
	GameState.players[2].is_alive = false  # Shadow1 dead
	GameState.players[3].is_alive = false  # Shadow2 dead
	GameState.players[4].is_alive = false  # Neutral dead

	# WHEN: Check win conditions
	var result = win_checker.check_win_conditions()

	# THEN: Only Hunters win, not Neutral
	assert_true(result.has_winner, "Should have a winner")
	assert_eq(result.winning_faction, "Hunter", "Hunter faction should win")
	assert_eq(result.winning_players.size(), 2, "Should have only 2 Hunters")


# =============================================================================
# HELPER METHOD TESTS
# =============================================================================

func test_get_alive_players_by_faction_hunters():
	# GIVEN: 2 Hunters, 1 alive, 1 dead
	GameState.players[0].is_alive = true
	GameState.players[1].is_alive = false

	# WHEN: Get alive Hunters
	var alive_hunters = win_checker.get_alive_players_by_faction("Hunter")

	# THEN: Should return 1 Hunter
	assert_eq(alive_hunters.size(), 1, "Should have 1 alive Hunter")
	assert_eq(alive_hunters[0].display_name, "Hunter1", "Should be Hunter1")


func test_get_alive_players_by_faction_shadows():
	# GIVEN: 2 Shadows, both alive
	GameState.players[2].is_alive = true
	GameState.players[3].is_alive = true

	# WHEN: Get alive Shadows
	var alive_shadows = win_checker.get_alive_players_by_faction("Shadow")

	# THEN: Should return 2 Shadows
	assert_eq(alive_shadows.size(), 2, "Should have 2 alive Shadows")


func test_get_alive_players_by_faction_empty():
	# GIVEN: All Shadows dead
	GameState.players[2].is_alive = false
	GameState.players[3].is_alive = false

	# WHEN: Get alive Shadows
	var alive_shadows = win_checker.get_alive_players_by_faction("Shadow")

	# THEN: Should return empty array
	assert_true(alive_shadows.is_empty(), "Should have no alive Shadows")


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_no_winner_if_both_factions_have_alive_players():
	# GIVEN: Both factions have alive players
	for player in GameState.players:
		player.is_alive = true

	# WHEN: Check win conditions
	var result = win_checker.check_win_conditions()

	# THEN: No winner yet
	assert_false(result.game_over, "Game should not be over")
	assert_eq(result.winning_faction, "", "No faction should win yet")


func test_faction_status_helper():
	# GIVEN: Mixed alive/dead players
	GameState.players[0].is_alive = true   # Hunter1
	GameState.players[1].is_alive = false  # Hunter2 dead
	GameState.players[2].is_alive = true   # Shadow1
	GameState.players[3].is_alive = true   # Shadow2
	GameState.players[4].is_alive = true   # Neutral1

	# WHEN: Get faction status
	var status = win_checker.get_faction_status()

	# THEN: Should return correct counts
	assert_eq(status.alive_hunters, 1, "Should have 1 alive Hunter")
	assert_eq(status.alive_shadows, 2, "Should have 2 alive Shadows")
	assert_eq(status.alive_neutrals, 1, "Should have 1 alive Neutral")


# =============================================================================
# INTEGRATION TESTS (with GameState signals)
# =============================================================================

func test_win_check_triggered_on_player_death():
	# GIVEN: Hunter kills last Shadow
	var shadow2 = GameState.players[3]
	GameState.players[2].is_alive = false  # Shadow1 already dead

	# Setup signal watchers
	watch_signals(GameState)

	# WHEN: Last Shadow dies (trigger player_died signal)
	shadow2.is_alive = false
	GameState.player_died.emit(shadow2, GameState.players[0])

	# Wait for signal processing
	await get_tree().create_timer(0.1).timeout

	# THEN: win_condition_met and game_over signals should be emitted
	assert_signal_emitted(GameState, "win_condition_met", "Should emit win_condition_met")
	assert_signal_emitted(GameState, "game_over", "Should emit game_over")
