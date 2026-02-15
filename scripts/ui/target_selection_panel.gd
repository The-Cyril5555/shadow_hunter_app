## TargetSelectionPanel - UI for selecting attack targets
## Shows available targets and emits selection signal.
class_name TargetSelectionPanel
extends PanelContainer


# Signals
signal target_selected(target: Player)


# References @onready
@onready var targets_container: VBoxContainer = $MarginContainer/VBoxContainer/TargetsContainer
@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/CancelButton


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	cancel_button.pressed.connect(_on_cancel_pressed)


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Show target selection panel with valid targets
func show_targets(valid_targets: Array, title: String = "", button_text: String = "Attaquer") -> void:
	# Clear previous targets
	for child in targets_container.get_children():
		child.queue_free()

	# Update title
	if valid_targets.is_empty():
		title_label.text = "Aucune cible disponible"
		cancel_button.visible = true
		visible = true
		return
	else:
		title_label.text = title if title != "" else "Choisissez votre cible"

	# Create rich entry for each valid target
	for target in valid_targets:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		# Character portrait
		var portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2(50, 50)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var char_id = target.character_id if target.is_revealed else "back"
		var texture = CardImageMapper.load_texture(CardImageMapper.get_character_image_path(char_id))
		if texture != null:
			portrait.texture = texture
		row.add_child(portrait)

		# Player info
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl = Label.new()
		var label_tag = PlayerColors.get_label(target)
		name_lbl.text = "%s — %s" % [label_tag, target.display_name]
		if target.is_revealed:
			name_lbl.text += " (%s)" % target.character_name
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", PlayerColors.get_color(target.id))
		info.add_child(name_lbl)

		row.add_child(info)

		# Action button
		var btn = Button.new()
		btn.text = button_text
		btn.custom_minimum_size = Vector2(100, 40)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_target_button_pressed.bind(target))
		row.add_child(btn)

		targets_container.add_child(row)

	cancel_button.visible = true
	visible = true
	print("[TargetSelection] Showing %d targets" % valid_targets.size())


## Hide the panel
func hide_panel() -> void:
	visible = false


# -----------------------------------------------------------------------------
# Signal Handlers
# -----------------------------------------------------------------------------

func _on_target_button_pressed(target: Player) -> void:
	target_selected.emit(target)
	hide_panel()


func _on_cancel_pressed() -> void:
	hide_panel()
