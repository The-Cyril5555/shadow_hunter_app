## HelpMenu - In-game help overlay with searchable rules
##
## Accessible via F1 key or "?" button. Shows game rules organized by topic.
## Covers: setup, movement, combat, cards, characters, win conditions.
class_name HelpMenu
extends CanvasLayer


# =============================================================================
# CONSTANTS
# =============================================================================

func _get_rules() -> Array[Dictionary]:
	return [
		{"title": Tr.t("help.setup_title"), "content": Tr.t("help.setup_content")},
		{"title": Tr.t("help.turn_title"), "content": Tr.t("help.turn_content")},
		{"title": Tr.t("help.zones_title"), "content": Tr.t("help.zones_content")},
		{"title": Tr.t("help.cards_title"), "content": Tr.t("help.cards_content")},
		{"title": Tr.t("help.combat_title"), "content": Tr.t("help.combat_content")},
		{"title": Tr.t("help.factions_title"), "content": Tr.t("help.factions_content")},
		{"title": Tr.t("help.abilities_title"), "content": Tr.t("help.abilities_content")},
		{"title": Tr.t("help.save_title"), "content": Tr.t("help.save_content")},
		{"title": Tr.t("help.shortcuts_title"), "content": Tr.t("help.shortcuts_content")},
	]


# =============================================================================
# PROPERTIES
# =============================================================================

var _overlay: ColorRect
var _content_container: VBoxContainer
var _search_field: LineEdit
var _sections: Array[Dictionary] = []  # {label: Label, content: RichTextLabel, title: String}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	layer = 101  # Above pause menu
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		if visible:
			hide_help()
		else:
			show_help()
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC METHODS
# =============================================================================

func show_help() -> void:
	visible = true
	_search_field.text = ""
	_filter_sections("")
	_search_field.grab_focus()
	get_tree().paused = true
	print("[HelpMenu] Opened")


func hide_help() -> void:
	visible = false
	# Only unpause if pause menu isn't also open
	if not get_tree().paused:
		return
	# Check if a PauseMenu is visible
	var pause_menus = get_tree().get_nodes_in_group("pause_menu")
	var pause_visible = false
	for pm in pause_menus:
		if pm.visible:
			pause_visible = true
			break
	if not pause_visible:
		get_tree().paused = false
	print("[HelpMenu] Closed")


# =============================================================================
# UI BUILDING
# =============================================================================

func _build_ui() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.8)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	# Main layout
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 200)
	margin.add_theme_constant_override("margin_right", 200)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	_overlay.add_child(margin)

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.98)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.4, 0.6)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Header row
	var header = HBoxContainer.new()
	vbox.add_child(header)

	var title = Label.new()
	title.text = Tr.t("help.title")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = Tr.t("help.close")
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(hide_help)
	header.add_child(close_btn)

	# Search field
	_search_field = LineEdit.new()
	_search_field.placeholder_text = Tr.t("help.search")
	_search_field.add_theme_font_size_override("font_size", 16)
	_search_field.text_changed.connect(_filter_sections)
	vbox.add_child(_search_field)

	# Separator
	vbox.add_child(HSeparator.new())

	# Scrollable content
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_content_container = VBoxContainer.new()
	_content_container.add_theme_constant_override("separation", 16)
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content_container)

	# Build rule sections
	for rule in _get_rules():
		var section = _create_section(rule.title, rule.content)
		_content_container.add_child(section.container)
		_sections.append(section)


func _create_section(title_text: String, content_text: String) -> Dictionary:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	var title_label = Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	container.add_child(title_label)

	var content_label = RichTextLabel.new()
	content_label.bbcode_enabled = false
	content_label.fit_content = true
	content_label.text = content_text.strip_edges()
	content_label.add_theme_font_size_override("normal_font_size", 15)
	content_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.9))
	content_label.scroll_active = false
	container.add_child(content_label)

	return {
		"container": container,
		"label": title_label,
		"content": content_label,
		"title": title_text.to_lower(),
		"text": content_text.to_lower(),
	}


# =============================================================================
# SEARCH / FILTER
# =============================================================================

func _filter_sections(query: String) -> void:
	var q = query.strip_edges().to_lower()
	for section in _sections:
		if q == "":
			section.container.visible = true
		else:
			var matches = section.title.contains(q) or section.text.contains(q)
			section.container.visible = matches
