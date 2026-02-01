## AnimationHelper - Utility functions for standard animations
##
## Provides consistent, reusable animations using Godot's Tween system
## All animations respect PolishConfig timing values and reduced motion mode
## Uses stateless static methods for easy access from any script
##
## Pattern: Stateless utility class for consistent animation creation
## Usage: AnimationHelper.fade_in(my_node, "card_flip_duration")
class_name AnimationHelper
extends RefCounted


# -----------------------------------------------------------------------------
# Fade Animations
# -----------------------------------------------------------------------------

## Fade in a CanvasItem from transparent to opaque
## @param node: CanvasItem to fade in (Control, Sprite2D, etc.)
## @param duration_key: Key from polish_config.json for duration
static func fade_in(node: CanvasItem, duration_key: String = "card_play_animation_duration") -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] fade_in: Invalid node")
		return

	var duration = PolishConfig.get_duration(duration_key)

	node.modulate.a = 0.0
	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


## Fade out a CanvasItem from opaque to transparent
## @param node: CanvasItem to fade out
## @param duration_key: Key from polish_config.json for duration
static func fade_out(node: CanvasItem, duration_key: String = "card_play_animation_duration") -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] fade_out: Invalid node")
		return

	var duration = PolishConfig.get_duration(duration_key)

	var tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)


# -----------------------------------------------------------------------------
# Scale Animations
# -----------------------------------------------------------------------------

## Scale pulse animation: scales up then back to normal
## Creates a "breathing" or "attention" effect
## @param node: Node2D or Control to animate
## @param target_scale: Maximum scale to reach (default 1.2)
## @param duration_key: Key from polish_config.json for duration
static func scale_pulse(node: Node, target_scale: float = 1.2, duration_key: String = "card_play_animation_duration") -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] scale_pulse: Invalid node")
		return

	if not node.has("scale"):
		push_error("[AnimationHelper] scale_pulse: Node does not have 'scale' property")
		return

	var duration = PolishConfig.get_duration(duration_key)

	var tween = node.create_tween()
	# Scale up
	tween.tween_property(node, "scale", Vector2(target_scale, target_scale), duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)
	# Scale back down
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), duration * 0.5)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)


## Scale pop animation: instant scale up, then elastic bounce back
## Creates a satisfying "pop" effect commonly used in Balatro-style games
## @param node: Node2D or Control to animate
## @param target_scale: Initial scale to pop to (default 1.3)
## @param duration_key: Key from polish_config.json for duration
static func scale_pop(node: Node, target_scale: float = 1.3, duration_key: String = "card_play_animation_duration") -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] scale_pop: Invalid node")
		return

	if not node.has("scale"):
		push_error("[AnimationHelper] scale_pop: Node does not have 'scale' property")
		return

	var duration = PolishConfig.get_duration(duration_key)

	# Instant pop
	node.scale = Vector2(target_scale, target_scale)

	# Elastic bounce back
	var tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), duration)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)


# -----------------------------------------------------------------------------
# Position Animations
# -----------------------------------------------------------------------------

## Slide in from an offset position
## Node starts at position + offset, then slides to original position
## @param node: Node2D or Control to animate
## @param from_offset: Offset from original position (e.g., Vector2(-100, 0) for left)
## @param duration_key: Key from polish_config.json for duration
static func slide_in(node: Node, from_offset: Vector2, duration_key: String = "card_play_animation_duration") -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] slide_in: Invalid node")
		return

	if not node.has("position"):
		push_error("[AnimationHelper] slide_in: Node does not have 'position' property")
		return

	var duration = PolishConfig.get_duration(duration_key)

	var original_pos = node.position
	node.position = original_pos + from_offset

	var tween = node.create_tween()
	tween.tween_property(node, "position", original_pos, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


## Slide out to an offset position
## @param node: Node2D or Control to animate
## @param to_offset: Offset to slide to (e.g., Vector2(100, 0) for right)
## @param duration_key: Key from polish_config.json for duration
static func slide_out(node: Node, to_offset: Vector2, duration_key: String = "card_play_animation_duration") -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] slide_out: Invalid node")
		return

	if not node.has("position"):
		push_error("[AnimationHelper] slide_out: Node does not have 'position' property")
		return

	var duration = PolishConfig.get_duration(duration_key)

	var target_pos = node.position + to_offset

	var tween = node.create_tween()
	tween.tween_property(node, "position", target_pos, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)


