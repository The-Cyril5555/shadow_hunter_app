## DeckManagementDemo - Demo for testing deck management system
## Tests initialization, shuffling, drawing, discarding, and reshuffling
class_name DeckManagementDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var system_label: Label = $VBoxContainer/SystemLabel
@onready var init_deck_button: Button = $VBoxContainer/TestButtons/InitDeckButton
@onready var shuffle_button: Button = $VBoxContainer/TestButtons/ShuffleButton
@onready var draw_card_button: Button = $VBoxContainer/TestButtons/DrawCardButton
@onready var draw_5_button: Button = $VBoxContainer/TestButtons/Draw5Button
@onready var discard_all_button: Button = $VBoxContainer/TestButtons/DiscardAllButton
@onready var reshuffle_button: Button = $VBoxContainer/TestButtons/ReshuffleButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var drawn_cards_label: Label = $VBoxContainer/DrawnCardsLabel
@onready var back_button: Button = $VBoxContainer/BackButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var test_deck: DeckManager = null
var drawn_cards: Array[Card] = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect buttons
	init_deck_button.pressed.connect(_on_init_deck_pressed)
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	draw_card_button.pressed.connect(_on_draw_card_pressed)
	draw_5_button.pressed.connect(_on_draw_5_pressed)
	discard_all_button.pressed.connect(_on_discard_all_pressed)
	reshuffle_button.pressed.connect(_on_reshuffle_pressed)
	back_button.pressed.connect(_on_back_pressed)

	_update_status_labels()

	print("[DeckManagementDemo] Demo ready")


# -----------------------------------------------------------------------------
# Test Handlers
# -----------------------------------------------------------------------------
func _on_init_deck_pressed() -> void:
	print("\n[Demo] Initializing test deck with sample cards")

	# Create test deck
	test_deck = DeckManager.new()
	test_deck.deck_type = "test"

	# Connect signals
	test_deck.card_drawn.connect(_on_card_drawn)
	test_deck.deck_reshuffled.connect(_on_deck_reshuffled)
	test_deck.deck_exhausted.connect(_on_deck_exhausted)

	# Create sample card data (simplified White deck cards)
	var test_cards_data = [
		{
			"id": "holy_water",
			"name": "Holy Water",
			"deck": "white",
			"type": "equipment",
			"effect": "damage",
			"value": 1,
			"copies_in_deck": 3
		},
		{
			"id": "first_aid",
			"name": "First Aid",
			"deck": "white",
			"type": "equipment",
			"effect": "heal",
			"value": 2,
			"copies_in_deck": 2
		},
		{
			"id": "holy_robe",
			"name": "Holy Robe",
			"deck": "white",
			"type": "equipment",
			"effect": "defense",
			"value": 1,
			"copies_in_deck": 2
		},
		{
			"id": "talisman",
			"name": "Talisman",
			"deck": "white",
			"type": "equipment",
			"effect": "damage",
			"value": 2,
			"copies_in_deck": 1
		}
	]

	# Initialize deck
	test_deck.initialize_from_data(test_cards_data)

	# Clear drawn cards
	drawn_cards.clear()

	print("  Total cards in deck: %d" % test_deck.get_card_count())
	print("  Cards: 3x Holy Water, 2x First Aid, 2x Holy Robe, 1x Talisman")

	_update_status_labels()


func _on_shuffle_pressed() -> void:
	if not test_deck:
		print("\n[Demo] ❌ No deck initialized!")
		return

	print("\n[Demo] Shuffling deck")

	# Show first 3 cards before shuffle
	print("  First 3 cards before shuffle:")
	for i in range(min(3, test_deck.draw_pile.size())):
		var card = test_deck.draw_pile[i]
		print("    %d: %s" % [i + 1, card.name])

	test_deck.shuffle_draw_pile()

	# Show first 3 cards after shuffle
	print("  First 3 cards after shuffle:")
	for i in range(min(3, test_deck.draw_pile.size())):
		var card = test_deck.draw_pile[i]
		print("    %d: %s" % [i + 1, card.name])

	_update_status_labels()


func _on_draw_card_pressed() -> void:
	if not test_deck:
		print("\n[Demo] ❌ No deck initialized!")
		return

	print("\n[Demo] Drawing 1 card")

	var card = test_deck.draw_card()

	if card:
		drawn_cards.append(card)
		print("  Drew: %s (type: %s, effect: %s +%d)" % [
			card.name,
			card.type,
			card.effect,
			card.value
		])
	else:
		print("  ❌ Deck exhausted!")

	_update_status_labels()


func _on_draw_5_pressed() -> void:
	if not test_deck:
		print("\n[Demo] ❌ No deck initialized!")
		return

	print("\n[Demo] Drawing 5 cards")

	for i in range(5):
		var card = test_deck.draw_card()
		if card:
			drawn_cards.append(card)
			print("  %d: Drew %s" % [i + 1, card.name])
		else:
			print("  %d: ❌ Deck exhausted!" % (i + 1))
			break

	_update_status_labels()


func _on_discard_all_pressed() -> void:
	if not test_deck:
		print("\n[Demo] ❌ No deck initialized!")
		return

	print("\n[Demo] Discarding all drawn cards (%d cards)" % drawn_cards.size())

	for card in drawn_cards:
		test_deck.discard_card(card)
		print("  Discarded: %s" % card.name)

	drawn_cards.clear()

	_update_status_labels()


func _on_reshuffle_pressed() -> void:
	if not test_deck:
		print("\n[Demo] ❌ No deck initialized!")
		return

	print("\n[Demo] Manually reshuffling discard pile into deck")
	print("  Discard pile before: %d cards" % test_deck.get_discard_count())

	test_deck.reshuffle_discard_into_deck()

	print("  Discard pile after: %d cards" % test_deck.get_discard_count())
	print("  Draw pile after: %d cards" % test_deck.get_card_count())

	_update_status_labels()


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------
func _on_card_drawn(card: Card) -> void:
	print("[Demo] 📤 card_drawn signal: %s" % card.name)


func _on_deck_reshuffled() -> void:
	print("[Demo] 🔄 deck_reshuffled signal emitted")


func _on_deck_exhausted() -> void:
	print("[Demo] 🚫 deck_exhausted signal emitted")


func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_status_labels() -> void:
	if not test_deck:
		status_label.text = "Deck State:\n\nNo deck initialized\n\nClick 'Initialize Test Deck' to start"
		drawn_cards_label.text = "Drawn Cards: 0"
		return

	var status_text = "Deck State:\n"
	status_text += "\nDraw Pile: %d cards" % test_deck.get_card_count()
	status_text += "\nDiscard Pile: %d cards" % test_deck.get_discard_count()
	status_text += "\n\nDraw Pile Contents:"

	if test_deck.draw_pile.is_empty():
		status_text += "\n  (empty)"
	else:
		var card_counts = {}
		for card in test_deck.draw_pile:
			if card_counts.has(card.name):
				card_counts[card.name] += 1
			else:
				card_counts[card.name] = 1

		for card_name in card_counts:
			status_text += "\n  %dx %s" % [card_counts[card_name], card_name]

	status_label.text = status_text

	# Update drawn cards
	var drawn_text = "Drawn Cards: %d" % drawn_cards.size()
	if not drawn_cards.is_empty():
		drawn_text += "\n"
		for card in drawn_cards:
			drawn_text += "\n- %s" % card.name

	drawn_cards_label.text = drawn_text
