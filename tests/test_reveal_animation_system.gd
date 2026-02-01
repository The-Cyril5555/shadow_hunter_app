## TestRevealAnimationSystem - Automated tests for dramatic reveal animations
## Tests AnimationOrchestrator, reveal sequence stages, and reduced motion
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
	print("REVEAL ANIMATION SYSTEM TEST SUITE")
	print("=".repeat(80) + "\n")

	# Run all tests
	run_all_tests()

	# Print summary
	print_test_summary()

	# Auto-quit after tests
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


# -----------------------------------------------------------------------------
# Test Runner
# -----------------------------------------------------------------------------
func run_all_tests() -> void:
	# Test 1: PolishConfig reveal timings exist
	run_test("PolishConfig Reveal Timings Exist", test_polish_config_reveal_timings)

	# Test 2: AnimationOrchestrator class exists
	run_test("AnimationOrchestrator Class Exists", test_animation_orchestrator_exists)

	# Test 3: Reveal sequence duration calculation
	run_test("Reveal Sequence Duration", test_reveal_sequence_duration)

	# Test 4: Reduced motion detection
	run_test("Reduced Motion Detection", test_reduced_motion_detection)

	# Test 5: Reduced motion duration adjustment
	run_test("Reduced Motion Duration Adjustment", test_reduced_motion_duration)

	# Test 6: Reduced motion particle adjustment
	run_test("Reduced Motion Particle Adjustment", test_reduced_motion_particles)

	# Test 7: Reduced motion shake adjustment
	run_test("Reduced Motion Shake Adjustment", test_reduced_motion_shake)

	# Test 8: UserSettings reduced motion property
	run_test("UserSettings Reduced Motion Property", test_user_settings_reduced_motion)

	# Test 9: Full reveal sequence (visual test)
	run_test("Full Reveal Sequence Execution", test_full_reveal_sequence)


func run_test(test_name: String, test_func: Callable) -> void:
	print("TEST: %s" % test_name)
	var passed = await test_func.call()

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

## Test 1: PolishConfig reveal timings exist
func test_polish_config_reveal_timings() -> bool:
	var required_timings = [
		"reveal_buildup_duration",
		"card_flip_duration",
		"reveal_explosion_duration",
		"reveal_pause_duration",
		"reveal_shake_intensity"
	]

	for timing_key in required_timings:
		var value = PolishConfig.get_value(timing_key, -1.0)
		if value <= 0.0:
			print("  ❌ FAILED: Missing or invalid timing: %s (got %.2f)" % [timing_key, value])
			return false

	print("  ✓ All reveal timings present in PolishConfig")
	return true


## Test 2: AnimationOrchestrator class exists
func test_animation_orchestrator_exists() -> bool:
	# Try to reference the class
	var orchestrator_script = load("res://scripts/systems/animation_orchestrator.gd")
	if not orchestrator_script:
		print("  ❌ FAILED: AnimationOrchestrator script not found")
		return false

	print("  ✓ AnimationOrchestrator class exists")
	return true


## Test 3: Reveal sequence duration calculation
func test_reveal_sequence_duration() -> bool:
	var expected_total = 0.0
	expected_total += PolishConfig.get_value("reveal_buildup_duration", 0.5)
	expected_total += PolishConfig.get_value("card_flip_duration", 0.8)
	expected_total += PolishConfig.get_value("reveal_explosion_duration", 1.0)
	expected_total += PolishConfig.get_value("reveal_pause_duration", 0.7)

	var actual_total = AnimationOrchestrator.get_reveal_sequence_duration()

	if abs(actual_total - expected_total) > 0.01:
		print("  ❌ FAILED: Duration mismatch (expected %.2fs, got %.2fs)" % [expected_total, actual_total])
		return false

	print("  ✓ Reveal sequence duration: %.2fs" % actual_total)
	return true


## Test 4: Reduced motion detection
func test_reduced_motion_detection() -> bool:
	# Save original state
	var original_state = UserSettings.reduced_motion_enabled

	# Test with reduced motion disabled
	UserSettings.set_reduced_motion(false)
	if AnimationOrchestrator.is_reduced_motion():
		print("  ❌ FAILED: Reduced motion should be false")
		UserSettings.set_reduced_motion(original_state)
		return false

	# Test with reduced motion enabled
	UserSettings.set_reduced_motion(true)
	if not AnimationOrchestrator.is_reduced_motion():
		print("  ❌ FAILED: Reduced motion should be true")
		UserSettings.set_reduced_motion(original_state)
		return false

	# Restore original state
	UserSettings.set_reduced_motion(original_state)

	print("  ✓ Reduced motion detection working")
	return true


