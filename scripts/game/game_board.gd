## GameBoard - Main game board controller
## Manages the game board, zones, player displays, and game flow.
class_name GameBoard
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var zones_container: GridContainer = $MarginContainer/HBoxContainer/BoardArea/ZonesContainer
@onready var current_player_label: Label = $MarginContainer/HBoxContainer/LeftPanel/GameInfo/CurrentPlayerLabel
@onready var turn_label: Label = $MarginContainer/HBoxContainer/LeftPanel/GameInfo/TurnLabel
@onready var phase_label: Label = $MarginContainer/HBoxContainer/LeftPanel/GameInfo/PhaseLabel

# Deck count labels
@onready var hermit_count_label: Label = $MarginContainer/HBoxContainer/LeftPanel/DecksContainer/HermitDeck/CountLabel
@onready var white_count_label: Label = $MarginContainer/HBoxContainer/LeftPanel/DecksContainer/WhiteDeck/CountLabel
@onready var black_count_label: Label = $MarginContainer/HBoxContainer/LeftPanel/DecksContainer/BlackDeck/CountLabel

# Hand display
@onready var hand_cards_container: VBoxContainer = $MarginContainer/HBoxContainer/LeftPanel/HandCardsContainer

# Equipment display
@onready var equipment_container: VBoxContainer = $MarginContainer/HBoxContainer/LeftPanel/EquipmentContainer

# Dice components
@onready var dice: Dice = $MarginContainer/HBoxContainer/LeftPanel/DiceContainer/Dice
@onready var roll_dice_button: Button = $MarginContainer/HBoxContainer/LeftPanel/DiceContainer/RollDiceButton

# Action buttons
@onready var draw_card_button: Button = $MarginContainer/HBoxContainer/LeftPanel/ButtonContainer/DrawCardButton
@onready var attack_button: Button = $MarginContainer/HBoxContainer/LeftPanel/ButtonContainer/AttackButton

# UI overlays
@onready var card_reveal: CardReveal = $CardRevealLayer/CardReveal
@onready var equipment_action_menu: EquipmentActionMenu = $EquipmentMenuLayer/EquipmentActionMenu
@onready var target_selection_panel: TargetSelectionPanel = $TargetSelectionLayer/TargetSelectionPanel
@onready var error_message: ErrorMessage = $ErrorMessageLayer/ErrorMessage
@onready var end_turn_button: Button = $MarginContainer/HBoxContainer/LeftPanel/ButtonContainer/EndTurnButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var zones: Array = []  # Array of Zone instances
var last_dice_sum: int = 0  # Last dice roll result
var has_drawn_this_turn: bool = false  # Track if player has drawn a card this turn
var has_rolled_this_turn: bool = false  # Track if player has rolled dice this turn

## Action validator instance
var validator: ActionValidator = ActionValidator.new()

## Tutorial overlay (null if not in tutorial mode)
var tutorial: TutorialOverlay = null

## Feedback toast for multi-channel notifications
var toast: FeedbackToast = null


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	print("[GameBoard] Initializing game board")

	# Initialize game state
	GameState.turn_count = 1
	GameState.current_player_index = 0
	GameState.current_phase = GameState.TurnPhase.MOVEMENT
	GameState.game_in_progress = true

	# Initialize decks
	GameState.initialize_decks()

	# Initialize zones
	_initialize_zones()

	# Place player tokens in starting zones
	_place_player_tokens()

	# Update displays
	_update_display()
	_update_deck_displays()
	_update_hand_display()
	_update_equipment_display()

	# Connect to phase change signal
	GameState.phase_changed.connect(_on_phase_changed)

	# Connect to game over signal
	GameState.game_over.connect(_on_game_over)

	# Connect equipment menu signal
	equipment_action_menu.action_selected.connect(_on_equipment_action_selected)

	# Connect target selection signal
	target_selection_panel.target_selected.connect(_on_target_selected)

	# Add pause menu
	var pause_menu = PauseMenu.new()
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS  # Works even when paused
	add_child(pause_menu)

	# Reset auto-save counter for new game
	SaveManager.reset_action_counter()

	# Setup button tooltips
	_setup_tooltips()

	# Add help menu (F1)
	var help_menu = HelpMenu.new()
	add_child(help_menu)

	# Add feedback toast
	toast = FeedbackToast.new()
	add_child(toast)

	# Setup keyboard focus chain
	_setup_focus_chain()

	# Start tutorial if in tutorial mode
	if GameModeStateMachine.current_mode == GameModeStateMachine.GameMode.TUTORIAL:
		_start_tutorial()

	print("[GameBoard] Game started with %d players" % GameState.players.size())


