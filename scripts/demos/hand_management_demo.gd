## HandManagementDemo - Demo for testing hand management system
## Tests adding cards, drawing, discarding, and hand queries
class_name HandManagementDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var system_label: Label = $VBoxContainer/SystemLabel
@onready var init_player_button: Button = $VBoxContainer/TestButtons/InitPlayerButton
@onready var draw_to_hand_button: Button = $VBoxContainer/TestButtons/DrawToHandButton
@onready var add_card_button: Button = $VBoxContainer/TestButtons/AddCardButton
@onready var discard_card_button: Button = $VBoxContainer/TestButtons/DiscardCardButton
@onready var get_equipment_button: Button = $VBoxContainer/TestButtons/GetEquipmentButton
@onready var clear_hand_button: Button = $VBoxContainer/TestButtons/ClearHandButton
@onready var hand_label: Label = $VBoxContainer/HandLabel
@onready var deck_status_label: Label = $VBoxContainer/DeckStatusLabel
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var test_player: Player = null
var test_deck: DeckManager = null
var decks: Dictionary = {}  # {"white": DeckManager, "black": DeckManager}


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect buttons
	init_player_button.pressed.connect(_on_init_player_pressed)
	draw_to_hand_button.pressed.connect(_on_draw_to_hand_pressed)
	add_card_button.pressed.connect(_on_add_card_pressed)
	discard_card_button.pressed.connect(_on_discard_card_pressed)
	get_equipment_button.pressed.connect(_on_get_equipment_pressed)
	clear_hand_button.pressed.connect(_on_clear_hand_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_status_labels()

	print("[HandManagementDemo] Demo ready")


# -----------------------------------------------------------------------------
# Test Handlers
# -----------------------------------------------------------------------------
func _on_init_player_pressed() -> void:
	print("\n[Demo] Initializing test player and deck")

	# Create test player
	test_player = Player.new()
	test_player.display_name = "TestPlayer"
	test_player.hand = []

	# Create test deck (White deck)
	test_deck = DeckManager.new()
	test_deck.deck_type = "white"

	var white_cards_data = [
		{
			"id": "white_holy_water",
			"name": "Eau Bénite",
			"deck": "white",
			"type": "instant",
			"copies_in_deck": 3,
			"effect": {"type": "heal", "value": 2, "description": "Soigne 2 HP."}
		},
		{
			"id": "white_first_aid",
			"name": "First Aid",
			"deck": "white",
			"type": "instant",
			"copies_in_deck": 2,
			"effect": {"type": "set_damage", "value": 7, "description": "Set damage to 7."}
		},
		{
			"id": "white_spear_longinus",
			"name": "Lance de Longinus",
			"deck": "white",
			"type": "equipment",
			"copies_in_deck": 1,
			"faction_restriction": "hunter",
			"effect": {"type": "damage", "value": 2, "description": "Attack +2."}
		}
	]

	test_deck.initialize_from_data(white_cards_data)

	# Create Black deck for discard testing
	var black_deck = DeckManager.new()
	black_deck.deck_type = "black"

	var black_cards_data = [
		{
			"id": "black_chainsaw",
			"name": "Chainsaw",
			"deck": "black",
			"type": "equipment",
			"copies_in_deck": 2,
			"effect": {"type": "damage", "value": 1, "description": "Attack +1."}
		}
	]

	black_deck.initialize_from_data(black_cards_data)

	# Setup decks dictionary for discard routing
	decks = {
		"white": test_deck,
		"black": black_deck
	}

	print("  Created player: %s" % test_player.display_name)
	print("  Created White deck: %d cards" % test_deck.get_card_count())
	print("  Created Black deck: %d cards" % black_deck.get_card_count())

	_update_status_labels()


func _on_draw_to_hand_pressed() -> void:
	if not test_player or not test_deck:
		print("\n[Demo] ❌ No player or deck initialized!")
		return

	print("\n[Demo] Drawing card to hand")

	var card = HandManager.draw_to_hand(test_player, test_deck)

	if card:
		print("  Drew: %s" % card.name)
		print("  Hand size: %d" % HandManager.get_hand_size(test_player))
	else:
		print("  ❌ Deck exhausted!")

	_update_status_labels()


func _on_add_card_pressed() -> void:
	if not test_player:
		print("\n[Demo] ❌ No player initialized!")
		return

	print("\n[Demo] Adding manual card to hand")

	# Create a test card manually
	var card = Card.new()
	card.id = "test_card"
	card.name = "Test Card"
	card.deck = "white"
	card.type = "equipment"
	card.effect = {"type": "damage", "value": 1, "description": "Test effect"}

	var success = HandManager.add_to_hand(test_player, card)

	if success:
		print("  Added: %s" % card.name)
		print("  Hand size: %d" % HandManager.get_hand_size(test_player))
	else:
		print("  ❌ Failed to add card!")

	_update_status_labels()


func _on_discard_card_pressed() -> void:
	if not test_player:
		print("\n[Demo] ❌ No player initialized!")
		return

	if not HandManager.has_cards(test_player):
		print("\n[Demo] ❌ Hand is empty, nothing to discard!")
		return

	print("\n[Demo] Discarding first card from hand")

	var card = test_player.hand[0]
	var card_name = card.name
	var deck_type = card.deck

	var success = HandManager.discard_from_hand(test_player, card, decks)

	if success:
		print("  Discarded: %s to %s deck" % [card_name, deck_type])
		print("  Hand size: %d" % HandManager.get_hand_size(test_player))
		print("  %s discard pile: %d cards" % [deck_type, decks[deck_type].get_discard_count()])
	else:
		print("  ❌ Failed to discard!")

	_update_status_labels()


func _on_get_equipment_pressed() -> void:
	if not test_player:
		print("\n[Demo] ❌ No player initialized!")
		return

	print("\n[Demo] Getting equipment cards from hand")

	var equipment = HandManager.get_equipment_cards(test_player)

	print("  Equipment cards: %d" % equipment.size())
	for card in equipment:
		print("    - %s (%s)" % [card.name, card.get_effect_description()])

	_update_status_labels()


func _on_clear_hand_pressed() -> void:
	if not test_player:
		print("\n[Demo] ❌ No player initialized!")
		return

	print("\n[Demo] Clearing hand")

	HandManager.clear_hand(test_player)

	_update_status_labels()


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_status_labels() -> void:
	if not test_player:
		hand_label.text = "Player Hand:\n\nNo player initialized\n\nClick 'Initialize Player & Deck' to start"
		deck_status_label.text = "Deck Status: (not initialized)"
		return

	# Update hand display
	var hand_text = "Player Hand: %s\n" % test_player.display_name
	hand_text += "\nHand Size: %d cards\n" % HandManager.get_hand_size(test_player)

	if test_player.hand.is_empty():
		hand_text += "\n(empty)"
	else:
		hand_text += "\nCards:"
		for i in range(test_player.hand.size()):
			var card = test_player.hand[i]
			hand_text += "\n  %d. %s [%s] (%s)" % [
				i + 1,
				card.name,
				card.deck,
				card.get_effect_description()
			]

	# Count equipment
	var equipment_count = HandManager.get_equipment_cards(test_player).size()
	hand_text += "\n\nEquipment cards: %d" % equipment_count

	hand_label.text = hand_text

	# Update deck status
	if not test_deck:
		deck_status_label.text = "Deck Status: (not initialized)"
		return

	var deck_text = "Deck Status:\n"
	deck_text += "\nWhite Deck:"
	deck_text += "\n  Draw pile: %d cards" % test_deck.get_card_count()
	deck_text += "\n  Discard pile: %d cards" % test_deck.get_discard_count()

	if decks.has("black"):
		deck_text += "\n\nBlack Deck:"
		deck_text += "\n  Draw pile: %d cards" % decks["black"].get_card_count()
		deck_text += "\n  Discard pile: %d cards" % decks["black"].get_discard_count()

	deck_status_label.text = deck_text
