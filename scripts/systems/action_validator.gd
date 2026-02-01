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
		return {"valid": false, "reason": "Peut seulement lancer les dés pendant la phase Mouvement"}

	# Check if dice already rolled this turn (tracked in GameBoard)
	if game_board.has_rolled_this_turn:
		return {"valid": false, "reason": "Dés déjà lancés ce tour"}

	return {"valid": true, "reason": ""}


## Validate if player can draw a card
## Returns: Dictionary with {"valid": bool, "reason": String}
func can_draw_card(game_board) -> Dictionary:
	# Check if in ACTION phase
	if GameState.current_phase != GameState.TurnPhase.ACTION:
		return {"valid": false, "reason": "Peut seulement piocher pendant la phase Action"}

	# Check if already drawn this turn
	if game_board.has_drawn_this_turn:
		return {"valid": false, "reason": "Carte déjà piochée ce tour"}

	# Get current player
	var current_player = GameState.get_current_player()
	if current_player == null:
		return {"valid": false, "reason": "Aucun joueur actif"}

	# Check if zone has a deck
	var zone_id = current_player.position_zone
	var deck = GameState.get_deck_for_zone(zone_id)
	if deck == null:
		return {"valid": false, "reason": "Aucun deck disponible dans cette zone"}

	# Check if deck has cards available
	if deck.get_card_count() == 0:
		return {"valid": false, "reason": "Le deck est vide"}

	return {"valid": true, "reason": ""}


## Validate if player can attack
## Returns: Dictionary with {"valid": bool, "reason": String}
func can_attack(game_board) -> Dictionary:
	# Check if in ACTION phase
	if GameState.current_phase != GameState.TurnPhase.ACTION:
		return {"valid": false, "reason": "Peut seulement attaquer pendant la phase Action"}

	# Check if valid targets exist
	var valid_targets = game_board.get_valid_targets()
	if valid_targets.is_empty():
		return {"valid": false, "reason": "Aucune cible valide à attaquer"}

	return {"valid": true, "reason": ""}


## Validate if player can move to a zone
## Returns: Dictionary with {"valid": bool, "reason": String}
func can_move(game_board, target_zone_id: String) -> Dictionary:
	# Check if in MOVEMENT phase
	if GameState.current_phase != GameState.TurnPhase.MOVEMENT:
		return {"valid": false, "reason": "Peut seulement se déplacer pendant la phase Mouvement"}

	# Check if dice have been rolled
	if not game_board.has_rolled_this_turn:
		return {"valid": false, "reason": "Les dés doivent être lancés avant de se déplacer"}

	# Check if target zone is reachable
	var current_player = GameState.get_current_player()
	if current_player == null:
		return {"valid": false, "reason": "Aucun joueur actif"}

	var current_zone = current_player.position_zone
	var dice_sum = game_board.last_dice_sum

	# Get reachable zones
	var reachable_zones = ZoneData.get_reachable_zones(current_zone, dice_sum)

	if not reachable_zones.has(target_zone_id):
		return {"valid": false, "reason": "Zone trop éloignée (distance: %d)" % dice_sum}

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
		"move":
			if extra_param == null:
				return {"valid": false, "reason": "Zone cible manquante"}
			return can_move(game_board, extra_param)
		"end_turn":
			return can_end_turn()
		_:
			push_warning("[ActionValidator] Unknown action: %s" % action_name)
			return {"valid": false, "reason": "Action inconnue: %s" % action_name}
