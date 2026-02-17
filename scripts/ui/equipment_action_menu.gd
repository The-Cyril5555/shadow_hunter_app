## EquipmentActionMenu - Popup menu for equipment card actions
## Shows Equip/Discard options when player clicks a card in hand
class_name EquipmentActionMenu
extends PanelContainer


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal action_selected(action: String, card: Card)


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var equip_button: Button = $MarginContainer/VBoxContainer/EquipButton
@onready var discard_button: Button = $MarginContainer/VBoxContainer/DiscardButton
@onready var card_name_label: Label = $MarginContainer/VBoxContainer/CardNameLabel


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var current_card: Card = null


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Start hidden
	visible = false

	# Connect buttons
	equip_button.pressed.connect(_on_equip_pressed)
	discard_button.pressed.connect(_on_discard_pressed)


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show menu for a specific card
func show_for_card(card: Card, at_position: Vector2) -> void:
	current_card = card
	card_name_label.text = card.name

	# Check faction restriction — disable equip if player can't use this card
	var current_player = GameState.get_current_player()
	if card.faction_restriction != "" and current_player and current_player.faction != card.faction_restriction:
		equip_button.disabled = true
		equip_button.tooltip_text = Tr.t("equip.restricted", [card.faction_restriction])
	else:
		equip_button.disabled = false
		equip_button.tooltip_text = ""

	# Position menu
	global_position = at_position

	# Show menu
	visible = true
	print("[EquipmentActionMenu] Showing menu for: %s" % card.name)


## Hide menu
func hide_menu() -> void:
	visible = false
	current_card = null


# -----------------------------------------------------------------------------
# Button Handlers
# -----------------------------------------------------------------------------

func _on_equip_pressed() -> void:
	if current_card:
		action_selected.emit("equip", current_card)
		hide_menu()


func _on_discard_pressed() -> void:
	if current_card:
		action_selected.emit("discard", current_card)
		hide_menu()
