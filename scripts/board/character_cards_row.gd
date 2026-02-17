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
var _slots: Dictionary = {}  # player.id -> { "card_container": Control, "bg": TextureRect, "char": TextureRect, "label": Label, "panel": PanelContainer, "shine": ColorRect }
var _current_highlight_id: int = -1
var _card_back_texture: Texture2D = null
var _card_bg_texture: Texture2D = null
var _shine_shader: Shader = null
var _float_tweens: Array = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	_card_back_texture = CardImageMapper.load_texture(
		CardImageMapper.get_character_image_path("back")
	)
	_card_bg_texture = load("res://remake character/card_background.png") as Texture2D
	_shine_shader = load("res://assets/shaders/card_3d_tilt.gdshader") as Shader


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Create a card slot for each player
func setup(players: Array) -> void:
	# Clear existing
	for child in get_children():
		child.queue_free()
	_slots.clear()
	for tw in _float_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_float_tweens.clear()

	for player in players:
		var slot = _create_card_slot(player)
		add_child(slot)

	# Start staggered floating animations
	_start_idle_animations()


## Reveal a player's character with dramatic animation sequence
func reveal_character(player: Player) -> void:
	if not _slots.has(player.id):
		return

	var slot_data = _slots[player.id]
	var container: Control = slot_data["card_container"]
	var bg: TextureRect = slot_data["bg"]
	var char_img: TextureRect = slot_data["char"]

	# Define texture swap callback (called at mid-flip)
	var swap_textures = func():
		if _card_bg_texture:
			bg.texture = _card_bg_texture
		var char_texture = CardImageMapper.load_texture(
			CardImageMapper.get_character_image_path(player.character_id)
		)
		if char_texture:
			char_img.texture = char_texture
			char_img.visible = true

	# Play full dramatic reveal sequence (buildup → flip → explosion → settle)
	await AnimationOrchestrator.play_reveal_sequence(
		player, container, get_tree(), swap_textures
	)

	# Update tooltip with revealed info
	var panel: PanelContainer = slot_data["panel"]
	panel.tooltip_text = _build_tooltip(player)


## Get a player's card panel for animation purposes
func get_card_panel(player_id: int) -> PanelContainer:
	if _slots.has(player_id):
		return _slots[player_id]["panel"]
	return null


## Mark a dead player's card: gray out + red cross + skull overlay
func mark_dead(player: Player) -> void:
	if not _slots.has(player.id):
		return
	var slot_data = _slots[player.id]

	# Already marked dead
	if slot_data.get("death_overlay") != null:
		return

	var container: Control = slot_data["card_container"]

	# 1. Gray out the card
	container.modulate = Color(0.4, 0.4, 0.4, 1.0)

	# 2. Create death overlay (covers the whole card)
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Dark tint
	var dark_bg = ColorRect.new()
	dark_bg.color = Color(0.0, 0.0, 0.0, 0.4)
	dark_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dark_bg)

	# Red cross — two diagonal bars
	var cross_size = Vector2(min(CARD_WIDTH, CARD_HEIGHT) * 0.85, 8)
	var center = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)

	var bar1 = ColorRect.new()
	bar1.color = Color(0.85, 0.1, 0.1, 0.8)
	bar1.size = cross_size
	bar1.position = center - cross_size / 2.0
	bar1.pivot_offset = cross_size / 2.0
	bar1.rotation = deg_to_rad(45)
	bar1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bar1)

	var bar2 = ColorRect.new()
	bar2.color = Color(0.85, 0.1, 0.1, 0.8)
	bar2.size = cross_size
	bar2.position = center - cross_size / 2.0
	bar2.pivot_offset = cross_size / 2.0
	bar2.rotation = deg_to_rad(-45)
	bar2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bar2)

	# Skull pixel art (generated procedurally)
	var skull_rect = TextureRect.new()
	skull_rect.texture = _create_skull_texture()
	skull_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skull_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skull_rect.custom_minimum_size = Vector2(40, 40)
	skull_rect.size = Vector2(40, 40)
	skull_rect.position = Vector2((CARD_WIDTH - 40) / 2.0, (CARD_HEIGHT - 40) / 2.0)
	skull_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(skull_rect)

	container.add_child(overlay)
	slot_data["death_overlay"] = overlay

	# Update tooltip
	var panel: PanelContainer = slot_data["panel"]
	panel.tooltip_text = _build_tooltip(player) + "\n(Mort)"

	# Apply dead border style (dark red)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.05, 0.05, 0.9)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.border_color = Color(0.6, 0.1, 0.1)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)


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

	# Card container (layered: background + character)
	var card_container = Control.new()
	card_container.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card_container.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT / 2.0)

	var bg_rect = TextureRect.new()
	bg_rect.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_rect.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_container.add_child(bg_rect)

	var char_rect = TextureRect.new()
	char_rect.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	char_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_rect.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	char_rect.visible = false
	char_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_container.add_child(char_rect)

	# Shine overlay (transparent, renders the tilt shader)
	var shine_overlay = ColorRect.new()
	shine_overlay.color = Color(0, 0, 0, 0)
	shine_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shine_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shine_shader:
		var mat = ShaderMaterial.new()
		mat.shader = _shine_shader
		shine_overlay.material = mat
	card_container.add_child(shine_overlay)

	if player.is_revealed:
		if _card_bg_texture:
			bg_rect.texture = _card_bg_texture
		var char_texture = CardImageMapper.load_texture(
			CardImageMapper.get_character_image_path(player.character_id)
		)
		if char_texture:
			char_rect.texture = char_texture
			char_rect.visible = true
	else:
		if _card_back_texture:
			bg_rect.texture = _card_back_texture

	vbox.add_child(card_container)

	# Player label
	var label = Label.new()
	label.text = PlayerColors.get_label(player)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", PlayerColors.get_color(player.id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	_slots[player.id] = {
		"card_container": card_container,
		"bg": bg_rect,
		"char": char_rect,
		"label": label,
		"panel": panel,
		"player": player,
		"shine": shine_overlay,
	}

	panel.tooltip_text = _build_tooltip(player)
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Connect hover signals for 3D tilt effect
	panel.mouse_entered.connect(_on_card_hover_enter.bind(player.id))
	panel.mouse_exited.connect(_on_card_hover_exit.bind(player.id))
	panel.gui_input.connect(_on_card_gui_input.bind(player.id))

	return panel


