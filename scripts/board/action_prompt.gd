## ActionPrompt - Inline contextual prompt for player actions
## Sits below the zone cards, showing what the current player can do.
class_name ActionPrompt
extends PanelContainer


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal action_chosen(action: String)  # "draw", "attack", "end_turn"


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var prompt_label: Label = $MarginContainer/HBoxContainer/PromptLabel
@onready var draw_button: Button = $MarginContainer/HBoxContainer/DrawButton
@onready var attack_button: Button = $MarginContainer/HBoxContainer/AttackButton
@onready var end_turn_button: Button = $MarginContainer/HBoxContainer/EndTurnButton


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	draw_button.pressed.connect(func(): action_chosen.emit("draw"))
	attack_button.pressed.connect(func(): action_chosen.emit("attack"))
	end_turn_button.pressed.connect(func(): action_chosen.emit("end_turn"))
	visible = false


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show action choices for the current human player
func show_action_prompt(player: Player, can_draw: bool, deck_type: String, target_count: int) -> void:
	# Build contextual message
	if can_draw and deck_type != "":
		var deck_name = deck_type.capitalize()
		prompt_label.text = "%s peut piocher une carte %s" % [PlayerColors.get_label(player), deck_name]
	else:
		prompt_label.text = "Tour de %s — Choisissez une action" % PlayerColors.get_label(player)
	prompt_label.add_theme_color_override("font_color", PlayerColors.get_color(player.id))

	# Button states
	draw_button.visible = true
	draw_button.disabled = not can_draw
	attack_button.visible = true
	attack_button.disabled = target_count == 0
	attack_button.text = "Attaquer (%d)" % target_count if target_count > 0 else "Attaquer"
	end_turn_button.visible = true
	end_turn_button.disabled = false

	_show_animated()


## Update prompt after a draw (disable draw, keep attack/end)
func update_after_draw(player: Player, target_count: int) -> void:
	prompt_label.text = "Carte piochée — Choisissez une action"
	prompt_label.add_theme_color_override("font_color", PlayerColors.get_color(player.id))
	draw_button.disabled = true
	attack_button.disabled = target_count == 0
	attack_button.text = "Attaquer (%d)" % target_count if target_count > 0 else "Attaquer"
	end_turn_button.disabled = false
	_show_animated()


## Show a waiting message during bot turns
func show_waiting_prompt(player_name: String) -> void:
	prompt_label.text = "Tour de %s..." % player_name
	prompt_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	draw_button.visible = false
	attack_button.visible = false
	end_turn_button.visible = false
	_show_animated()


## Show movement phase prompt
func show_movement_prompt(player: Player) -> void:
	prompt_label.text = "%s — Lancez les dés pour vous déplacer" % PlayerColors.get_label(player)
	prompt_label.add_theme_color_override("font_color", PlayerColors.get_color(player.id))
	draw_button.visible = false
	attack_button.visible = false
	end_turn_button.visible = false
	_show_animated()


## Hide the prompt
func hide_prompt() -> void:
	visible = false


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

func _show_animated() -> void:
	if not visible:
		visible = true
		modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.15)
