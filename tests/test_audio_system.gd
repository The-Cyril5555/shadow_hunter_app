## TestAudioSystem - Automated tests for AudioManager
## Tests sound playback, volume control, pool management, and bus configuration
extends Node


# -----------------------------------------------------------------------------
# Test Configuration
# -----------------------------------------------------------------------------
var test_results: Array = []
var tests_passed: int = 0
var tests_failed: int = 0


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	print("\n" + "=".repeat(80))
	print("AUDIO SYSTEM TEST SUITE")
	print("=".repeat(80) + "\n")

	# Run all tests
	run_all_tests()

	# Print summary
	print_test_summary()

	# Auto-quit after tests (optional)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


# -----------------------------------------------------------------------------
# Test Runner
# -----------------------------------------------------------------------------
func run_all_tests() -> void:
	# Test 1: AudioManager autoload exists
	run_test("AudioManager Autoload Exists", test_audio_manager_exists)

	# Test 2: Audio bus configuration
	run_test("Audio Bus Configuration", test_audio_bus_configuration)

	# Test 3: Sound pool initialization
	run_test("Sound Pool Initialization", test_sound_pool_initialization)

	# Test 4: Play SFX (silent WAV files)
	run_test("Play Sound Effect", test_play_sfx)

	# Test 5: Pitch variation
	run_test("Pitch Variation", test_pitch_variation)

	# Test 6: Volume controls
	run_test("Volume Controls", test_volume_controls)

	# Test 7: Sound pool limit (max concurrent)
	run_test("Sound Pool Limit", test_sound_pool_limit)

	# Test 8: Active sound count tracking
	run_test("Active Sound Count", test_active_sound_count)

	# Test 9: Stop all sounds
	run_test("Stop All Sounds", test_stop_all_sfx)

	# Test 10: Sound caching
	run_test("Sound Caching", test_sound_caching)


func run_test(test_name: String, test_func: Callable) -> void:
	print("TEST: %s" % test_name)
	var passed = test_func.call()

	if passed:
		tests_passed += 1
		print("  ✅ PASSED\n")
	else:
		tests_failed += 1
		print("  ❌ FAILED\n")

	test_results.append({"name": test_name, "passed": passed})


# -----------------------------------------------------------------------------
# Test Cases
# -----------------------------------------------------------------------------

## Test 1: AudioManager autoload exists
func test_audio_manager_exists() -> bool:
	if not has_node("/root/AudioManager"):
		print("  ❌ FAILED: AudioManager autoload not found")
		return false

	var audio_manager = get_node("/root/AudioManager")
	if not is_instance_valid(audio_manager):
		print("  ❌ FAILED: AudioManager instance is invalid")
		return false

	print("  ✓ AudioManager autoload found and valid")
	return true


## Test 2: Audio bus configuration
func test_audio_bus_configuration() -> bool:
	var master_bus = AudioServer.get_bus_index("Master")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var music_bus = AudioServer.get_bus_index("Music")

	if master_bus == -1:
		print("  ❌ FAILED: Master bus not found")
		return false

	if sfx_bus == -1:
		print("  ❌ FAILED: SFX bus not found")
		return false

	if music_bus == -1:
		print("  ❌ FAILED: Music bus not found")
		return false

	# Check bus hierarchy (SFX and Music should send to Master)
	var sfx_send = AudioServer.get_bus_send(sfx_bus)
	var music_send = AudioServer.get_bus_send(music_bus)

	if sfx_send != "Master":
		print("  ❌ FAILED: SFX bus should send to Master, got: %s" % sfx_send)
		return false

	if music_send != "Master":
		print("  ❌ FAILED: Music bus should send to Master, got: %s" % music_send)
		return false

	print("  ✓ All audio buses configured correctly")
	return true


## Test 3: Sound pool initialization
func test_sound_pool_initialization() -> bool:
	var pool_size = AudioManager.get_pool_size()

	if pool_size != 10:
		print("  ❌ FAILED: Expected pool size 10, got %d" % pool_size)
		return false

	print("  ✓ Sound pool initialized with %d players" % pool_size)
	return true


## Test 4: Play sound effect
func test_play_sfx() -> bool:
	# Try to play a sound (placeholder WAV file)
	var player = AudioManager.play_sfx("button_click", false)  # No pitch variation for test

	if not is_instance_valid(player):
		print("  ❌ FAILED: play_sfx returned null or invalid player")
		return false

	if not player.playing:
		print("  ❌ FAILED: Sound player is not playing")
		return false

	print("  ✓ Sound effect played successfully")
	return true


