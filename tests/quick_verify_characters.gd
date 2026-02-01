## Quick verification script to check character data after corrections
extends Node

func _ready():
	print("\n=== VERIFYING CORRECTED CHARACTER DATA ===\n")

	var all_chars = GameState.get_all_characters()
	print("Total characters loaded: %d (should be 20)" % all_chars.size())

	var base = GameState.get_base_characters()
	var expansion = GameState.get_expansion_characters()
	print("Base: %d (should be 10)" % base.size())
	print("Expansion: %d (should be 10)" % expansion.size())

	var hunters = GameState.get_characters_by_faction("hunter", true)
	var shadows = GameState.get_characters_by_faction("shadow", true)
	var neutrals = GameState.get_characters_by_faction("neutral", true)

	print("\nFaction breakdown:")
	print("- Hunters: %d (should be 6 total: 3 base + 3 expansion)" % hunters.size())
	print("- Shadows: %d (should be 6 total: 3 base + 3 expansion)" % shadows.size())
	print("- Neutrals: %d (should be 8 total: 4 base + 4 expansion)" % neutrals.size())

	# Verify specific corrections
	print("\n=== Verifying specific character corrections ===")

	var charles = GameState.get_character("charles")
	print("Charles faction: %s (should be neutral)" % charles.get("faction", "ERROR"))
	print("Charles is_expansion: %s (should be false)" % charles.get("is_expansion", "ERROR"))

	var bob = GameState.get_character("bob")
	print("Bob faction: %s (should be neutral)" % bob.get("faction", "ERROR"))

	var allie = GameState.get_character("allie")
	print("Allie faction: %s (should be neutral)" % allie.get("faction", "ERROR"))

	var emi = GameState.get_character("emi")
	print("Emi faction: %s (should be hunter)" % emi.get("faction", "ERROR"))
	print("Emi is_expansion: %s (should be false)" % emi.get("is_expansion", "ERROR"))

	var fuka = GameState.get_character("fuka")
	print("Fuka faction: %s (should be hunter)" % fuka.get("faction", "ERROR"))
	print("Fuka is_expansion: %s (should be true)" % fuka.get("is_expansion", "ERROR"))

	var gregor = GameState.get_character("gregor")
	if gregor.is_empty():
		print("ERROR: Gregor not found!")
	else:
		print("Gregor found: %s (hunter expansion)" % gregor.get("name", ""))

	var david = GameState.get_character("david")
	if david.is_empty():
		print("ERROR: David not found!")
	else:
		print("David found: %s (neutral expansion)" % david.get("name", ""))

	# Check removed characters
	var jack = GameState.get_character("jack")
	if jack.is_empty():
		print("✓ Jack correctly removed (doesn't exist in game)")
	else:
		print("ERROR: Jack still exists!")

	var allie_n = GameState.get_character("allie_n")
	if allie_n.is_empty():
		print("✓ allie_n correctly removed (duplicate)")
	else:
		print("ERROR: allie_n still exists!")

	print("\n=== VERIFICATION COMPLETE ===\n")

	# Auto-quit after verification
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
