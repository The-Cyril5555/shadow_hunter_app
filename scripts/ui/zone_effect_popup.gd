## ZoneEffectPopup - Modal popup for zone special abilities
## Handles Weird Woods (damage/heal), Underworld Gate (choose deck), Erstwhile Altar (steal equipment)
class_name ZoneEffectPopup
extends PanelContainer


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal effect_completed(result: Dictionary)


# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------
var _current_player: Player = null
var _selected_target: Player = null
var _zone_effect: String = ""


# -----------------------------------------------------------------------------
# UI References (created in _ready)
# -----------------------------------------------------------------------------
var title_label: Label
var description_label: Label
var content_container: VBoxContainer
var cancel_button: Button


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	_build_ui()


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show popup for a zone effect
func show_effect(zone_data: Dictionary, current_player: Player, all_players: Array) -> void:
	_current_player = current_player
	_selected_target = null
	_zone_effect = zone_data.get("effect", "")

	title_label.text = zone_data.get("name", "Zone")
	description_label.text = zone_data.get("description", "")

	# Clear previous content
	for child in content_container.get_children():
		child.queue_free()

	match _zone_effect:
		"damage_or_heal":
			_build_damage_or_heal_ui(all_players)
		"choose_deck":
			_build_choose_deck_ui()
		"steal_equipment":
			_build_steal_equipment_ui(all_players)
		_:
			push_warning("[ZoneEffectPopup] Unknown effect: %s" % _zone_effect)
			return

	cancel_button.visible = true
	_show_animated()


## Hide the popup
func hide_popup() -> void:
	visible = false


# -----------------------------------------------------------------------------
# UI Builders
# -----------------------------------------------------------------------------

## Build the base UI structure
func _build_ui() -> void:
	custom_minimum_size = Vector2(420, 300)
	anchors_preset = Control.PRESET_CENTER
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -210
	offset_top = -200
	offset_right = 210
	offset_bottom = 200
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	# Dark background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.18, 0.95)
	style.border_color = Color(0.6, 0.5, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_top = 20
	style.content_margin_right = 20
	style.content_margin_bottom = 20
	add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# Description
	description_label = Label.new()
	description_label.add_theme_font_size_override("font_size", 14)
	description_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(description_label)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Dynamic content area
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 8)
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_container)

	# Cancel button
	cancel_button = Button.new()
	cancel_button.text = "Annuler"
	cancel_button.custom_minimum_size = Vector2(0, 36)
	cancel_button.pressed.connect(_on_cancel_pressed)
	vbox.add_child(cancel_button)


## Build UI for Weird Woods: choose a player, then damage or heal
func _build_damage_or_heal_ui(all_players: Array) -> void:
	var hint = Label.new()
	hint.text = "Choisissez un joueur :"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	content_container.add_child(hint)

	var targets = _get_alive_others(all_players)
	if targets.is_empty():
		hint.text = "Aucun joueur ciblable"
		cancel_button.text = "Fermer"
		return

	for target in targets:
		var row = _create_player_row(target)

		var dmg_btn = Button.new()
		dmg_btn.text = "2 Dégâts"
		dmg_btn.custom_minimum_size = Vector2(90, 34)
		dmg_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		dmg_btn.pressed.connect(_on_weird_woods_choice.bind(target, "damage"))
		row.add_child(dmg_btn)

		var heal_btn = Button.new()
		heal_btn.text = "1 Soin"
		heal_btn.custom_minimum_size = Vector2(80, 34)
		heal_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		heal_btn.pressed.connect(_on_weird_woods_choice.bind(target, "heal"))
		row.add_child(heal_btn)

		content_container.add_child(row)


