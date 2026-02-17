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
var has_attacked_this_turn: bool = false  # Track if player has attacked this turn
var _vision_pending: bool = false  # True when waiting for vision card target selection
var _vision_card: Card = null  # Vision card being resolved
var _vision_deck: DeckManager = null  # Deck to discard vision card to
var _pending_ability: bool = false  # True when waiting for ability target selection
var _instant_card_pending: bool = false  # True when waiting for instant card target selection
var _instant_card: Card = null  # Instant card being resolved
var _instant_card_player: Player = null  # Player who drew the instant card
var _combat_target: Player = null  # Target awaiting combat dice result

## Action validator instance
var validator: ActionValidator = ActionValidator.new()

## Tutorial overlay (null if not in tutorial mode)
var tutorial: TutorialOverlay = null

## Feedback toast for multi-channel notifications
var toast: FeedbackToast = null

## True once game_over signal fires — stops all game logic
var _game_ended: bool = false


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

	# Register active abilities for all players
	for player in GameState.players:
		GameState.active_ability_system.register_player_ability(player)

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

	# Connect dice roll popup signals
	dice_roll_popup.zone_selected.connect(_on_popup_zone_selected)
	dice_roll_popup.combat_roll_completed.connect(_on_combat_roll_completed)

	# Connect action prompt signal
	human_player_info.action_chosen.connect(_on_action_prompt_chosen)

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
		toast.show_toast(Tr.t("toast.player_moves", [player.display_name, target_zone.zone_name]), Color(0.7, 0.8, 1.0))
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
			phase_info_label.text = Tr.t("phase.movement")
		GameState.TurnPhase.ACTION:
			phase_info_label.text = Tr.t("phase.action")
		GameState.TurnPhase.END:
			phase_info_label.text = Tr.t("phase.end")


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
	if _game_ended:
		return
	print("[GameBoard] Phase changed to: %s" % new_phase)
	_update_display()

	match new_phase:
		GameState.TurnPhase.MOVEMENT:
			has_drawn_this_turn = false
			has_rolled_this_turn = false
			has_attacked_this_turn = false
			_pending_ability = false
			_instant_card_pending = false

			var current_player = GameState.get_current_player()
			# Reset Gregor's shield at the start of his turn
			if current_player and current_player.has_meta("shielded"):
				current_player.set_meta("shielded", false)
			# Reset Guardian Angel immunity at the start of player's turn
			if current_player and current_player.has_meta("damage_immune"):
				current_player.set_meta("damage_immune", false)
			if current_player and not current_player.is_human:
				human_player_info.show_waiting_prompt(current_player.display_name)
				_execute_bot_turn()
			else:
				human_player_info.show_movement_prompt(current_player)
				var has_compass = _has_active_equipment(current_player, "double_dice_roll")
				dice_roll_popup.show_for_player(current_player, has_compass)

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
				human_player_info.show_waiting_prompt(action_player.display_name if action_player else "")

		GameState.TurnPhase.END:
			human_player_info.hide_prompt()


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
	human_player_info.show_action_prompt(player, can_draw, deck_type, target_count, has_attacked_this_turn)


## Handle action prompt choice
func _on_action_prompt_chosen(action: String) -> void:
	if _game_ended:
		return
	match action:
		"draw":
			_on_draw_card_pressed()
		"attack":
			_on_attack_button_pressed()
		"reveal":
			_on_reveal_pressed()
		"ability":
			_on_ability_pressed()
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
		toast.show_toast(Tr.t("toast.dice_move", [last_dice_sum, zone.zone_name]), Color(0.8, 0.9, 1.0))

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

	# Cursed Sword Masamune — must attack if targets available
	if not has_attacked_this_turn and _has_active_equipment(current_player, "forced_attack"):
		if not get_valid_targets().is_empty():
			error_message.show_error(Tr.t("combat.cursed_sword_force"))
			return

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
	has_attacked_this_turn = false
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
		toast.show_toast(Tr.t("toast.player_draws", [player.display_name, card.name]), Color(0.6, 1.0, 0.6))
	print("[GameBoard] Auto-draw: %s drew '%s' from %s deck" % [player.display_name, card.name, deck.deck_type])

	_update_deck_displays()

	card_reveal.show_card(card)
	await card_reveal.card_reveal_finished

	if card.type == "instant":
		_apply_instant_card_effect(card, player)
		deck.discard_card(card)
		_update_deck_displays()
		if _instant_card_pending:
			return  # Instant card target selection in progress
	elif card.type == "equipment":
		player.equipment.append(card)
		GameState.equipment_equipped.emit(player, card)
		if card.faction_restriction != "" and player.faction != card.faction_restriction:
			if toast:
				toast.show_toast(Tr.t("toast.equipment_inactive", [player.display_name, card.name, card.faction_restriction]), Color(0.7, 0.7, 0.3))
		else:
			if toast:
				toast.show_toast(Tr.t("toast.player_equips", [player.display_name, card.name]), Color(1.0, 0.9, 0.3))
		human_player_info.update_display()
	elif card.type == "vision":
		_start_vision_card(player, card, deck)
		return  # Vision flow handles has_drawn + action prompt

	has_drawn_this_turn = true
	_notify_tutorial("draw_card")
	SaveManager.track_action()

	# Show remaining actions (attack/end turn)
	var target_count = get_valid_targets().size()
	human_player_info.update_after_draw(player, target_count, has_attacked_this_turn)


## Check if a zone has a special effect (no deck)
func _zone_has_effect(zone_id: String) -> bool:
	var zone_data = ZoneData.get_zone_by_id(zone_id)
	return zone_data.has("effect") and zone_data.effect != ""


## Show zone effect popup for the current player
func _show_zone_effect(player: Player) -> void:
	# Fortune Brooch — immune to Weird Woods
	if player.position_zone == "weird_woods" and _has_active_equipment(player, "immunity_weird_woods"):
		if toast:
			toast.show_toast(Tr.t("toast.fortune_brooch", [player.display_name]), Color(0.3, 0.9, 0.5))
		_show_action_prompt(player)
		return
	var zone_data = ZoneData.get_zone_by_id(player.position_zone)
	if toast:
		toast.show_toast(Tr.t("toast.zone_activates", [player.display_name, zone_data.name]), Color(0.8, 0.7, 1.0))
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
					toast.show_toast(Tr.t("toast.deals_damage", [current_player.display_name, 2, target.display_name]), Color(1.0, 0.5, 0.5))
			elif action == "heal":
				target.heal(1)
				damage_tracker.update_player_hp(target)
				_play_heal_visual(target, 1)
				if toast:
					toast.show_toast(Tr.t("toast.heals", [current_player.display_name, target.display_name, 1]), Color(0.5, 1.0, 0.5))
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
						if _instant_card_pending:
							return  # Instant card target selection in progress
					elif card.type == "equipment":
						current_player.equipment.append(card)
						GameState.equipment_equipped.emit(current_player, card)
						if card.faction_restriction != "" and current_player.faction != card.faction_restriction:
							if toast:
								toast.show_toast(Tr.t("toast.equipment_inactive", [current_player.display_name, card.name, card.faction_restriction]), Color(0.7, 0.7, 0.3))
						else:
							if toast:
								toast.show_toast(Tr.t("toast.player_equips", [current_player.display_name, card.name]), Color(1.0, 0.9, 0.3))
						human_player_info.update_display()
					elif card.type == "vision":
						_start_vision_card(current_player, card, deck)
						return  # Vision flow handles the rest
			else:
				if toast:
					toast.show_toast(Tr.t("toast.deck_empty"), Color(1.0, 0.6, 0.3))

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
				toast.show_toast(Tr.t("toast.steals_equip", [current_player.display_name, card.name, target.display_name]), Color(1.0, 0.7, 0.2))
			_update_display()

		"cancelled":
			pass  # Player cancelled, just show action prompt

	has_drawn_this_turn = true
	SaveManager.track_action()

	# Show remaining actions (attack/end turn)
	if current_player.is_human:
		var target_count = get_valid_targets().size()
		human_player_info.update_after_draw(current_player, target_count, has_attacked_this_turn)


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
		toast.show_toast(Tr.t("toast.player_draws", [current_player.display_name, card.name]), Color(0.6, 1.0, 0.6))
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
		if _instant_card_pending:
			return  # Instant card target selection in progress
	elif card.type == "equipment":
		current_player.equipment.append(card)
		GameState.equipment_equipped.emit(current_player, card)
		if card.faction_restriction != "" and current_player.faction != card.faction_restriction:
			if toast:
				toast.show_toast(Tr.t("toast.equipment_inactive", [current_player.display_name, card.name, card.faction_restriction]), Color(0.7, 0.7, 0.3))
		else:
			if toast:
				toast.show_toast(Tr.t("toast.player_equips", [current_player.display_name, card.name]), Color(1.0, 0.9, 0.3))
		human_player_info.update_display()
	elif card.type == "vision":
		_start_vision_card(current_player, card, deck)
		return  # Vision flow handles has_drawn + action prompt

	has_drawn_this_turn = true
	_notify_tutorial("draw_card")
	SaveManager.track_action()

	# Re-show action prompt for remaining choices
	if current_player.is_human and GameState.current_phase == GameState.TurnPhase.ACTION:
		var target_count = get_valid_targets().size()
		human_player_info.update_after_draw(current_player, target_count, has_attacked_this_turn)

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

