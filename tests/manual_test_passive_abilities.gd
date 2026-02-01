## Manual test runner for Story 2.3: Passive Ability System
## This test verifies basic passive ability functionality
extends Node


func _ready():
	print("\n========================================")
	print("STORY 2.3: PASSIVE ABILITY SYSTEM")
	print("Manual Test Verification")
	print("========================================\n")

	print("[INFO] Testing passive ability registration and execution...")

	# Test 1: Verify PassiveAbilitySystem exists
	print("\n[TEST 1] PassiveAbilitySystem class exists")
	var system = PassiveAbilitySystem.new()
	assert(system != null, "FAIL: PassiveAbilitySystem should exist")
	print("  ✓ PASS: PassiveAbilitySystem instantiated")

	# Test 2: Verify VALID_TRIGGERS constant
	print("\n[TEST 2] VALID_TRIGGERS defined correctly")
	assert(PassiveAbilitySystem.VALID_TRIGGERS.size() == 6, "FAIL: Should have 6 trigger types")
	assert("on_kill" in PassiveAbilitySystem.VALID_TRIGGERS, "FAIL: Missing on_kill")
	assert("on_turn_start" in PassiveAbilitySystem.VALID_TRIGGERS, "FAIL: Missing on_turn_start")
	assert("on_attacked" in PassiveAbilitySystem.VALID_TRIGGERS, "FAIL: Missing on_attacked")
	assert("on_attack" in PassiveAbilitySystem.VALID_TRIGGERS, "FAIL: Missing on_attack")
	assert("on_reveal" in PassiveAbilitySystem.VALID_TRIGGERS, "FAIL: Missing on_reveal")
	assert("on_death" in PassiveAbilitySystem.VALID_TRIGGERS, "FAIL: Missing on_death")
	print("  ✓ PASS: All 6 trigger types present")

	# Test 3: Verify GameState has passive_ability_system
	print("\n[TEST 3] GameState integration")
	assert(GameState.passive_ability_system != null, "FAIL: GameState should have passive_ability_system")
	print("  ✓ PASS: PassiveAbilitySystem integrated in GameState")

	# Test 4: Test registration
	print("\n[TEST 4] Ability registration")
	var test_player = Player.new(99, "Test Player", true)
	var werewolf_data = GameState.get_character("werewolf")
	test_player.assign_character(werewolf_data)

	system.register_player_ability(test_player)
	assert(system.registered_abilities.has(test_player.id), "FAIL: Player should be registered")
	assert(system.registered_abilities[test_player.id].trigger == "on_kill", "FAIL: Trigger should be on_kill")
	print("  ✓ PASS: Werewolf ability registered with on_kill trigger")

	# Test 5: Test Catherine
	print("\n[TEST 5] Catherine ability registration")
	var catherine_player = Player.new(100, "Catherine Test", true)
	var catherine_data = GameState.get_character("catherine")
	catherine_player.assign_character(catherine_data)

	system.register_player_ability(catherine_player)
	assert(system.registered_abilities.has(catherine_player.id), "FAIL: Catherine should be registered")
	assert(system.registered_abilities[catherine_player.id].trigger == "on_turn_start", "FAIL: Trigger should be on_turn_start")
	print("  ✓ PASS: Catherine ability registered with on_turn_start trigger")

	# Test 6: Test Bryan
	print("\n[TEST 6] Bryan ability registration")
	var bryan_player = Player.new(101, "Bryan Test", true)
	var bryan_data = GameState.get_character("bryan")
	bryan_player.assign_character(bryan_data)

	system.register_player_ability(bryan_player)
	assert(system.registered_abilities.has(bryan_player.id), "FAIL: Bryan should be registered")
	assert(system.registered_abilities[bryan_player.id].trigger == "on_kill", "FAIL: Trigger should be on_kill")
	print("  ✓ PASS: Bryan ability registered with on_kill trigger")

	# Test 7: Test invalid trigger
	print("\n[TEST 7] Invalid trigger rejection")
	var invalid_player = Player.new(102, "Invalid Test", true)
	invalid_player.character_id = "test"
	invalid_player.ability_data = {
		"name": "Invalid Ability",
		"type": "passive",
		"trigger": "invalid_trigger"
	}

	system.register_player_ability(invalid_player)
	assert(not system.registered_abilities.has(invalid_player.id), "FAIL: Invalid trigger should not register")
	print("  ✓ PASS: Invalid trigger rejected gracefully")

	# Test 8: Test non-passive ability
	print("\n[TEST 8] Non-passive ability skipped")
	var active_player = Player.new(103, "Active Test", true)
	var vampire_data = GameState.get_character("vampire")
	active_player.assign_character(vampire_data)

	system.register_player_ability(active_player)
	assert(not system.registered_abilities.has(active_player.id), "FAIL: Active abilities should not register")
	print("  ✓ PASS: Active abilities correctly skipped")

	# Test 9: Test unregistration
	print("\n[TEST 9] Ability unregistration")
	var unreg_player = Player.new(104, "Unreg Test", true)
	unreg_player.assign_character(werewolf_data)

	system.register_player_ability(unreg_player)
	assert(system.registered_abilities.has(unreg_player.id), "FAIL: Should be registered")

	system.unregister_player_ability(unreg_player)
	assert(not system.registered_abilities.has(unreg_player.id), "FAIL: Should be unregistered")
	print("  ✓ PASS: Ability unregistered correctly")

	print("\n========================================")
	print("ALL BASIC TESTS PASSED")
	print("========================================\n")

	print("[INFO] To test ability execution (healing, damage, etc.), run the game")
	print("[INFO] and verify that abilities trigger automatically during gameplay.\n")

	# Auto-quit
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
