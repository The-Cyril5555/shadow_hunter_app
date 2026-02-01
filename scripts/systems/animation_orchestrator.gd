## AnimationOrchestrator - Coordinates complex multi-stage animation sequences
##
## Manages dramatic reveal sequences with synchronized animations, particles,
## sounds, and timing. All sequences are async and can be cancelled.
##
## Pattern: Stateless utility class with async coordination methods
## Usage: await AnimationOrchestrator.play_reveal_sequence(player, card_node)
class_name AnimationOrchestrator
extends RefCounted


# =============================================================================
# CONSTANTS - Sequence Stages
# =============================================================================

enum RevealStage {
	BUILDUP,      # Anticipation particles and scale pulse
	FLIP,         # Card rotation reveal
	EXPLOSION,    # Dramatic particle burst and shake
	PAUSE,        # Hold to appreciate reveal
	STING         # Musical cue
}


# =============================================================================
# PUBLIC METHODS - Reveal Sequence
# =============================================================================

## Play complete dramatic reveal sequence for a character
## @param player: Player instance being revealed
## @param card_node: Control/Node2D displaying the character card
## @param tree: SceneTree for awaiting (usually card_node.get_tree())
## @returns: void (async)
static func play_reveal_sequence(player: Player, card_node: Node, tree: SceneTree) -> void:
	if not is_instance_valid(player) or not is_instance_valid(card_node):
		push_error("[AnimationOrchestrator] Invalid player or card_node")
		return

	if not is_instance_valid(tree):
		push_error("[AnimationOrchestrator] Invalid tree reference")
		return

	print("[AnimationOrchestrator] Starting reveal sequence for %s (%s)" % [player.character_name, player.faction])

	# Stage 1: Buildup (0.5s)
	await _stage_buildup(card_node, tree)

	# Stage 2: Card Flip (0.8s)
	await _stage_flip(card_node, player, tree)

	# Stage 3: Explosion (1.0s)
	await _stage_explosion(card_node, tree)

	# Stage 4: Music Sting (simultaneous with pause)
	_stage_sting(player)

	# Stage 5: Pause (0.7s)
	await _stage_pause(tree)

	print("[AnimationOrchestrator] Reveal sequence completed for %s" % player.character_name)


# =============================================================================
# PRIVATE METHODS - Sequence Stages
# =============================================================================

## Stage 1: Buildup - Anticipation with particles and pulse
static func _stage_buildup(card_node: Node, tree: SceneTree) -> void:
	var duration = PolishConfig.get_duration("reveal_buildup_duration")

	# Scale pulse animation (1.0 → 1.05 → 1.0)
	if card_node.has("scale"):
		AnimationHelper.scale_pulse(card_node, 1.05, "reveal_buildup_duration")

	# TODO: Spawn buildup particles (Story 5.4 will implement particles)
	# For now, just play buildup sound
	AudioManager.play_sfx("reveal_dramatic", false)  # No pitch variation for dramatic sound

	# Wait for buildup duration
	await tree.create_timer(duration).timeout

	print("[AnimationOrchestrator] Buildup stage complete (%.2fs)" % duration)


## Stage 2: Card Flip - Rotate card and reveal character
static func _stage_flip(card_node: Node, player: Player, tree: SceneTree) -> void:
	var duration = PolishConfig.get_duration("card_flip_duration")

	if not card_node.has("rotation_degrees"):
		push_warning("[AnimationOrchestrator] Card node doesn't have rotation_degrees property")
		await tree.create_timer(duration).timeout
		return

	# Create flip animation tween
	var tween = card_node.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Rotate 180 degrees (flip over)
	tween.tween_property(card_node, "rotation_degrees", 180.0, duration * 0.5)

	# Rotate back to 0 (complete flip)
	tween.tween_property(card_node, "rotation_degrees", 360.0, duration * 0.5)

	# Wait for mid-flip to swap texture/text
	await tree.create_timer(duration * 0.5).timeout

	# TODO: Swap card texture/text to show character (requires card_node structure)
	# For now, just update via signal or assume UI handles it

	# Wait for flip to complete
	await tree.create_timer(duration * 0.5).timeout

	# Reset rotation to 0
	if card_node.has("rotation_degrees"):
		card_node.rotation_degrees = 0.0

	print("[AnimationOrchestrator] Flip stage complete (%.2fs)" % duration)