## Get a target for a card effect (bot: random alive, human: random for now)
## @param include_self: Whether the player can target themselves
func _get_card_target(player: Player, include_self: bool) -> Player:
	var targets: Array = []
	for p in GameState.players:
		if not p.is_alive:
			continue
		if p == player and not include_self:
			continue
		targets.append(p)
	if targets.is_empty():
		return null
	return targets[randi() % targets.size()]


## Get a target that has equipment (for steal effects)
func _get_card_target_with_equipment(player: Player) -> Player:
	var targets: Array = []
	for p in GameState.players:
		if not p.is_alive or p == player:
			continue
		if not p.equipment.is_empty():
			targets.append(p)
	if targets.is_empty():
		return null
	return targets[randi() % targets.size()]


## Get intelligent card target for bot players based on effect type
## Human players get target selection popup (handled in _apply_instant_card_effect)
func _get_smart_card_target(player: Player, effect_type: String) -> Player:
	var allies: Array = []
	var enemies: Array = []
	for p in GameState.players:
		if not p.is_alive or p == player:
			continue
		if p.is_revealed and AIDecisionEngine._is_ally_static(player, p):
			allies.append(p)
		else:
			enemies.append(p)

	match effect_type:
		"heal_d6":
			# Heal most damaged ally (or self)
			var best: Player = player
			var best_missing: int = player.hp_max - player.hp
			for a in allies:
				var missing = a.hp_max - a.hp
				if missing > best_missing:
					best = a
					best_missing = missing
			return best if best_missing > 0 else player

		"set_damage":
			# Heal ally with damage > 7, or harm enemy with damage < 7
			var best_ally: Player = null
			var best_ally_damage: int = 0
			for a in allies + [player]:
				var dmg = a.hp_max - a.hp
				if dmg > 7 and dmg > best_ally_damage:
					best_ally = a
					best_ally_damage = dmg
			if best_ally:
				return best_ally
			var best_enemy: Player = null
			var lowest_damage: int = 99
			for e in enemies:
				var dmg = e.hp_max - e.hp
				if dmg < 7 and dmg < lowest_damage:
					best_enemy = e
					lowest_damage = dmg
			if best_enemy:
				return best_enemy
			return _get_card_target(player, true)

		"vampire_drain", "mutual_damage", "self_damage_gamble":
			# Always target enemy, never ally — pick weakest
			if not enemies.is_empty():
				var weakest: Player = enemies[0]
				for e in enemies:
					if e.hp < weakest.hp:
						weakest = e
				return weakest
			return _get_card_target(player, false)

		"give_equipment":
			# Give to ally
			if not allies.is_empty():
				return allies[randi() % allies.size()]
			return _get_card_target(player, false)

		_:
			return _get_card_target(player, false)


## Get intelligent steal target for bot: prefer enemies with equipment
func _get_smart_card_target_with_equipment(player: Player) -> Player:
	var best: Player = null
	for p in GameState.players:
		if not p.is_alive or p == player or p.equipment.is_empty():
			continue
		if p.is_revealed and not AIDecisionEngine._is_ally_static(player, p):
			if best == null or p.equipment.size() > best.equipment.size():
				best = p
	if best == null:
		return _get_card_target_with_equipment(player)
	return best


## Apply instant card effect to player
## For targeted effects: humans get popup, bots use smart targeting
func _apply_instant_card_effect(card: Card, player: Player) -> void:
	var effect_type = card.get_effect_type()
	var effect_value = card.get_effect_value()

	# --- Non-targeted effects (no target selection needed) ---
	match effect_type:
		"heal":
			player.heal(effect_value)
			damage_tracker.update_player_hp(player)
			_play_heal_visual(player, effect_value)
			human_player_info.update_display()
			_log_card_effect(card, player, effect_type, effect_value)
			return
		"damage":
			var died = player.take_damage(effect_value)
			GameState.damage_dealt.emit(player, player, effect_value)
			if died:
				GameState.player_died.emit(player, player)
			_log_card_effect(card, player, effect_type, effect_value)
			return
		"damage_all_others":
			for p in GameState.players:
				if p != player and p.is_alive:
					var died = p.take_damage(effect_value)
					GameState.damage_dealt.emit(player, p, effect_value)
					damage_tracker.update_player_hp(p)
					if died:
						GameState.player_died.emit(p, player)
			if toast:
				toast.show_toast(Tr.t("toast.deals_damage_all", [PlayerColors.get_label(player), effect_value]), Color(1.0, 0.5, 0.2))
			_log_card_effect(card, player, effect_type, effect_value)
			return
		"extra_turn":
			player.set_meta("extra_turn", true)
			if toast:
				toast.show_toast(Tr.t("toast.extra_turn", [PlayerColors.get_label(player)]), Color(0.3, 0.8, 1.0))
			_log_card_effect(card, player, effect_type, 0)
			return
		"damage_immunity":
			player.set_meta("damage_immune", true)
			if toast:
				toast.show_toast(Tr.t("toast.guardian_angel", [PlayerColors.get_label(player)]), Color(0.3, 0.9, 1.0))
			_log_card_effect(card, player, effect_type, 0)
			return
		"force_shadow_reveal":
			if player.faction == "shadow" and not player.is_revealed:
				player.is_revealed = true
				GameState.player_revealed.emit(player)
				if toast:
					toast.show_toast(Tr.t("toast.forced_reveal", [player.character_name]), Color(1.0, 0.3, 0.3))
			else:
				if toast:
					toast.show_toast(Tr.t("toast.no_effect"), Color(0.5, 0.5, 0.5))
			_log_card_effect(card, player, effect_type, 0)
			return
		"aoe_dice_damage":
			var d6 = randi() % 6 + 1
			var d4 = randi() % 4 + 1
			var dice_sum = d6 + d4
			var zone_id = ZoneData.get_zone_for_dice_sum(dice_sum, GameState.zone_positions)
			var dmg = card.effect.get("damage", 3)
			if zone_id == "":
				if toast:
					toast.show_toast(Tr.t("toast.dynamite_no_zone", [d6, d4, dice_sum]), Color(0.5, 0.5, 0.5))
			else:
				var hit_count = 0
				for p in GameState.players:
					if p.is_alive and p.position_zone == zone_id:
						if _has_active_equipment(p, "immunity_black_cards"):
							if toast:
								toast.show_toast(Tr.t("toast.talisman_protects", [PlayerColors.get_label(p)]), Color(0.3, 0.9, 0.5))
							continue
						var died = p.take_damage(dmg)
						GameState.damage_dealt.emit(player, p, dmg)
						damage_tracker.update_player_hp(p)
						hit_count += 1
						if died:
							GameState.player_died.emit(p, player)
				if toast:
					var zone_data = ZoneData.get_zone_by_id(zone_id)
					var zone_name = zone_data.get("name", zone_id) if zone_data else zone_id
					toast.show_toast(Tr.t("toast.dynamite_hit", [d6, d4, dice_sum, zone_name, hit_count]), Color(1.0, 0.4, 0.1))
			_log_card_effect(card, player, effect_type, 0)
			return
		"faction_reveal_heal":
			_apply_faction_reveal_heal(card, player)
			_log_card_effect(card, player, effect_type, effect_value)
			return
		"give_equipment":
			# Special case: if no equipment, self-damage (no target needed)
			if player.equipment.is_empty():
				var died = player.take_damage(1)
				GameState.damage_dealt.emit(player, player, 1)
				damage_tracker.update_player_hp(player)
				if toast:
					toast.show_toast(Tr.t("toast.no_equipment_damage", [PlayerColors.get_label(player)]), Color(1.0, 0.3, 0.3))
				if died:
					GameState.player_died.emit(player, player)
				human_player_info.update_display()
				_log_card_effect(card, player, effect_type, effect_value)
				return

	# --- Targeted effects: human gets popup, bot uses smart targeting ---
	if player.is_human:
		_instant_card_pending = true
		_instant_card = card
		_instant_card_player = player
		var popup_info = _get_instant_card_popup_info(effect_type, card)
		var targets = popup_info.get("targets", _get_all_alive_others(player))
		target_selection_panel.show_targets(targets, popup_info.title, popup_info.button)
		return  # Resolution happens in _on_target_selected

	# Bot: smart targeting
	var target: Player = null
	if effect_type == "steal_equipment":
		target = _get_smart_card_target_with_equipment(player)
	else:
		target = _get_smart_card_target(player, effect_type)

	if target:
		_apply_instant_card_on_target(card, player, target)
	else:
		if toast:
			toast.show_toast(Tr.t("toast.no_targets"), Color(0.5, 0.5, 0.5))


