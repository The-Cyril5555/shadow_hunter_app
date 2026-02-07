## PauseMenu - In-game pause menu with save/load functionality
##
## Displays pause options: Resume, Save, Load, Quit
## Save/Load shows slot selection with metadata
class_name PauseMenu
extends CanvasLayer


# =============================================================================
# SIGNALS
# =============================================================================

signal resumed()
signal quit_to_menu()


# =============================================================================
# PROPERTIES
# =============================================================================

var _panel: PanelContainer
var _main_buttons: VBoxContainer
var _save_load_panel: VBoxContainer
var _slots_container: VBoxContainer
var _current_mode: String = ""  # "save" or "load"


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	layer = 100  # Above everything
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_on_resume_pressed()
		else:
			show_pause_menu()
		get_viewport().set_input_as_handled()


# =============================================================================
# PUBLIC METHODS
# =============================================================================

func show_pause_menu() -> void:
	if not GameState.game_in_progress:
		return
	visible = true
	_show_main_menu()
	get_tree().paused = true
	print("[PauseMenu] Paused")


func hide_pause_menu() -> void:
	visible = false
	get_tree().paused = false
	print("[PauseMenu] Resumed")


# =============================================================================
# UI BUILDING
# =============================================================================

func _build_ui() -> void:
	# Dark overlay background
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Center panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 350)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.4, 0.6)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "PAUSE"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Main buttons
	_main_buttons = VBoxContainer.new()
	_main_buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(_main_buttons)

	_add_button(_main_buttons, "Reprendre", _on_resume_pressed)
	_add_button(_main_buttons, "Sauvegarder", _on_save_pressed)
	_add_button(_main_buttons, "Charger", _on_load_pressed)
	_add_button(_main_buttons, "Quitter au menu", _on_quit_pressed)

	# Save/Load panel (hidden by default)
	_save_load_panel = VBoxContainer.new()
	_save_load_panel.add_theme_constant_override("separation", 8)
	_save_load_panel.visible = false
	vbox.add_child(_save_load_panel)

	var slot_title = Label.new()
	slot_title.name = "SlotTitle"
	slot_title.add_theme_font_size_override("font_size", 20)
	slot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_load_panel.add_child(slot_title)

	_slots_container = VBoxContainer.new()
	_slots_container.add_theme_constant_override("separation", 6)
	_save_load_panel.add_child(_slots_container)

	_add_button(_save_load_panel, "Retour", _on_back_pressed)


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


# =============================================================================
# NAVIGATION
# =============================================================================

func _show_main_menu() -> void:
	_main_buttons.visible = true
	_save_load_panel.visible = false


func _show_slots(mode: String) -> void:
	_current_mode = mode
	_main_buttons.visible = false
	_save_load_panel.visible = true

	# Set title
	var slot_title = _save_load_panel.get_node("SlotTitle")
	slot_title.text = "SAUVEGARDER" if mode == "save" else "CHARGER"

	# Clear existing slots
	for child in _slots_container.get_children():
		child.queue_free()

	# Populate slots
	var slots = SaveManager.get_all_slot_info()
	for info in slots:
		var slot_id = info.get("slot_id", 0)

		# Skip auto-save for manual save
		if mode == "save" and slot_id == 0:
			continue

		# Skip empty slots for load (except if they exist)
		if mode == "load" and not info.get("exists", false):
			var empty_btn = Button.new()
			empty_btn.text = "%s - Vide" % info.get("slot_name", "")
			empty_btn.custom_minimum_size = Vector2(0, 45)
			empty_btn.disabled = true
			_slots_container.add_child(empty_btn)
			continue

		var btn = Button.new()
		if info.get("exists", false):
			btn.text = "%s - Tour %d (%d joueurs) - %s" % [
				info.get("slot_name", ""),
				info.get("turn_count", 0),
				info.get("player_count", 0),
				info.get("date_string", ""),
			]
		else:
			btn.text = "%s - Vide" % info.get("slot_name", "")

		btn.custom_minimum_size = Vector2(0, 45)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_slot_selected.bind(slot_id))
		_slots_container.add_child(btn)


# =============================================================================
# BUTTON HANDLERS
# =============================================================================

func _on_resume_pressed() -> void:
	hide_pause_menu()
	resumed.emit()


func _on_save_pressed() -> void:
	_show_slots("save")


func _on_load_pressed() -> void:
	_show_slots("load")


func _on_back_pressed() -> void:
	_show_main_menu()


func _on_quit_pressed() -> void:
	hide_pause_menu()
	GameState.reset()
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)
	quit_to_menu.emit()


func _on_slot_selected(slot_id: int) -> void:
	if _current_mode == "save":
		var success = SaveManager.save_to_slot(slot_id)
		if success:
			print("[PauseMenu] Saved to slot %d" % slot_id)
			# Refresh slots display
			_show_slots("save")
		else:
			push_warning("[PauseMenu] Save failed for slot %d" % slot_id)
	elif _current_mode == "load":
		var success: bool
		if slot_id == 0:
			success = SaveManager.load_auto_save()
		else:
			success = SaveManager.load_from_slot(slot_id)

		if success:
			print("[PauseMenu] Loaded from slot %d" % slot_id)
			hide_pause_menu()
			# Reload the game board scene to reflect loaded state
			GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME)
		else:
			push_warning("[PauseMenu] Load failed for slot %d" % slot_id)
