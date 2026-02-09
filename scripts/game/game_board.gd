## GameBoard - Main game board controller
## Manages the game board, zones, player displays, and game flow.
class_name GameBoard
extends Control


# -----------------------------------------------------------------------------
# References @onready — New visual components
# -----------------------------------------------------------------------------
@onready var damage_tracker: DamageTracker = $MainLayout/VBoxContainer/MiddleRow/DamageTracker
@onready var character_cards_row: CharacterCardsRow = $MainLayout/VBoxContainer/CharacterCardsRow
@onready var zones_container: HBoxContainer = $MainLayout/VBoxContainer/MiddleRow/CenterArea/ZonesContainer
@onready var action_prompt: ActionPrompt = $MainLayout/VBoxContainer/MiddleRow/CenterArea/ActionPrompt
@onready var human_player_info: HumanPlayerInfo = $MainLayout/VBoxContainer/HumanPlayerInfo
@onready var turn_info_label: Label = $MainLayout/VBoxContainer/MiddleRow/TurnInfoPanel/TurnLabel
@onready var phase_info_label: Label = $MainLayout/VBoxContainer/MiddleRow/TurnInfoPanel/PhaseLabel
@onready var deck_info_label: Label = $MainLayout/VBoxContainer/MiddleRow/TurnInfoPanel/DeckLabel

# UI overlays (kept from previous implementation)
@onready var card_reveal: CardReveal = $CardRevealLayer/CardReveal
@onready var equipment_action_menu: EquipmentActionMenu = $EquipmentMenuLayer/EquipmentActionMenu
@onready var target_selection_panel: TargetSelectionPanel = $TargetSelectionLayer/TargetSelectionPanel
@onready var error_message: ErrorMessage = $ErrorMessageLayer/ErrorMessage
@onready var dice_roll_popup: DiceRollPopup = $DiceRollPopupLayer/DiceRollPopup
@onready var zone_effect_popup: ZoneEffectPopup = $ZoneEffectPopupLayer/ZoneEffectPopup


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

	# Setup new visual components
	damage_tracker.setup(GameState.players)
	character_cards_row.setup(GameState.players)
	human_player_info.setup(_get_local_human_player())

	# Initial display update
	_update_display()

	# Connect to phase change signal
	GameState.phase_changed.connect(_on_phase_changed)

	# Connect to game over signal
	GameState.game_over.connect(_on_game_over)

	# Connect to damage/reveal signals for visual components
	GameState.damage_dealt.connect(_on_damage_dealt)
	GameState.character_revealed.connect(_on_character_revealed)
	GameState.player_died.connect(_on_player_died)

	# Connect equipment menu signal
	equipment_action_menu.action_selected.connect(_on_equipment_action_selected)

	# Connect target selection signal
	target_selection_panel.target_selected.connect(_on_target_selected)

	# Connect dice roll popup signal
	dice_roll_popup.zone_selected.connect(_on_popup_zone_selected)

	# Connect action prompt signal
	action_prompt.action_chosen.connect(_on_action_prompt_chosen)

	# Connect zone effect popup signal
	zone_effect_popup.effect_completed.connect(_on_zone_effect_completed)

	# Connect human player info hand card clicks
	human_player_info.hand_card_clicked.connect(_on_hand_card_clicked)

	# Add pause menu
	var pause_menu = PauseMenu.new()
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_menu)

	# Reset auto-save counter for new game
	SaveManager.reset_action_counter()

	# Add help menu (F1)
	var help_menu = HelpMenu.new()
	add_child(help_menu)

	# Add feedback toast
	toast = FeedbackToast.new()
	add_child(toast)

	# Start tutorial if in tutorial mode
	if GameModeStateMachine.current_mode == GameModeStateMachine.GameMode.TUTORIAL:
		_start_tutorial()

	# Trigger initial phase handling (signal was connected after phase was set)
	_on_phase_changed(GameState.current_phase)

	print("[GameBoard] Game started with %d players" % GameState.players.size())


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

## Get the first human player (local player for bottom panel)
func _get_local_human_player() -> Player:
	for player in GameState.players:
		if player.is_human:
			return player
	return null


