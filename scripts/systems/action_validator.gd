## ActionValidator - Validation system for game actions
## Validates player actions against game rules to prevent invalid moves.
## Pattern: Utility class (RefCounted) - stateless validation logic
class_name ActionValidator
extends RefCounted


# =============================================================================
# VALIDATION METHODS
# =============================================================================

## Validate if player can roll dice
## Returns: Dictionary with {"valid": bool, "reason": String}
func can_roll_dice(game_board) -> Dictionary:
	# Check if in MOVEMENT phase
	if GameState.current_phase != GameState.TurnPhase.MOVEMENT:
		return {"valid": false, "reason": Tr.t("validate.dice_phase")}

	# Check if dice already rolled this turn (tracked in GameBoard)
	if game_board.has_rolled_this_turn:
		return {"valid": false, "reason": Tr.t("validate.dice_used")}

	return {"valid": true, "reason": ""}


## Validate if player can draw a card
## Returns: Dictionary with {"valid": bool, "reason": String}
func can_draw_card(game_board) -> Dictionary:
	# Check if in ACTION phase
	if GameState.current_phase != GameState.TurnPhase.ACTION:
		return {"valid": false, "reason": Tr.t("validate.draw_phase")}

	# Check if already drawn this turn
	if game_board.has_drawn_this_turn:
		return {"valid": false, "reason": Tr.t("validate.draw_used")}

	# Get current player
	var current_player = GameState.get_current_player()
	if current_player == null:
		return {"valid": false, "reason": Tr.t("validate.no_player")}

	# Check if zone has a deck
	var zone_id = current_player.position_zone
	var deck = GameState.get_deck_for_zone(zone_id)
	if deck == null:
		return {"valid": false, "reason": Tr.t("validate.no_deck")}

	# Check if deck has cards available
	if deck.get_card_count() == 0:
		return {"valid": false, "reason": Tr.t("validate.deck_empty")}

	return {"valid": true, "reason": ""}


## Validate if player can attack
## Returns: Dictionary with {"valid": bool, "reason": String}
func can_attack(game_board) -> Dictionary:
	# Check if in ACTION phase
	if GameState.current_phase != GameState.TurnPhase.ACTION:
		return {"valid": false, "reason": Tr.t("validate.attack_phase")}

	# Check if valid targets exist
	var valid_targets = game_board.get_valid_targets()
	if valid_targets.is_empty():
		return {"valid": false, "reason": Tr.t("validate.no_target")}

	return {"valid": true, "reason": ""}


## Validate if player can end turn (always allowed)
## Returns: Dictionary with {"valid": bool, "reason": String}
func can_end_turn() -> Dictionary:
	# End turn is always allowed in any phase (allows passing)
	return {"valid": true, "reason": ""}


# =============================================================================
# HELPER METHODS
# =============================================================================

## Check if action is valid and return reason if not
## Generic wrapper for consistent error handling
func validate_action(action_name: String, game_board, extra_param = null) -> Dictionary:
	match action_name:
		"roll_dice":
			return can_roll_dice(game_board)
		"draw_card":
			return can_draw_card(game_board)
		"attack":
			return can_attack(game_board)
		"end_turn":
			return can_end_turn()
		_:
			push_warning("[ActionValidator] Unknown action: %s" % action_name)
			return {"valid": false, "reason": Tr.t("validate.unknown", [action_name])}
