## HumanPlayerInfo - Bottom panel showing the local human player's info
## Always displays the human player (not the current turn player).
class_name HumanPlayerInfo
extends PanelContainer


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal hand_card_clicked(card: Card)


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var player_label: Label = $MarginContainer/HBoxContainer/PlayerLabel
@onready var character_image: TextureRect = $MarginContainer/HBoxContainer/CharacterImage
@onready var hp_label: Label = $MarginContainer/HBoxContainer/InfoVBox/HPLabel
@onready var hand_container: HBoxContainer = $MarginContainer/HBoxContainer/InfoVBox/HandContainer
@onready var equipment_container: HBoxContainer = $MarginContainer/HBoxContainer/InfoVBox/EquipmentContainer


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var _player: Player = null


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Set the human player to display (called once at game start)
func setup(player: Player) -> void:
	if player == null:
		visible = false
		return
	_player = player
	visible = true
	update_display()


## Get the tracked player
func get_player() -> Player:
	return _player


## Refresh all display elements
func update_display() -> void:
	if _player == null:
		return

	# Player label with color
	player_label.text = PlayerColors.get_label(_player)
	player_label.add_theme_color_override("font_color", PlayerColors.get_color(_player.id))

	# Character image (always shown face-up for the local player)
	var char_path = CardImageMapper.get_character_image_path(_player.character_id)
	var texture = CardImageMapper.load_texture(char_path)
	if texture:
		character_image.texture = texture
		character_image.visible = true
	else:
		character_image.visible = false

	# HP
	hp_label.text = "HP: %d/%d" % [_player.hp, _player.hp_max]
	if _player.hp <= _player.hp_max * 0.3:
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif _player.hp <= _player.hp_max * 0.6:
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		hp_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))

	# Hand cards
	_update_hand()

	# Equipment
	_update_equipment()


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

## Rebuild hand card buttons
func _update_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()

	if _player.hand.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Pas de carte"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hand_container.add_child(empty_label)
		return

	for card in _player.hand:
		var btn = Button.new()
		btn.text = card.name
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = card.get_effect_description() if card.has_method("get_effect_description") else card.name
		btn.pressed.connect(func(): hand_card_clicked.emit(card))
		hand_container.add_child(btn)


## Rebuild equipment display
func _update_equipment() -> void:
	for child in equipment_container.get_children():
		child.queue_free()

	if _player.equipment.is_empty():
		var empty_label = Label.new()
		empty_label.text = "Aucun"
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		equipment_container.add_child(empty_label)
		return

	for card in _player.equipment:
		var label = Label.new()
		label.text = card.name
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		equipment_container.add_child(label)
