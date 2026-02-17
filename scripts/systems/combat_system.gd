## CombatSystem - Combat logic for attacks and damage
## Handles damage calculation, death processing, and combat flow.
## Pattern: Stateless utility class (RefCounted)
class_name CombatSystem
extends RefCounted


## Calculate attack damage using Shadow Hunters rules: |D6 - D4|
## If both dice are equal, the attack misses (0 damage).
## Valkyrie uses d4 only (no miss possible).
## Used by bots who don't go through the visual dice popup.
func calculate_attack_damage(attacker: Player, target: Player) -> Dictionary:
	var d6 = randi() % 6 + 1
	var d4 = randi() % 4 + 1

	# Valkyrie "Horn of War Outbreak" — uses d4 only, no miss
	var is_valkyrie = attacker.character_id == "valkyrie" \
		and attacker.is_revealed and not attacker.ability_disabled

	# Cursed Sword Masamune — d4 only, no miss
	var has_cursed_sword = _has_active_equipment(attacker, "forced_attack")

	var missed: bool
	var base_damage: int
	if is_valkyrie or has_cursed_sword:
		missed = false
		base_damage = d4
		d6 = 0  # Not used
	elif d6 == d4:
		missed = true
		base_damage = 0
	else:
		missed = false
		base_damage = abs(d6 - d4)

	var equipment_bonus = attacker.get_attack_damage_bonus()
	var defense_bonus = target.get_defense_bonus()
	var total = 0
	if not missed:
		total = max(1, base_damage + equipment_bonus - defense_bonus)

	if is_valkyrie:
		print("[Combat] %s (Valkyrie) attacks %s: D4=%d +%d equip −%d def = %d" % [
			attacker.display_name, target.display_name,
			d4, equipment_bonus, defense_bonus, total
		])
	else:
		print("[Combat] %s attacks %s: D6=%d D4=%d → |%d−%d|=%d +%d equip −%d def = %d%s" % [
			attacker.display_name, target.display_name,
			d6, d4, d6, d4, base_damage,
			equipment_bonus, defense_bonus, total,
			" (MISSED)" if missed else ""
		])

	return {
		"d6": d6, "d4": d4,
		"base": base_damage,
		"equipment": equipment_bonus,
		"defense": defense_bonus,
		"total": total,
		"missed": missed,
	}


## Apply pre-calculated damage to target (defense already factored in by caller)
func apply_damage(attacker: Player, target: Player, final_damage: int) -> void:
	# Gregor "Ghostly Barrier" - absorb all damage if shielded
	if target.has_meta("shielded") and target.get_meta("shielded"):
		print("[Combat] %s is shielded by Ghostly Barrier — no damage!" % target.display_name)
		target.set_meta("shielded", false)
		AudioManager.play_sfx("shield_block")
		return

	# Guardian Angel — immune to attack damage until next turn
	if target.has_meta("damage_immune") and target.get_meta("damage_immune"):
		print("[Combat] %s is protected by Guardian Angel — no damage!" % target.display_name)
		AudioManager.play_sfx("shield_block")
		return

	if final_damage <= 0:
		return

	# Apply damage
	target.hp -= final_damage
	GameState.damage_dealt.emit(attacker, target, final_damage)

	# Vampire "Suck Blood" - heal 2 when attacking and dealing damage
	if attacker.character_id == "vampire" and attacker.is_revealed and not attacker.ability_disabled and final_damage > 0:
		attacker.heal(2)
		print("[Combat] Vampire's Suck Blood: healed 2 HP after dealing damage")

	# Check for death
	if target.hp <= 0:
		process_death(target, attacker)


## Process player death (mark dead + force reveal)
func process_death(victim: Player, killer: Player) -> void:
	AudioManager.play_sfx("player_death")

	victim.is_alive = false
	victim.is_revealed = true
	GameState.character_revealed.emit(victim, null, victim.faction)

	# Silver Rosary — killer steals all equipment from victim
	if killer and killer != victim:
		for card in killer.equipment:
			if card.get_effect_type() == "steal_equip_on_kill":
				if card.faction_restriction == "" or killer.faction == card.faction_restriction:
					var stolen_cards = victim.equipment.duplicate()
					for stolen in stolen_cards:
						victim.equipment.erase(stolen)
						killer.equipment.append(stolen)
					if stolen_cards.size() > 0:
						print("[Combat] Silver Rosary: %s stole %d equipment from %s" % [killer.display_name, stolen_cards.size(), victim.display_name])
					break

	GameState.player_died.emit(victim, killer)

	print("[Combat] %s killed by %s - character revealed!" % [
		victim.display_name,
		killer.display_name
	])


## Check if player has an active equipment with the given effect type (faction OK)
static func _has_active_equipment(player: Player, effect_type: String) -> bool:
	for card in player.equipment:
		if card.get_effect_type() == effect_type:
			if card.faction_restriction == "" or player.faction == card.faction_restriction:
				return true
	return false