## Get popup title and button text for human instant card targeting
func _get_instant_card_popup_info(effect_type: String, card: Card) -> Dictionary:
	var all_others = _get_all_alive_others(GameState.get_current_player())
	match effect_type:
		"heal_d6":
			# Blessing: can target self too
			var targets = all_others + [GameState.get_current_player()]
			return {"title": Tr.t("popup.heal_d6", [card.name]), "button": Tr.t("popup.btn_heal"), "targets": targets}
		"set_damage":
			var targets = all_others + [GameState.get_current_player()]
			return {"title": Tr.t("popup.set_damage", [card.name, card.get_effect_value()]), "button": Tr.t("popup.btn_apply"), "targets": targets}
		"vampire_drain":
			return {"title": Tr.t("popup.vampire_drain", [card.name]), "button": Tr.t("popup.btn_drain"), "targets": all_others}
		"mutual_damage":
			return {"title": Tr.t("popup.mutual_damage", [card.name]), "button": Tr.t("popup.btn_attack"), "targets": all_others}
		"self_damage_gamble":
			return {"title": Tr.t("popup.self_damage_gamble", [card.name]), "button": Tr.t("popup.btn_roll"), "targets": all_others}
		"steal_equipment":
			var equipped = all_others.filter(func(p): return not p.equipment.is_empty())
			if equipped.is_empty():
				return {"title": Tr.t("popup.no_equipment_steal", [card.name]), "button": Tr.t("popup.btn_ok"), "targets": all_others}
			return {"title": Tr.t("popup.steal_equipment", [card.name]), "button": Tr.t("popup.btn_steal"), "targets": equipped}
		"give_equipment":
			return {"title": Tr.t("popup.give_equipment", [card.name]), "button": Tr.t("popup.btn_give"), "targets": all_others}
		_:
			return {"title": card.name, "button": Tr.t("popup.btn_choose"), "targets": all_others}


## Apply a targeted instant card effect on a specific target
func _apply_instant_card_on_target(card: Card, player: Player, target: Player) -> void:
	var effect_type = card.get_effect_type()
	var effect_value = card.get_effect_value()
	var effect = card.effect

	# Talisman — target immune to black card damage effects
	if effect_type in ["vampire_drain", "mutual_damage", "self_damage_gamble"] and _has_active_equipment(target, "immunity_black_cards"):
		if toast:
			toast.show_toast(Tr.t("toast.talisman_protects", [PlayerColors.get_label(target)]), Color(0.3, 0.9, 0.5))
		human_player_info.update_display()
		_update_display()
		_log_card_effect(card, player, effect_type, effect_value)
		return

	match effect_type:
		"vampire_drain":
			var dmg = effect.get("damage", 2)
			var heal_amount = effect.get("heal", 1)
			var died = target.take_damage(dmg)
			GameState.damage_dealt.emit(player, target, dmg)
			damage_tracker.update_player_hp(target)
			player.heal(heal_amount)
			damage_tracker.update_player_hp(player)
			_play_heal_visual(player, heal_amount)
			if toast:
				toast.show_toast(Tr.t("toast.drain", [PlayerColors.get_label(player), PlayerColors.get_label(target), dmg, heal_amount]), Color(0.8, 0.2, 0.2))
			if died:
				GameState.player_died.emit(target, player)

		"mutual_damage":
			var dmg = effect.get("damage", 2)
			var self_dmg = effect.get("self_damage", 2)
			var target_died = target.take_damage(dmg)
			GameState.damage_dealt.emit(player, target, dmg)
			damage_tracker.update_player_hp(target)
			var self_died = player.take_damage(self_dmg)
			GameState.damage_dealt.emit(player, player, self_dmg)
			damage_tracker.update_player_hp(player)
			if toast:
				toast.show_toast(Tr.t("toast.mutual_damage", [PlayerColors.get_label(player), PlayerColors.get_label(target), dmg]), Color(0.8, 0.2, 0.2))
			if target_died:
				GameState.player_died.emit(target, player)
			if self_died:
				GameState.player_died.emit(player, player)

		"self_damage_gamble":
			var dmg = effect.get("damage", 3)
			var threshold = effect.get("threshold", 4)
			var roll = randi() % 6 + 1
			if roll <= threshold:
				var died = target.take_damage(dmg)
				GameState.damage_dealt.emit(player, target, dmg)
				damage_tracker.update_player_hp(target)
				if toast:
					toast.show_toast(Tr.t("toast.gamble_target", [roll, PlayerColors.get_label(target), dmg]), Color(0.8, 0.2, 0.2))
				if died:
					GameState.player_died.emit(target, player)
			else:
				var died = player.take_damage(dmg)
				GameState.damage_dealt.emit(player, player, dmg)
				damage_tracker.update_player_hp(player)
				if toast:
					toast.show_toast(Tr.t("toast.gamble_self", [roll, PlayerColors.get_label(player), dmg]), Color(1.0, 0.3, 0.3))
				if died:
					GameState.player_died.emit(player, player)

		"steal_equipment":
			if target and not target.equipment.is_empty():
				var stolen_card = target.equipment.pop_back()
				player.equipment.append(stolen_card)
				GameState.equipment_equipped.emit(player, stolen_card)
				if toast:
					toast.show_toast(Tr.t("toast.steals_equip", [PlayerColors.get_label(player), stolen_card.name, PlayerColors.get_label(target)]), Color(0.6, 0.2, 0.8))
			else:
				if toast:
					toast.show_toast(Tr.t("toast.no_equipment_to_steal"), Color(0.5, 0.5, 0.5))

		"give_equipment":
			if not player.equipment.is_empty():
				var given_card = player.equipment.pop_back()
				target.equipment.append(given_card)
				GameState.equipment_equipped.emit(target, given_card)
				if toast:
					toast.show_toast(Tr.t("toast.gives_equip", [PlayerColors.get_label(player), given_card.name, PlayerColors.get_label(target)]), Color(0.6, 0.6, 0.2))

		"set_damage":
			var target_damage = target.hp_max - target.hp
			if target_damage > effect_value:
				var heal_amount = target_damage - effect_value
				target.heal(heal_amount)
				_play_heal_visual(target, heal_amount)
			elif target_damage < effect_value:
				var dmg = effect_value - target_damage
				target.take_damage(dmg)
				GameState.damage_dealt.emit(player, target, dmg)
			damage_tracker.update_player_hp(target)
			if toast:
				toast.show_toast(Tr.t("toast.damage_fixed", [PlayerColors.get_label(target), effect_value]), Color(0.3, 0.8, 0.3))

		"heal_d6":
			var roll = randi() % 6 + 1
			target.heal(roll)
			damage_tracker.update_player_hp(target)
			_play_heal_visual(target, roll)
			if toast:
				toast.show_toast(Tr.t("toast.heal_roll", [roll, PlayerColors.get_label(target), roll]), Color(0.3, 0.8, 0.3))

	human_player_info.update_display()
	_update_display()
	_log_card_effect(card, player, effect_type, effect_value)


