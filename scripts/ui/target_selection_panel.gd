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
func show_targets(valid_targets: Array) -> void:
	# Clear previous targets
	for child in targets_container.get_children():
		child.queue_free()

	# Update title
	if valid_targets.is_empty():
		title_label.text = "No valid targets"
		cancel_button.visible = true
		visible = true
		return
	else:
		title_label.text = "Select Attack Target"

	# Create button for each valid target
	for target in valid_targets:
		var button = Button.new()
		button.text = "%s (HP: %d/%d)" % [
			target.display_name,
			target.hp,
			target.hp_max
		]
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_target_button_pressed.bind(target))
		targets_container.add_child(button)

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
