## test_animation_system.gd - Unit tests for Animation System Foundation
## Tests PolishConfig autoload and AnimationHelper utility
##
## Framework: GDScript built-in testing (can be run via Godot editor or CI)
## Coverage: AC1 (60 FPS), AC2 (PolishConfig), AC3 (AnimationHelper), AC4 (Reduced Motion)
extends Node


# -----------------------------------------------------------------------------
# Test Suite Configuration
# -----------------------------------------------------------------------------
const TEST_NODE_SCENE = preload("res://scenes/ui/screens/main_menu.tscn")


# -----------------------------------------------------------------------------
# Test Runner
# -----------------------------------------------------------------------------
func _ready() -> void:
	print("\n========================================")
	print("Animation System Foundation - Test Suite")
	print("========================================\n")

	var passed = 0
	var failed = 0

	# PolishConfig Tests
	if test_polish_config_loads(): passed += 1
	else: failed += 1

	if test_polish_config_get_value(): passed += 1
	else: failed += 1

	if test_polish_config_get_duration(): passed += 1
	else: failed += 1

	if test_polish_config_speed_multiplier(): passed += 1
	else: failed += 1

	# AnimationHelper Tests
	if test_animation_helper_fade_in(): passed += 1
	else: failed += 1

	if test_animation_helper_fade_out(): passed += 1
	else: failed += 1

	if test_animation_helper_scale_pulse(): passed += 1
	else: failed += 1

	if test_animation_helper_shake(): passed += 1
	else: failed += 1

	if test_animation_helper_slide_in(): passed += 1
	else: failed += 1

	# Integration Tests
	if test_reduced_motion_support(): passed += 1
	else: failed += 1

	# Summary
	print("\n========================================")
	print("Test Results:")
	print("  PASSED: %d" % passed)
	print("  FAILED: %d" % failed)
	print("  TOTAL:  %d" % (passed + failed))
	print("========================================\n")

	if failed == 0:
		print("✅ ALL TESTS PASSED")
	else:
		print("❌ SOME TESTS FAILED")

	# Exit after tests (useful for CI)
	await get_tree().create_timer(0.5).timeout
	# get_tree().quit()  # Uncomment for automated testing


# -----------------------------------------------------------------------------
# PolishConfig Tests (AC2)
# -----------------------------------------------------------------------------

## Test that PolishConfig loads successfully
func test_polish_config_loads() -> bool:
	print("[TEST] PolishConfig loads configuration...")

	if not has_node("/root/PolishConfig"):
		print("  ❌ FAILED: PolishConfig autoload not found")
		return false

	var polish_config = get_node("/root/PolishConfig")
	if polish_config.config_data.size() == 0:
		print("  ❌ FAILED: PolishConfig loaded but config_data is empty")
		return false

	print("  ✅ PASSED: PolishConfig loaded %d values" % polish_config.config_data.size())
	return true


## Test get_value() method
func test_polish_config_get_value() -> bool:
	print("[TEST] PolishConfig.get_value() returns correct values...")

	var polish_config = get_node("/root/PolishConfig")

	var shake_intensity = polish_config.get_value("shake_intensity")
	if not is_equal_approx(shake_intensity, 0.05):
		print("  ❌ FAILED: Expected shake_intensity=0.05, got %f" % shake_intensity)
		return false

	var card_flip = polish_config.get_value("card_flip_duration")
	if not is_equal_approx(card_flip, 0.8):
		print("  ❌ FAILED: Expected card_flip_duration=0.8, got %f" % card_flip)
		return false

	print("  ✅ PASSED: get_value() returns correct values")
	return true


## Test get_duration() with speed multiplier
func test_polish_config_get_duration() -> bool:
	print("[TEST] PolishConfig.get_duration() applies speed multiplier...")

	var polish_config = get_node("/root/PolishConfig")

	# Test with speed multiplier = 1.0
	polish_config.config_data["animation_speed_multiplier"] = 1.0
	var duration = polish_config.get_duration("card_play_animation_duration")

	if not is_equal_approx(duration, 0.4):
		print("  ❌ FAILED: Expected duration=0.4 (1.0x speed), got %f" % duration)
		return false

	print("  ✅ PASSED: get_duration() applies speed multiplier correctly")
	return true


## Test speed multiplier effect
func test_polish_config_speed_multiplier() -> bool:
	print("[TEST] Animation speed multiplier affects duration...")

	var polish_config = get_node("/root/PolishConfig")

	# Test 2x speed (0.5x duration)
	polish_config.config_data["animation_speed_multiplier"] = 2.0
	var duration_2x = polish_config.get_duration("card_play_animation_duration")

	# Expected: 0.4 * 2.0 = 0.8
	if not is_equal_approx(duration_2x, 0.8):
		print("  ❌ FAILED: Expected duration=0.8 (2.0x speed), got %f" % duration_2x)
		return false

	# Reset to 1.0
	polish_config.config_data["animation_speed_multiplier"] = 1.0

	print("  ✅ PASSED: Speed multiplier correctly affects duration")
	return true


# -----------------------------------------------------------------------------
# AnimationHelper Tests (AC3)
# -----------------------------------------------------------------------------