## Apply faction reveal heal effect (Advent/Diabolic Ritual/Chocolate)
func _apply_faction_reveal_heal(card: Card, player: Player) -> void:
	var effect = card.effect
	var can_use = false
	if effect.has("condition_factions"):
		can_use = player.faction in effect.get("condition_factions", [])
	elif effect.has("condition_type"):
		var cond_type = effect.get("condition_type", "")
		var cond_value = effect.get("condition_value", 0)
		if cond_type == "hp_max_lte":
			can_use = player.hp_max <= cond_value
		elif cond_type == "hp_max_gte":
			can_use = player.hp_max >= cond_value
	if can_use:
		if not player.is_revealed:
			player.reveal()
			GameState.character_revealed.emit(player, player.ability_data, player.faction)
		var healed = player.hp_max - player.hp
		player.heal(player.hp_max)
		damage_tracker.update_player_hp(player)
		if healed > 0:
			_play_heal_visual(player, healed)
		if toast:
			toast.show_toast(Tr.t("toast.reveal_full_heal", [PlayerColors.get_label(player)]), Color(1.0, 0.85, 0.2))
	else:
		if toast:
			toast.show_toast(Tr.t("toast.condition_not_met"), Color(0.5, 0.5, 0.5))
	human_player_info.update_display()


## Log card effect action
func _log_card_effect(card: Card, player: Player, effect_type: String, effect_value: int) -> void:
	GameState.log_action("card_effect_applied", {
		"player": player.display_name,
		"card": card.name,
		"effect_type": effect_type,
		"effect_value": effect_value
	})


# -----------------------------------------------------------------------------
# Vision Card System
# -----------------------------------------------------------------------------

## Start vision card flow: choose a player to apply the card's condition
func _start_vision_card(player: Player, card: Card, deck: DeckManager) -> void:
	_vision_pending = true
	_vision_card = card
	_vision_deck = deck

	# Get all alive players except current
	var targets: Array = []
	for p in GameState.players:
		if p != player and p.is_alive:
			targets.append(p)

	if targets.is_empty():
		_finish_vision_card(player)
		return

	target_selection_panel.show_targets(targets, Tr.t("popup.vision_title"), Tr.t("popup.vision_send"))


## Apply vision card condition after target is selected
func _resolve_vision_card(target: Player) -> void:
	var current_player = GameState.get_current_player()
	var effect = _vision_card.effect if _vision_card else {}
	var condition_factions: Array = effect.get("condition_factions", [])
	var condition_type: String = effect.get("condition_type", "")
	var action: String = effect.get("action", "")
	var value: int = effect.get("value", 0)

	# Check if condition is met
	var condition_met: bool = false
	if condition_type != "":
		# HP-based conditions (Bully, Tough Love)
		var cond_value: int = effect.get("condition_value", 0)
		match condition_type:
			"hp_max_lte":
				condition_met = target.hp_max <= cond_value
			"hp_max_gte":
				condition_met = target.hp_max >= cond_value
	elif not condition_factions.is_empty():
		# Faction-based conditions
		condition_met = target.faction in condition_factions

	if condition_met:
		# Condition matches — apply the effect
		match action:
			"damage_target":
				target.take_damage(value, current_player)
				if toast:
					toast.show_toast(Tr.t("toast.vision_trigger_damage", [target.display_name, value]), Color(1.0, 0.5, 0.5))
				damage_tracker.update_player_hp(target)
			"heal_drawer":
				current_player.heal(value)
				damage_tracker.update_player_hp(current_player)
				_play_heal_visual(current_player, value)
				if toast:
					toast.show_toast(Tr.t("toast.vision_trigger_heal", [current_player.display_name, value]), Color(0.5, 1.0, 0.5))
			"heal_or_damage":
				# Heal target if possible, otherwise damage them
				var current_damage = target.hp_max - target.hp
				if current_damage > 0:
					target.heal(value)
					_play_heal_visual(target, value)
					if toast:
						toast.show_toast(Tr.t("toast.vision_trigger_target_heal", [target.display_name, value]), Color(0.5, 1.0, 0.5))
				else:
					target.take_damage(value, current_player)
					if toast:
						toast.show_toast(Tr.t("toast.vision_trigger_max_damage", [target.display_name, value]), Color(1.0, 0.5, 0.5))
				damage_tracker.update_player_hp(target)
			"give_equipment_or_damage":
				# Target must give equipment to drawer or take damage
				if not target.equipment.is_empty():
					var given_card = target.equipment.pop_back()
					current_player.equipment.append(given_card)
					GameState.equipment_equipped.emit(current_player, given_card)
					if toast:
						toast.show_toast(Tr.t("toast.vision_trigger_give_equip", [target.display_name, given_card.name, current_player.display_name]), Color(1.0, 0.7, 0.2))
				else:
					target.take_damage(value, current_player)
					if toast:
						toast.show_toast(Tr.t("toast.vision_trigger_no_equip", [target.display_name, value]), Color(1.0, 0.5, 0.5))
					damage_tracker.update_player_hp(target)
			"reveal_to_drawer":
				# Target reveals character to drawer (info only)
				if toast:
					toast.show_toast(Tr.t("toast.vision_trigger_reveal", [target.display_name, target.character_name, target.faction]), Color(0.8, 0.6, 1.0))
			"steal_equipment":
				if not target.equipment.is_empty():
					var stolen_card = target.equipment.pop_back()
					current_player.equipment.append(stolen_card)
					GameState.equipment_equipped.emit(current_player, stolen_card)
					if toast:
						toast.show_toast(Tr.t("toast.vision_trigger_steal", [current_player.display_name, stolen_card.name, target.display_name]), Color(1.0, 0.7, 0.2))
				else:
					if toast:
						toast.show_toast(Tr.t("toast.vision_trigger_steal_none", [target.display_name]), Color(0.8, 0.6, 0.4))
			_:
				if toast:
					toast.show_toast(Tr.t("toast.vision_trigger_generic"), Color(0.8, 0.6, 1.0))
		print("[GameBoard] Vision condition matched for %s" % target.display_name)
	else:
		# Condition does not match — no effect
		if toast:
			toast.show_toast(Tr.t("toast.vision_no_match", [target.display_name]), Color(0.7, 0.7, 0.7))
		print("[GameBoard] Vision condition not matched for %s" % target.display_name)

	_update_display()
	_finish_vision_card(current_player)


## Clean up vision card state and continue turn
func _finish_vision_card(player: Player) -> void:
	# Discard the vision card
	if _vision_card and _vision_deck:
		_vision_deck.discard_card(_vision_card)
		_update_deck_displays()

	_vision_pending = false
	_vision_card = null
	_vision_deck = null

	has_drawn_this_turn = true
	_notify_tutorial("draw_card")
	SaveManager.track_action()

	# Show remaining actions
	if player.is_human:
		var target_count = get_valid_targets().size()
		human_player_info.update_after_draw(player, target_count, has_attacked_this_turn)


# -----------------------------------------------------------------------------
# Signal Handlers — Visual component updates
# -----------------------------------------------------------------------------