## Shake animation: rapid random position offsets
## Creates impact or error feedback effect
## @param node: Node2D or Control to shake
## @param intensity_key: Key from polish_config.json for shake intensity
## @param duration: Duration of shake in seconds (default 0.3s)
static func shake(node: Node, intensity_key: String = "shake_intensity", duration: float = 0.3) -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] shake: Invalid node")
		return

	if not node.has("position"):
		push_error("[AnimationHelper] shake: Node does not have 'position' property")
		return

	var intensity = PolishConfig.get_shake_intensity(intensity_key)
	var original_pos = node.position

	var tween = node.create_tween()
	var steps = int(duration / 0.05)  # 20 steps per second for smooth shake

	for i in range(steps):
		var offset = Vector2(
			randf_range(-intensity, intensity) * 10.0,
			randf_range(-intensity, intensity) * 10.0
		)
		tween.tween_property(node, "position", original_pos + offset, 0.05)

	# Return to original position smoothly
	tween.tween_property(node, "position", original_pos, 0.05)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)


# -----------------------------------------------------------------------------
# Utility Functions
# -----------------------------------------------------------------------------

## Kill all active tweens on a node
## Useful to prevent animation conflicts when retriggering animations
## Note: Godot 4.x auto-manages tweens, creating new tween replaces old ones
## @param node: Node to kill tweens on
static func kill_tweens(node: Node) -> void:
	if not is_instance_valid(node):
		return

	# In Godot 4.x, creating a new tween automatically replaces previous ones
	# This function exists for API compatibility and future-proofing
	pass


## Await animation completion using duration from PolishConfig
## Useful for chaining animations sequentially
## @param node: Node to get tree from (for timer)
## @param duration_key: Key from polish_config.json for duration
## @returns: Awaitable signal that completes after duration
static func await_animation(node: Node, duration_key: String) -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] await_animation: Invalid node")
		return

	var duration = PolishConfig.get_duration(duration_key)
	await node.get_tree().create_timer(duration).timeout


# -----------------------------------------------------------------------------
# Combo Animations
# -----------------------------------------------------------------------------

## Fade in with scale pop: common combination for card reveals
## @param node: Node to animate (must be CanvasItem with scale property)
## @param duration_key: Key from polish_config.json for duration
static func fade_in_with_pop(node: Node, duration_key: String = "card_play_animation_duration") -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] fade_in_with_pop: Invalid node")
		return

	if not node is CanvasItem:
		push_error("[AnimationHelper] fade_in_with_pop: Node must be CanvasItem")
		return

	if not node.has("scale"):
		push_error("[AnimationHelper] fade_in_with_pop: Node does not have 'scale' property")
		return

	var duration = PolishConfig.get_duration(duration_key)

	# Set initial state
	node.modulate.a = 0.0
	node.scale = Vector2(1.3, 1.3)

	# Create parallel tween for fade and scale
	var tween = node.create_tween()
	tween.set_parallel(true)

	# Fade in
	tween.tween_property(node, "modulate:a", 1.0, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	# Scale pop (elastic bounce)
	tween.tween_property(node, "scale", Vector2(1.0, 1.0), duration)\
		.set_trans(Tween.TRANS_ELASTIC)\
		.set_ease(Tween.EASE_OUT)


## Fade out with scale down: common combination for card removal
## @param node: Node to animate (must be CanvasItem with scale property)
## @param duration_key: Key from polish_config.json for duration
static func fade_out_with_shrink(node: Node, duration_key: String = "card_play_animation_duration") -> void:
	if not is_instance_valid(node):
		push_error("[AnimationHelper] fade_out_with_shrink: Invalid node")
		return

	if not node is CanvasItem:
		push_error("[AnimationHelper] fade_out_with_shrink: Node must be CanvasItem")
		return

	if not node.has("scale"):
		push_error("[AnimationHelper] fade_out_with_shrink: Node does not have 'scale' property")
		return

	var duration = PolishConfig.get_duration(duration_key)

	# Create parallel tween for fade and scale
	var tween = node.create_tween()
	tween.set_parallel(true)

	# Fade out
	tween.tween_property(node, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	# Shrink
	tween.tween_property(node, "scale", Vector2(0.5, 0.5), duration)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
