## TutorialOverlay - Step-by-step interactive tutorial overlay
##
## Guides new players through game mechanics with highlighted UI elements
## and contextual instructions. Each step waits for user action or "Next".
class_name TutorialOverlay
extends CanvasLayer


# =============================================================================
# SIGNALS
# =============================================================================

signal tutorial_completed()
signal tutorial_skipped()
signal step_action_required(action: String)


# =============================================================================
# CONSTANTS
# =============================================================================

func _get_steps() -> Array[Dictionary]:
	return [
		{"title": Tr.t("tutorial.step1_title"), "text": Tr.t("tutorial.step1_text"), "action": "next"},
		{"title": Tr.t("tutorial.step2_title"), "text": Tr.t("tutorial.step2_text"), "action": "next"},
		{"title": Tr.t("tutorial.step3_title"), "text": Tr.t("tutorial.step3_text"), "action": "roll_dice", "highlight": "roll_dice_button"},
		{"title": Tr.t("tutorial.step4_title"), "text": Tr.t("tutorial.step4_text"), "action": "move_to_zone"},
		{"title": Tr.t("tutorial.step5_title"), "text": Tr.t("tutorial.step5_text"), "action": "draw_card_or_next", "highlight": "draw_card_button"},
		{"title": Tr.t("tutorial.step6_title"), "text": Tr.t("tutorial.step6_text"), "action": "next"},
		{"title": Tr.t("tutorial.step7_title"), "text": Tr.t("tutorial.step7_text"), "action": "next"},
		{"title": Tr.t("tutorial.step8_title"), "text": Tr.t("tutorial.step8_text"), "action": "next"},
		{"title": Tr.t("tutorial.step9_title"), "text": Tr.t("tutorial.step9_text"), "action": "next"},
		{"title": Tr.t("tutorial.step10_title"), "text": Tr.t("tutorial.step10_text"), "action": "finish"},
	]


# =============================================================================
# PROPERTIES
# =============================================================================

var _current_step: int = 0
var _panel: PanelContainer
var _title_label: Label
var _text_label: RichTextLabel
var _next_button: Button
var _skip_button: Button
var _step_counter: Label
var _waiting_for_action: String = ""


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_show_step(0)


# =============================================================================
# PUBLIC METHODS
# =============================================================================

## Notify the tutorial that an action was performed
func notify_action(action: String) -> void:
	if _waiting_for_action == "" or not visible:
		return

	# Check if the performed action matches what we're waiting for
	var matches = false
	match _waiting_for_action:
		"roll_dice":
			matches = (action == "roll_dice")
		"move_to_zone":
			matches = (action == "move_to_zone")
		"draw_card_or_next":
			matches = (action == "draw_card")

	if matches:
		_waiting_for_action = ""
		_advance_step()


## Check if tutorial is active and waiting for a specific action
func is_waiting_for(_action: String) -> bool:
	return _waiting_for_action != "" and visible


# =============================================================================
# UI BUILDING
# =============================================================================

func _build_ui() -> void:
	# Semi-transparent overlay (doesn't block all input)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.3)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks through
	add_child(overlay)

	# Instruction panel at bottom
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.anchor_top = 0.7
	margin.add_theme_constant_override("margin_left", 250)
	margin.add_theme_constant_override("margin_right", 250)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	style.set_border_width_all(3)
	style.border_color = Color(1.0, 0.9, 0.3, 0.8)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Header row
	var header = HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_step_counter = Label.new()
	_step_counter.add_theme_font_size_override("font_size", 14)
	_step_counter.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	header.add_child(_step_counter)

	# Content
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	_text_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.95))
	vbox.add_child(_text_label)

	# Button row
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_skip_button = Button.new()
	_skip_button.text = Tr.t("tutorial.skip")
	_skip_button.add_theme_font_size_override("font_size", 14)
	_skip_button.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_skip_button.pressed.connect(_on_skip_pressed)
	btn_row.add_child(_skip_button)

	_next_button = Button.new()
	_next_button.add_theme_font_size_override("font_size", 18)
	_next_button.custom_minimum_size = Vector2(120, 40)
	_next_button.pressed.connect(_on_next_pressed)
	btn_row.add_child(_next_button)


# =============================================================================
# STEP MANAGEMENT
# =============================================================================

func _show_step(index: int) -> void:
	var steps = _get_steps()
	if index < 0 or index >= steps.size():
		return

	_current_step = index
	var step = steps[index]

	_title_label.text = step.title
	_text_label.text = step.text
	_step_counter.text = "%d/%d" % [index + 1, steps.size()]

	var action = step.get("action", "next")
	_waiting_for_action = ""

	match action:
		"next":
			_next_button.text = Tr.t("tutorial.next")
			_next_button.visible = true
		"finish":
			_next_button.text = Tr.t("tutorial.finish")
			_next_button.visible = true
		"roll_dice":
			_next_button.text = Tr.t("tutorial.waiting")
			_next_button.visible = false
			_waiting_for_action = "roll_dice"
			step_action_required.emit("roll_dice")
		"move_to_zone":
			_next_button.text = Tr.t("tutorial.waiting")
			_next_button.visible = false
			_waiting_for_action = "move_to_zone"
			step_action_required.emit("move_to_zone")
		"draw_card_or_next":
			_next_button.text = Tr.t("tutorial.skip_step")
			_next_button.visible = true
			_waiting_for_action = "draw_card_or_next"
			step_action_required.emit("draw_card")

	print("[Tutorial] Step %d: %s" % [index + 1, step.title])


func _advance_step() -> void:
	if _current_step + 1 < _get_steps().size():
		_show_step(_current_step + 1)
	else:
		_finish_tutorial()


func _finish_tutorial() -> void:
	visible = false
	tutorial_completed.emit()
	print("[Tutorial] Completed")


# =============================================================================
# HANDLERS
# =============================================================================

func _on_next_pressed() -> void:
	var step = _get_steps()[_current_step]
	var action = step.get("action", "next")

	if action == "finish":
		_finish_tutorial()
	else:
		_advance_step()


func _on_skip_pressed() -> void:
	visible = false
	tutorial_skipped.emit()
	print("[Tutorial] Skipped at step %d" % (_current_step + 1))
