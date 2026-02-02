## ParticleDemo - Interactive particle effects demonstration
## Tests all 5 particle presets with pool statistics
class_name ParticleDemo
extends Control


# -----------------------------------------------------------------------------
# References @onready
# -----------------------------------------------------------------------------
@onready var spawn_center: Vector2 = Vector2(960, 400)

@onready var pool_stats_label: Label = $VBoxContainer/PoolStats
@onready var particle_multiplier_slider: HSlider = $VBoxContainer/MultiplierControl/Slider
@onready var multiplier_label: Label = $VBoxContainer/MultiplierControl/ValueLabel
@onready var reduced_motion_toggle: CheckButton = $VBoxContainer/ReducedMotionToggle


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	# Connect effect buttons
	$VBoxContainer/EffectButtons/HitImpactButton.pressed.connect(func(): _spawn_effect("hit_impact"))
	$VBoxContainer/EffectButtons/HealSparkleButton.pressed.connect(func(): _spawn_effect("heal_sparkle"))
	$VBoxContainer/EffectButtons/ExplosionBurstButton.pressed.connect(func(): _spawn_effect("explosion_burst"))
	$VBoxContainer/EffectButtons/CardDrawTrailButton.pressed.connect(func(): _spawn_effect("card_draw_trail"))
	$VBoxContainer/EffectButtons/AbilityGlowButton.pressed.connect(func(): _spawn_effect("ability_glow"))

	# Connect control buttons
	$VBoxContainer/ControlButtons/StopAllButton.pressed.connect(_on_stop_all_pressed)
	$VBoxContainer/ControlButtons/SpawnMultipleButton.pressed.connect(_on_spawn_multiple_pressed)
	$VBoxContainer/ControlButtons/BackButton.pressed.connect(_on_back_pressed)

	# Connect settings
	particle_multiplier_slider.value_changed.connect(_on_multiplier_changed)
	reduced_motion_toggle.toggled.connect(_on_reduced_motion_toggled)

	# Initialize UI
	_update_pool_stats()
	multiplier_label.text = "%.1fx" % particle_multiplier_slider.value

	print("[ParticleDemo] Demo ready")


func _process(_delta: float) -> void:
	# Update pool stats every frame
	_update_pool_stats()


# -----------------------------------------------------------------------------
# Particle Spawning
# -----------------------------------------------------------------------------
func _spawn_effect(effect_name: String) -> void:
	# Add random offset for visual variety
	var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	var spawn_pos = spawn_center + offset

	var particle = ParticlePool.spawn_particles(effect_name, spawn_pos)
	if particle:
		print("[ParticleDemo] Spawned %s at %s" % [effect_name, spawn_pos])
	else:
		print("[ParticleDemo] Failed to spawn %s (pool exhausted?)" % effect_name)


func _on_spawn_multiple_pressed() -> void:
	# Spawn 10 random effects to test pool growth
	for i in range(10):
		var effects = ["hit_impact", "heal_sparkle", "explosion_burst", "card_draw_trail", "ability_glow"]
		var effect = effects[randi() % effects.size()]
		_spawn_effect(effect)
		await get_tree().create_timer(0.1).timeout


func _on_stop_all_pressed() -> void:
	ParticlePool.stop_all()
	print("[ParticleDemo] Stopped all particles")


# -----------------------------------------------------------------------------
# Settings
# -----------------------------------------------------------------------------
func _on_multiplier_changed(value: float) -> void:
	PolishConfig.config_data["particle_count_multiplier"] = value
	multiplier_label.text = "%.1fx" % value
	print("[ParticleDemo] Particle multiplier: %.1fx" % value)


func _on_reduced_motion_toggled(enabled: bool) -> void:
	UserSettings.set_reduced_motion(enabled)
	print("[ParticleDemo] Reduced motion: %s" % ("ON" if enabled else "OFF"))


# -----------------------------------------------------------------------------
# UI Updates
# -----------------------------------------------------------------------------
func _update_pool_stats() -> void:
	var stats = ParticlePool.get_pool_stats()
	pool_stats_label.text = "Pool: %d available | %d active | %d total (max %d)" % [
		stats.available,
		stats.active,
		stats.total,
		stats.max
	]


# -----------------------------------------------------------------------------
# Navigation
# -----------------------------------------------------------------------------
func _on_back_pressed() -> void:
	GameModeStateMachine.transition_to(GameModeStateMachine.GameMode.MAIN_MENU)
