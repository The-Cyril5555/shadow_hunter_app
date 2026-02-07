## FeedbackToast - Floating notification for multi-channel action feedback
##
## Shows brief text messages that fade out automatically.
## Provides the text channel alongside audio and visual feedback.
class_name FeedbackToast
extends CanvasLayer


# =============================================================================
# PROPERTIES
# =============================================================================

var _container: VBoxContainer
const MAX_TOASTS: int = 5
const TOAST_DURATION: float = 2.5


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	layer = 90

	# Container anchored to top-right
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.anchor_left = 0.65
	margin.anchor_bottom = 0.5
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_container = VBoxContainer.new()
	_container.theme_override_constants.separation = 6
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(_container)


# =============================================================================
# PUBLIC METHODS
# =============================================================================

## Show a toast notification
func show_toast(message: String, color: Color = Color(1.0, 1.0, 1.0)) -> void:
	# Limit toast count
	if _container.get_child_count() >= MAX_TOASTS:
		var oldest = _container.get_child(0)
		oldest.queue_free()

	var label = Label.new()
	label.text = message
	label.theme_override_font_sizes.font_size = 14
	label.theme_override_colors.font_color = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background style
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	_container.add_child(panel)

	# Fade in
	panel.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.2)
	tween.tween_interval(TOAST_DURATION)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(panel.queue_free)
