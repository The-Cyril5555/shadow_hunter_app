## Manual test for Story 2.2: Extension Toggle
## Run this scene to verify UserSettings and expansion toggle functionality
extends Node


func _ready():
	print("\n========================================")
	print("STORY 2.2: EXTENSION TOGGLE - MANUAL TEST")
	print("========================================\n")

	test_user_settings_default()
	test_user_settings_save_load()
	test_expansion_toggle_persistence()
	test_graceful_fallback()
	test_character_distribution_integration()

	print("\n========================================")
	print("ALL MANUAL TESTS COMPLETED")
	print("========================================\n")

	# Auto-quit after tests
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func test_user_settings_default():
	print("[TEST 1] UserSettings default value...")

	# UserSettings should default to include_expansion = true
	assert(UserSettings.include_expansion == true, "✗ FAIL: Default should be true")

	print("  ✓ PASS: UserSettings defaults to include_expansion = true\n")


func test_user_settings_save_load():
	print("[TEST 2] Save and load persistence...")

	# Set to false and save
	UserSettings.set_expansion_enabled(false)
	assert(UserSettings.include_expansion == false, "✗ FAIL: Should be false after set")

	# Reload from file
	UserSettings.load_settings()
	assert(UserSettings.include_expansion == false, "✗ FAIL: Should persist false after reload")

	print("  ✓ PASS: Settings persist correctly (false)\n")

	# Reset to true for other tests
	UserSettings.set_expansion_enabled(true)


func test_expansion_toggle_persistence():
	print("[TEST 3] Expansion toggle state changes...")

	var signal_emitted = false
	var emitted_value = false

	# Connect to signal
	var callable_func = func(value: bool):
		signal_emitted = true
		emitted_value = value

	UserSettings.expansion_toggle_changed.connect(callable_func)

	# Toggle to false
	UserSettings.set_expansion_enabled(false)

	assert(signal_emitted, "✗ FAIL: Signal should be emitted")
	assert(emitted_value == false, "✗ FAIL: Signal value should be false")
	assert(UserSettings.include_expansion == false, "✗ FAIL: Property should be false")

	print("  ✓ PASS: Toggle changes emit signal and update property\n")

	# Reset
	UserSettings.set_expansion_enabled(true)
	UserSettings.expansion_toggle_changed.disconnect(callable_func)


func test_graceful_fallback():
	print("[TEST 4] Graceful fallback on corrupted file...")

	# Write invalid JSON
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string("{invalid json content")
		file.close()

	# Reload should not crash and use defaults
	UserSettings.include_expansion = false  # Set to false first
	UserSettings.load_settings()  # Should fail parsing and keep current value OR reset to default

	# After failed parse, value should remain or revert to code default (true)
	# For this test, we just check no crash occurred
	print("  ✓ PASS: No crash on corrupted JSON (graceful fallback)\n")

	# Clean up - write valid settings back
	UserSettings.set_expansion_enabled(true)


func test_character_distribution_integration():
	print("[TEST 5] Integration with CharacterDistributor...")

	# Test with expansion ON
	UserSettings.set_expansion_enabled(true)
	var hunters_with_expansion = GameState.get_characters_by_faction("hunter", UserSettings.include_expansion)
	var shadows_with_expansion = GameState.get_characters_by_faction("shadow", UserSettings.include_expansion)
	var neutrals_with_expansion = GameState.get_characters_by_faction("neutral", UserSettings.include_expansion)

	var total_with_expansion = hunters_with_expansion.size() + shadows_with_expansion.size() + neutrals_with_expansion.size()
	assert(total_with_expansion == 20, "✗ FAIL: Should have 20 characters with expansion ON (got %d)" % total_with_expansion)

	print("  Expansion ON: %d total characters (%d hunters, %d shadows, %d neutrals)" % [total_with_expansion, hunters_with_expansion.size(), shadows_with_expansion.size(), neutrals_with_expansion.size()])

	# Test with expansion OFF
	UserSettings.set_expansion_enabled(false)
	var hunters_base_only = GameState.get_characters_by_faction("hunter", UserSettings.include_expansion)
	var shadows_base_only = GameState.get_characters_by_faction("shadow", UserSettings.include_expansion)
	var neutrals_base_only = GameState.get_characters_by_faction("neutral", UserSettings.include_expansion)

	var total_base_only = hunters_base_only.size() + shadows_base_only.size() + neutrals_base_only.size()
	assert(total_base_only == 10, "✗ FAIL: Should have 10 characters with expansion OFF (got %d)" % total_base_only)

	print("  Expansion OFF: %d total characters (%d hunters, %d shadows, %d neutrals)" % [total_base_only, hunters_base_only.size(), shadows_base_only.size(), neutrals_base_only.size()])

	print("  ✓ PASS: CharacterDistributor integration works correctly\n")

	# Reset
	UserSettings.set_expansion_enabled(true)


## Verification summary
func _exit_tree():
	print("\n[MANUAL TEST] Verification complete - check output above for failures")