# -----------------------------------------------------------------------------
# Zone System
# -----------------------------------------------------------------------------

## Initialize all 6 zones from ZoneData
func _initialize_zones() -> void:
	# Clear any existing zones
	for child in zones_container.get_children():
		child.queue_free()
	zones.clear()

	# Create zones from ZoneData configuration
	for zone_data in ZoneData.ZONES:
		var zone = preload("res://scenes/board/zone.tscn").instantiate()
		zones_container.add_child(zone)
		zone.setup(zone_data)
		zone.zone_clicked.connect(_on_zone_clicked)
		zones.append(zone)

	print("[GameBoard] Initialized %d zones" % zones.size())


## Place all player tokens in their starting zones
func _place_player_tokens() -> void:
	# All players start at Hermit's Cabin (first zone)
	var starting_zone = _get_zone_by_id("hermit")

	if starting_zone == null:
		push_error("[GameBoard] Starting zone 'hermit' not found")
		return

	for player in GameState.players:
		player.position_zone = "hermit"
		starting_zone.add_player_token(player)

	print("[GameBoard] Placed %d player tokens in starting zone" % GameState.players.size())


## Get zone by its ID
func _get_zone_by_id(zone_id: String) -> Zone:
	for zone in zones:
		if zone.zone_id == zone_id:
			return zone
	return null


## Highlight zones reachable with dice sum
func _highlight_reachable_zones(dice_sum: int) -> void:
	# Clear all highlights first
	_clear_zone_highlights()

	# Get current player's position
	var current_player = GameState.get_current_player()
	if current_player == null:
		return

	var current_zone_id = current_player.position_zone

	# Get reachable zones using BFS
	var reachable_zone_ids = ZoneData.get_reachable_zones(current_zone_id, dice_sum)

	# Highlight all reachable zones
	for zone_id in reachable_zone_ids:
		var zone = _get_zone_by_id(zone_id)
		if zone:
			zone.set_highlight(true)

	print("[GameBoard] Highlighted %d reachable zones from %s with distance %d" % [reachable_zone_ids.size(), current_zone_id, dice_sum])


## Clear all zone highlights
func _clear_zone_highlights() -> void:
	for zone in zones:
		zone.set_highlight(false)


