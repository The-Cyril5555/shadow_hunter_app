## CombatSystem - Combat logic for attacks and damage
## Handles damage calculation, death processing, and combat flow.
## Pattern: Stateless utility class (RefCounted)
class_name CombatSystem
extends RefCounted


## Calculate total attack damage (D6 + equipment bonuses)
func calculate_attack_damage(attacker: Player, target: Player) -> int:
	AudioManager.play_sfx("attack_swing")

	var base_damage = roll_d6()
	var equipment_bonus = attacker.get_attack_damage_bonus()
	var total = base_damage + equipment_bonus

	print("[Combat] %s attacks %s: %d (base) + %d (equipment) = %d damage" % [
		attacker.display_name,
		target.display_name,
		base_damage,
		equipment_bonus,
		total
	])

	return total


## Apply damage to target (with defense reduction)
func apply_damage(attacker: Player, target: Player, attack_damage: int) -> void:
	# Calculate defense reduction
	var defense_bonus = target.get_defense_bonus()
	var final_damage = max(1, attack_damage - defense_bonus)  # Minimum 1 damage

	# Log defense reduction if applicable
	if defense_bonus > 0:
		print("[Combat] %s defends: %d attack - %d defense = %d final damage" % [
			target.display_name,
			attack_damage,
			defense_bonus,
			final_damage
		])
		AudioManager.play_sfx("shield_block")
	else:
		AudioManager.play_sfx("damage_hit")

	# Note: We can't spawn particles here directly because CombatSystem is RefCounted
	# and doesn't have global_position. Particle spawning should happen in UI layer.
	# For now, we'll emit the signal and let GameBoard handle particles.

	# Apply final damage
	target.hp -= final_damage
	GameState.damage_dealt.emit(attacker, target, final_damage)

	# Check for death
	if target.hp <= 0:
		process_death(target, attacker)


## Process player death (mark dead + force reveal)
func process_death(victim: Player, killer: Player) -> void:
	AudioManager.play_sfx("player_death")

	victim.is_alive = false
	victim.is_revealed = true
	GameState.player_died.emit(victim, killer)

	print("[Combat] %s killed by %s - character revealed!" % [
		victim.display_name,
		killer.display_name
	])


## Roll a D6 dice (returns 1-6)
func roll_d6() -> int:
	return randi() % 6 + 1
