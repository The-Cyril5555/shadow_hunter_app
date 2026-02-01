## Manual test for Story 2.3: Passive Ability System
## Run this scene to verify PassiveAbilitySystem functionality
extends Node


func _ready():
	print("\n========================================")
	print("STORY 2.3: PASSIVE ABILITY SYSTEM - MANUAL TEST")
	print("========================================\n")

	test_registration()
	test_werewolf_on_kill()
	test_catherine_on_turn_start()
	test_bryan_on_kill_forced_reveal()
	test_invalid_trigger()
	test_death_unregisters_ability()
	test_multiple_players()

	print("\n========================================")
	print("ALL MANUAL TESTS COMPLETED")
	print("========================================\n")

	# Auto-quit after tests
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func test_registration():
	print("[TEST 1] Passive ability registration...")

	# Create test player with Werewolf
	var werewolf_player = Player.new(1, "Werewolf Test", true)
	var werewolf_data = GameState.get_character("werewolf")
	werewolf_player.assign_character(werewolf_data)

	# Create PassiveAbilitySystem instance
	var passive_system = PassiveAbilitySystem.new()

	# Register ability
	passive_system.register_player_ability(werewolf_player)

	# Verify registration
	assert(passive_system.registered_abilities.has(werewolf_player.id), "✗ FAIL: Werewolf should be registered")
	assert(passive_system.registered_abilities[werewolf_player.id].trigger == "on_kill", "✗ FAIL: Werewolf trigger should be 'on_kill'")

	print("  ✓ PASS: Passive ability registered correctly\n")


func test_werewolf_on_kill():
	print("[TEST 2] Werewolf 'Unearthly Speed' heals on kill...")

	# Create players
	var werewolf_player = Player.new(1, "Werewolf", true)
	werewolf_player.assign_character(GameState.get_character("werewolf"))
	werewolf_player.hp = 10  # Damaged

	var victim = Player.new(2, "Victim", true)
	victim.assign_character(GameState.get_character("emi"))
	victim.faction = "hunter"

	# Create system
	var passive_system = PassiveAbilitySystem.new()
	passive_system.register_player_ability(werewolf_player)

	# Trigger on_kill
	passive_system._on_player_died(victim, werewolf_player)

	# Verify heal occurred
	assert(werewolf_player.hp == 12, "✗ FAIL: Werewolf should heal 2 HP (expected 12, got %d)" % werewolf_player.hp)

	print("  ✓ PASS: Werewolf heals 2 HP after kill\n")


func test_catherine_on_turn_start():
	print("[TEST 3] Catherine 'Stigmata' heals at turn start...")

	# Create Catherine player
	var catherine_player = Player.new(3, "Catherine", true)
	catherine_player.assign_character(GameState.get_character("catherine"))
	catherine_player.hp = 10  # Damaged

	# Create system
	var passive_system = PassiveAbilitySystem.new()
	passive_system.register_player_ability(catherine_player)

	# Trigger on_turn_start
	passive_system._on_turn_started(catherine_player, 1)

	# Verify heal occurred
	assert(catherine_player.hp == 11, "✗ FAIL: Catherine should heal 1 HP (expected 11, got %d)" % catherine_player.hp)

	print("  ✓ PASS: Catherine heals 1 HP at turn start\n")


func test_bryan_on_kill_forced_reveal():
	print("[TEST 4] Bryan 'My GOD!!!' forced reveal on kill...")

	# Create Bryan player
	var bryan_player = Player.new(4, "Bryan", true)
	bryan_player.assign_character(GameState.get_character("bryan"))
	bryan_player.is_revealed = false

	# Create victim with HP ≤ 12
	var victim = Player.new(5, "Victim", true)
	victim.assign_character(GameState.get_character("allie"))  # Allie has 11 HP
	victim.hp_max = 11

	# Create system
	var passive_system = PassiveAbilitySystem.new()
	passive_system.register_player_ability(bryan_player)

	# Trigger on_kill
	passive_system._on_player_died(victim, bryan_player)

	# Verify Bryan was forced to reveal
	assert(bryan_player.is_revealed == true, "✗ FAIL: Bryan should be revealed after killing HP ≤ 12 character")

	print("  ✓ PASS: Bryan forced to reveal after killing low HP character\n")


func test_invalid_trigger():
	print("[TEST 5] Invalid trigger type is skipped...")

	# Create custom player with invalid trigger
	var test_player = Player.new(6, "Invalid", true)
	test_player.character_id = "test"
	test_player.ability_data = {
		"name": "Test Ability",
		"type": "passive",
		"trigger": "invalid_trigger_type"
	}

	# Create system
	var passive_system = PassiveAbilitySystem.new()

	# Register ability (should log warning and skip)
	passive_system.register_player_ability(test_player)

	# Verify NOT registered
	assert(not passive_system.registered_abilities.has(test_player.id), "✗ FAIL: Invalid trigger should not be registered")

	print("  ✓ PASS: Invalid trigger skipped gracefully\n")


func test_death_unregisters_ability():
	print("[TEST 6] Player death unregisters ability...")

	# Create Werewolf player
	var werewolf_player = Player.new(7, "Werewolf", true)
	werewolf_player.assign_character(GameState.get_character("werewolf"))

	var victim = Player.new(8, "Victim", true)
	victim.assign_character(GameState.get_character("emi"))

	# Create system
	var passive_system = PassiveAbilitySystem.new()
	passive_system.register_player_ability(werewolf_player)

	# Verify registered
	assert(passive_system.registered_abilities.has(werewolf_player.id), "✗ FAIL: Should be registered before death")

	# Simulate werewolf dying
	passive_system._on_player_died(werewolf_player, victim)

	# Verify unregistered
	assert(not passive_system.registered_abilities.has(werewolf_player.id), "✗ FAIL: Dead player should be unregistered")

	print("  ✓ PASS: Dead player unregistered correctly\n")


func test_multiple_players():
	print("[TEST 7] Multiple players with passive abilities...")

	# Create multiple players
	var werewolf = Player.new(9, "Werewolf", true)
	werewolf.assign_character(GameState.get_character("werewolf"))
	werewolf.hp = 10

	var catherine = Player.new(10, "Catherine", true)
	catherine.assign_character(GameState.get_character("catherine"))
	catherine.hp = 12

	var bryan = Player.new(11, "Bryan", true)
	bryan.assign_character(GameState.get_character("bryan"))

	# Create system
	var passive_system = PassiveAbilitySystem.new()
	passive_system.register_player_ability(werewolf)
	passive_system.register_player_ability(catherine)
	passive_system.register_player_ability(bryan)

	# Verify all registered
	assert(passive_system.registered_abilities.has(werewolf.id), "✗ FAIL: Werewolf should be registered")
	assert(passive_system.registered_abilities.has(catherine.id), "✗ FAIL: Catherine should be registered")
	assert(passive_system.registered_abilities.has(bryan.id), "✗ FAIL: Bryan should be registered")

	# Trigger Catherine's turn start (only Catherine should heal)
	passive_system._on_turn_started(catherine, 1)
	assert(catherine.hp == 13, "✗ FAIL: Only Catherine should heal (expected 13, got %d)" % catherine.hp)
	assert(werewolf.hp == 10, "✗ FAIL: Werewolf should NOT heal on Catherine's turn (expected 10, got %d)" % werewolf.hp)

	print("  ✓ PASS: Multiple players work correctly, abilities trigger only for relevant player\n")


## Verification summary
func _exit_tree():
	print("\n[MANUAL TEST] Verification complete - check output above for failures")