## Move player token from current zone to target zone with animation
func _move_player_to_zone(player: Player, target_zone: Zone) -> void:
	# Get current zone
	var current_zone = _get_zone_by_id(player.position_zone)
	if current_zone == null:
		push_error("[GameBoard] Current zone not found for player %s" % player.display_name)
		return

	# Find the player token in current zone
	var token = null
	for child in current_zone.token_container.get_children():
		if child.has_method("get_player") and child.get_player() == player:
			token = child
			break

	if token == null:
		push_error("[GameBoard] Token not found for player %s" % player.display_name)
		return

	# Get positions for animation
	var start_pos = token.global_position
	var end_pos = target_zone.token_container.global_position

	# Disable input during animation
	set_process_input(false)

	# Play movement sound
	AudioManager.play_sfx("move_player")

	# Create smooth movement tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(token, "global_position", end_pos, 0.6)

	# Optional: Add bounce at end
	tween.tween_property(token, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(token, "scale", Vector2(1.0, 1.0), 0.1)

	await tween.finished

	# Reparent token to target zone
	current_zone.remove_player_token(player)
	target_zone.add_player_token(player)

	# Update player's position
	player.position_zone = target_zone.zone_id

	# Clear highlights after movement
	_clear_zone_highlights()

	# Re-enable input
	set_process_input(true)

	if toast:
		toast.show_toast("%s se déplace vers %s" % [player.display_name, target_zone.zone_name], Color(0.7, 0.8, 1.0))
	print("[GameBoard] Moved %s from %s to %s" % [player.display_name, current_zone.zone_name, target_zone.zone_name])

	# Notify tutorial
	_notify_tutorial("move_to_zone")

	# Advance to ACTION phase after movement completes
	GameState.advance_phase()


# -----------------------------------------------------------------------------
# Display Updates
# -----------------------------------------------------------------------------

## Update current player and turn display
func _update_display() -> void:
	var current_player = GameState.get_current_player()
	if current_player:
		current_player_label.text = "Current: %s" % current_player.display_name
	turn_label.text = "Turn: %d" % GameState.turn_count
	_update_phase_display()


## Update phase display
func _update_phase_display() -> void:
	var phase_text = ""
	match GameState.current_phase:
		GameState.TurnPhase.MOVEMENT:
			phase_text = "Phase: Movement"
		GameState.TurnPhase.ACTION:
			phase_text = "Phase: Action"
		GameState.TurnPhase.END:
			phase_text = "Phase: End Turn"

	phase_label.text = phase_text


## Update deck count displays
func _update_deck_displays() -> void:
	hermit_count_label.text = str(GameState.hermit_deck.get_card_count() if GameState.hermit_deck else 0)
	white_count_label.text = str(GameState.white_deck.get_card_count() if GameState.white_deck else 0)
	black_count_label.text = str(GameState.black_deck.get_card_count() if GameState.black_deck else 0)


## Update hand display for current player
func _update_hand_display() -> void:
	# Clear existing hand display
	for child in hand_cards_container.get_children():
		child.queue_free()

	# Get current player
	var current_player = GameState.get_current_player()
	if current_player == null:
		return

	# Display each card in hand as clickable buttons
	for card in current_player.hand:
		var button = Button.new()
		button.text = "• %s" % card.name
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, 1.0))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE

		# Store card reference in button metadata
		button.set_meta("card", card)

		# Connect click signal
		button.pressed.connect(_on_hand_card_clicked.bind(card))

		# Set tooltip with full card details
		button.tooltip_text = "%s\n\nType: %s\nDeck: %s\n\n%s" % [
			card.name,
			card.type.capitalize(),
			card.deck.capitalize(),
			card.get_effect_description()
		]

		hand_cards_container.add_child(button)

	print("[GameBoard] Hand display updated: %d cards" % current_player.hand.size())


## Update active equipment display for current player
func _update_equipment_display() -> void:
	# Clear existing equipment display
	for child in equipment_container.get_children():
		child.queue_free()

	# Get current player
	var current_player = GameState.get_current_player()
	if current_player == null:
		return

	# Show equipped items
	for card in current_player.equipment:
		var label = Label.new()
		label.text = "⚔ %s (+%d)" % [card.name, card.get_effect_value()]
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))  # Gold color
		equipment_container.add_child(label)

	# Show total bonus
	if current_player.equipment.size() > 0:
		var total_bonus = current_player.get_attack_damage_bonus()
		var total_label = Label.new()
		total_label.text = "Total: +%d damage" % total_bonus
		total_label.add_theme_font_size_override("font_size", 14)
		total_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))  # Green color
		equipment_container.add_child(total_label)

	print("[GameBoard] Equipment display updated: %d items" % current_player.equipment.size())


# -----------------------------------------------------------------------------
# Button Handlers
# -----------------------------------------------------------------------------

func _on_end_turn_pressed() -> void:
	# Validate end turn action (always valid)
	var validation = validator.can_end_turn()
	if not validation.valid:
		error_message.show_error(validation.reason)
		return

	var current_player = GameState.get_current_player()
	print("[GameBoard] %s ending turn" % current_player.display_name)

	# End turn can be used in any phase - advance to END phase, then to next player
	match GameState.current_phase:
		GameState.TurnPhase.MOVEMENT:
			GameState.advance_phase()  # MOVEMENT → ACTION
			GameState.advance_phase()  # ACTION → END
			GameState.advance_phase()  # END → MOVEMENT (next player)
		GameState.TurnPhase.ACTION:
			GameState.advance_phase()  # ACTION → END
			GameState.advance_phase()  # END → MOVEMENT (next player)
		GameState.TurnPhase.END:
			GameState.advance_phase()  # END → MOVEMENT (next player)

	# Reset turn flags
	has_drawn_this_turn = false
	has_rolled_this_turn = false

	# Update displays
	_update_display()
	_update_hand_display()
	_update_equipment_display()
	_update_action_hints()

	# Track action for auto-save
	SaveManager.track_action()

	var next_player = GameState.get_current_player()
	print("[GameBoard] Turn ended. Now: %s, Turn %d" % [next_player.display_name, GameState.turn_count])


