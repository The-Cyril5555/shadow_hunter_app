## ParticlePool - Object pooling system for CPUParticles2D
##
## Manages a pool of reusable particle effects for performance optimization.
## Avoids expensive instantiate/free operations by reusing particles.
##
## Features:
## - Initial pool of 20 particles, grows to max 50
## - 5 preset effects: hit_impact, heal_sparkle, explosion_burst, card_draw_trail, ability_glow
## - PolishConfig integration for particle count
## - Reduced motion support (70% particle reduction)
## - Auto-return to pool when particles finish
##
## Pattern: Object pool singleton (autoload)
## Usage: ParticlePool.spawn_particles("hit_impact", global_position)
class_name ParticlePoolClass
extends Node


# =============================================================================
# CONSTANTS
# =============================================================================

const INITIAL_POOL_SIZE: int = 20
const MAX_POOL_SIZE: int = 50


# =============================================================================
# PROPERTIES
# =============================================================================

## Pool of available (inactive) particles
var _particle_pool: Array[CPUParticles2D] = []

## Currently active particles
var _active_particles: Array[CPUParticles2D] = []

## Effect preset configurations
var _effect_presets: Dictionary = {}


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("[ParticlePool] Headless mode — skipping particle pool initialization")
		return
	_initialize_presets()
	_create_initial_pool()
	print("[ParticlePool] Initialized with %d particles" % INITIAL_POOL_SIZE)


## Create initial pool of particles
func _create_initial_pool() -> void:
	for i in range(INITIAL_POOL_SIZE):
		var particle = _create_particle_node()
		_particle_pool.append(particle)


## Create a new CPUParticles2D node
func _create_particle_node() -> CPUParticles2D:
	var particles = CPUParticles2D.new()
	particles.name = "PooledParticle_%d" % (_particle_pool.size() + _active_particles.size())
	particles.one_shot = true
	particles.emitting = false
	particles.finished.connect(_on_particle_finished.bind(particles))
	add_child(particles)
	return particles


# =============================================================================
# PUBLIC METHODS - Particle Spawning
# =============================================================================

## Spawn particle effect at position
## @param effect_name: Name of preset effect (e.g., "hit_impact")
## @param world_position: Global position to spawn particles
## @returns: CPUParticles2D instance (or null if pool exhausted)
func spawn_particles(effect_name: String, world_position: Vector2) -> CPUParticles2D:
	# Get available particle from pool
	var particle = _get_available_particle()
	if not particle:
		push_warning("[ParticlePool] Pool exhausted, cannot spawn %s" % effect_name)
		return null

	# Apply preset configuration
	if not _apply_preset(particle, effect_name):
		# Invalid preset, return to pool
		_return_to_pool(particle)
		return null

	# Position and emit
	particle.global_position = world_position
	particle.emitting = true
	particle.visible = true

	# Track as active
	_active_particles.append(particle)

	print("[ParticlePool] Spawned %s at %s (active: %d/%d)" % [
		effect_name,
		world_position,
		_active_particles.size(),
		_particle_pool.size() + _active_particles.size()
	])

	return particle


## Stop all active particles immediately
func stop_all() -> void:
	for particle in _active_particles:
		if is_instance_valid(particle):
			particle.emitting = false
			_return_to_pool(particle)
	_active_particles.clear()


# =============================================================================
# PRIVATE METHODS - Pool Management
# =============================================================================

## Get an available particle from pool (or create new one if needed)
func _get_available_particle() -> CPUParticles2D:
	# Try to get from pool
	if _particle_pool.size() > 0:
		return _particle_pool.pop_back()

	# Pool exhausted, try to grow if under max
	var total_particles = _particle_pool.size() + _active_particles.size()
	if total_particles < MAX_POOL_SIZE:
		print("[ParticlePool] Growing pool (%d -> %d)" % [total_particles, total_particles + 1])
		return _create_particle_node()

	# Pool at max capacity
	return null


## Return particle to pool
func _return_to_pool(particle: CPUParticles2D) -> void:
	if not is_instance_valid(particle):
		return

	# Remove from active list
	var index = _active_particles.find(particle)
	if index >= 0:
		_active_particles.remove_at(index)

	# Reset particle state
	particle.emitting = false
	particle.visible = false
	particle.amount = 0

	# Return to pool
	_particle_pool.append(particle)


## Called when particle effect finishes
func _on_particle_finished(particle: CPUParticles2D) -> void:
	_return_to_pool(particle)


# =============================================================================
# PRIVATE METHODS - Effect Presets
# =============================================================================

