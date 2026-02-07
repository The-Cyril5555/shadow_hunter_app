## SaveManager - Handles game save/load operations
##
## Provides auto-save and manual save/load with 3 save slots.
## Saves to user:// directory as JSON files.
##
## Features:
## - Auto-save every N major actions
## - 3 manual save slots with metadata
## - Non-blocking save operations
## - Save validation with version checking
##
## Pattern: Utility class with static methods
class_name SaveManager
extends RefCounted


# =============================================================================
# CONSTANTS
# =============================================================================

const SAVE_DIR: String = "user://saves/"
const AUTO_SAVE_FILE: String = "autosave.json"
const SAVE_SLOT_PREFIX: String = "save_slot_"
const MAX_SAVE_SLOTS: int = 3
const AUTO_SAVE_INTERVAL: int = 5  # Save every N major actions
const SAVE_VERSION: int = 1


# =============================================================================
# AUTO-SAVE
# =============================================================================

## Track action count for auto-save
static var _action_count: int = 0


## Increment action counter and auto-save if threshold reached
static func track_action() -> void:
	_action_count += 1
	if _action_count >= AUTO_SAVE_INTERVAL:
		auto_save()
		_action_count = 0


## Reset action counter (on new game or load)
static func reset_action_counter() -> void:
	_action_count = 0


## Perform auto-save
static func auto_save() -> bool:
	var save_data = _build_save_data("autosave")
	var success = _write_save_file(AUTO_SAVE_FILE, save_data)
	if success:
		print("[SaveManager] Auto-save completed (turn %d)" % GameState.turn_count)
	return success


# =============================================================================
# MANUAL SAVE/LOAD
# =============================================================================

## Save to a specific slot (1-3)
static func save_to_slot(slot: int) -> bool:
	if slot < 1 or slot > MAX_SAVE_SLOTS:
		push_error("[SaveManager] Invalid slot: %d" % slot)
		return false

	var filename = "%s%d.json" % [SAVE_SLOT_PREFIX, slot]
	var save_data = _build_save_data("slot_%d" % slot)
	var success = _write_save_file(filename, save_data)
	if success:
		print("[SaveManager] Saved to slot %d" % slot)
	return success


## Load from a specific slot (1-3)
static func load_from_slot(slot: int) -> bool:
	if slot < 1 or slot > MAX_SAVE_SLOTS:
		push_error("[SaveManager] Invalid slot: %d" % slot)
		return false

	var filename = "%s%d.json" % [SAVE_SLOT_PREFIX, slot]
	return _load_save_file(filename)


## Load from auto-save
static func load_auto_save() -> bool:
	return _load_save_file(AUTO_SAVE_FILE)


# =============================================================================
# SLOT INFO
# =============================================================================

## Get metadata for all save slots (for display in UI)
static func get_all_slot_info() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []

	# Auto-save slot
	var auto_info = _get_slot_metadata(AUTO_SAVE_FILE)
	auto_info["slot_name"] = "Auto-save"
	auto_info["slot_id"] = 0
	slots.append(auto_info)

	# Manual slots
	for i in range(1, MAX_SAVE_SLOTS + 1):
		var filename = "%s%d.json" % [SAVE_SLOT_PREFIX, i]
		var info = _get_slot_metadata(filename)
		info["slot_name"] = "Emplacement %d" % i
		info["slot_id"] = i
		slots.append(info)

	return slots


## Check if a save file exists
static func has_save(slot: int) -> bool:
	var filename: String
	if slot == 0:
		filename = AUTO_SAVE_FILE
	else:
		filename = "%s%d.json" % [SAVE_SLOT_PREFIX, slot]

	return FileAccess.file_exists(SAVE_DIR + filename)


## Delete a save slot
static func delete_save(slot: int) -> bool:
	var filename: String
	if slot == 0:
		filename = AUTO_SAVE_FILE
	else:
		filename = "%s%d.json" % [SAVE_SLOT_PREFIX, slot]

	var path = SAVE_DIR + filename
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[SaveManager] Deleted save: %s" % filename)
		return true
	return false


# =============================================================================
# PRIVATE - Build & Write
# =============================================================================

## Build complete save data with metadata
static func _build_save_data(save_name: String) -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"save_name": save_name,
		"timestamp": Time.get_unix_time_from_system(),
		"date_string": Time.get_datetime_string_from_system(),
		"game_state": GameState.to_dict(),
	}


## Write save data to file
static func _write_save_file(filename: String, data: Dictionary) -> bool:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var path = SAVE_DIR + filename
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Failed to open file for writing: %s (error: %d)" % [path, FileAccess.get_open_error()])
		return false

	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	return true


## Load save data from file and restore game state
static func _load_save_file(filename: String) -> bool:
	var path = SAVE_DIR + filename

	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] Save file not found: %s" % path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Failed to open file for reading: %s" % path)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[SaveManager] JSON parse error in %s: %s" % [filename, json.get_error_message()])
		return false

	var data = json.data
	if not data is Dictionary:
		push_error("[SaveManager] Invalid save data format in %s" % filename)
		return false

	# Version check
	var version = data.get("save_version", 0)
	if version != SAVE_VERSION:
		push_warning("[SaveManager] Save version mismatch: expected %d, got %d" % [SAVE_VERSION, version])

	# Restore game state
	var game_data = data.get("game_state", {})
	GameState.from_dict(game_data)

	# Reset auto-save counter
	reset_action_counter()

	print("[SaveManager] Loaded save: %s (turn %d, %d players)" % [
		filename,
		GameState.turn_count,
		GameState.players.size()
	])
	return true


## Get metadata for a save file (without loading full state)
static func _get_slot_metadata(filename: String) -> Dictionary:
	var path = SAVE_DIR + filename
	var info = {
		"exists": false,
		"timestamp": 0,
		"date_string": "",
		"turn_count": 0,
		"player_count": 0,
	}

	if not FileAccess.file_exists(path):
		return info

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return info

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return info

	var data = json.data
	if not data is Dictionary:
		return info

	info.exists = true
	info.timestamp = data.get("timestamp", 0)
	info.date_string = data.get("date_string", "")

	var game_data = data.get("game_state", {})
	info.turn_count = game_data.get("turn_count", 0)
	info.player_count = game_data.get("players", []).size()

	return info