func _on_damage_dealt(_attacker: Player, victim: Player, _amount: int) -> void:
	damage_tracker.update_player_hp(victim)
	human_player_info.update_display()


func _on_character_revealed(player: Player, _character: Variant, _faction: String) -> void:
	await character_cards_row.reveal_character(player)


func _on_player_died(player: Player, _killer: Variant) -> void:
	damage_tracker.mark_player_dead(player)
	_update_dead_player_ui(player)
	character_cards_row.mark_dead(player)


# -----------------------------------------------------------------------------
# Bot Turn Execution
# -----------------------------------------------------------------------------

func _execute_bot_turn() -> void:
	if _game_ended:
		return
	var bot = GameState.get_current_player()
	if not bot or bot.is_human:
		return

	print("[GameBoard] Bot turn: %s" % bot.display_name)
	var bot_controller = BotController.new()
	bot_controller.bot_action_completed.connect(_on_bot_action_completed)
	await bot_controller.execute_bot_turn(bot, get_tree())

	print("[GameBoard] Bot turn complete, ending turn")
	_on_end_turn_pressed()


## Move a bot's visual token from its current zone to the target zone
func _move_bot_token(bot: Player, target_zone_id: String) -> void:
	var target_zone = _get_zone_by_id(target_zone_id)
	if target_zone == null:
		return

	# Find and remove token from whichever zone it's currently displayed in
	for zone in zones:
		for child in zone.token_container.get_children():
			if child.has_method("get_player") and child.get_player() == bot:
				zone.remove_player_token(bot)
				target_zone.add_player_token(bot)
				return


func _on_bot_action_completed(bot: Player, action_type: String, result: Variant) -> void:
	match action_type:
		"move":
			# Move the visual token to the new zone
			_move_bot_token(bot, result as String)
			var zone_data = ZoneData.get_zone_by_id(result) if result else {}
			var zone_name: String = zone_data.get("name", str(result))
			if toast:
				toast.show_toast("%s → %s" % [PlayerColors.get_label(bot), zone_name], PlayerColors.get_color(bot.id))  # Bot move - no key needed, simple format
			_update_display()

		"zone_effect":
			# Bot triggered a special zone effect (weird_woods / underworld / altar)
			if result is Dictionary:
				_apply_bot_zone_effect(bot, result)

		"vision":
			# Bot resolved a vision card
			if result is Dictionary:
				_apply_bot_vision_result(bot, result)

		"zone_action":
			if result is Card:
				var card: Card = result as Card
				if toast:
					toast.show_toast(Tr.t("toast.player_draws", [PlayerColors.get_label(bot), card.name]), PlayerColors.get_color(bot.id))
				if card.type == "instant":
					_apply_instant_card_effect(card, bot)
					var deck = GameState.get_deck_for_zone(bot.position_zone)
					if deck:
						deck.discard_card(card)
					_update_deck_displays()
				elif card.type == "equipment":
					bot.equipment.append(card)
					GameState.equipment_equipped.emit(bot, card)
					if card.faction_restriction != "" and bot.faction != card.faction_restriction:
						print("[GameBoard] Bot %s keeps %s (effect inactive — restricted to %s)" % [bot.display_name, card.name, card.faction_restriction])
				# Remove from hand (was added by HandManager)
				var hand_idx = bot.hand.find(card)
				if hand_idx >= 0:
					bot.hand.remove_at(hand_idx)
			elif result is Dictionary:
				var action = result.get("action", "")
				if action == "attack":
					var target: Player = result.get("target")
					var damage: int = result.get("damage", 0)
					var missed: bool = result.get("missed", false)
					if missed:
						if toast:
							toast.show_toast(Tr.t("toast.bot_attack_miss", [PlayerColors.get_label(bot), PlayerColors.get_label(target)]), Color(1.0, 0.6, 0.3))
					else:
						await _play_card_strike_animation(bot, target, damage)
						if toast:
							var msg = Tr.t("toast.bot_attack_hit", [PlayerColors.get_label(bot), damage, PlayerColors.get_label(target)])
							if not target.is_alive:
								msg += Tr.t("toast.dead")
							toast.show_toast(msg, Color(1.0, 0.5, 0.5))
						# Werewolf counterattack check
						await _check_werewolf_counterattack(target, bot)
						# Charles "Bloody Feast" re-attack check
						await _check_charles_reattack(bot, target)
					if target:
						damage_tracker.update_player_hp(target)
					_update_display()
				elif action == "reveal":
					if toast:
						toast.show_toast(Tr.t("toast.reveals", [PlayerColors.get_label(bot), bot.character_name]), Color(0.8, 0.6, 1.0))
					_update_display()
				elif action == "ability":
					var ability_name: String = bot.ability_data.get("name", "Ability")
					if toast:
						toast.show_toast(Tr.t("toast.uses_ability", [PlayerColors.get_label(bot), ability_name]), PlayerColors.get_color(bot.id))
					_update_display()


## Apply bot zone effect result (from BotController zone_effect action)
func _apply_bot_zone_effect(bot: Player, result: Dictionary) -> void:
	var effect_type: String = result.get("type", "")

	match effect_type:
		"damage_or_heal":
			# Fortune Brooch — immune to Weird Woods
			if bot.position_zone == "weird_woods" and _has_active_equipment(bot, "immunity_weird_woods"):
				print("[GameBoard] Bot %s — Fortune Brooch protects from Weird Woods" % bot.display_name)
				return
			var target: Player = result.get("target")
			var action: String = result.get("action", "")
			if target == null:
				return
			if action == "damage":
				var died = target.take_damage(2)
				GameState.damage_dealt.emit(bot, target, 2)
				if died:
					GameState.player_died.emit(target, bot)
				if toast:
					toast.show_toast(Tr.t("toast.weird_woods_damage", [PlayerColors.get_label(bot), PlayerColors.get_label(target)]), Color(1.0, 0.5, 0.5))
			elif action == "heal":
				target.heal(1)
				damage_tracker.update_player_hp(target)
				_play_heal_visual(target, 1)
				if toast:
					toast.show_toast(Tr.t("toast.weird_woods_heal", [PlayerColors.get_label(bot), PlayerColors.get_label(target)]), Color(0.5, 1.0, 0.5))

		"choose_deck":
			var deck_type: String = result.get("deck_type", "")
			var deck = _get_deck_by_type(deck_type)
			if deck and deck.get_card_count() > 0:
				var card = deck.draw_card()
				if card:
					_update_deck_displays()
					if toast:
						toast.show_toast(Tr.t("toast.bot_draws", [PlayerColors.get_label(bot), deck_type, card.name]), PlayerColors.get_color(bot.id))
					if card.type == "instant":
						_apply_instant_card_effect(card, bot)
						deck.discard_card(card)
						_update_deck_displays()
					elif card.type == "equipment":
						bot.equipment.append(card)
						GameState.equipment_equipped.emit(bot, card)
					elif card.type == "vision":
						# Vision from Underworld draw — resolve inline (bot already chose deck)
						pass  # BotController handles vision resolution separately
			else:
				if toast:
					toast.show_toast(Tr.t("toast.deck_type_empty", [deck_type]), Color(1.0, 0.6, 0.3))

		"steal_equipment":
			if result.get("skipped", false):
				if toast:
					toast.show_toast(Tr.t("toast.no_equipment_steal", [PlayerColors.get_label(bot)]), Color(0.5, 0.5, 0.5))
				return
			var target: Player = result.get("target")
			var card: Card = result.get("card")
			if target and card:
				var idx = target.equipment.find(card)
				if idx >= 0:
					target.equipment.remove_at(idx)
				bot.equipment.append(card)
				GameState.equipment_equipped.emit(bot, card)
				if toast:
					toast.show_toast(Tr.t("toast.steals_equip", [PlayerColors.get_label(bot), card.name, PlayerColors.get_label(target)]), Color(1.0, 0.7, 0.2))

	_update_display()


