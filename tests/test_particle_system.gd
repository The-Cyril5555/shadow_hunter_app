## TestParticleSystem - Automated tests for ParticlePool and effects
## Tests pooling, presets, PolishConfig integration, and reduced motion
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
	print("PARTICLE SYSTEM TEST SUITE")
	print("=".repeat(80) + "\n")

	# Run all tests
	await run_all_tests()

	# Print summary
	print_test_summary()

	# Auto-quit after tests
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


# -----------------------------------------------------------------------------
# Test Runner
# -----------------------------------------------------------------------------
func run_all_tests() -> void:
	# Test 1: ParticlePool autoload exists
	run_test("ParticlePool Autoload Exists", test_particle_pool_exists)

	# Test 2: Initial pool creation
	run_test("Initial Pool Creation", test_initial_pool_creation)

	# Test 3: Spawn particles (hit_impact)
	run_test("Spawn Particles", test_spawn_particles)

	# Test 4: All effect presets exist
	run_test("Effect Presets Exist", test_effect_presets_exist)

	# Test 5: Particle count multiplier
	run_test("Particle Count Multiplier", test_particle_count_multiplier)

	# Test 6: Reduced motion particle reduction
	run_test("Reduced Motion Particle Reduction", test_reduced_motion_particles)

	# Test 7: Pool growth (spawn >20 particles)
	run_test("Pool Growth", test_pool_growth)

	# Test 8: Stop all particles
	run_test("Stop All Particles", test_stop_all_particles)

	# Test 9: Particle auto-return to pool
	run_test("Particle Auto-Return", test_particle_auto_return)

	# Test 10: Invalid preset handling
	run_test("Invalid Preset Handling", test_invalid_preset)


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


# =============================================================================
# Test Cases
# =============================================================================

## Test 1: ParticlePool autoload exists
func test_particle_pool_exists() -> bool:
	if not has_node("/root/ParticlePool"):
		print("  ❌ FAILED: ParticlePool autoload not found")
		return false

	var particle_pool = get_node("/root/ParticlePool")
	if not is_instance_valid(particle_pool):
		print("  ❌ FAILED: ParticlePool instance is invalid")
		return false

	print("  ✓ ParticlePool autoload found and valid")
	return true


## Test 2: Initial pool creation
func test_initial_pool_creation() -> bool:
	var stats = ParticlePool.get_pool_stats()

	if stats.total != 20:
		print("  ❌ FAILED: Expected 20 initial particles, got %d" % stats.total)
		return false

	if stats.available != 20:
		print("  ❌ FAILED: Expected 20 available particles, got %d" % stats.available)
		return false

	if stats.active != 0:
		print("  ❌ FAILED: Expected 0 active particles, got %d" % stats.active)
		return false

	print("  ✓ Pool initialized with 20 particles (all available)")
	return true


## Test 3: Spawn particles
func test_spawn_particles() -> bool:
	# Clean pool first
	ParticlePool.stop_all()
	await get_tree().process_frame

	var spawn_pos = Vector2(500, 500)
	var particle = ParticlePool.spawn_particles("hit_impact", spawn_pos)

	if not is_instance_valid(particle):
		print("  ❌ FAILED: Spawn returned null or invalid particle")
		return false

	if not particle.emitting:
		print("  ❌ FAILED: Spawned particle is not emitting")
		return false

	var stats = ParticlePool.get_pool_stats()
	if stats.active != 1:
		print("  ❌ FAILED: Expected 1 active particle, got %d" % stats.active)
		return false

	# Cleanup
	ParticlePool.stop_all()
	await get_tree().process_frame

	print("  ✓ Particle spawned successfully")
	return true


## Test 4: All effect presets exist
func test_effect_presets_exist() -> bool:
	var required_effects = ["hit_impact", "heal_sparkle", "explosion_burst", "card_draw_trail", "ability_glow"]
	var available_effects = ParticlePool.get_available_effects()

	for effect in required_effects:
		if effect not in available_effects:
			print("  ❌ FAILED: Missing effect preset: %s" % effect)
			return false

	print("  ✓ All 5 effect presets available: %s" % str(available_effects))
	return true


## Test 5: Particle count multiplier
func test_particle_count_multiplier() -> bool:
	# Save original multiplier
	var original_multiplier = PolishConfig.get_value("particle_count_multiplier", 1.0)

	# Test with 2.0x multiplier
	PolishConfig.config_data["particle_count_multiplier"] = 2.0

	var particle = ParticlePool.spawn_particles("hit_impact", Vector2(500, 500))
	if not is_instance_valid(particle):
		print("  ❌ FAILED: Could not spawn particle")
		PolishConfig.config_data["particle_count_multiplier"] = original_multiplier
		return false

	# Base amount for hit_impact is 15, with 2.0x should be 30
	var expected_amount = 30
	if particle.amount != expected_amount:
		print("  ❌ FAILED: Expected %d particles with 2.0x multiplier, got %d" % [expected_amount, particle.amount])
		ParticlePool.stop_all()
		PolishConfig.config_data["particle_count_multiplier"] = original_multiplier
		return false

	# Cleanup and restore
	ParticlePool.stop_all()
	await get_tree().process_frame
	PolishConfig.config_data["particle_count_multiplier"] = original_multiplier

	print("  ✓ Particle multiplier working (15 → 30 with 2.0x)")
	return true


