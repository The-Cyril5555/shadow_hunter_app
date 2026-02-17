## HumanPlayerInfo - Bottom panel showing the local human player's info
## Always displays the human player (not the current turn player).
class_name HumanPlayerInfo
extends PanelContainer


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal hand_card_clicked(card: Card)
signal action_chosen(action: String)  # "reveal", "ability", "attack", "end_turn"


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var player_label: Label = $MarginContainer/HBoxContainer/PlayerLabel
@onready var character_image: TextureRect = $MarginContainer/HBoxContainer/CharacterImage
@onready var hp_label: Label = $MarginContainer/HBoxContainer/InfoVBox/HPLabel
@onready var hand_container: HBoxContainer = $MarginContainer/HBoxContainer/InfoVBox/HandContainer
@onready var equipment_container: HBoxContainer = $MarginContainer/HBoxContainer/InfoVBox/EquipmentContainer

# Action buttons
@onready var reveal_button: Button = $MarginContainer/HBoxContainer/ButtonGrid/RevealButton
@onready var ability_button: Button = $MarginContainer/HBoxContainer/ButtonGrid/AbilityButton
@onready var attack_button: Button = $MarginContainer/HBoxContainer/ButtonGrid/AttackButton
@onready var end_turn_button: Button = $MarginContainer/HBoxContainer/ButtonGrid/EndTurnButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var _player: Player = null
var _card_bg_texture: Texture2D = null
var _bg_rect: TextureRect = null
var _card_container: Control = null
var _shine_overlay: ColorRect = null
var _float_tween: Tween = null


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------

func _ready() -> void:
	# Connect button signals
	reveal_button.pressed.connect(func(): action_chosen.emit("reveal"))
	ability_button.pressed.connect(func(): action_chosen.emit("ability"))
	attack_button.pressed.connect(func(): action_chosen.emit("attack"))
	end_turn_button.pressed.connect(func(): action_chosen.emit("end_turn"))

	# Add icons to buttons
	reveal_button.icon = IconLoader.get_icon("reveal")
	ability_button.icon = IconLoader.get_icon("ability")
	attack_button.icon = IconLoader.get_icon("attack")
	end_turn_button.icon = IconLoader.get_icon("end_turn")

	# Configure icon alignment
	for btn in [reveal_button, ability_button, attack_button, end_turn_button]:
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = true

	# Start disabled
	_set_disabled(true)


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

	# Load card background and insert behind character image
	_card_bg_texture = CardImageMapper.load_texture("res://remake character/card_background.png")
	if _card_bg_texture and character_image:
		var parent = character_image.get_parent()
		var idx = character_image.get_index()
		var card_size = character_image.custom_minimum_size
		if card_size == Vector2.ZERO:
			card_size = Vector2(80, 112)

		# Create container to hold bg + character + shine
		_card_container = Control.new()
		_card_container.custom_minimum_size = card_size
		_card_container.pivot_offset = card_size / 2.0

		# Remove character_image from parent and re-add inside container
		parent.remove_child(character_image)
		parent.add_child(_card_container)
		parent.move_child(_card_container, idx)

		# Background layer
		_bg_rect = TextureRect.new()
		_bg_rect.texture = _card_bg_texture
		_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_card_container.add_child(_bg_rect)

		# Character layer on top
		character_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_card_container.add_child(character_image)

		# Shine overlay for 3D tilt effect
		_shine_overlay = ColorRect.new()
		_shine_overlay.color = Color(0, 0, 0, 0)
		_shine_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shine_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shine_shader = load("res://assets/shaders/card_3d_tilt.gdshader") as Shader
		if shine_shader:
			var mat = ShaderMaterial.new()
			mat.shader = shine_shader
			_shine_overlay.material = mat
		_card_container.add_child(_shine_overlay)

		# Connect hover signals
		_card_container.mouse_entered.connect(_on_card_hover_enter)
		_card_container.mouse_exited.connect(_on_card_hover_exit)
		_card_container.gui_input.connect(_on_card_gui_input)
		_card_container.mouse_filter = Control.MOUSE_FILTER_STOP

		# Start floating
		_float_tween = AnimationHelper.start_floating(_card_container)

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
		empty_label.text = Tr.t("info.no_card")
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
		empty_label.text = Tr.t("info.no_equipment")
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		equipment_container.add_child(empty_label)
		return

	for card in _player.equipment:
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(60, 84)
		panel.tooltip_text = "%s\n%s" % [card.name, card.get_effect_description()]
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.12, 0.1, 0.9)
		style.set_border_width_all(1)
		style.border_color = Color(1.0, 0.85, 0.2)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)

		var tex_rect = TextureRect.new()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(60, 84)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var texture = CardImageMapper.load_texture(CardImageMapper.get_card_image_path(card))
		if texture:
			tex_rect.texture = texture
		panel.add_child(tex_rect)
		equipment_container.add_child(panel)


