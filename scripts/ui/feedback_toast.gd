## FeedbackToast - Persistent game log in the top-right corner
##
## Shows text messages that stay visible as a scrolling log.
class_name FeedbackToast
extends CanvasLayer


# =============================================================================
# PROPERTIES
# =============================================================================

var _container: VBoxContainer
var _scroll: ScrollContainer
const MAX_TOASTS: int = 20


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

	_scroll = ScrollContainer.new()
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_scroll)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 4)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.alignment = BoxContainer.ALIGNMENT_END
	_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_container)


# =============================================================================
# PUBLIC METHODS
# =============================================================================

## Show a persistent log entry
func show_toast(message: String, color: Color = Color(1.0, 1.0, 1.0)) -> void:
	# Remove oldest if at limit
	if _container.get_child_count() >= MAX_TOASTS:
		var oldest = _container.get_child(0)
		oldest.queue_free()

	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Background style
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	_container.add_child(panel)

	# Fade in only (no auto-remove)
	panel.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.2)

	# Auto-scroll to bottom
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