func _on_back_to_menu_pressed() -> void:
	GameState.reset()
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


func _on_draw_card_pressed() -> void:
	# Validate draw card action
	var validation = validator.can_draw_card(self)
	if not validation.valid:
		error_message.show_error(validation.reason)
		return

	# Get current player
	var current_player = GameState.get_current_player()
	if current_player == null:
		push_error("[GameBoard] No current player found")
		return

	# Get current player's zone
	var zone_id = current_player.position_zone

	# Get deck for that zone
	var deck = GameState.get_deck_for_zone(zone_id)
	if deck == null:
		push_warning("[GameBoard] No deck available for zone: %s" % zone_id)
		return

	# Draw card from deck
	var card = deck.draw_card()
	if card == null:
		push_warning("[GameBoard] Failed to draw card from %s deck" % zone_id)
		return

	if toast:
		toast.show_toast("%s pioche : %s" % [current_player.display_name, card.name], Color(0.6, 1.0, 0.6))
	print("[GameBoard] %s drew card '%s' from %s deck" % [current_player.display_name, card.name, deck.deck_type])

	# Update deck displays
	_update_deck_displays()

	# Disable button during animation
	draw_card_button.disabled = true

	# Show card reveal animation
	card_reveal.show_card(card)
	await card_reveal.card_reveal_finished

	# Apply card effect based on type
	if card.type == "instant":
		# Apply instant effect immediately
		_apply_instant_card_effect(card, current_player)
		# Discard instant card
		deck.discard_card(card)
		_update_deck_displays()
	elif card.type == "equipment":
		# Add equipment card to player's hand
		current_player.hand.append(card)
		print("[GameBoard] Equipment card '%s' added to %s's hand" % [card.name, current_player.display_name])
		_update_hand_display()
	elif card.type == "vision":
		# TODO: Handle vision cards (Story 1.6+)
		print("[GameBoard] Vision card - handling (TODO)")

	# Mark as drawn this turn and disable button
	has_drawn_this_turn = true
	draw_card_button.disabled = true

	# Notify tutorial
	_notify_tutorial("draw_card")

	# Update action hints after draw
	_update_action_hints()

	# Track action for auto-save
	SaveManager.track_action()

	print("[GameBoard] Card draw complete. Button disabled for this turn.")


# -----------------------------------------------------------------------------
# Equipment Card Handlers
# -----------------------------------------------------------------------------

## Handle click on card in hand
func _on_hand_card_clicked(card: Card) -> void:
	# Get button global position for menu placement
	var button_position = get_viewport().get_mouse_position()

	# Show equipment action menu
	equipment_action_menu.show_for_card(card, button_position)
	print("[GameBoard] Card clicked: %s" % card.name)


## Handle equipment action selection (equip or discard)
func _on_equipment_action_selected(action: String, card: Card) -> void:
	var current_player = GameState.get_current_player()
	if current_player == null:
		push_error("[GameBoard] No current player found")
		return

	match action:
		"equip":
			_equip_card(current_player, card)
		"discard":
			_discard_card_from_hand(current_player, card)
		_:
			push_warning("[GameBoard] Unknown action: %s" % action)


## Equip a card from hand
func _equip_card(player: Player, card: Card) -> void:
	print("[GameBoard] Equipping %s for %s" % [card.name, player.display_name])

	# Equip the card (moves from hand to equipment)
	player.equip_card(card)

	# Emit signal
	GameState.equipment_equipped.emit(player, card)

	# Update displays
	_update_hand_display()
	_update_equipment_display()

	# Log action
	GameState.log_action("equipment_equipped", {
		"player": player.display_name,
		"card": card.name,
		"effect": card.get_effect_description()
	})

	print("[GameBoard] Equipment total damage bonus: +%d" % player.get_attack_damage_bonus())


