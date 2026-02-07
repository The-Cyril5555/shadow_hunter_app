## ActionPhasePopup - Modal popup for ACTION phase choices
## Presents Draw / Attack / End Turn options with visual cards
class_name ActionPhasePopup
extends Control


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal action_chosen(action: String)  # "draw", "attack", "end_turn"


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var dimmer: ColorRect = $Dimmer
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var player_info_label: Label = $Panel/MarginContainer/VBoxContainer/PlayerInfoLabel
@onready var choices_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer

# Choice cards
@onready var draw_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/DrawCard
@onready var draw_image: TextureRect = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/DrawCard/VBox/DrawImage
@onready var draw_label: Label = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/DrawCard/VBox/DrawLabel
@onready var draw_sub_label: Label = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/DrawCard/VBox/DrawSubLabel
@onready var draw_button: Button = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/DrawCard/VBox/DrawButton

@onready var attack_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/AttackCard
@onready var attack_image: TextureRect = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/AttackCard/VBox/AttackImage
@onready var attack_label: Label = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/AttackCard/VBox/AttackLabel
@onready var attack_sub_label: Label = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/AttackCard/VBox/AttackSubLabel
@onready var attack_button: Button = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/AttackCard/VBox/AttackButton

@onready var end_turn_card: PanelContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/EndTurnCard
@onready var end_label: Label = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/EndTurnCard/VBox/EndLabel
@onready var end_sub_label: Label = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/EndTurnCard/VBox/EndSubLabel
@onready var end_button: Button = $Panel/MarginContainer/VBoxContainer/ChoicesContainer/EndTurnCard/VBox/EndButton


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	draw_button.pressed.connect(_on_draw_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	end_button.pressed.connect(_on_end_turn_pressed)


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show action popup with context about available actions
func show_for_player(player: Player, can_draw: bool, deck_type: String, target_count: int) -> void:
	# Title and player info
	title_label.text = "Phase d'action"
	var zone_data = ZoneData.get_zone_by_id(player.position_zone)
	var zone_name = zone_data.get("name", player.position_zone) if zone_data else player.position_zone
	player_info_label.text = "%s | Zone : %s" % [player.display_name, zone_name]

	# --- Draw card ---
	if can_draw and deck_type != "":
		draw_button.disabled = false
		draw_label.text = "Piocher"
		draw_sub_label.text = "Deck %s" % deck_type.capitalize()
		draw_card.modulate = Color.WHITE
		# Load card back image
		var texture = CardImageMapper.load_texture(CardImageMapper.get_card_back_path(deck_type))
		if texture != null:
			draw_image.texture = texture
			draw_image.visible = true
		else:
			draw_image.visible = false
	else:
		draw_button.disabled = true
		draw_label.text = "Piocher"
		if deck_type == "":
			draw_sub_label.text = "Pas de deck ici"
		else:
			draw_sub_label.text = "Déjà pioché"
		draw_card.modulate = Color(0.5, 0.5, 0.5)
		draw_image.visible = false

	# --- Attack ---
	if target_count > 0:
		attack_button.disabled = false
		attack_label.text = "Attaquer"
		attack_sub_label.text = "%d cible(s)" % target_count
		attack_card.modulate = Color.WHITE
	else:
		attack_button.disabled = true
		attack_label.text = "Attaquer"
		attack_sub_label.text = "Aucune cible"
		attack_card.modulate = Color(0.5, 0.5, 0.5)

	# --- End Turn ---
	end_button.disabled = false
	end_label.text = "Fin de tour"
	end_sub_label.text = "Passer au joueur suivant"

	# Show with fade
	visible = true
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

	print("[ActionPhasePopup] Shown for %s (draw=%s, targets=%d)" % [player.display_name, can_draw, target_count])


## Hide the popup
func hide_popup() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	visible = false


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------

func _on_draw_pressed() -> void:
	hide_popup()
	action_chosen.emit("draw")

func _on_attack_pressed() -> void:
	hide_popup()
	action_chosen.emit("attack")

func _on_end_turn_pressed() -> void:
	hide_popup()
	action_chosen.emit("end_turn")
