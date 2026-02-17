## ActionPrompt - Action buttons (Reveal / Ability / Attack / End Turn) anchored bottom-right
## Always visible, disabled when not the player's action phase.
class_name ActionPrompt
extends PanelContainer


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal action_chosen(action: String)  # "reveal", "ability", "attack", "end_turn"


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var reveal_button: Button = $MarginContainer/VBoxContainer/RevealButton
@onready var ability_button: Button = $MarginContainer/VBoxContainer/AbilityButton
@onready var attack_button: Button = $MarginContainer/VBoxContainer/AttackButton
@onready var end_turn_button: Button = $MarginContainer/VBoxContainer/EndTurnButton


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
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

	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.15, 0.85)
	style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)

	# Start disabled
	_set_disabled(true)
	visible = true


# -----------------------------------------------------------------------------
# Public Methods
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


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

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