## Discard a card from hand
func _discard_card_from_hand(player: Player, card: Card) -> void:
	print("[GameBoard] Discarding %s for %s" % [card.name, player.display_name])

	# Find appropriate deck by card.deck property
	var deck = GameState.get_deck_for_zone(card.deck)
	if deck == null:
		push_error("[GameBoard] Cannot find deck for card: %s (deck: %s)" % [card.name, card.deck])
		return

	# Remove card from hand
	var hand_idx = player.hand.find(card)
	if hand_idx >= 0:
		player.hand.remove_at(hand_idx)
	else:
		push_warning("[GameBoard] Card not found in hand: %s" % card.name)
		return

	# Add to deck's discard pile
	deck.discard_card(card)

	# Emit signal
	GameState.equipment_discarded.emit(player, card)

	# Update displays
	_update_hand_display()
	_update_deck_displays()

	# Log action
	GameState.log_action("card_discarded", {
		"player": player.display_name,
		"card": card.name,
		"deck": card.deck
	})

	print("[GameBoard] Card discarded to %s deck discard pile" % card.deck)


# -----------------------------------------------------------------------------
# Card Effect System
# -----------------------------------------------------------------------------

## Apply instant card effect to player
func _apply_instant_card_effect(card: Card, player: Player) -> void:
	var effect_type = card.get_effect_type()
	var effect_value = card.get_effect_value()

	print("[GameBoard] Applying instant effect: %s (value: %d) to %s" % [effect_type, effect_value, player.display_name])

	match effect_type:
		"heal":
			# Heal player
			var hp_before = player.hp
			player.heal(effect_value)
			var hp_gained = player.hp - hp_before
			print("[GameBoard] %s healed for %d HP (%d → %d)" % [player.display_name, hp_gained, hp_before, player.hp])

		"damage":
			# For now, apply damage to self (TODO: add target selection)
			var hp_before = player.hp
			var died = player.take_damage(effect_value)
			print("[GameBoard] %s took %d damage (%d → %d)" % [player.display_name, effect_value, hp_before, player.hp])

			# Emit damage signal
			GameState.damage_dealt.emit(player, player, effect_value)

			if died:
				print("[GameBoard] %s has died!" % player.display_name)
				GameState.player_died.emit(player, player)

		_:
			push_warning("[GameBoard] Unknown instant effect type: %s" % effect_type)

	# Log action
	GameState.log_action("card_effect_applied", {
		"player": player.display_name,
		"card": card.name,
		"effect_type": effect_type,
		"effect_value": effect_value
	})


# -----------------------------------------------------------------------------
# Dice Handlers
# -----------------------------------------------------------------------------

func _on_roll_dice_pressed() -> void:
	# Validate roll dice action
	var validation = validator.can_roll_dice(self)
	if not validation.valid:
		error_message.show_error(validation.reason)
		return

	# Disable button during roll
	roll_dice_button.disabled = true

	# Mark as rolled this turn
	has_rolled_this_turn = true

	# Roll the dice
	dice.roll()

	# Notify tutorial
	_notify_tutorial("roll_dice")

	print("[GameBoard] Rolling dice...")


func _on_dice_rolled(sum: int) -> void:
	last_dice_sum = sum
	if toast:
		toast.show_toast("Dés : %d — Choisissez une zone" % sum, Color(0.8, 0.9, 1.0))

	print("[GameBoard] Dice rolled: %d" % sum)

	# Highlight reachable zones
	_highlight_reachable_zones(sum)

	# Phase advance happens after movement (in _move_player_to_zone)


func _on_zone_clicked(zone: Zone) -> void:
	# Get current player
	var current_player = GameState.get_current_player()
	if current_player == null:
		push_warning("[GameBoard] No current player found")
		return

	# Validate move action
	var validation = validator.can_move(self, zone.zone_id)
	if not validation.valid:
		error_message.show_error(validation.reason)
		return

	# Validate zone is highlighted (clickable)
	if not zone.is_highlighted:
		error_message.show_error("Cette zone n'est pas accessible")
		return

	print("[GameBoard] Zone clicked: %s by %s" % [zone.zone_name, current_player.display_name])

	# Move player to clicked zone
	_move_player_to_zone(current_player, zone)


