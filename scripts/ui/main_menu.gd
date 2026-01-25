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

	# Setup button hover effects
	_setup_button_hover_effects()

	print("[MainMenu] Ready")


func _setup_button_hover_effects() -> void:
	var buttons = $CenterContainer/VBoxContainer/ButtonContainer.get_children()
	for button in buttons:
		if button is Button:
			button.mouse_entered.connect(_on_button_hover.bind(button))
			button.mouse_exited.connect(_on_button_unhover.bind(button))


func _on_button_hover(button: Button) -> void:
	# Visual feedback on hover - scale up slightly
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)


func _on_button_unhover(button: Button) -> void:
	# Reset scale on unhover
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)


func _on_new_game_pressed() -> void:
	print("[MainMenu] New Game pressed")
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.GAME_SETUP)


func _on_load_game_pressed() -> void:
	print("[MainMenu] Load Game pressed - Not implemented yet")
	# TODO: Implement in Story 6.3


func _on_settings_pressed() -> void:
	print("[MainMenu] Settings pressed - Not implemented yet")
	# TODO: Implement settings screen


func _on_quit_pressed() -> void:
	print("[MainMenu] Quit pressed")
	get_tree().quit()