## Apply bot vision card result (from BotController vision action)
func _apply_bot_vision_result(bot: Player, result: Dictionary) -> void:
	if result.get("skipped", false):
		return

	var card: Card = result.get("card")
	var deck: DeckManager = result.get("deck")
	var target: Player = result.get("target")
	var condition_met: bool = result.get("condition_met", false)

	if card == null or target == null:
		return

	var effect: Dictionary = card.effect if card.effect is Dictionary else {}
	var action: String = effect.get("action", "")
	var value: int = effect.get("value", 0)

	if condition_met:
		match action:
			"damage_target":
				var died = target.take_damage(value, bot)
				GameState.damage_dealt.emit(bot, target, value)
				if died:
					GameState.player_died.emit(target, bot)
				if toast:
					toast.show_toast(Tr.t("toast.vision_damage", [PlayerColors.get_label(bot), value, PlayerColors.get_label(target)]), Color(1.0, 0.5, 0.5))
			"heal_drawer":
				bot.heal(value)
				damage_tracker.update_player_hp(bot)
				_play_heal_visual(bot, value)
				if toast:
					toast.show_toast(Tr.t("toast.vision_heal", [PlayerColors.get_label(bot), value]), Color(0.5, 1.0, 0.5))
			"heal_or_damage":
				var current_damage = target.hp_max - target.hp
				if current_damage > 0:
					target.heal(value)
					_play_heal_visual(target, value)
					if toast:
						toast.show_toast(Tr.t("toast.vision_target_heal", [PlayerColors.get_label(target), value]), Color(0.5, 1.0, 0.5))
				else:
					target.take_damage(value, bot)
					GameState.damage_dealt.emit(bot, target, value)
					if toast:
						toast.show_toast(Tr.t("toast.vision_target_damage", [PlayerColors.get_label(target), value]), Color(1.0, 0.5, 0.5))
				damage_tracker.update_player_hp(target)
			"give_equipment_or_damage":
				if not target.equipment.is_empty():
					var given_card = target.equipment.pop_back()
					bot.equipment.append(given_card)
					GameState.equipment_equipped.emit(bot, given_card)
					if toast:
						toast.show_toast(Tr.t("toast.vision_give_equip", [PlayerColors.get_label(target), given_card.name, PlayerColors.get_label(bot)]), Color(1.0, 0.7, 0.2))
				else:
					target.take_damage(value, bot)
					GameState.damage_dealt.emit(bot, target, value)
					if toast:
						toast.show_toast(Tr.t("toast.vision_target_damage", [PlayerColors.get_label(target), value]), Color(1.0, 0.5, 0.5))
					damage_tracker.update_player_hp(target)
			"reveal_to_drawer":
				if toast:
					toast.show_toast(Tr.t("toast.vision_reveal", [PlayerColors.get_label(bot), target.character_name, target.faction]), Color(0.8, 0.6, 1.0))
			"steal_equipment":
				if not target.equipment.is_empty():
					var stolen_card = target.equipment.pop_back()
					bot.equipment.append(stolen_card)
					GameState.equipment_equipped.emit(bot, stolen_card)
					if toast:
						toast.show_toast(Tr.t("toast.vision_steal", [PlayerColors.get_label(bot), stolen_card.name, PlayerColors.get_label(target)]), Color(1.0, 0.7, 0.2))
	else:
		if toast:
			toast.show_toast(Tr.t("toast.vision_no_effect", [PlayerColors.get_label(target)]), Color(0.7, 0.7, 0.7))

	# Discard vision card
	if card and deck:
		deck.discard_card(card)
		_update_deck_displays()

	# Remove from hand if still there
	var hand_idx = bot.hand.find(card)
	if hand_idx >= 0:
		bot.hand.remove_at(hand_idx)

	_update_display()


# -----------------------------------------------------------------------------
# Combat System
# -----------------------------------------------------------------------------

## Get valid attack targets for current player (same island/group of 2 zones)
func get_valid_targets() -> Array:
	var current_player = GameState.get_current_player()
	if current_player == null:
		return []

	var current_group = ZoneData.get_group_for_zone(current_player.position_zone, GameState.zone_positions)
	if current_group == -1:
		return []

	# Handgun — attack all zones EXCEPT own group
	var has_handgun = _has_active_equipment(current_player, "extended_range")

	var valid_targets = []
	for player in GameState.players:
		if player == current_player:
			continue
		if not player.is_alive:
			continue
		var player_group = ZoneData.get_group_for_zone(player.position_zone, GameState.zone_positions)
		if has_handgun:
			if player_group == current_group:
				continue  # Handgun inverts: skip same group
		else:
			if player_group != current_group:
				continue  # Normal: skip different group

		valid_targets.append(player)

	return valid_targets


## Handle reveal button click
func _on_reveal_pressed() -> void:
	var current_player = GameState.get_current_player()
	if current_player == null or current_player.is_revealed:
		return

	# Daniel cannot voluntarily reveal (only via Scream on character death)
	if current_player.character_id == "daniel":
		if toast:
			toast.show_toast(Tr.t("toast.daniel_cannot_reveal"), Color(1.0, 0.6, 0.3))
		return

	current_player.reveal()
	GameState.character_revealed.emit(current_player, null, current_player.faction)

	if toast:
		toast.show_toast(Tr.t("toast.reveals", [current_player.display_name, current_player.character_name]), Color(0.8, 0.6, 1.0))

	# Re-show action buttons with reveal now disabled
	var target_count = get_valid_targets().size()
	human_player_info.update_after_draw(current_player, target_count, has_attacked_this_turn)


## Handle ability button click
func _on_ability_pressed() -> void:
	var player = GameState.get_current_player()
	if not player or not player.is_revealed:
		return

	var check = GameState.active_ability_system.can_activate_ability(player)
	if not check.can_activate:
		if toast:
			toast.show_toast(check.reason, Color(1.0, 0.6, 0.3))
		return

	var char_id = player.character_id

	match char_id:
		"franklin":
			# Lightning: pick any player, roll d6 for damage
			_pending_ability = true
			target_selection_panel.show_targets(_get_all_alive_others(player), Tr.t("popup.lightning"), Tr.t("popup.lightning_btn"))
		"george":
			# Demolish: pick any player, roll d4 for damage
			_pending_ability = true
			target_selection_panel.show_targets(_get_all_alive_others(player), Tr.t("popup.demolish"), Tr.t("popup.demolish_btn"))
		"allie":
			# Mother's Love: full heal, no target needed
			GameState.active_ability_system.activate_ability(player, [])
			if toast:
				toast.show_toast(Tr.t("toast.mothers_love", [player.display_name]), Color(0.4, 1.0, 0.4))
			damage_tracker.update_player_hp(player)
			_refresh_action_buttons(player)
		"ellen":
			# Disable a revealed player's ability
			_pending_ability = true
			var targets = _get_revealed_with_abilities(player)
			if targets.is_empty():
				if toast:
					toast.show_toast(Tr.t("toast.no_ability_target"), Color(1.0, 0.6, 0.3))
				_pending_ability = false
				return
			target_selection_panel.show_targets(targets, Tr.t("popup.disable_ability"), Tr.t("popup.disable_btn"))
		"fuka":
			# Set any player's damage to exactly 7
			_pending_ability = true
			target_selection_panel.show_targets(_get_all_alive_others(player), Tr.t("popup.set_damage_7"), Tr.t("popup.btn_apply"))
		"gregor":
			# Shield self until next turn
			GameState.active_ability_system.activate_ability(player, [])
			if toast:
				toast.show_toast(Tr.t("toast.spectral_barrier", [player.display_name]), Color(0.4, 0.8, 1.0))
			_refresh_action_buttons(player)
		"wight":
			# Gain extra turns
			var result = GameState.active_ability_system.activate_ability(player, [])
			if result and toast:
				var extra = player.get_meta("extra_turns", 0)
				toast.show_toast(Tr.t("toast.extra_turns", [player.display_name, extra]), Color(0.7, 0.5, 1.0))
			_refresh_action_buttons(player)
		"ultra_soul":
			# Damage all players in Underworld
			var underworld_players = _get_players_in_zone("underworld", player)
			GameState.active_ability_system.activate_ability(player, underworld_players)
			if toast:
				toast.show_toast(Tr.t("toast.murder_ray", [underworld_players.size()]), Color(1.0, 0.3, 0.3))
			_update_display()
			_refresh_action_buttons(player)
		"agnes":
			# Swap target direction
			GameState.active_ability_system.activate_ability(player, [])
			if toast:
				toast.show_toast(Tr.t("toast.capriccio", [player.display_name]), Color(0.9, 0.5, 0.8))
			_refresh_action_buttons(player)
		_:
			if toast:
				toast.show_toast(Tr.t("toast.ability_unavailable"), Color(1.0, 0.6, 0.3))