func _on_phase_changed(new_phase: GameState.TurnPhase) -> void:
	print("[GameBoard] Phase changed to: %s" % new_phase)

	# Update phase display
	_update_phase_display()

	# Update button states based on phase and validation
	match new_phase:
		GameState.TurnPhase.MOVEMENT:
			# Reset turn flags for new player
			has_drawn_this_turn = false
			has_rolled_this_turn = false
			# Update displays for new player
			_update_display()
			_update_hand_display()
			_update_equipment_display()

			# Check if current player is a bot
			var current_player = GameState.get_current_player()
			if current_player and not current_player.is_human:
				# Disable all UI for bot turns
				roll_dice_button.disabled = true
				draw_card_button.disabled = true
				attack_button.disabled = true
				end_turn_button.disabled = true
				_clear_button_highlights()
				# Execute bot turn
				_execute_bot_turn()
			else:
				# Enable dice roll, disable actions for human players
				roll_dice_button.disabled = false
				draw_card_button.disabled = true
				attack_button.disabled = true
				end_turn_button.disabled = false
				_update_action_hints()
		GameState.TurnPhase.ACTION:
			# Disable dice roll
			roll_dice_button.disabled = true
			# Enable draw button only if haven't drawn yet
			draw_card_button.disabled = has_drawn_this_turn
			# Enable attack button (targets validated on click)
			attack_button.disabled = false
			end_turn_button.disabled = false
			_update_action_hints()
		GameState.TurnPhase.END:
			# Disable all action buttons during transition
			roll_dice_button.disabled = true
			draw_card_button.disabled = true
			attack_button.disabled = true
			end_turn_button.disabled = true
			_clear_button_highlights()


# -----------------------------------------------------------------------------
# Bot Turn Execution
# -----------------------------------------------------------------------------

## Execute bot turn automatically
func _execute_bot_turn() -> void:
	var bot = GameState.get_current_player()
	if not bot or bot.is_human:
		return

	print("[GameBoard] 🤖 Bot turn: %s" % bot.display_name)

	# Create bot controller
	var bot_controller = BotController.new()

	# Execute bot turn (async)
	await bot_controller.execute_bot_turn(bot, get_tree())

	# After bot turn completes, end turn
	print("[GameBoard] 🤖 Bot turn complete, ending turn")
	_on_end_turn_pressed()


# -----------------------------------------------------------------------------
# Combat System
# -----------------------------------------------------------------------------

## Get valid attack targets for current player
func get_valid_targets() -> Array:
	var current_player = GameState.get_current_player()
	if current_player == null:
		return []

	var valid_targets = []

	for player in GameState.players:
		# Cannot attack self
		if player == current_player:
			continue

		# Cannot attack dead players
		if not player.is_alive:
			continue

		# Must be in same zone
		if player.position_zone != current_player.position_zone:
			continue

		valid_targets.append(player)

	return valid_targets


## Handle attack button click - show target selection
func _on_attack_button_pressed() -> void:
	# Validate attack action
	var validation = validator.can_attack(self)
	if not validation.valid:
		error_message.show_error(validation.reason)
		return

	# Get valid targets
	var valid_targets = get_valid_targets()

	if valid_targets.is_empty():
		error_message.show_error("Aucune cible valide à attaquer")
		return

	# Show target selection panel
	target_selection_panel.show_targets(valid_targets)
	print("[GameBoard] Showing %d valid targets for attack" % valid_targets.size())


## Handle target selection - perform attack
func _on_target_selected(target: Player) -> void:
	var attacker = GameState.get_current_player()
	if attacker == null:
		push_error("[GameBoard] No current player found")
		return

	# Create combat system instance
	var combat = CombatSystem.new()

	# Calculate damage
	var damage = combat.calculate_attack_damage(attacker, target)

	# Apply damage (also handles death)
	combat.apply_damage(attacker, target, damage)

	# Play damage animation
	await _play_damage_animation(target)

	# Update dead player UI if target died
	if not target.is_alive:
		_update_dead_player_ui(target)
		# TODO: Trigger reveal animation (AnimationOrchestrator - Story 1.8+)
		print("[GameBoard] %s died! Character revealed: %s (%s)" % [
			target.display_name,
			target.character_name,
			target.faction
		])

	# Update HP display
	_update_display()

	# Log action
	GameState.log_action("attack_performed", {
		"attacker": attacker.display_name,
		"target": target.display_name,
		"damage": damage,
		"target_hp_remaining": target.hp,
		"target_died": not target.is_alive
	})

	# Track action for auto-save
	SaveManager.track_action()

	# Advance to END phase
	GameState.advance_phase()

	if toast:
		var msg = "%s inflige %d dégâts à %s" % [attacker.display_name, damage, target.display_name]
		if not target.is_alive:
			msg += " — Mort !"
		toast.show_toast(msg, Color(1.0, 0.5, 0.5))

	print("[GameBoard] Attack complete: %s dealt %d damage to %s (HP: %d)" % [
		attacker.display_name,
		damage,
		target.display_name,
		target.hp
	])


