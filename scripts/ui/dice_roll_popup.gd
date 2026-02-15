## DiceRollPopup - Modal popup for dice rolling (movement + combat)
## Movement mode: shows zone destination. Combat mode: shows |D6 - D4| damage.
class_name DiceRollPopup
extends Control


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal zone_selected(zone_id: String)
signal combat_roll_completed(total_damage: int)


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
var _mode: String = "movement"  # "movement" or "combat"
var _combat_attacker: Player = null
var _combat_target: Player = null


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	roll_button.pressed.connect(_on_roll_pressed)
	dice.dice_rolled.connect(_on_dice_result)
	_apply_styling()


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show the popup for a player's movement phase
func show_for_player(player: Player) -> void:
	_current_player = player
	_dice_result = 0
	_mode = "movement"

	# Populate info
	title_label.text = "Votre tour — Lancez les dés"
	player_info_label.text = "%s | Zone : %s" % [player.display_name, player.position_zone.capitalize()]

	# Reset state
	roll_button.visible = true
	roll_button.disabled = false
	result_label.visible = false
	dice.reset()

	# Show with fade
	visible = true
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)


## Show the popup for a combat dice roll (damage = |D6 - D4|)
func show_for_combat(attacker: Player, target: Player) -> void:
	_current_player = attacker
	_combat_attacker = attacker
	_combat_target = target
	_dice_result = 0
	_mode = "combat"

	# Populate info
	title_label.text = "Combat — Lancez les dés"
	player_info_label.text = "%s attaque %s" % [attacker.display_name, target.display_name]

	# Reset state
	roll_button.visible = true
	roll_button.disabled = false
	result_label.visible = false
	dice.reset()

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
# Private Methods
# -----------------------------------------------------------------------------

func _apply_styling() -> void:
	# Panel — dark background with gold border
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.08, 0.14)
	panel_style.border_color = Color(0.85, 0.68, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 8
	panel_style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", panel_style)

	# Title — gold color
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))

	# Player info — lighter grey
	player_info_label.add_theme_color_override("font_color", Color(0.65, 0.6, 0.7))

	# Roll button — styled with normal/hover/pressed states
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.65, 0.2, 0.12)
	btn_normal.border_color = Color(0.85, 0.68, 0.2)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(8)
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10
	btn_normal.content_margin_left = 20
	btn_normal.content_margin_right = 20
	roll_button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.8, 0.28, 0.15)
	btn_hover.border_color = Color(1.0, 0.85, 0.3)
	btn_hover.set_border_width_all(2)
	roll_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.5, 0.15, 0.08)
	roll_button.add_theme_stylebox_override("pressed", btn_pressed)

	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.3, 0.15, 0.1, 0.5)
	btn_disabled.border_color = Color(0.5, 0.4, 0.2, 0.5)
	roll_button.add_theme_stylebox_override("disabled", btn_disabled)

	roll_button.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	roll_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9))

	# Result label — bright green, larger
	result_label.add_theme_font_size_override("font_size", 26)
	result_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------

func _on_roll_pressed() -> void:
	roll_button.disabled = true
	dice.roll()


func _on_dice_result(sum: int) -> void:
	_dice_result = sum
	roll_button.visible = false

	if _mode == "combat":
		_handle_combat_result()
	else:
		_handle_movement_result(sum)


## Handle movement dice result (zone destination)
func _handle_movement_result(sum: int) -> void:
	var dest_zone_id = ZoneData.get_zone_for_dice_sum(sum, GameState.zone_positions)
	var zone_data = ZoneData.get_zone_by_id(dest_zone_id) if dest_zone_id != "" else {}
	var zone_name = zone_data.get("name", "???")

	result_label.text = "Résultat : %d → %s" % [sum, zone_name]
	result_label.visible = true

	await get_tree().create_timer(1.2).timeout
	hide_popup()
	if dest_zone_id != "":
		zone_selected.emit(dest_zone_id)


## Handle combat dice result (damage = |D6 - D4|, or d4-only for Valkyrie)
func _handle_combat_result() -> void:
	var d6 = dice.dice1_result
	var d4 = dice.dice2_result

	# Valkyrie "Horn of War Outbreak" — uses d4 only, no miss possible
	var is_valkyrie = _combat_attacker and _combat_attacker.character_id == "valkyrie" \
		and _combat_attacker.is_revealed and not _combat_attacker.ability_disabled

	var missed: bool
	var base_damage: int
	var text: String

	if is_valkyrie:
		missed = false
		base_damage = d4
		text = "Horn of War — D4: %d dégâts" % d4
		result_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	elif d6 == d4:
		missed = true
		base_damage = 0
		text = "D6: %d = D4: %d → Attaque ratée !" % [d6, d4]
		result_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.3))
	else:
		missed = false
		base_damage = abs(d6 - d4)
		text = "D6: %d − D4: %d = %d dégâts" % [d6, d4, base_damage]
		result_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))

	# Equipment and defense modifiers
	var total_damage = base_damage
	if not missed and _combat_attacker and _combat_target:
		var equip_bonus = _combat_attacker.get_attack_damage_bonus()
		var defense = _combat_target.get_defense_bonus()
		if equip_bonus > 0 or defense > 0:
			total_damage = max(1, base_damage + equip_bonus - defense)
			var modifier_text = ""
			if equip_bonus > 0:
				modifier_text += " + %d équip." % equip_bonus
			if defense > 0:
				modifier_text += " − %d déf." % defense
			text += "\n%d%s = %d" % [base_damage, modifier_text, total_damage]

	result_label.text = text
	result_label.visible = true

	# Auto-close and emit
	await get_tree().create_timer(1.5).timeout
	hide_popup()

	_mode = "movement"
	combat_roll_completed.emit(total_damage)
