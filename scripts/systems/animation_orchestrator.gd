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
	FLIP,         # Card scale:x flip with texture swap
	EXPLOSION,    # Dramatic particle burst and shake
	SETTLE,       # Hold to appreciate reveal
}


# =============================================================================
# PUBLIC METHODS - Reveal Sequence
# =============================================================================

## Play complete dramatic reveal sequence for a character
## @param player: Player instance being revealed
## @param card_node: Control/Node2D displaying the character card
## @param tree: SceneTree for awaiting (usually card_node.get_tree())
## @param texture_swap_callback: Callable to swap card textures at mid-flip
## @returns: void (async)
static func play_reveal_sequence(player: Player, card_node: Node, tree: SceneTree, texture_swap_callback: Callable = Callable()) -> void:
	if not is_instance_valid(player) or not is_instance_valid(card_node):
		push_error("[AnimationOrchestrator] Invalid player or card_node")
		return

	if not is_instance_valid(tree):
		push_error("[AnimationOrchestrator] Invalid tree reference")
		return

	print("[AnimationOrchestrator] Starting reveal sequence for %s (%s)" % [player.character_name, player.faction])

	# Stage 1: Buildup (0.5s)
	await _stage_buildup(card_node, tree)

	# Stage 2: Card Flip (0.8s) with texture swap at midpoint
	await _stage_flip(card_node, tree, texture_swap_callback)

	# Stage 3: Explosion (0.6s)
	await _stage_explosion(card_node, tree)

	# Stage 4: Settle (0.3s)
	await _stage_pause(tree)

	print("[AnimationOrchestrator] Reveal sequence completed for %s" % player.character_name)


# =============================================================================
# PRIVATE METHODS - Sequence Stages
# =============================================================================

## Stage 1: Buildup - Anticipation with particles and pulse
static func _stage_buildup(card_node: Node, tree: SceneTree) -> void:
	var duration = PolishConfig.get_duration("reveal_buildup_duration")

	# Scale pulse animation (1.0 → 1.05 → 1.0)
	if "scale" in card_node:
		AnimationHelper.scale_pulse(card_node, 1.05, "reveal_buildup_duration")

	# Spawn buildup particles (ability_glow effect)
	if "global_position" in card_node:
		ParticlePool.spawn_particles("ability_glow", card_node.global_position)

	# Play buildup sound
	AudioManager.play_sfx("reveal_dramatic", false)  # No pitch variation for dramatic sound

	# Wait for buildup duration
	await tree.create_timer(duration).timeout

	print("[AnimationOrchestrator] Buildup stage complete (%.2fs)" % duration)


## Stage 2: Card Flip - Scale X flip with texture swap at midpoint
static func _stage_flip(card_node: Node, tree: SceneTree, texture_swap_callback: Callable = Callable()) -> void:
	var duration = PolishConfig.get_duration("card_flip_duration")

	if not "scale" in card_node:
		push_warning("[AnimationOrchestrator] Card node doesn't have scale property")
		if texture_swap_callback.is_valid():
			texture_swap_callback.call()
		await tree.create_timer(duration).timeout
		return

	# Phase 1: scale:x 1.0 → 0.0 (card edge)
	var tween1 = card_node.create_tween()
	tween1.tween_property(card_node, "scale:x", 0.0, duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween1.finished

	# Swap textures at midpoint (card is invisible edge-on)
	if texture_swap_callback.is_valid():
		texture_swap_callback.call()

	# Phase 2: scale:x 0.0 → 1.0 (reveal face)
	var tween2 = card_node.create_tween()
	tween2.tween_property(card_node, "scale:x", 1.0, duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween2.finished

	print("[AnimationOrchestrator] Flip stage complete (%.2fs)" % duration)


## Stage 3: Explosion - Dramatic burst with particles and shake
static func _stage_explosion(card_node: Node, tree: SceneTree) -> void:
	var duration = PolishConfig.get_duration("reveal_explosion_duration")
	# Play explosion sound
	AudioManager.play_sfx("reveal_dramatic", true)

	# Spawn explosion particles (explosion_burst effect)
	if "global_position" in card_node:
		ParticlePool.spawn_particles("explosion_burst", card_node.global_position)

	# Screen shake effect
	if "position" in card_node:
		AnimationHelper.shake(card_node, "reveal_shake_intensity", duration * 0.3)

	# Scale pop animation (1.0 → 1.3 → 1.0)
	if "scale" in card_node:
		AnimationHelper.scale_pop(card_node, 1.3, "reveal_explosion_duration")

	# Wait for explosion duration
	await tree.create_timer(duration).timeout

	print("[AnimationOrchestrator] Explosion stage complete (%.2fs)" % duration)


## Stage 4: Settle - Hold to appreciate the reveal
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