## Test 5: Reduced motion duration adjustment
func test_reduced_motion_duration() -> bool:
	# Save original state
	var original_state = UserSettings.reduced_motion_enabled

	# Get base duration
	UserSettings.set_reduced_motion(false)
	var base_duration = AnimationOrchestrator.get_adjusted_duration("reveal_buildup_duration")

	# Get reduced duration
	UserSettings.set_reduced_motion(true)
	var reduced_duration = AnimationOrchestrator.get_adjusted_duration("reveal_buildup_duration")

	# Reduced should be 30% of original (70% faster)
	var expected_reduced = base_duration * 0.3
	if abs(reduced_duration - expected_reduced) > 0.01:
		print("  ❌ FAILED: Reduced duration incorrect (expected %.2fs, got %.2fs)" % [expected_reduced, reduced_duration])
		UserSettings.set_reduced_motion(original_state)
		return false

	# Restore original state
	UserSettings.set_reduced_motion(original_state)

	print("  ✓ Reduced motion duration: %.2fs → %.2fs (70%% faster)" % [base_duration, reduced_duration])
	return true


## Test 6: Reduced motion particle adjustment
func test_reduced_motion_particles() -> bool:
	# Save original state
	var original_state = UserSettings.reduced_motion_enabled

	var base_count = 100

	# Normal mode
	UserSettings.set_reduced_motion(false)
	var normal_particles = AnimationOrchestrator.get_adjusted_particle_count(base_count)

	# Reduced mode
	UserSettings.set_reduced_motion(true)
	var reduced_particles = AnimationOrchestrator.get_adjusted_particle_count(base_count)

	# Should be 30% of original (70% reduction)
	var expected_reduced = int(base_count * 0.3)
	if reduced_particles != expected_reduced:
		print("  ❌ FAILED: Reduced particles incorrect (expected %d, got %d)" % [expected_reduced, reduced_particles])
		UserSettings.set_reduced_motion(original_state)
		return false

	# Restore original state
	UserSettings.set_reduced_motion(original_state)

	print("  ✓ Reduced motion particles: %d → %d (70%% reduction)" % [normal_particles, reduced_particles])
	return true


## Test 7: Reduced motion shake adjustment
func test_reduced_motion_shake() -> bool:
	# Save original state
	var original_state = UserSettings.reduced_motion_enabled

	# Normal mode
	UserSettings.set_reduced_motion(false)
	var normal_shake = AnimationOrchestrator.get_adjusted_shake_intensity("reveal_shake_intensity")

	# Reduced mode
	UserSettings.set_reduced_motion(true)
	var reduced_shake = AnimationOrchestrator.get_adjusted_shake_intensity("reveal_shake_intensity")

	# Should be 50% of original
	var expected_reduced = normal_shake * 0.5
	if abs(reduced_shake - expected_reduced) > 0.001:
		print("  ❌ FAILED: Reduced shake incorrect (expected %.3f, got %.3f)" % [expected_reduced, reduced_shake])
		UserSettings.set_reduced_motion(original_state)
		return false

	# Restore original state
	UserSettings.set_reduced_motion(original_state)

	print("  ✓ Reduced motion shake: %.3f → %.3f (50%% reduction)" % [normal_shake, reduced_shake])
	return true


## Test 8: UserSettings reduced motion property
func test_user_settings_reduced_motion() -> bool:
	# Check property exists
	if not "reduced_motion_enabled" in UserSettings:
		print("  ❌ FAILED: reduced_motion_enabled property not found in UserSettings")
		return false

	# Save original state
	var original_state = UserSettings.reduced_motion_enabled

	# Test setter
	UserSettings.set_reduced_motion(true)
	if not UserSettings.reduced_motion_enabled:
		print("  ❌ FAILED: set_reduced_motion(true) didn't work")
		UserSettings.set_reduced_motion(original_state)
		return false

	UserSettings.set_reduced_motion(false)
	if UserSettings.reduced_motion_enabled:
		print("  ❌ FAILED: set_reduced_motion(false) didn't work")
		UserSettings.set_reduced_motion(original_state)
		return false

	# Restore original state
	UserSettings.set_reduced_motion(original_state)

	print("  ✓ UserSettings reduced_motion_enabled working")
	return true


## Test 9: Full reveal sequence execution
func test_full_reveal_sequence() -> bool:
	# Create test player
	var test_player = Player.new(0, "Test Player", true)
	test_player.character_id = "test"
	test_player.character_name = "Test Character"
	test_player.faction = "hunter"

	# Create test card node (simple Control)
	var test_card = Control.new()
	test_card.scale = Vector2(1.0, 1.0)
	test_card.rotation_degrees = 0.0
	test_card.position = Vector2(100, 100)
	add_child(test_card)

	# Execute reveal sequence
	var start_time = Time.get_ticks_msec()
	await AnimationOrchestrator.play_reveal_sequence(test_player, test_card, get_tree())
	var end_time = Time.get_ticks_msec()

	var actual_duration = (end_time - start_time) / 1000.0
	var expected_duration = AnimationOrchestrator.get_reveal_sequence_duration()

	# Allow 20% tolerance for timing
	var tolerance = expected_duration * 0.2
	if abs(actual_duration - expected_duration) > tolerance:
		print("  ❌ FAILED: Sequence duration out of range (expected %.2fs ± %.2fs, got %.2fs)" % [expected_duration, tolerance, actual_duration])
		test_card.queue_free()
		return false

	# Cleanup
	test_card.queue_free()

	print("  ✓ Full reveal sequence executed (%.2fs)" % actual_duration)
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
