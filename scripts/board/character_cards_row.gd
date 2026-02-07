## CharacterCardsRow - Horizontal row of face-down character cards
## Cards flip face-up when a player's character is revealed.
class_name CharacterCardsRow
extends HBoxContainer


# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const CARD_WIDTH: int = 100
const CARD_HEIGHT: int = 140


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var _slots: Dictionary = {}  # player.id -> { "card": TextureRect, "label": Label, "panel": PanelContainer }
var _current_highlight_id: int = -1
var _card_back_texture: Texture2D = null


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	_card_back_texture = CardImageMapper.load_texture(
		CardImageMapper.get_character_image_path("back")
	)


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Create a card slot for each player
func setup(players: Array) -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()
	_slots.clear()

	for player in players:
		var slot = _create_card_slot(player)
		add_child(slot)


## Flip a player's card to reveal their character
func reveal_character(player: Player) -> void:
	if not _slots.has(player.id):
		return

	var slot_data = _slots[player.id]
	var card: TextureRect = slot_data["card"]

	# Flip animation: scale X to 0, swap texture, scale back to 1
	var tween = create_tween()
	tween.tween_property(card, "scale:x", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		var char_texture = CardImageMapper.load_texture(
			CardImageMapper.get_character_image_path(player.character_id)
		)
		if char_texture:
			card.texture = char_texture
	)
	tween.tween_property(card, "scale:x", 1.0, 0.15).set_ease(Tween.EASE_OUT)


## Highlight the current player's card with a golden border
func highlight_current_player(player_id: int) -> void:
	# Remove previous highlight
	if _current_highlight_id >= 0 and _slots.has(_current_highlight_id):
		var prev_panel: PanelContainer = _slots[_current_highlight_id]["panel"]
		_apply_panel_style(prev_panel, false)

	# Apply new highlight
	_current_highlight_id = player_id
	if _slots.has(player_id):
		var panel: PanelContainer = _slots[player_id]["panel"]
		_apply_panel_style(panel, true)


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

## Create a single card slot (panel + card image + label)
func _create_card_slot(player: Player) -> PanelContainer:
	var panel = PanelContainer.new()
	_apply_panel_style(panel, false)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Card image
	var card = TextureRect.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)
	if player.is_revealed:
		var char_texture = CardImageMapper.load_texture(
			CardImageMapper.get_character_image_path(player.character_id)
		)
		if char_texture:
			card.texture = char_texture
		elif _card_back_texture:
			card.texture = _card_back_texture
	elif _card_back_texture:
		card.texture = _card_back_texture
	vbox.add_child(card)

	# Player label
	var label = Label.new()
	label.text = PlayerColors.get_label(player)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", PlayerColors.get_color(player.id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	_slots[player.id] = {
		"card": card,
		"label": label,
		"panel": panel,
	}

	return panel


## Apply or remove golden highlight style to a panel
func _apply_panel_style(panel: PanelContainer, highlighted: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.15, 0.8)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	if highlighted:
		style.border_color = Color(1.0, 0.85, 0.2)
		style.set_border_width_all(3)
	else:
		style.border_color = Color(0.3, 0.25, 0.2)
		style.set_border_width_all(1)

	panel.add_theme_stylebox_override("panel", style)