## Update UI to show dead player state (grayed out token)
func _update_dead_player_ui(player: Player) -> void:
	# Find zone where player is located
	var zone = _get_zone_by_id(player.position_zone)
	if zone == null:
		push_warning("[GameBoard] Cannot find zone for dead player: %s" % player.display_name)
		return

	# Find player token in zone
	for child in zone.token_container.get_children():
		if child.has_method("get_player") and child.get_player() == player:
			# Mark token as dead (grayed out)
			child.mark_as_dead()
			break

	print("[GameBoard] Updated UI for dead player: %s" % player.display_name)


## Play damage animation on target player token (red flash)
func _play_damage_animation(target: Player) -> void:
	# Find zone where target is located
	var zone = _get_zone_by_id(target.position_zone)
	if zone == null:
		return

	# Find target token
	var target_token = null
	for child in zone.token_container.get_children():
		if child.has_method("get_player") and child.get_player() == target:
			target_token = child
			break

	if target_token == null:
		return

	# Create damage flash animation (red tint)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Flash red then back to normal
	tween.tween_property(target_token, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.1)
	tween.tween_property(target_token, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

	await tween.finished

	# TODO: Add damage particles (ParticlePool system - Epic 5)
	# TODO: Add camera shake (PolishConfig + camera setup - Epic 5)
	# TODO: Play damage sound effect (AudioManager - Epic 5)


# -----------------------------------------------------------------------------
# Game Over Handler
# -----------------------------------------------------------------------------

## Handle game over signal - transition to Game Over screen
func _on_game_over(winning_faction: String) -> void:
	print("[GameBoard] Game Over! %s wins!" % winning_faction)

	# Transition to Game Over screen
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME_OVER)


# -----------------------------------------------------------------------------
# Tooltips
# -----------------------------------------------------------------------------

## Setup contextual tooltips on buttons and deck displays
func _setup_tooltips() -> void:
	roll_dice_button.tooltip_text = "Lancer les dés pour déterminer votre mouvement"
	draw_card_button.tooltip_text = "Piocher une carte du deck de la zone actuelle"
	attack_button.tooltip_text = "Attaquer un joueur présent dans votre zone"
	end_turn_button.tooltip_text = "Terminer votre tour et passer au joueur suivant"

	# Deck tooltips
	hermit_count_label.get_parent().tooltip_text = "Deck Hermite — Cartes de vision"
	white_count_label.get_parent().tooltip_text = "Deck Lumière — Cartes bénéfiques (soin, protection)"
	black_count_label.get_parent().tooltip_text = "Deck Ténèbres — Cartes offensives (dégâts, malus)"