# -----------------------------------------------------------------------------
# 3D Tilt Effect Handlers
# -----------------------------------------------------------------------------

func _on_card_hover_enter() -> void:
	if _card_container == null:
		return
	var tween = _card_container.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_card_container, "scale", Vector2(1.08, 1.08), 0.2)
	if _shine_overlay and _shine_overlay.material:
		_shine_overlay.material.set_shader_parameter("active", true)


func _on_card_hover_exit() -> void:
	if _card_container == null:
		return
	var tween = _card_container.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_card_container, "scale", Vector2(1.0, 1.0), 0.25)
	tween.tween_property(_card_container, "rotation", 0.0, 0.25)
	if _shine_overlay and _shine_overlay.material:
		_shine_overlay.material.set_shader_parameter("active", false)


func _on_card_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion or _card_container == null:
		return
	var local_pos = _card_container.get_local_mouse_position()
	var card_size = _card_container.custom_minimum_size
	var tilt_x = clampf((local_pos.x / card_size.x - 0.5) * 2.0, -1.0, 1.0)
	var tilt_y = clampf((local_pos.y / card_size.y - 0.5) * 2.0, -1.0, 1.0)
	_card_container.rotation = lerpf(_card_container.rotation, -tilt_x * deg_to_rad(4.0), 0.3)
	if _shine_overlay and _shine_overlay.material:
		_shine_overlay.material.set_shader_parameter("tilt", Vector2(tilt_x, tilt_y))


# -----------------------------------------------------------------------------
# Action Button Management
# -----------------------------------------------------------------------------

## Enable buttons after card draw (action phase)
func show_action_prompt(player: Player, _can_draw: bool, _deck_type: String, target_count: int, has_attacked: bool = false) -> void:
	_update_buttons(player, target_count, has_attacked)


## Enable buttons after card draw
func update_after_draw(player: Player, target_count: int, has_attacked: bool = false) -> void:
	_update_buttons(player, target_count, has_attacked)


## Disable buttons during bot turns
func show_waiting_prompt(_player_name: String) -> void:
	_set_disabled(true)


## Disable buttons during movement phase
func show_movement_prompt(_player: Player) -> void:
	_set_disabled(true)


## Disable buttons (end of turn)
func hide_prompt() -> void:
	_set_disabled(true)


func _update_buttons(player: Player, target_count: int, has_attacked: bool) -> void:
	# Daniel cannot voluntarily reveal (only via Scream on character death)
	reveal_button.disabled = player.is_revealed or player.character_id == "daniel"
	_update_ability_button(player)
	attack_button.disabled = target_count == 0 or has_attacked
	attack_button.text = Tr.t("action.attack_n", [target_count]) if target_count > 0 and not has_attacked else Tr.t("action.attack")
	end_turn_button.disabled = false


func _update_ability_button(player: Player) -> void:
	# Must be revealed and have an active ability
	if not player.is_revealed:
		ability_button.disabled = true
		ability_button.text = Tr.t("action.ability")
		return

	var ability = player.ability_data
	if ability.is_empty() or ability.get("type", "") != "active":
		ability_button.disabled = true
		ability_button.text = Tr.t("action.ability")
		return

	# Check with ActiveAbilitySystem
	var check = GameState.active_ability_system.can_activate_ability(player)
	ability_button.disabled = not check.can_activate
	ability_button.text = ability.get("name", "Compétence")


func _set_disabled(disabled: bool) -> void:
	reveal_button.disabled = disabled
	ability_button.disabled = disabled
	ability_button.text = Tr.t("action.ability")
	attack_button.disabled = disabled
	attack_button.text = Tr.t("action.attack")
	end_turn_button.disabled = disabled