## Resolve ability on selected target
func _resolve_ability_on_target(target: Player) -> void:
	_pending_ability = false
	var player = GameState.get_current_player()
	if player == null:
		return

	var success = GameState.active_ability_system.activate_ability(player, [target])

	if success:
		var char_id = player.character_id
		match char_id:
			"franklin":
				if toast:
					toast.show_toast(Tr.t("toast.lightning", [player.display_name, target.display_name]), Color(1.0, 1.0, 0.3))
				damage_tracker.update_player_hp(target)
			"george":
				if toast:
					toast.show_toast(Tr.t("toast.demolish", [player.display_name, target.display_name]), Color(1.0, 0.6, 0.2))
				damage_tracker.update_player_hp(target)
			"fuka":
				if toast:
					toast.show_toast(Tr.t("toast.set_damage_7", [player.display_name, target.display_name]), Color(1.0, 0.4, 0.6))
				damage_tracker.update_player_hp(target)
			"ellen":
				if toast:
					toast.show_toast(Tr.t("toast.curse_ability", [player.display_name, target.display_name]), Color(0.6, 0.2, 0.8))
	else:
		if toast:
			toast.show_toast(Tr.t("toast.ability_failed"), Color(1.0, 0.5, 0.3))

	_update_display()
	_refresh_action_buttons(player)


## Get all alive players except the given one
func _get_all_alive_others(player: Player) -> Array:
	var targets: Array = []
	for p in GameState.players:
		if p != player and p.is_alive:
			targets.append(p)
	return targets


## Check if player has an active equipment with the given effect type (faction OK)
func _has_active_equipment(player: Player, effect_type: String) -> bool:
	for card in player.equipment:
		if card.get_effect_type() == effect_type:
			if card.faction_restriction == "" or player.faction == card.faction_restriction:
				return true
	return false


## Get revealed players with active abilities (for Ellen's curse)
func _get_revealed_with_abilities(player: Player) -> Array:
	var targets: Array = []
	for p in GameState.players:
		if p == player or not p.is_alive or not p.is_revealed:
			continue
		if p.ability_data.is_empty() or p.ability_data.get("type", "") != "active":
			continue
		if p.ability_disabled:
			continue
		targets.append(p)
	return targets


## Get alive players in a specific zone (excluding the given player)
func _get_players_in_zone(zone_id: String, exclude: Player) -> Array:
	var targets: Array = []
	for p in GameState.players:
		if p == exclude or not p.is_alive:
			continue
		if p.position_zone == zone_id:
			targets.append(p)
	return targets


## Refresh action buttons after ability use
func _refresh_action_buttons(player: Player) -> void:
	var target_count = get_valid_targets().size()
	human_player_info.update_after_draw(player, target_count, has_attacked_this_turn)


## Handle attack button click
func _on_attack_button_pressed() -> void:
	var validation = validator.can_attack(self)
	if not validation.valid:
		error_message.show_error(validation.reason)
		return

	var valid_targets = get_valid_targets()
	if valid_targets.is_empty():
		error_message.show_error(Tr.t("validate.no_target"))
		return

	target_selection_panel.show_targets(valid_targets)


## Handle target selection
func _on_target_selected(target: Player) -> void:
	# Vision card mode: reveal target instead of attacking
	if _vision_pending:
		_resolve_vision_card(target)
		return

	# Instant card mode: apply targeted card effect
	if _instant_card_pending:
		var card = _instant_card
		var card_player = _instant_card_player
		_instant_card_pending = false
		_instant_card = null
		_instant_card_player = null
		_apply_instant_card_on_target(card, card_player, target)
		# Continue turn flow after card resolution
		has_drawn_this_turn = true
		SaveManager.track_action()
		if card_player.is_human:
			var target_count = get_valid_targets().size()
			human_player_info.update_after_draw(card_player, target_count, has_attacked_this_turn)
		return

	# Ability mode: resolve ability on target
	if _pending_ability:
		_resolve_ability_on_target(target)
		return

	var attacker = GameState.get_current_player()
	if attacker == null:
		push_error("[GameBoard] No current player found")
		return

	# Store target and show combat dice popup — result handled in _on_combat_roll_completed
	_combat_target = target
	dice_roll_popup.show_for_combat(attacker, target)


## Handle combat dice roll result — animate card strike and apply damage
func _on_combat_roll_completed(total_damage: int) -> void:
	var attacker = GameState.get_current_player()
	var target = _combat_target
	_combat_target = null

	if attacker == null or target == null:
		return

	if total_damage == 0:
		# Missed attack (D6 == D4)
		if toast:
			toast.show_toast(Tr.t("toast.attack_missed"), Color(1.0, 0.6, 0.3))
	else:
		# Play card strike animation
		await _play_card_strike_animation(attacker, target, total_damage)

		# Apply damage to game state
		var combat = CombatSystem.new()
		combat.apply_damage(attacker, target, total_damage)
		damage_tracker.update_player_hp(attacker)

		if not target.is_alive:
			_update_dead_player_ui(target)

		if toast:
			var msg = "%s inflige %d dégâts à %s" % [attacker.display_name, total_damage, target.display_name]
			if not target.is_alive:
				msg += " — Mort !"
			toast.show_toast(msg, Color(1.0, 0.5, 0.5))

		# Machine Gun — AoE attack: hit all other valid targets in attack zone
		if _has_active_equipment(attacker, "aoe_attack"):
			var aoe_targets = get_valid_targets()
			for aoe_target in aoe_targets:
				if aoe_target == target or not aoe_target.is_alive:
					continue
				await _play_card_strike_animation(attacker, aoe_target, total_damage)
				combat.apply_damage(attacker, aoe_target, total_damage)
				damage_tracker.update_player_hp(aoe_target)
				if not aoe_target.is_alive:
					_update_dead_player_ui(aoe_target)
				if toast:
					var aoe_msg = "Machine Gun : %s subit %d dégâts" % [aoe_target.display_name, total_damage]
					if not aoe_target.is_alive:
						aoe_msg += " — Mort !"
					toast.show_toast(aoe_msg, Color(1.0, 0.5, 0.5))

		# Werewolf counterattack check
		await _check_werewolf_counterattack(target, attacker)

		# Charles "Bloody Feast" re-attack check
		await _check_charles_reattack(attacker, target)

	_update_display()

	GameState.log_action("attack_performed", {
		"attacker": attacker.display_name,
		"target": target.display_name,
		"damage": total_damage,
		"target_hp_remaining": target.hp,
		"target_died": not target.is_alive
	})

	SaveManager.track_action()
	has_attacked_this_turn = true

	# Re-show action buttons (attack now disabled)
	var target_count = get_valid_targets().size()
	human_player_info.update_after_draw(attacker, target_count, has_attacked_this_turn)


## Update UI to show dead player state
func _update_dead_player_ui(player: Player) -> void:
	var zone = _get_zone_by_id(player.position_zone)
	if zone == null:
		return

	for child in zone.token_container.get_children():
		if child.has_method("get_player") and child.get_player() == player:
			child.mark_as_dead()
			break


## Find a player's token node in their current zone
func _find_player_token(player: Player) -> PlayerToken:
	var zone = _get_zone_by_id(player.position_zone)
	if zone == null:
		return null
	for child in zone.token_container.get_children():
		if child.has_method("get_player") and child.get_player() == player:
			return child
	return null


