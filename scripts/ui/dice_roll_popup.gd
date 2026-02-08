## DiceRollPopup - Modal popup for dice rolling during MOVEMENT phase
## Shows dice, roll button, then auto-moves to the destination zone.
class_name DiceRollPopup
extends Control


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal zone_selected(zone_id: String)


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var player_info_label: Label = $Panel/MarginContainer/VBoxContainer/PlayerInfoLabel
@onready var dice: Dice = $Panel/MarginContainer/VBoxContainer/DiceContainer/Dice
@onready var roll_button: Button = $Panel/MarginContainer/VBoxContainer/RollButton
@onready var result_label: Label = $Panel/MarginContainer/VBoxContainer/ResultLabel


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var _current_player: Player = null
var _dice_result: int = 0


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	roll_button.pressed.connect(_on_roll_pressed)
	dice.dice_rolled.connect(_on_dice_result)


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show the popup for a player's movement phase
func show_for_player(player: Player) -> void:
	_current_player = player
	_dice_result = 0

	# Populate info
	title_label.text = "Votre tour — Lancez les dés"
	player_info_label.text = "%s | Zone : %s" % [player.display_name, player.position_zone.capitalize()]

	# Reset state
	roll_button.visible = true
	roll_button.disabled = false
	result_label.visible = false

	# Show with fade
	visible = true
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


## Hide the popup with fade
func hide_popup() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	visible = false


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------

func _on_roll_pressed() -> void:
	roll_button.disabled = true
	dice.roll()


func _on_dice_result(sum: int) -> void:
	_dice_result = sum
	roll_button.visible = false

	# Determine destination zone from dice sum
	var dest_zone_id = ZoneData.get_zone_for_dice_sum(sum, GameState.zone_positions)
	var zone_data = ZoneData.get_zone_by_id(dest_zone_id) if dest_zone_id != "" else {}
	var zone_name = zone_data.get("name", "???")

	result_label.text = "Résultat : %d → %s" % [sum, zone_name]
	result_label.visible = true

	# Auto-close and emit after a short delay
	await get_tree().create_timer(1.2).timeout
	hide_popup()
	if dest_zone_id != "":
		zone_selected.emit(dest_zone_id)