# -----------------------------------------------------------------------------
# Zone System
# -----------------------------------------------------------------------------

## Initialize all 6 zones in randomized positions with group spacers
func _initialize_zones() -> void:
	# Clear any existing zones
	for child in zones_container.get_children():
		child.queue_free()
	zones.clear()

	# Shuffle zone positions for this game
	GameState.setup_zone_positions()

	# Create zones in position order with spacers between groups
	for i in range(GameState.zone_positions.size()):
		# Add spacer between groups (after position 1 and 3)
		if i == 2 or i == 4:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(30, 0)
			zones_container.add_child(spacer)

		var zone_id = GameState.zone_positions[i]
		var zone_data = ZoneData.get_zone_by_id(zone_id)
		var dice_range = ZoneData.get_dice_range_for_position(i)

		var zone = preload("res://scenes/board/zone.tscn").instantiate()
		zones_container.add_child(zone)
		zone.setup(zone_data, dice_range)
		zones.append(zone)

	print("[GameBoard] Initialized %d zones in random positions" % zones.size())


## Place all player tokens in their starting zones
func _place_player_tokens() -> void:
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


## Move player token from current zone to target zone with animation
func _move_player_to_zone(player: Player, target_zone: Zone) -> void:
	var current_zone = _get_zone_by_id(player.position_zone)
	if current_zone == null:
		push_error("[GameBoard] Current zone not found for player %s" % player.display_name)
		return

	var token = null
	for child in current_zone.token_container.get_children():
		if child.has_method("get_player") and child.get_player() == player:
			token = child
			break

	if token == null:
		push_error("[GameBoard] Token not found for player %s" % player.display_name)
		return

	var end_pos = target_zone.token_container.global_position

	set_process_input(false)
	AudioManager.play_sfx("move_player")

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(token, "global_position", end_pos, 0.6)
	tween.tween_property(token, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(token, "scale", Vector2(1.0, 1.0), 0.1)

	await tween.finished

	current_zone.remove_player_token(player)
	target_zone.add_player_token(player)
	player.position_zone = target_zone.zone_id

	set_process_input(true)

	if toast:
		toast.show_toast("%s se déplace vers %s" % [player.display_name, target_zone.zone_name], Color(0.7, 0.8, 1.0))
	print("[GameBoard] Moved %s to %s" % [player.display_name, target_zone.zone_name])

	_notify_tutorial("move_to_zone")
	GameState.advance_phase()


# -----------------------------------------------------------------------------
# Display Updates
# -----------------------------------------------------------------------------

## Update turn info display
func _update_display() -> void:
	var current_player = GameState.get_current_player()
	if current_player:
		var label = PlayerColors.get_label(current_player)
		turn_info_label.text = "Tour %d\n%s" % [GameState.turn_count, label]
		turn_info_label.add_theme_color_override("font_color", PlayerColors.get_color(current_player.id))
		character_cards_row.highlight_current_player(current_player.id)
	_update_phase_display()
	_update_deck_displays()
	human_player_info.update_display()


## Update phase display
func _update_phase_display() -> void:
	match GameState.current_phase:
		GameState.TurnPhase.MOVEMENT:
			phase_info_label.text = "Mouvement"
		GameState.TurnPhase.ACTION:
			phase_info_label.text = "Action"
		GameState.TurnPhase.END:
			phase_info_label.text = "Fin de tour"


## Update deck count display
func _update_deck_displays() -> void:
	var h = GameState.hermit_deck.get_card_count() if GameState.hermit_deck else 0
	var w = GameState.white_deck.get_card_count() if GameState.white_deck else 0
	var b = GameState.black_deck.get_card_count() if GameState.black_deck else 0
	deck_info_label.text = "Hermit: %d\nWhite: %d\nBlack: %d" % [h, w, b]


# -----------------------------------------------------------------------------
# Phase Change Handler
# -----------------------------------------------------------------------------

func _on_phase_changed(new_phase: GameState.TurnPhase) -> void:
	print("[GameBoard] Phase changed to: %s" % new_phase)
	_update_display()

	match new_phase:
		GameState.TurnPhase.MOVEMENT:
			has_drawn_this_turn = false
			has_rolled_this_turn = false

			var current_player = GameState.get_current_player()
			if current_player and not current_player.is_human:
				action_prompt.show_waiting_prompt(current_player.display_name)
				_execute_bot_turn()
			else:
				action_prompt.show_movement_prompt(current_player)
				dice_roll_popup.show_for_player(current_player)

		GameState.TurnPhase.ACTION:
			var action_player = GameState.get_current_player()
			if action_player and action_player.is_human:
				var deck = GameState.get_deck_for_zone(action_player.position_zone)
				if not has_drawn_this_turn and deck != null and deck.get_card_count() > 0:
					_auto_draw_card(action_player)
				elif not has_drawn_this_turn and _zone_has_effect(action_player.position_zone):
					_show_zone_effect(action_player)
				else:
					_show_action_prompt(action_player)
			else:
				action_prompt.show_waiting_prompt(action_player.display_name if action_player else "")

		GameState.TurnPhase.END:
			action_prompt.hide_prompt()


# -----------------------------------------------------------------------------
# Action Prompt
# -----------------------------------------------------------------------------

## Show the action prompt with context
func _show_action_prompt(player: Player) -> void:
	var zone_id = player.position_zone
	var deck = GameState.get_deck_for_zone(zone_id)
	var can_draw = not has_drawn_this_turn and deck != null and deck.get_card_count() > 0
	var deck_type = deck.deck_type if deck != null else ""
	var target_count = get_valid_targets().size()
	action_prompt.show_action_prompt(player, can_draw, deck_type, target_count)


## Handle action prompt choice
func _on_action_prompt_chosen(action: String) -> void:
	match action:
		"draw":
			_on_draw_card_pressed()
		"attack":
			_on_attack_button_pressed()
		"end_turn":
			_on_end_turn_pressed()


# -----------------------------------------------------------------------------
# Dice / Zone Click Handlers
# -----------------------------------------------------------------------------

## Handler for dice roll popup zone selection
func _on_popup_zone_selected(zone_id: String) -> void:
	var current_player = GameState.get_current_player()
	if current_player == null:
		return

	var zone = _get_zone_by_id(zone_id)
	if zone == null:
		push_error("[GameBoard] Zone not found: %s" % zone_id)
		return

	last_dice_sum = dice_roll_popup._dice_result
	has_rolled_this_turn = true

	if toast:
		toast.show_toast("Dés : %d — Déplacement vers %s" % [last_dice_sum, zone.zone_name], Color(0.8, 0.9, 1.0))

	_notify_tutorial("roll_dice")
	_move_player_to_zone(current_player, zone)


# -----------------------------------------------------------------------------
# Button Handlers
# -----------------------------------------------------------------------------

func _on_end_turn_pressed() -> void:
	var validation = validator.can_end_turn()
	if not validation.valid:
		error_message.show_error(validation.reason)
		return

	var current_player = GameState.get_current_player()
	print("[GameBoard] %s ending turn" % current_player.display_name)

	match GameState.current_phase:
		GameState.TurnPhase.MOVEMENT:
			GameState.advance_phase()  # → ACTION
			GameState.advance_phase()  # → END
			GameState.advance_phase()  # → MOVEMENT (next)
		GameState.TurnPhase.ACTION:
			GameState.advance_phase()  # → END
			GameState.advance_phase()  # → MOVEMENT (next)
		GameState.TurnPhase.END:
			GameState.advance_phase()  # → MOVEMENT (next)

	has_drawn_this_turn = false
	has_rolled_this_turn = false
	_update_display()
	SaveManager.track_action()


func _on_back_to_menu_pressed() -> void:
	GameState.reset()
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


## Auto-draw card when arriving on a zone with a deck (mandatory in Shadow Hunter)
func _auto_draw_card(player: Player) -> void:
	var zone_id = player.position_zone
	var deck = GameState.get_deck_for_zone(zone_id)
	if deck == null:
		_show_action_prompt(player)
		return

	var card = deck.draw_card()
	if card == null:
		_show_action_prompt(player)
		return

	if toast:
		toast.show_toast("%s pioche : %s" % [player.display_name, card.name], Color(0.6, 1.0, 0.6))
	print("[GameBoard] Auto-draw: %s drew '%s' from %s deck" % [player.display_name, card.name, deck.deck_type])

	_update_deck_displays()

	card_reveal.show_card(card)
	await card_reveal.card_reveal_finished

	if card.type == "instant":
		_apply_instant_card_effect(card, player)
		deck.discard_card(card)
		_update_deck_displays()
	elif card.type == "equipment":
		player.hand.append(card)
		human_player_info.update_display()
	elif card.type == "vision":
		pass  # TODO: vision card handling

	has_drawn_this_turn = true
	_notify_tutorial("draw_card")
	SaveManager.track_action()

	# Show remaining actions (attack/end turn)
	var target_count = get_valid_targets().size()
	action_prompt.update_after_draw(player, target_count)


## Check if a zone has a special effect (no deck)
func _zone_has_effect(zone_id: String) -> bool:
	var zone_data = ZoneData.get_zone_by_id(zone_id)
	return zone_data.has("effect") and zone_data.effect != ""


## Show zone effect popup for the current player
func _show_zone_effect(player: Player) -> void:
	var zone_data = ZoneData.get_zone_by_id(player.position_zone)
	if toast:
		toast.show_toast("%s active : %s" % [player.display_name, zone_data.name], Color(0.8, 0.7, 1.0))
	zone_effect_popup.show_effect(zone_data, player, GameState.players)


## Handle zone effect completion
func _on_zone_effect_completed(result: Dictionary) -> void:
	var current_player = GameState.get_current_player()
	if current_player == null:
		return

	var effect_type = result.get("type", "")

	match effect_type:
		"damage_or_heal":
			var target: Player = result.target
			var action: String = result.action
			if action == "damage":
				var died = target.take_damage(2)
				GameState.damage_dealt.emit(current_player, target, 2)
				if died:
					GameState.player_died.emit(target, current_player)
				if toast:
					toast.show_toast("%s inflige 2 dégâts à %s" % [current_player.display_name, target.display_name], Color(1.0, 0.5, 0.5))
			elif action == "heal":
				target.heal(1)
				if toast:
					toast.show_toast("%s soigne %s de 1 HP" % [current_player.display_name, target.display_name], Color(0.5, 1.0, 0.5))
			_update_display()

		"choose_deck":
			var deck_type: String = result.deck_type
			var deck = _get_deck_by_type(deck_type)
			if deck and deck.get_card_count() > 0:
				var card = deck.draw_card()
				if card:
					_update_deck_displays()
					card_reveal.show_card(card)
					await card_reveal.card_reveal_finished
					if card.type == "instant":
						_apply_instant_card_effect(card, current_player)
						deck.discard_card(card)
						_update_deck_displays()
					elif card.type == "equipment":
						current_player.hand.append(card)
						human_player_info.update_display()
					elif card.type == "vision":
						pass  # TODO: vision card handling
			else:
				if toast:
					toast.show_toast("Deck vide !", Color(1.0, 0.6, 0.3))

		"steal_equipment":
			var target: Player = result.target
			var card: Card = result.card
			# Remove from target's equipment
			var idx = target.equipment.find(card)
			if idx >= 0:
				target.equipment.remove_at(idx)
			# Add to current player's equipment
			current_player.equipment.append(card)
			GameState.equipment_equipped.emit(current_player, card)
			if toast:
				toast.show_toast("%s vole %s à %s" % [current_player.display_name, card.name, target.display_name], Color(1.0, 0.7, 0.2))
			_update_display()

		"cancelled":
			pass  # Player cancelled, just show action prompt

	has_drawn_this_turn = true
	SaveManager.track_action()

	# Show remaining actions (attack/end turn)
	if current_player.is_human:
		var target_count = get_valid_targets().size()
		action_prompt.update_after_draw(current_player, target_count)


## Get deck by type name (hermit/white/black)
func _get_deck_by_type(deck_type: String) -> DeckManager:
	match deck_type:
		"hermit":
			return GameState.hermit_deck
		"white":
			return GameState.white_deck
		"black":
			return GameState.black_deck
	return null


func _on_draw_card_pressed() -> void:
	var validation = validator.can_draw_card(self)
	if not validation.valid:
		error_message.show_error(validation.reason)
		return

	var current_player = GameState.get_current_player()
	if current_player == null:
		push_error("[GameBoard] No current player found")
		return

	var zone_id = current_player.position_zone
	var deck = GameState.get_deck_for_zone(zone_id)
	if deck == null:
		push_warning("[GameBoard] No deck available for zone: %s" % zone_id)
		return

	var card = deck.draw_card()
	if card == null:
		push_warning("[GameBoard] Failed to draw card from %s deck" % zone_id)
		return

	if toast:
		toast.show_toast("%s pioche : %s" % [current_player.display_name, card.name], Color(0.6, 1.0, 0.6))
	print("[GameBoard] %s drew card '%s' from %s deck" % [current_player.display_name, card.name, deck.deck_type])

	_update_deck_displays()

	# Show card reveal animation
	card_reveal.show_card(card)
	await card_reveal.card_reveal_finished

	# Apply card effect based on type
	if card.type == "instant":
		_apply_instant_card_effect(card, current_player)
		deck.discard_card(card)
		_update_deck_displays()
	elif card.type == "equipment":
		current_player.hand.append(card)
		print("[GameBoard] Equipment card '%s' added to %s's hand" % [card.name, current_player.display_name])
		human_player_info.update_display()
	elif card.type == "vision":
		print("[GameBoard] Vision card - handling (TODO)")

	has_drawn_this_turn = true
	_notify_tutorial("draw_card")
	SaveManager.track_action()

	# Re-show action prompt for remaining choices
	if current_player.is_human and GameState.current_phase == GameState.TurnPhase.ACTION:
		var target_count = get_valid_targets().size()
		action_prompt.update_after_draw(current_player, target_count)

	print("[GameBoard] Card draw complete.")


# -----------------------------------------------------------------------------
# Equipment Card Handlers
# -----------------------------------------------------------------------------

## Handle click on card in hand
func _on_hand_card_clicked(card: Card) -> void:
	var button_position = get_viewport().get_mouse_position()
	equipment_action_menu.show_for_card(card, button_position)


## Handle equipment action selection
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


## Equip a card from hand
func _equip_card(player: Player, card: Card) -> void:
	player.equip_card(card)
	GameState.equipment_equipped.emit(player, card)
	human_player_info.update_display()

	GameState.log_action("equipment_equipped", {
		"player": player.display_name,
		"card": card.name,
		"effect": card.get_effect_description()
	})


## Discard a card from hand
func _discard_card_from_hand(player: Player, card: Card) -> void:
	var deck = GameState.get_deck_for_zone(card.deck)
	if deck == null:
		push_error("[GameBoard] Cannot find deck for card: %s (deck: %s)" % [card.name, card.deck])
		return

	var hand_idx = player.hand.find(card)
	if hand_idx >= 0:
		player.hand.remove_at(hand_idx)
	else:
		push_warning("[GameBoard] Card not found in hand: %s" % card.name)
		return

	deck.discard_card(card)
	GameState.equipment_discarded.emit(player, card)
	human_player_info.update_display()
	_update_deck_displays()

	GameState.log_action("card_discarded", {
		"player": player.display_name,
		"card": card.name,
		"deck": card.deck
	})


# -----------------------------------------------------------------------------
# Card Effect System
# -----------------------------------------------------------------------------

## Apply instant card effect to player
func _apply_instant_card_effect(card: Card, player: Player) -> void:
	var effect_type = card.get_effect_type()
	var effect_value = card.get_effect_value()

	match effect_type:
		"heal":
			player.heal(effect_value)
		"damage":
			var died = player.take_damage(effect_value)
			GameState.damage_dealt.emit(player, player, effect_value)
			if died:
				GameState.player_died.emit(player, player)
		_:
			push_warning("[GameBoard] Unknown instant effect type: %s" % effect_type)

	GameState.log_action("card_effect_applied", {
		"player": player.display_name,
		"card": card.name,
		"effect_type": effect_type,
		"effect_value": effect_value
	})


# -----------------------------------------------------------------------------
# Signal Handlers — Visual component updates
# -----------------------------------------------------------------------------

func _on_damage_dealt(_attacker: Player, victim: Player, _amount: int) -> void:
	damage_tracker.update_player_hp(victim)
	human_player_info.update_display()


func _on_character_revealed(player: Player, _character: Variant, _faction: String) -> void:
	character_cards_row.reveal_character(player)


func _on_player_died(player: Player, _killer: Variant) -> void:
	damage_tracker.mark_player_dead(player)
	_update_dead_player_ui(player)


# -----------------------------------------------------------------------------
# Bot Turn Execution
# -----------------------------------------------------------------------------

func _execute_bot_turn() -> void:
	var bot = GameState.get_current_player()
	if not bot or bot.is_human:
		return

	print("[GameBoard] Bot turn: %s" % bot.display_name)
	var bot_controller = BotController.new()
	await bot_controller.execute_bot_turn(bot, get_tree())

	print("[GameBoard] Bot turn complete, ending turn")
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
		if player == current_player:
			continue
		if not player.is_alive:
			continue
		if player.position_zone != current_player.position_zone:
			continue
		valid_targets.append(player)

	return valid_targets


## Handle attack button click
func _on_attack_button_pressed() -> void:
	var validation = validator.can_attack(self)
	if not validation.valid:
		error_message.show_error(validation.reason)
		return

	var valid_targets = get_valid_targets()
	if valid_targets.is_empty():
		error_message.show_error("Aucune cible valide à attaquer")
		return

	target_selection_panel.show_targets(valid_targets)


## Handle target selection
func _on_target_selected(target: Player) -> void:
	var attacker = GameState.get_current_player()
	if attacker == null:
		push_error("[GameBoard] No current player found")
		return

	var combat = CombatSystem.new()
	var damage = combat.calculate_attack_damage(attacker, target)
	combat.apply_damage(attacker, target, damage)

	await _play_damage_animation(target)

	if not target.is_alive:
		_update_dead_player_ui(target)

	_update_display()

	GameState.log_action("attack_performed", {
		"attacker": attacker.display_name,
		"target": target.display_name,
		"damage": damage,
		"target_hp_remaining": target.hp,
		"target_died": not target.is_alive
	})

	SaveManager.track_action()
	GameState.advance_phase()

	if toast:
		var msg = "%s inflige %d dégâts à %s" % [attacker.display_name, damage, target.display_name]
		if not target.is_alive:
			msg += " — Mort !"
		toast.show_toast(msg, Color(1.0, 0.5, 0.5))


## Update UI to show dead player state
func _update_dead_player_ui(player: Player) -> void:
	var zone = _get_zone_by_id(player.position_zone)
	if zone == null:
		return

	for child in zone.token_container.get_children():
		if child.has_method("get_player") and child.get_player() == player:
			child.mark_as_dead()
			break


## Play damage animation on target player token
func _play_damage_animation(target: Player) -> void:
	var zone = _get_zone_by_id(target.position_zone)
	if zone == null:
		return

	var target_token = null
	for child in zone.token_container.get_children():
		if child.has_method("get_player") and child.get_player() == target:
			target_token = child
			break

	if target_token == null:
		return

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target_token, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.1)
	tween.tween_property(target_token, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
	await tween.finished


# -----------------------------------------------------------------------------
# Game Over Handler
# -----------------------------------------------------------------------------

func _on_game_over(winning_faction: String) -> void:
	print("[GameBoard] Game Over! %s wins!" % winning_faction)
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME_OVER)


# -----------------------------------------------------------------------------
# Tutorial
# -----------------------------------------------------------------------------

func _start_tutorial() -> void:
	tutorial = TutorialOverlay.new()
	tutorial.tutorial_completed.connect(_on_tutorial_finished)
	tutorial.tutorial_skipped.connect(_on_tutorial_finished)
	add_child(tutorial)


func _on_tutorial_finished() -> void:
	tutorial = null
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


func _notify_tutorial(action: String) -> void:
	if tutorial != null:
		tutorial.notify_action(action)
