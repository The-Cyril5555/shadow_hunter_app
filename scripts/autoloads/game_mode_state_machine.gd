## GameModeStateMachine - Manages game mode transitions (Autoload)
## Controls scene changes and game state flow.
class_name GameModeStateMachineClass
extends Node


enum GameMode {
	MAIN_MENU,
	GAME_SETUP,
	SETTINGS,
	TUTORIAL,
	GAME,
	GAME_OVER,
	ONLINE_LOBBY
}


var current_mode: GameMode = GameMode.MAIN_MENU


signal mode_changed(old_mode: GameMode, new_mode: GameMode)


func _ready() -> void:
	print("[GameModeStateMachine] Initialized")


func transition_to(new_mode: GameMode) -> void:
	if new_mode == current_mode:
		print("[GameModeStateMachine] Already in mode: %s" % GameMode.keys()[new_mode])
		return

	var old_mode = current_mode
	current_mode = new_mode

	print("[GameModeStateMachine] Transitioning: %s → %s" % [GameMode.keys()[old_mode], GameMode.keys()[new_mode]])

	mode_changed.emit(old_mode, new_mode)

	match new_mode:
		GameMode.MAIN_MENU:
			get_tree().change_scene_to_file("res://scenes/ui/screens/main_menu.tscn")
		GameMode.GAME_SETUP:
			get_tree().change_scene_to_file("res://scenes/ui/screens/game_setup.tscn")
		GameMode.SETTINGS:
			get_tree().change_scene_to_file("res://scenes/ui/screens/settings_menu.tscn")
		GameMode.TUTORIAL:
			get_tree().change_scene_to_file("res://scenes/game/game_board.tscn")
		GameMode.GAME:
			get_tree().change_scene_to_file("res://scenes/game/game_board.tscn")
		GameMode.GAME_OVER:
			get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
		GameMode.ONLINE_LOBBY:
			get_tree().change_scene_to_file("res://scenes/ui/screens/online_lobby.tscn")


func get_mode_name() -> String:
	return GameMode.keys()[current_mode]
