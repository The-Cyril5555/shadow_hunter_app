## DiceRollPopup - Modal popup for dice rolling during MOVEMENT phase
## Shows dice, roll button, then zone choices after rolling
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
@onready var zone_choice_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ZoneChoiceContainer
@onready var zones_grid: GridContainer = $Panel/MarginContainer/VBoxContainer/ZoneChoiceContainer/ZonesGrid


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
	zone_choice_container.visible = false
	_clear_zone_choices()

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
	result_label.text = "Résultat : %d" % sum
	result_label.visible = true

	# Populate zone choices
	_populate_zone_choices(sum)


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

func _populate_zone_choices(dice_sum: int) -> void:
	_clear_zone_choices()

	if _current_player == null:
		return

	var current_zone_id = _current_player.position_zone
	var reachable_ids = ZoneData.get_reachable_zones(current_zone_id, dice_sum)

	if reachable_ids.is_empty():
		var no_zones_label = Label.new()
		no_zones_label.text = "Aucune zone accessible"
		no_zones_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zones_grid.add_child(no_zones_label)
	else:
		for zone_id in reachable_ids:
			var zone_data = ZoneData.get_zone_by_id(zone_id)
			var btn = Button.new()
			btn.text = zone_data.get("name", zone_id.capitalize())
			btn.custom_minimum_size = Vector2(180, 50)
			btn.add_theme_font_size_override("font_size", 16)

			# Add zone image as icon if available
			var texture = CardImageMapper.load_texture(CardImageMapper.get_zone_image_path(zone_id))
			if texture != null:
				btn.icon = texture
				btn.expand_icon = true
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT

			btn.pressed.connect(_on_zone_choice_pressed.bind(zone_id))
			zones_grid.add_child(btn)

	zone_choice_container.visible = true


func _on_zone_choice_pressed(zone_id: String) -> void:
	hide_popup()
	zone_selected.emit(zone_id)


func _clear_zone_choices() -> void:
	for child in zones_grid.get_children():
		child.queue_free()