## Update visual action hints on buttons based on current state
func _update_action_hints() -> void:
	var current_player = GameState.get_current_player()
	if current_player == null:
		return

	# Skip hints for bot turns
	if not current_player.is_human:
		_clear_button_highlights()
		return

	var phase = GameState.current_phase

	# Roll Dice
	if phase == GameState.TurnPhase.MOVEMENT and not has_rolled_this_turn:
		_highlight_button(roll_dice_button, true)
		roll_dice_button.tooltip_text = "Lancer les dés pour déterminer votre mouvement"
	else:
		_highlight_button(roll_dice_button, false)
		if has_rolled_this_turn:
			roll_dice_button.tooltip_text = "Dés déjà lancés ce tour"
		elif phase != GameState.TurnPhase.MOVEMENT:
			roll_dice_button.tooltip_text = "Disponible uniquement en phase de mouvement"

	# Draw Card
	if phase == GameState.TurnPhase.ACTION and not has_drawn_this_turn:
		var zone_id = current_player.position_zone
		var deck = GameState.get_deck_for_zone(zone_id)
		if deck != null and deck.get_card_count() > 0:
			_highlight_button(draw_card_button, true)
			draw_card_button.tooltip_text = "Piocher une carte du deck %s" % deck.deck_type.capitalize()
		else:
			_highlight_button(draw_card_button, false)
			if deck == null:
				draw_card_button.tooltip_text = "Aucun deck dans cette zone"
			else:
				draw_card_button.tooltip_text = "Le deck est vide"
	else:
		_highlight_button(draw_card_button, false)
		if has_drawn_this_turn:
			draw_card_button.tooltip_text = "Carte déjà piochée ce tour"
		elif phase != GameState.TurnPhase.ACTION:
			draw_card_button.tooltip_text = "Disponible uniquement en phase d'action"

	# Attack
	if phase == GameState.TurnPhase.ACTION:
		var targets = get_valid_targets()
		if targets.size() > 0:
			_highlight_button(attack_button, true)
			attack_button.tooltip_text = "Attaquer un joueur (%d cible(s) disponible(s))" % targets.size()
		else:
			_highlight_button(attack_button, false)
			attack_button.tooltip_text = "Aucun joueur à attaquer dans votre zone"
	else:
		_highlight_button(attack_button, false)
		if phase != GameState.TurnPhase.ACTION:
			attack_button.tooltip_text = "Disponible uniquement en phase d'action"

	# End Turn (always available during human turn)
	_highlight_button(end_turn_button, false)
	end_turn_button.tooltip_text = "Terminer votre tour et passer au joueur suivant"


## Apply or remove pulse highlight on a button
func _highlight_button(button: Button, highlight: bool) -> void:
	if highlight:
		button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		# Start pulse animation
		if not button.has_meta("pulse_tween") or not is_instance_valid(button.get_meta("pulse_tween")):
			var tween = create_tween().set_loops()
			tween.tween_property(button, "modulate", Color(1.3, 1.3, 0.9, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
			tween.tween_property(button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)
			button.set_meta("pulse_tween", tween)
	else:
		# Stop pulse
		if button.has_meta("pulse_tween"):
			var tween = button.get_meta("pulse_tween")
			if is_instance_valid(tween):
				tween.kill()
			button.remove_meta("pulse_tween")
		if button.disabled:
			button.modulate = Color(0.5, 0.5, 0.5, 0.8)
		else:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)


## Clear all button highlights
func _clear_button_highlights() -> void:
	for btn in [roll_dice_button, draw_card_button, attack_button, end_turn_button]:
		_highlight_button(btn, false)


# -----------------------------------------------------------------------------
# Tutorial
# -----------------------------------------------------------------------------

## Start the tutorial overlay
func _start_tutorial() -> void:
	tutorial = TutorialOverlay.new()
	tutorial.tutorial_completed.connect(_on_tutorial_finished)
	tutorial.tutorial_skipped.connect(_on_tutorial_finished)
	add_child(tutorial)
	print("[GameBoard] Tutorial started")


## Handle tutorial completion or skip
func _on_tutorial_finished() -> void:
	tutorial = null
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


## Notify tutorial overlay of an action
func _notify_tutorial(action: String) -> void:
	if tutorial != null:
		tutorial.notify_action(action)


# -----------------------------------------------------------------------------
# Keyboard Navigation
# -----------------------------------------------------------------------------

## Setup focus chain for keyboard navigation (Tab order)
func _setup_focus_chain() -> void:
	# Set focus neighbors for main action buttons
	roll_dice_button.focus_neighbor_bottom = draw_card_button.get_path()
	draw_card_button.focus_neighbor_top = roll_dice_button.get_path()
	draw_card_button.focus_neighbor_bottom = attack_button.get_path()
	attack_button.focus_neighbor_top = draw_card_button.get_path()
	attack_button.focus_neighbor_bottom = end_turn_button.get_path()
	end_turn_button.focus_neighbor_top = attack_button.get_path()
	end_turn_button.focus_neighbor_bottom = roll_dice_button.get_path()
	roll_dice_button.focus_neighbor_top = end_turn_button.get_path()

	# Set focus mode on all buttons
	roll_dice_button.focus_mode = Control.FOCUS_ALL
	draw_card_button.focus_mode = Control.FOCUS_ALL
	attack_button.focus_mode = Control.FOCUS_ALL
	end_turn_button.focus_mode = Control.FOCUS_ALL

	# Give initial focus to roll dice button
	roll_dice_button.grab_focus()
