## MainMenu - Main menu screen controller
## Handles menu button interactions and navigation.
class_name MainMenu
extends Control


func _ready() -> void:
	# Connect button signals
	$CenterContainer/VBoxContainer/ButtonContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$CenterContainer/VBoxContainer/ButtonContainer/LoadGameButton.pressed.connect(_on_load_game_pressed)
	$CenterContainer/VBoxContainer/ButtonContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$CenterContainer/VBoxContainer/ButtonContainer/QuitButton.pressed.connect(_on_quit_pressed)

	# Add tutorial button programmatically (before Settings)
	var btn_container = $CenterContainer/VBoxContainer/ButtonContainer
	var tutorial_btn = Button.new()
	tutorial_btn.name = "TutorialButton"
	tutorial_btn.custom_minimum_size = Vector2(250, 50)
	tutorial_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tutorial_btn.theme_override_font_sizes.font_size = 22
	tutorial_btn.text = "Tutorial"
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	# Insert after LoadGameButton (index 1)
	btn_container.add_child(tutorial_btn)
	btn_container.move_child(tutorial_btn, 2)

	# Setup button hover effects
	_setup_button_hover_effects()

	# Add help menu (F1)
	var help_menu = HelpMenu.new()
	add_child(help_menu)

	# Add "?" button in bottom-right corner
	var help_btn = Button.new()
	help_btn.text = "?"
	help_btn.tooltip_text = "Aide et règles (F1)"
	help_btn.custom_minimum_size = Vector2(44, 44)
	help_btn.theme_override_font_sizes.font_size = 24
	help_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	help_btn.position = Vector2(-54, -54)
	help_btn.pressed.connect(func(): help_menu.show_help())
	add_child(help_btn)

	print("[MainMenu] Ready")


func _setup_button_hover_effects() -> void:
	var buttons = $CenterContainer/VBoxContainer/ButtonContainer.get_children()
	for button in buttons:
		if button is Button:
			button.mouse_entered.connect(_on_button_hover.bind(button))
			button.mouse_exited.connect(_on_button_unhover.bind(button))


func _on_button_hover(button: Button) -> void:
	# Audio feedback
	AudioManager.play_sfx("button_hover")

	# Visual feedback on hover - scale up slightly
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)


func _on_button_unhover(button: Button) -> void:
	# Reset scale on unhover
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)


func _on_new_game_pressed() -> void:
	AudioManager.play_sfx("button_click")
	print("[MainMenu] New Game pressed")
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME_SETUP)


func _on_load_game_pressed() -> void:
	AudioManager.play_sfx("button_click")
	print("[MainMenu] Load Game pressed")

	# Check if any save exists
	var has_any_save = false
	for i in range(0, SaveManager.MAX_SAVE_SLOTS + 1):
		if SaveManager.has_save(i):
			has_any_save = true
			break

	if not has_any_save:
		print("[MainMenu] No saves found")
		return

	# Show load dialog
	_show_load_dialog()


func _on_tutorial_pressed() -> void:
	AudioManager.play_sfx("button_click")
	print("[MainMenu] Tutorial pressed")

	# Setup a minimal game for tutorial: 1 human + 3 bots
	GameState.reset()
	var human = Player.new(0, "Vous", true)
	GameState.players.append(human)
	for i in range(3):
		var bot = Player.new(i + 1, "Bot %d" % (i + 1), false)
		GameState.players.append(bot)

	# Distribute characters
	CharacterDistributor.distribute_characters(GameState.players, 4, false)

	# Assign personalities to bots
	var personalities = PersonalityManager.load_personalities()
	if not personalities.is_empty():
		PersonalityManager.assign_personalities_to_bots(GameState.players, personalities)

	# Ensure human player is first
	for i in range(GameState.players.size()):
		if GameState.players[i].is_human:
			if i != 0:
				var temp = GameState.players[0]
				GameState.players[0] = GameState.players[i]
				GameState.players[i] = temp
			break

	# Update IDs
	for i in range(GameState.players.size()):
		GameState.players[i].id = i

	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.TUTORIAL)


func _on_settings_pressed() -> void:
	AudioManager.play_sfx("button_click")
	print("[MainMenu] Settings pressed - Not implemented yet")
	# TODO: Implement settings screen


func _on_quit_pressed() -> void:
	AudioManager.play_sfx("button_click")
	print("[MainMenu] Quit pressed")
	get_tree().quit()


## Show load game dialog with available save slots
func _show_load_dialog() -> void:
	# Create overlay
	var overlay = ColorRect.new()
	overlay.name = "LoadOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 300)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	style.set_border_width_all(2)
	style.border_color = Color(0.4, 0.4, 0.6)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.theme_override_constants.separation = 10
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "CHARGER UNE PARTIE"
	title.theme_override_font_sizes.font_size = 22
	title.theme_override_colors.font_color = Color(1.0, 0.9, 0.3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Populate save slots
	var slots = SaveManager.get_all_slot_info()
	for info in slots:
		var slot_id = info.get("slot_id", 0)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 45)
		btn.theme_override_font_sizes.font_size = 14

		if info.get("exists", false):
			btn.text = "%s - Tour %d (%d joueurs) - %s" % [
				info.get("slot_name", ""),
				info.get("turn_count", 0),
				info.get("player_count", 0),
				info.get("date_string", ""),
			]
			btn.pressed.connect(_on_load_slot_selected.bind(slot_id, overlay))
		else:
			btn.text = "%s - Vide" % info.get("slot_name", "")
			btn.disabled = true

		vbox.add_child(btn)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "Retour"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.theme_override_font_sizes.font_size = 16
	back_btn.pressed.connect(func(): overlay.queue_free())
	vbox.add_child(back_btn)


func _on_load_slot_selected(slot_id: int, overlay: Control) -> void:
	var success: bool
	if slot_id == 0:
		success = SaveManager.load_auto_save()
	else:
		success = SaveManager.load_from_slot(slot_id)

	if success:
		overlay.queue_free()
		GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME)
	else:
		print("[MainMenu] Failed to load slot %d" % slot_id)