## Test 6: Reduced motion particle reduction
func test_reduced_motion_particles() -> bool:
	# Save original state
	var original_reduced_motion = UserSettings.reduced_motion_enabled
	var original_multiplier = PolishConfig.get_value("particle_count_multiplier", 1.0)

	# Enable reduced motion
	UserSettings.set_reduced_motion(true)
	PolishConfig.config_data["particle_count_multiplier"] = 1.0

	var particle = ParticlePool.spawn_particles("hit_impact", Vector2(500, 500))
	if not is_instance_valid(particle):
		print("  ❌ FAILED: Could not spawn particle")
		UserSettings.set_reduced_motion(original_reduced_motion)
		PolishConfig.config_data["particle_count_multiplier"] = original_multiplier
		return false

	# Base amount 15, reduced motion 70% reduction = 30% = 4-5 particles
	var expected_amount = 4  # int(15 * 0.3)
	if particle.amount != expected_amount:
		print("  ❌ FAILED: Expected ~%d particles with reduced motion, got %d" % [expected_amount, particle.amount])
		ParticlePool.stop_all()
		UserSettings.set_reduced_motion(original_reduced_motion)
		PolishConfig.config_data["particle_count_multiplier"] = original_multiplier
		return false

	# Cleanup and restore
	ParticlePool.stop_all()
	await get_tree().process_frame
	UserSettings.set_reduced_motion(original_reduced_motion)
	PolishConfig.config_data["particle_count_multiplier"] = original_multiplier

	print("  ✓ Reduced motion particle reduction working (15 → %d)" % expected_amount)
	return true


## Test 7: Pool growth
func test_pool_growth() -> bool:
	# Clean pool
	ParticlePool.stop_all()
	await get_tree().process_frame

	# Spawn 25 particles (more than initial 20)
	for i in range(25):
		ParticlePool.spawn_particles("hit_impact", Vector2(500 + i * 10, 500))

	var stats = ParticlePool.get_pool_stats()
	if stats.total < 25:
		print("  ❌ FAILED: Pool should grow to at least 25, got %d" % stats.total)
		ParticlePool.stop_all()
		return false

	if stats.active != 25:
		print("  ❌ FAILED: Expected 25 active particles, got %d" % stats.active)
		ParticlePool.stop_all()
		return false

	# Cleanup
	ParticlePool.stop_all()
	await get_tree().process_frame

	print("  ✓ Pool grew dynamically (20 → %d)" % stats.total)
	return true


## Test 8: Stop all particles
func test_stop_all_particles() -> bool:
	# Spawn some particles
	for i in range(5):
		ParticlePool.spawn_particles("explosion_burst", Vector2(500 + i * 50, 500))

	var stats_before = ParticlePool.get_pool_stats()
	if stats_before.active != 5:
		print("  ❌ FAILED: Expected 5 active particles before stop, got %d" % stats_before.active)
		return false

	# Stop all
	ParticlePool.stop_all()
	await get_tree().process_frame

	var stats_after = ParticlePool.get_pool_stats()
	if stats_after.active != 0:
		print("  ❌ FAILED: Expected 0 active particles after stop, got %d" % stats_after.active)
		return false

	print("  ✓ Stop all working (%d active → 0)" % stats_before.active)
	return true


## Test 9: Particle auto-return to pool
func test_particle_auto_return() -> bool:
	# Clean pool
	ParticlePool.stop_all()
	await get_tree().process_frame

	# Spawn particle with very short lifetime
	var particle = ParticlePool.spawn_particles("hit_impact", Vector2(500, 500))
	if not is_instance_valid(particle):
		print("  ❌ FAILED: Could not spawn particle")
		return false

	# Manually set very short lifetime
	particle.lifetime = 0.1

	# Wait for particle to finish
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame

	var stats = ParticlePool.get_pool_stats()
	if stats.active != 0:
		print("  ❌ FAILED: Particle should auto-return to pool, got %d active" % stats.active)
		return false

	print("  ✓ Particle auto-returned to pool after finishing")
	return true


## Test 10: Invalid preset handling
func test_invalid_preset() -> bool:
	var particle = ParticlePool.spawn_particles("invalid_effect", Vector2(500, 500))

	if is_instance_valid(particle):
		print("  ❌ FAILED: Invalid preset should return null, got valid particle")
		ParticlePool.stop_all()
		return false

	print("  ✓ Invalid preset handled gracefully (returned null)")
	return true


# =============================================================================
# Test Summary
# =============================================================================
func print_test_summary() -> void:
	print("\n" + "=".repeat(80))
	print("TEST SUMMARY")
	print("=".repeat(80))
	print("Total Tests: %d" % (tests_passed + tests_failed))
	print("Passed: %d ✅" % tests_passed)
	print("Failed: %d ❌" % tests_failed)
	if tests_passed + tests_failed > 0:
		print("Success Rate: %.1f%%" % (tests_passed * 100.0 / (tests_passed + tests_failed)))
	print("=".repeat(80) + "\n")
