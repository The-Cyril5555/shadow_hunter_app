## DamageTracker - Visual HP tracker showing all players' damage levels
## Displays a vertical board with numbered rows (0-14) and colored player tokens.
class_name DamageTracker
extends PanelContainer


# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const MAX_DAMAGE_ROWS: int = 14


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var rows_container: VBoxContainer = $MarginContainer/VBoxContainer/RowsContainer


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var _player_markers: Dictionary = {}  # player.id -> Label node
var _row_containers: Array = []  # Index 0 = "NO DAMAGE", 1-14 = damage rows
var _players: Array = []


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	_apply_background()
	_build_rows()


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Initialize the tracker with all players
func setup(players: Array) -> void:
	_players = players
	# Clear any existing markers
	for marker in _player_markers.values():
		if is_instance_valid(marker):
			marker.queue_free()
	_player_markers.clear()

	# Create a marker for each player and place at row 0 (no damage)
	for player in players:
		var marker = _create_marker(player)
		_player_markers[player.id] = marker
		_place_marker_in_row(marker, 0)


## Update a player's position based on current HP
func update_player_hp(player: Player) -> void:
	if not _player_markers.has(player.id):
		return
	var marker = _player_markers[player.id]
	if not is_instance_valid(marker):
		return

	var damage = player.hp_max - player.hp
	damage = clampi(damage, 0, MAX_DAMAGE_ROWS)

	# Reparent marker to the correct row
	_place_marker_in_row(marker, damage)


## Mark a player as dead (gray out their marker)
func mark_player_dead(player: Player) -> void:
	if not _player_markers.has(player.id):
		return
	var marker = _player_markers[player.id]
	if not is_instance_valid(marker):
		return
	marker.modulate = Color(1, 1, 1, 0.35)


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

## Apply HP score card background texture
func _apply_background() -> void:
	var bg_path = CardImageMapper.get_hp_score_card_path("variant_01")
	var bg_texture = CardImageMapper.load_texture(bg_path)
	if bg_texture:
		var style = StyleBoxTexture.new()
		style.texture = bg_texture
		style.content_margin_left = 8
		style.content_margin_top = 8
		style.content_margin_right = 8
		style.content_margin_bottom = 8
		add_theme_stylebox_override("panel", style)


## Build the row structure
func _build_rows() -> void:
	_row_containers.clear()

	# Row 0 = "NO DAMAGE" (title row tokens area)
	# Already exists as the first flow in the scene
	# Rows 1-14 are built dynamically
	for i in range(MAX_DAMAGE_ROWS + 1):
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		if i == 0:
			# "NO DAMAGE" row - no number label needed, title handles it
			pass
		else:
			var num_label = Label.new()
			num_label.text = str(i)
			num_label.custom_minimum_size = Vector2(28, 0)
			num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			num_label.add_theme_font_size_override("font_size", 14)
			num_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
			row.add_child(num_label)

		# Separator line after number
		var sep = HSeparator.new()
		sep.custom_minimum_size = Vector2(0, 1)
		sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Token flow area
		var token_flow = HBoxContainer.new()
		token_flow.add_theme_constant_override("separation", 3)
		token_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(token_flow)

		rows_container.add_child(row)
		_row_containers.append(token_flow)


## Create a colored marker label for a player
func _create_marker(player: Player) -> Label:
	var marker = Label.new()
	marker.text = PlayerColors.get_label(player)
	marker.add_theme_font_size_override("font_size", 13)
	marker.add_theme_color_override("font_color", PlayerColors.get_color(player.id))
	return marker


## Place a marker in the specified damage row (0 = no damage, 14 = max)
func _place_marker_in_row(marker: Label, damage_row: int) -> void:
	damage_row = clampi(damage_row, 0, MAX_DAMAGE_ROWS)
	if damage_row >= _row_containers.size():
		return

	# Reparent
	if marker.get_parent():
		marker.get_parent().remove_child(marker)
	_row_containers[damage_row].add_child(marker)
