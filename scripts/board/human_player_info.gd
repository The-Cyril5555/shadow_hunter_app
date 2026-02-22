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
@onready var player_label: Label = $MarginContainer/MainHBox/CardVBox/PlayerLabel
@onready var card_container: Control = $MarginContainer/MainHBox/CardVBox/CardContainer
@onready var bg_rect: TextureRect = $MarginContainer/MainHBox/CardVBox/CardContainer/BgRect
@onready var character_image: TextureRect = $MarginContainer/MainHBox/CardVBox/CardContainer/CharacterImage
@onready var shine_overlay: ColorRect = $MarginContainer/MainHBox/CardVBox/CardContainer/ShineOverlay

@onready var hp_label: Label = $MarginContainer/MainHBox/Col1VBox/HPLabel
@onready var victory_label: Label = $MarginContainer/MainHBox/Col1VBox/VictoryLabel
@onready var skill_label: Label = $MarginContainer/MainHBox/Col1VBox/SkillLabel

@onready var hand_container: VBoxContainer = $MarginContainer/MainHBox/Col2VBox/HandContainer
@onready var equipment_container: HBoxContainer = $MarginContainer/MainHBox/Col3VBox/EquipmentContainer

# Action buttons
@onready var reveal_button: Button = $MarginContainer/MainHBox/ButtonsCenter/ButtonGrid/RevealButton
@onready var ability_button: Button = $MarginContainer/MainHBox/ButtonsCenter/ButtonGrid/AbilityButton
@onready var attack_button: Button = $MarginContainer/MainHBox/ButtonsCenter/ButtonGrid/AttackButton
@onready var end_turn_button: Button = $MarginContainer/MainHBox/ButtonsCenter/ButtonGrid/EndTurnButton


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var _player: Player = null
var _float_tween: Tween = null
var _must_use_card: bool = false  # True when player drew instant card that must be used


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

	# Load card background into pre-built BgRect
	var bg_texture = CardImageMapper.load_texture("res://remake character/card_background.png")
	if bg_texture:
		bg_rect.texture = bg_texture

	# Load shine shader into pre-built ShineOverlay
	var shine_shader = load("res://assets/shaders/card_3d_tilt.gdshader") as Shader
	if shine_shader:
		var mat = ShaderMaterial.new()
		mat.shader = shine_shader
		shine_overlay.material = mat

	# Connect hover signals on pre-built card_container
	card_container.mouse_entered.connect(_on_card_hover_enter)
	card_container.mouse_exited.connect(_on_card_hover_exit)
	card_container.gui_input.connect(_on_card_gui_input)

	# Start floating animation
	_float_tween = AnimationHelper.start_floating(card_container)

	update_display()


## Get the tracked player
func get_player() -> Player:
	return _player


## Switch the displayed player (local hot-seat or online — ensures panel shows correct player)
func switch_player(player: Player) -> void:
	if player == null or player == _player:
		return
	_player = player
	update_display()


## Refresh all display elements
func update_display() -> void:
	if _player == null:
		return

	# Player label (shown under the card)
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

	# HP with color coding
	hp_label.text = "HP: %d/%d" % [_player.hp, _player.hp_max]
	if _player.hp <= _player.hp_max * 0.3:
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	elif _player.hp <= _player.hp_max * 0.6:
		hp_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	else:
		hp_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))

	# Victory condition (derived from faction)
	var faction_victory: Dictionary = {
		"hunter": "Victoire : éliminer toutes les Ombres",
		"shadow": "Victoire : éliminer tous les Chasseurs",
		"neutral": "Victoire : objectif personnel",
	}
	victory_label.text = faction_victory.get(_player.faction, "")

	# Skill description (from ability_data)
	var skill_name: String = _player.ability_data.get("name", "")
	var skill_desc: String = _player.ability_data.get("description", "")
	if skill_name and skill_desc:
		skill_label.text = "%s : %s" % [skill_name, skill_desc]
	else:
		skill_label.text = skill_desc

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
	var tween = card_container.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(card_container, "scale", Vector2(1.08, 1.08), 0.2)
	if shine_overlay and shine_overlay.material:
		shine_overlay.material.set_shader_parameter("active", true)


func _on_card_hover_exit() -> void:
	var tween = card_container.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(card_container, "scale", Vector2(1.0, 1.0), 0.25)
	tween.tween_property(card_container, "rotation", 0.0, 0.25)
	if shine_overlay and shine_overlay.material:
		shine_overlay.material.set_shader_parameter("active", false)


func _on_card_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var local_pos = card_container.get_local_mouse_position()
	var card_size = card_container.custom_minimum_size
	var tilt_x = clampf((local_pos.x / card_size.x - 0.5) * 2.0, -1.0, 1.0)
	var tilt_y = clampf((local_pos.y / card_size.y - 0.5) * 2.0, -1.0, 1.0)
	card_container.rotation = lerpf(card_container.rotation, -tilt_x * deg_to_rad(4.0), 0.3)
	if shine_overlay and shine_overlay.material:
		shine_overlay.material.set_shader_parameter("tilt", Vector2(tilt_x, tilt_y))


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


## Force card use - disable end turn until card is used
func force_card_use() -> void:
	_must_use_card = true
	end_turn_button.disabled = true
	end_turn_button.tooltip_text = "Vous devez utiliser la carte piochée"


## Reset after card use
func card_used() -> void:
	_must_use_card = false
	end_turn_button.disabled = false
	end_turn_button.tooltip_text = ""