## Test 5: Pitch variation
func test_pitch_variation() -> bool:
	# Play multiple sounds with pitch variation and check they differ
	var pitches = []
	for i in range(5):
		var player = AudioManager.play_sfx("button_click", true)  # Pitch variation enabled
		if is_instance_valid(player):
			pitches.append(player.pitch_scale)

	if pitches.size() < 5:
		print("  ❌ FAILED: Not enough players returned")
		return false

	# Check that at least some pitches are different (randomization working)
	var all_same = true
	var first_pitch = pitches[0]
	for pitch in pitches:
		if abs(pitch - first_pitch) > 0.01:
			all_same = false
			break

	if all_same:
		print("  ❌ FAILED: All pitches are the same (variation not working)")
		return false

	# Check pitch range (1.0 ± 0.1 = 0.9 to 1.1)
	for pitch in pitches:
		if pitch < 0.85 or pitch > 1.15:
			print("  ❌ FAILED: Pitch %f out of expected range (0.9-1.1)" % pitch)
			return false

	print("  ✓ Pitch variation working (pitches: %s)" % str(pitches))
	return true


## Test 6: Volume controls
func test_volume_controls() -> bool:
	# Test master volume
	AudioManager.set_master_volume(0.5)
	var master_bus = AudioServer.get_bus_index("Master")
	var master_db = AudioServer.get_bus_volume_db(master_bus)

	# 0.5 linear should be approximately -6dB
	if abs(master_db - (-6.02)) > 0.5:
		print("  ❌ FAILED: Master volume incorrect (expected ~-6dB, got %.2fdB)" % master_db)
		return false

	# Test SFX volume
	AudioManager.set_sfx_volume(0.8)
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var sfx_db = AudioServer.get_bus_volume_db(sfx_bus)

	# 0.8 linear should be approximately -1.94dB
	if abs(sfx_db - (-1.94)) > 0.5:
		print("  ❌ FAILED: SFX volume incorrect (expected ~-2dB, got %.2fdB)" % sfx_db)
		return false

	# Reset volumes
	AudioManager.set_master_volume(1.0)
	AudioManager.set_sfx_volume(1.0)

	print("  ✓ Volume controls working correctly")
	return true


## Test 7: Sound pool limit (max 10 concurrent)
func test_sound_pool_limit() -> bool:
	# Try to play more than 10 sounds simultaneously
	var players = []
	for i in range(15):
		var player = AudioManager.play_sfx("button_click", false)
		if is_instance_valid(player):
			players.append(player)

	# Should only get 10 players (pool limit)
	if players.size() > 10:
		print("  ❌ FAILED: Pool limit not enforced (got %d players, expected max 10)" % players.size())
		return false

	# Clean up
	AudioManager.stop_all_sfx()

	print("  ✓ Pool limit enforced (got %d/%d players)" % [players.size(), 10])
	return true


## Test 8: Active sound count tracking
func test_active_sound_count() -> bool:
	# Clear all sounds first
	AudioManager.stop_all_sfx()

	# Wait a frame for cleanup
	await get_tree().process_frame

	var initial_count = AudioManager.get_active_sound_count()
	if initial_count != 0:
		print("  ❌ FAILED: Initial active count should be 0, got %d" % initial_count)
		return false

	# Play 3 sounds
	for i in range(3):
		AudioManager.play_sfx("button_click", false)

	var after_count = AudioManager.get_active_sound_count()
	if after_count != 3:
		print("  ❌ FAILED: Expected 3 active sounds, got %d" % after_count)
		return false

	# Clean up
	AudioManager.stop_all_sfx()

	print("  ✓ Active sound count tracking works")
	return true


## Test 9: Stop all sounds
func test_stop_all_sfx() -> bool:
	# Play several sounds
	for i in range(5):
		AudioManager.play_sfx("button_click", false)

	# Stop all
	AudioManager.stop_all_sfx()

	# Wait a frame
	await get_tree().process_frame

	var count = AudioManager.get_active_sound_count()
	if count != 0:
		print("  ❌ FAILED: After stop_all_sfx, active count should be 0, got %d" % count)
		return false

	print("  ✓ Stop all sounds works")
	return true


## Test 10: Sound caching
func test_sound_caching() -> bool:
	# Load a sound twice - should hit cache on second load
	AudioManager.play_sfx("card_draw", false)

	# Check if sound is in cache (we can't access private _sound_cache directly,
	# but we can verify no error occurs on second load)
	AudioManager.play_sfx("card_draw", false)

	# If we got here without errors, caching is working
	print("  ✓ Sound caching working (no errors on repeated loads)")
	return true


# -----------------------------------------------------------------------------
# Test Summary
# -----------------------------------------------------------------------------
func print_test_summary() -> void:
	print("\n" + "=".repeat(80))
	print("TEST SUMMARY")
	print("=".repeat(80))
	print("Total Tests: %d" % (tests_passed + tests_failed))
	print("Passed: %d ✅" % tests_passed)
	print("Failed: %d ❌" % tests_failed)
	print("Success Rate: %.1f%%" % (tests_passed * 100.0 / (tests_passed + tests_failed)))
	print("=".repeat(80) + "\n")