## Stage 3: Explosion - Dramatic burst with particles and shake
static func _stage_explosion(card_node: Node, tree: SceneTree) -> void:
	var duration = PolishConfig.get_duration("reveal_explosion_duration")
	var shake_intensity = PolishConfig.get_shake_intensity("reveal_shake_intensity")

	# Play explosion sound (reuse dramatic sound or add new one)
	# Using same sound as buildup but with pitch variation for variety
	AudioManager.play_sfx("reveal_dramatic", true)

	# Screen shake effect
	if card_node.has("position"):
		AnimationHelper.shake(card_node, "reveal_shake_intensity", duration * 0.3)

	# Scale pop animation (1.0 → 1.3 → 1.0)
	if card_node.has("scale"):
		AnimationHelper.scale_pop(card_node, 1.3, "reveal_explosion_duration")

	# TODO: Spawn explosion particles (Story 5.4 will implement particles)

	# Wait for explosion duration
	await tree.create_timer(duration).timeout

	print("[AnimationOrchestrator] Explosion stage complete (%.2fs)" % duration)


## Stage 4: Music Sting - Play dramatic musical cue
static func _stage_sting(player: Player) -> void:
	# TODO: Implement music sting based on faction
	# For now, we don't have music system yet (would be Story 5.2 expansion or later)
	# Just log the intent

	var faction_sting = "sting_%s" % player.faction
	print("[AnimationOrchestrator] Music sting: %s (not implemented yet)" % faction_sting)

	# Future implementation:
	# match player.faction:
	#     "hunter":
	#         AudioManager.play_music_sting("sting_hunter")
	#     "shadow":
	#         AudioManager.play_music_sting("sting_shadow")
	#     "neutral":
	#         AudioManager.play_music_sting("sting_neutral")


## Stage 5: Pause - Hold to appreciate the reveal
static func _stage_pause(tree: SceneTree) -> void:
	var duration = PolishConfig.get_duration("reveal_pause_duration")

	# Just wait - allow particles to dissipate naturally
	# No active animations during pause

	await tree.create_timer(duration).timeout

	print("[AnimationOrchestrator] Pause stage complete (%.2fs)" % duration)


# =============================================================================
# UTILITY METHODS
# =============================================================================

## Get total reveal sequence duration
static func get_reveal_sequence_duration() -> float:
	var total = 0.0
	total += PolishConfig.get_duration("reveal_buildup_duration")
	total += PolishConfig.get_duration("card_flip_duration")
	total += PolishConfig.get_duration("reveal_explosion_duration")
	total += PolishConfig.get_duration("reveal_pause_duration")
	return total


## Check if reduced motion mode is active
static func is_reduced_motion() -> bool:
	# Access UserSettings autoload
	# Note: This is a static method, so we can't use get_node directly
	# UserSettings is a global autoload, accessible directly by name
	if UserSettings:
		return UserSettings.reduced_motion_enabled
	return false


## Apply reduced motion adjustments to duration
static func get_adjusted_duration(duration_key: String) -> float:
	if is_reduced_motion():
		# Reduced motion mode: 70% faster (30% of original duration)
		var slowdown = PolishConfig.get_value("reduced_motion_tween_slowdown", 0.3)
		return PolishConfig.get_value(duration_key, 1.0) * slowdown
	else:
		return PolishConfig.get_duration(duration_key)


## Apply reduced motion adjustments to particle count
static func get_adjusted_particle_count(base_count: int) -> int:
	if is_reduced_motion():
		# Reduced motion mode: 70% fewer particles (30% of original)
		var reduction = PolishConfig.get_value("reduced_motion_particle_reduction", 0.7)
		return int(base_count * (1.0 - reduction))
	else:
		return base_count


## Apply reduced motion adjustments to shake intensity
static func get_adjusted_shake_intensity(intensity_key: String) -> float:
	if is_reduced_motion():
		# Reduced motion mode: 50% less shake
		return PolishConfig.get_shake_intensity(intensity_key) * 0.5
	else:
		return PolishConfig.get_shake_intensity(intensity_key)