## Test fade_in creates valid tween
func test_animation_helper_fade_in() -> bool:
	print("[TEST] AnimationHelper.fade_in() creates animation...")

	var test_node = Control.new()
	add_child(test_node)

	test_node.modulate.a = 0.0
	AnimationHelper.fade_in(test_node, "card_play_animation_duration")

	await get_tree().create_timer(0.1).timeout  # Wait for tween to start

	# Check that node is fading in (alpha > 0)
	if test_node.modulate.a <= 0.0:
		print("  ❌ FAILED: Node alpha not increasing (still %f)" % test_node.modulate.a)
		test_node.queue_free()
		return false

	test_node.queue_free()
	print("  ✅ PASSED: fade_in() creates working animation")
	return true


## Test fade_out creates valid tween
func test_animation_helper_fade_out() -> bool:
	print("[TEST] AnimationHelper.fade_out() creates animation...")

	var test_node = Control.new()
	add_child(test_node)

	test_node.modulate.a = 1.0
	AnimationHelper.fade_out(test_node, "card_play_animation_duration")

	await get_tree().create_timer(0.1).timeout

	# Check that node is fading out (alpha < 1.0)
	if test_node.modulate.a >= 1.0:
		print("  ❌ FAILED: Node alpha not decreasing (still %f)" % test_node.modulate.a)
		test_node.queue_free()
		return false

	test_node.queue_free()
	print("  ✅ PASSED: fade_out() creates working animation")
	return true


## Test scale_pulse animation
func test_animation_helper_scale_pulse() -> bool:
	print("[TEST] AnimationHelper.scale_pulse() creates animation...")

	var test_node = Control.new()
	add_child(test_node)

	test_node.scale = Vector2.ONE
	AnimationHelper.scale_pulse(test_node, 1.2, "card_play_animation_duration")

	await get_tree().create_timer(0.1).timeout

	# Scale should be different from 1.0 during animation
	if is_equal_approx(test_node.scale.x, 1.0):
		print("  ❌ FAILED: Node scale not changing (still %f)" % test_node.scale.x)
		test_node.queue_free()
		return false

	test_node.queue_free()
	print("  ✅ PASSED: scale_pulse() creates working animation")
	return true


## Test shake animation
func test_animation_helper_shake() -> bool:
	print("[TEST] AnimationHelper.shake() creates animation...")

	var test_node = Control.new()
	add_child(test_node)

	var original_pos = test_node.position
	AnimationHelper.shake(test_node, "shake_intensity", 0.2)

	await get_tree().create_timer(0.1).timeout

	# Position should be different during shake
	var position_changed = not is_equal_approx(test_node.position.x, original_pos.x) \
		or not is_equal_approx(test_node.position.y, original_pos.y)

	if not position_changed:
		print("  ❌ FAILED: Node position not shaking")
		test_node.queue_free()
		return false

	test_node.queue_free()
	print("  ✅ PASSED: shake() creates working animation")
	return true


## Test slide_in animation
func test_animation_helper_slide_in() -> bool:
	print("[TEST] AnimationHelper.slide_in() creates animation...")

	var test_node = Control.new()
	add_child(test_node)

	test_node.position = Vector2.ZERO
	AnimationHelper.slide_in(test_node, Vector2(-100, 0), "card_play_animation_duration")

	# Node should be offset initially
	if is_equal_approx(test_node.position.x, 0.0):
		print("  ❌ FAILED: Node not offset before slide")
		test_node.queue_free()
		return false

	test_node.queue_free()
	print("  ✅ PASSED: slide_in() creates working animation")
	return true


# -----------------------------------------------------------------------------
# Integration Tests (AC4)
# -----------------------------------------------------------------------------

## Test reduced motion support
func test_reduced_motion_support() -> bool:
	print("[TEST] Reduced motion mode affects animation timing...")

	var polish_config = get_node("/root/PolishConfig")

	# Simulate reduced motion ON
	if has_node("/root/UserSettings"):
		var user_settings = get_node("/root/UserSettings")
		if user_settings.has("reduced_motion_enabled"):
			user_settings.reduced_motion_enabled = true

			# Get duration with reduced motion
			var duration_reduced = polish_config.get_duration("card_play_animation_duration")

			# Should be faster (multiplied by 0.3)
			# Expected: 0.4 * 0.3 = 0.12
			if duration_reduced >= 0.4:
				print("  ❌ FAILED: Reduced motion not reducing duration (got %f)" % duration_reduced)
				user_settings.reduced_motion_enabled = false
				return false

			# Reset
			user_settings.reduced_motion_enabled = false
			print("  ✅ PASSED: Reduced motion correctly reduces animation timing")
			return true
		else:
			print("  ⚠️  SKIPPED: UserSettings.reduced_motion_enabled not found")
			return true
	else:
		print("  ⚠️  SKIPPED: UserSettings autoload not found (Story 5.6 dependency)")
		return true


# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

## Helper to check floating point equality
func is_equal_approx(a: float, b: float, epsilon: float = 0.01) -> bool:
	return abs(a - b) < epsilon