## Build tooltip text for a player's character card
func _build_tooltip(player: Player) -> String:
	var text = PlayerColors.get_label(player)
	if player.is_revealed:
		text += " — %s" % player.character_name
		text += "\nFaction: %s" % player.faction.capitalize()
		text += "\nHP: %d" % player.hp_max
		var char_data = GameState.get_character(player.character_id)
		if char_data and char_data.has("ability"):
			var ability = char_data.ability
			text += "\n\nCapacité: %s" % ability.get("name", "")
			text += "\n%s" % ability.get("description", "")
	else:
		text += "\nIdentité inconnue"
	return text


## Generate a 16x16 pixel art skull texture (white on transparent)
func _create_skull_texture() -> ImageTexture:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var w = Color.WHITE

	# Skull pixel art pattern (16x16)
	# Row data: [row_index, [col_indices...]]
	var pixels = [
		[1, [5, 6, 7, 8, 9, 10]],
		[2, [4, 5, 6, 7, 8, 9, 10, 11]],
		[3, [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]],
		[4, [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]],
		[5, [3, 4, 7, 8, 10, 11, 12]],        # Eyes (gaps at 5-6 and 9)
		[6, [3, 4, 7, 8, 10, 11, 12]],        # Eyes
		[7, [3, 4, 5, 6, 7, 8, 9, 10, 11, 12]],
		[8, [4, 5, 6, 7, 8, 9, 10, 11]],      # Nose area
		[9, [4, 5, 7, 8, 10, 11]],             # Nose holes
		[10, [4, 5, 6, 7, 8, 9, 10, 11]],
		[11, [5, 6, 7, 8, 9, 10]],             # Jaw
		[12, [5, 6, 7, 8, 9, 10]],             # Teeth row
		[13, [5, 7, 9]],                        # Teeth gaps
	]
	for row_data in pixels:
		var y: int = row_data[0]
		var cols: Array = row_data[1]
		for x in cols:
			img.set_pixel(x, y, w)

	return ImageTexture.create_from_image(img)


## Start idle floating animations on all cards (staggered)
func _start_idle_animations() -> void:
	var i := 0
	for slot_data in _slots.values():
		var container: Control = slot_data["card_container"]
		var tw = AnimationHelper.start_floating(container, i * 0.4)
		if tw:
			_float_tweens.append(tw)
		i += 1


## Handle mouse entering a card
func _on_card_hover_enter(player_id: int) -> void:
	if not _slots.has(player_id):
		return
	var slot_data = _slots[player_id]
	var container: Control = slot_data["card_container"]
	var shine: ColorRect = slot_data["shine"]

	# Scale up
	var tween = container.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(container, "scale", Vector2(1.08, 1.08), 0.2)

	# Activate shine
	if shine.material:
		shine.material.set_shader_parameter("active", true)


## Handle mouse exiting a card
func _on_card_hover_exit(player_id: int) -> void:
	if not _slots.has(player_id):
		return
	var slot_data = _slots[player_id]
	var container: Control = slot_data["card_container"]
	var shine: ColorRect = slot_data["shine"]

	# Scale back + reset rotation
	var tween = container.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.25)
	tween.tween_property(container, "rotation", 0.0, 0.25)

	# Deactivate shine
	if shine.material:
		shine.material.set_shader_parameter("active", false)


## Handle mouse movement over a card for tilt + shine update
func _on_card_gui_input(event: InputEvent, player_id: int) -> void:
	if not event is InputEventMouseMotion:
		return
	if not _slots.has(player_id):
		return

	var slot_data = _slots[player_id]
	var container: Control = slot_data["card_container"]
	var shine: ColorRect = slot_data["shine"]

	# Calculate mouse offset from card center (-1 to 1)
	var local_pos = container.get_local_mouse_position()
	var card_size = container.custom_minimum_size
	var tilt_x = clampf((local_pos.x / card_size.x - 0.5) * 2.0, -1.0, 1.0)
	var tilt_y = clampf((local_pos.y / card_size.y - 0.5) * 2.0, -1.0, 1.0)

	# Apply rotation (tilt around vertical axis simulated as Z rotation)
	var target_rotation = -tilt_x * deg_to_rad(4.0)
	container.rotation = lerpf(container.rotation, target_rotation, 0.3)

	# Update shine shader
	if shine.material:
		shine.material.set_shader_parameter("tilt", Vector2(tilt_x, tilt_y))


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