## Initialize effect preset configurations
func _initialize_presets() -> void:
	# Preset 1: Hit Impact - Orange/red burst
	_effect_presets["hit_impact"] = {
		"amount": 15,
		"lifetime": 0.4,
		"lifetime_randomness": 0.3,
		"explosiveness": 0.9,
		"direction": Vector2(0, -1),
		"spread": 180.0,
		"gravity": Vector2(0, 200),
		"initial_velocity_min": 50.0,
		"initial_velocity_max": 150.0,
		"scale_amount_min": 4.0,
		"scale_amount_max": 8.0,
		"color": Color(1.0, 0.5, 0.0),  # Orange
		"color_ramp": [Color(1.0, 0.5, 0.0), Color(1.0, 0.0, 0.0), Color(0.5, 0.0, 0.0, 0.0)]
	}

	# Preset 2: Heal Sparkle - Green/white upward float
	_effect_presets["heal_sparkle"] = {
		"amount": 12,
		"lifetime": 1.0,
		"lifetime_randomness": 0.4,
		"explosiveness": 0.5,
		"direction": Vector2(0, -1),
		"spread": 30.0,
		"gravity": Vector2(0, -100),
		"initial_velocity_min": 20.0,
		"initial_velocity_max": 50.0,
		"scale_amount_min": 2.0,
		"scale_amount_max": 4.0,
		"color": Color(0.0, 1.0, 0.3),  # Green
		"color_ramp": [Color(0.0, 1.0, 0.3), Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)]
	}

	# Preset 3: Explosion Burst - Yellow/orange/red radial
	_effect_presets["explosion_burst"] = {
		"amount": 40,
		"lifetime": 0.9,
		"lifetime_randomness": 0.2,
		"explosiveness": 0.95,
		"direction": Vector2(1, 0),
		"spread": 180.0,
		"gravity": Vector2(0, 100),
		"initial_velocity_min": 100.0,
		"initial_velocity_max": 250.0,
		"scale_amount_min": 6.0,
		"scale_amount_max": 10.0,
		"color": Color(1.0, 1.0, 0.0),  # Yellow
		"color_ramp": [Color(1.0, 1.0, 0.0), Color(1.0, 0.5, 0.0), Color(1.0, 0.0, 0.0, 0.0)]
	}

	# Preset 4: Card Draw Trail - Blue/white motion trail
	_effect_presets["card_draw_trail"] = {
		"amount": 8,
		"lifetime": 0.3,
		"lifetime_randomness": 0.2,
		"explosiveness": 0.3,
		"direction": Vector2(0, -1),
		"spread": 20.0,
		"gravity": Vector2(0, 0),
		"initial_velocity_min": 10.0,
		"initial_velocity_max": 30.0,
		"scale_amount_min": 3.0,
		"scale_amount_max": 5.0,
		"color": Color(0.3, 0.7, 1.0),  # Light blue
		"color_ramp": [Color(0.3, 0.7, 1.0), Color(1.0, 1.0, 1.0, 0.5), Color(1.0, 1.0, 1.0, 0.0)]
	}

	# Preset 5: Ability Glow - Faction-colored aura (default neutral yellow)
	_effect_presets["ability_glow"] = {
		"amount": 20,
		"lifetime": 0.8,
		"lifetime_randomness": 0.3,
		"explosiveness": 0.7,
		"direction": Vector2(0, -1),
		"spread": 180.0,
		"gravity": Vector2(0, -50),
		"initial_velocity_min": 30.0,
		"initial_velocity_max": 80.0,
		"scale_amount_min": 4.0,
		"scale_amount_max": 8.0,
		"color": Color(1.0, 1.0, 0.5),  # Yellow (neutral)
		"color_ramp": [Color(1.0, 1.0, 0.5, 0.8), Color(1.0, 1.0, 0.7, 0.4), Color(1.0, 1.0, 0.9, 0.0)]
	}


## Apply preset configuration to particle
func _apply_preset(particle: CPUParticles2D, effect_name: String) -> bool:
	if not _effect_presets.has(effect_name):
		push_error("[ParticlePool] Unknown effect preset: %s" % effect_name)
		return false

	var preset = _effect_presets[effect_name]

	# Apply base amount with PolishConfig multiplier and reduced motion
	var base_amount = preset.get("amount", 10)
	particle.amount = _get_adjusted_particle_count(base_amount)

	# Apply lifetime
	particle.lifetime = preset.get("lifetime", 1.0)
	particle.lifetime_randomness = preset.get("lifetime_randomness", 0.0)

	# Apply emission
	particle.explosiveness = preset.get("explosiveness", 0.0)
	particle.direction = preset.get("direction", Vector2(0, -1))
	particle.spread = preset.get("spread", 45.0)

	# Apply physics
	particle.gravity = preset.get("gravity", Vector2(0, 98))
	particle.initial_velocity_min = preset.get("initial_velocity_min", 0.0)
	particle.initial_velocity_max = preset.get("initial_velocity_max", 0.0)

	# Apply scale
	particle.scale_amount_min = preset.get("scale_amount_min", 1.0)
	particle.scale_amount_max = preset.get("scale_amount_max", 1.0)

	# Apply color (base color)
	particle.color = preset.get("color", Color.WHITE)

	# Note: CPUParticles2D doesn't support color_ramp directly
	# We'd need Gradient for that, which is more complex
	# For MVP, single color is sufficient

	return true


## Get adjusted particle count based on PolishConfig and reduced motion
func _get_adjusted_particle_count(base_count: int) -> int:
	# Apply multiplier from PolishConfig
	var multiplier = PolishConfig.get_value("particle_count_multiplier", 1.0)
	var adjusted = int(base_count * multiplier)

	# Apply reduced motion reduction if enabled
	if AnimationOrchestrator.is_reduced_motion():
		adjusted = AnimationOrchestrator.get_adjusted_particle_count(adjusted)

	return max(1, adjusted)  # At least 1 particle


# =============================================================================
# PUBLIC METHODS - Pool Status
# =============================================================================

## Get current pool statistics
func get_pool_stats() -> Dictionary:
	return {
		"available": _particle_pool.size(),
		"active": _active_particles.size(),
		"total": _particle_pool.size() + _active_particles.size(),
		"max": MAX_POOL_SIZE
	}


## Get list of available effect presets
func get_available_effects() -> Array:
	return _effect_presets.keys()