## Play card strike animation: attacker card lunges toward target card
func _play_card_strike_animation(attacker: Player, target: Player, damage: int) -> void:
	var attacker_card = character_cards_row.get_card_panel(attacker.id)
	var target_card = character_cards_row.get_card_panel(target.id)

	# Fallback if cards are unavailable
	if target_card == null:
		return

	var lunge_duration = PolishConfig.get_value("attack_lunge_duration", 0.15)
	var bounce_duration = PolishConfig.get_value("attack_bounce_duration", 0.25)

	AudioManager.play_sfx("attack_swing")

	if attacker_card:
		var original_pos = attacker_card.global_position
		var original_z = attacker_card.z_index
		attacker_card.z_index = 100

		var target_pos = target_card.global_position
		var direction = (target_pos - original_pos).normalized()
		var lunge_distance = original_pos.distance_to(target_pos) * 0.5
		var lunge_pos = original_pos + direction * lunge_distance

		# Wind-up + Lunge
		var lunge_tween = create_tween()
		lunge_tween.tween_property(attacker_card, "scale", Vector2(1.15, 1.15), 0.05)
		lunge_tween.tween_property(attacker_card, "global_position", lunge_pos, lunge_duration)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await lunge_tween.finished

		# Impact
		AudioManager.play_sfx("damage_hit")
		ParticlePool.spawn_particles("hit_impact", target_card.global_position + Vector2(50, 70))
		_show_floating_damage(target_card.global_position + Vector2(30, -10), damage)

		# Flash red on target card
		var flash_tween = create_tween()
		flash_tween.tween_property(target_card, "modulate", Color(1.5, 0.4, 0.4, 1.0), 0.1)
		flash_tween.tween_property(target_card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

		# Bounce back
		var bounce_tween = create_tween()
		bounce_tween.set_parallel(true)
		bounce_tween.tween_property(attacker_card, "global_position", original_pos, bounce_duration)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		bounce_tween.tween_property(attacker_card, "scale", Vector2(1.0, 1.0), bounce_duration)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

		await flash_tween.finished
		attacker_card.z_index = original_z
	else:
		# No attacker card — just flash the target
		AudioManager.play_sfx("damage_hit")
		ParticlePool.spawn_particles("hit_impact", target_card.global_position + Vector2(50, 70))
		_show_floating_damage(target_card.global_position + Vector2(30, -10), damage)

		var flash_tween = create_tween()
		flash_tween.tween_property(target_card, "modulate", Color(1.5, 0.4, 0.4, 1.0), 0.1)
		flash_tween.tween_property(target_card, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)
		await flash_tween.finished


## Show floating damage number that rises and fades out
func _show_floating_damage(world_pos: Vector2, damage: int) -> void:
	var label = Label.new()
	label.text = "-%d" % damage
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.global_position = world_pos + Vector2(-15, -20)
	label.z_index = 100
	add_child(label)

	var float_duration = PolishConfig.get_value("damage_float_duration", 0.8)
	var float_distance = PolishConfig.get_value("damage_float_distance", 80)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", world_pos.y - float_distance, float_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, float_duration * 0.6)\
		.set_delay(float_duration * 0.4)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


## Show floating heal number that rises and fades out
func _show_floating_heal(world_pos: Vector2, amount: int) -> void:
	var label = Label.new()
	label.text = "+%d" % amount
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 3)
	label.global_position = world_pos + Vector2(-15, -20)
	label.z_index = 100
	add_child(label)

	var float_duration = PolishConfig.get_value("damage_float_duration", 0.8)
	var float_distance = PolishConfig.get_value("damage_float_distance", 80)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", world_pos.y - float_distance, float_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, float_duration * 0.6)\
		.set_delay(float_duration * 0.4)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


## Play heal visual effects on a player's character card (particles + float number + green flash)
func _play_heal_visual(player: Player, amount: int) -> void:
	var card_panel = character_cards_row.get_card_panel(player.id)
	if card_panel == null:
		return

	var pos = card_panel.global_position

	_show_floating_heal(pos + Vector2(30, -10), amount)
	ParticlePool.spawn_particles("heal_sparkle", pos + Vector2(50, 70))

	if not AnimationOrchestrator.is_reduced_motion():
		var flash_tween = create_tween()
		flash_tween.tween_property(card_panel, "modulate", Color(0.4, 1.5, 0.4, 1.0), 0.1)
		flash_tween.tween_property(card_panel, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)


## Check for Charles "Bloody Feast" re-attack (2 self-damage to attack again)
func _check_charles_reattack(attacker: Player, target: Player) -> void:
	if not attacker.is_alive or not target.is_alive:
		return
	if attacker.character_id != "charles" or not attacker.is_revealed or attacker.ability_disabled:
		return

	# Decision: bot always re-attacks if HP > 4, human auto-re-attacks too
	# (Charles' identity is about aggression — 2 HP cost is the tradeoff)
	if attacker.hp <= 2:
		return  # Would kill self, skip

	if toast:
		toast.show_toast(Tr.t("toast.bloody_feast", [attacker.display_name]), Color(0.8, 0.3, 0.3))

	# Self-damage
	attacker.hp -= 2
	GameState.damage_dealt.emit(attacker, attacker, 2)
	damage_tracker.update_player_hp(attacker)

	if not attacker.is_alive:
		_update_dead_player_ui(attacker)
		return

	# Calculate re-attack damage
	var combat = CombatSystem.new()
	var result = combat.calculate_attack_damage(attacker, target)

	if result.missed:
		await get_tree().create_timer(0.5).timeout
		if toast:
			toast.show_toast(Tr.t("toast.reattack_missed"), Color(1.0, 0.6, 0.3))
	else:
		await _play_card_strike_animation(attacker, target, result.total)
		combat.apply_damage(attacker, target, result.total)
		if not target.is_alive:
			_update_dead_player_ui(target)
		damage_tracker.update_player_hp(target)
		if toast:
			var msg = "Bloody Feast — %d dégâts à %s" % [result.total, target.display_name]
			if not target.is_alive:
				msg += " — Mort !"
			toast.show_toast(msg, Color(0.8, 0.3, 0.3))
		_update_display()


## Trigger Werewolf counterattack if applicable
func _check_werewolf_counterattack(target: Player, attacker: Player) -> void:
	if not target.is_alive:
		return
	if target.character_id != "werewolf" or not target.is_revealed or target.ability_disabled:
		return

	if toast:
		toast.show_toast(Tr.t("toast.werewolf_counter"), Color(0.7, 0.4, 1.0))

	# Calculate counterattack damage (always automatic)
	var combat = CombatSystem.new()
	var result = combat.calculate_attack_damage(target, attacker)

	if result.missed:
		await get_tree().create_timer(0.5).timeout
		if toast:
			toast.show_toast(Tr.t("toast.counter_missed"), Color(1.0, 0.6, 0.3))
	else:
		await _play_card_strike_animation(target, attacker, result.total)
		combat.apply_damage(target, attacker, result.total)
		if not attacker.is_alive:
			_update_dead_player_ui(attacker)
		damage_tracker.update_player_hp(attacker)
		if toast:
			var msg = "Loup-Garou inflige %d dégâts à %s" % [result.total, attacker.display_name]
			if not attacker.is_alive:
				msg += " — Mort !"
			toast.show_toast(msg, Color(0.7, 0.4, 1.0))
		_update_display()


# -----------------------------------------------------------------------------
# Game Over Handler
# -----------------------------------------------------------------------------

func _on_game_over(winning_faction: String) -> void:
	if _game_ended:
		return
	_game_ended = true
	print("[GameBoard] Game Over! %s wins!" % winning_faction)

	# Hide action prompts
	human_player_info.hide_prompt()
	target_selection_panel.hide_panel()

	# Show victory toast
	if toast:
		toast.show_toast(Tr.t("toast.game_end", [winning_faction.capitalize()]), Color(1.0, 0.85, 0.0))

	# Wait for death/reveal animations to finish before transitioning
	await get_tree().create_timer(2.5).timeout

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