## Build UI for Underworld Gate: choose a deck to draw from
func _build_choose_deck_ui() -> void:
	var hint = Label.new()
	hint.text = "Choisissez un deck :"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	content_container.add_child(hint)

	var decks = [
		{"type": "hermit", "label": "Hermite (Vision)", "color": Color(0.6, 0.5, 0.3)},
		{"type": "white", "label": "Blanche (Bénéfique)", "color": Color(0.9, 0.9, 0.9)},
		{"type": "black", "label": "Noire (Maléfique)", "color": Color(0.5, 0.5, 0.5)},
	]

	for deck_info in decks:
		var deck = _get_deck_by_type(deck_info.type)
		var count = deck.get_card_count() if deck else 0

		var btn = Button.new()
		btn.text = "%s (%d cartes)" % [deck_info.label, count]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", deck_info.color)
		btn.disabled = count == 0
		btn.pressed.connect(_on_deck_chosen.bind(deck_info.type))
		content_container.add_child(btn)


## Build UI for Erstwhile Altar: steal equipment from a player
func _build_steal_equipment_ui(all_players: Array) -> void:
	var targets = _get_players_with_equipment(all_players)

	if targets.is_empty():
		var hint = Label.new()
		hint.text = "Aucun joueur n'a d'équipement"
		hint.add_theme_font_size_override("font_size", 16)
		hint.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_container.add_child(hint)
		cancel_button.text = "Fermer"
		return

	var hint = Label.new()
	hint.text = "Volez un équipement :"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	content_container.add_child(hint)

	for target in targets:
		for card in target.equipment:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)

			var name_lbl = Label.new()
			name_lbl.text = "%s — %s" % [PlayerColors.get_label(target), card.name]
			name_lbl.add_theme_font_size_override("font_size", 14)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_lbl)

			var steal_btn = Button.new()
			steal_btn.text = "Voler"
			steal_btn.custom_minimum_size = Vector2(80, 34)
			steal_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			steal_btn.pressed.connect(_on_steal_equipment.bind(target, card))
			row.add_child(steal_btn)

			content_container.add_child(row)


# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

func _get_alive_others(all_players: Array) -> Array:
	var result: Array = []
	for p in all_players:
		if p != _current_player and p.is_alive:
			result.append(p)
	return result


func _get_players_with_equipment(all_players: Array) -> Array:
	var result: Array = []
	for p in all_players:
		if p != _current_player and p.is_alive and not p.equipment.is_empty():
			result.append(p)
	return result


func _get_deck_by_type(deck_type: String) -> DeckManager:
	match deck_type:
		"hermit":
			return GameState.hermit_deck
		"white":
			return GameState.white_deck
		"black":
			return GameState.black_deck
	return null


func _create_player_row(player: Player) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Player color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(6, 30)
	color_rect.color = PlayerColors.get_color(player.id)
	row.add_child(color_rect)

	# Player name + HP
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl = Label.new()
	name_lbl.text = PlayerColors.get_label(player)
	if player.is_revealed:
		name_lbl.text += " (%s)" % player.character_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", PlayerColors.get_color(player.id))
	info.add_child(name_lbl)

	var hp_lbl = Label.new()
	hp_lbl.text = "HP: %d/%d" % [player.hp, player.hp_max]
	hp_lbl.add_theme_font_size_override("font_size", 12)
	hp_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_child(hp_lbl)

	row.add_child(info)
	return row


func _show_animated() -> void:
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------

func _on_weird_woods_choice(target: Player, action: String) -> void:
	hide_popup()
	effect_completed.emit({
		"type": "damage_or_heal",
		"target": target,
		"action": action
	})


func _on_deck_chosen(deck_type: String) -> void:
	hide_popup()
	effect_completed.emit({
		"type": "choose_deck",
		"deck_type": deck_type
	})


func _on_steal_equipment(target: Player, card: Card) -> void:
	hide_popup()
	effect_completed.emit({
		"type": "steal_equipment",
		"target": target,
		"card": card
	})


func _on_cancel_pressed() -> void:
	hide_popup()
	effect_completed.emit({"type": "cancelled"})
