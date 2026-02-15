## Dice - 3D dice rolling component for Shadow Hunter
## Renders a D6 (cube) and D4 (tetrahedron) in SubViewports with pixel art filter
class_name Dice
extends Control


# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal dice_rolled(sum: int)


# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const D6_VIEWPORT_SIZE: int = 100
const D4_VIEWPORT_SIZE: int = 80
const CAMERA_DISTANCE: float = 2.0
const BG_COLOR: Color = Color(0.08, 0.08, 0.12, 0.0)


# -----------------------------------------------------------------------------
# Properties
# -----------------------------------------------------------------------------
var dice1_result: int = 0  # D6 result
var dice2_result: int = 0  # D4 result
var is_rolling: bool = false

var _d6_mesh: MeshInstance3D = null
var _d4_mesh: MeshInstance3D = null
var _d6_viewport: SubViewport = null
var _d4_viewport: SubViewport = null
var _result_label: Label = null
var _d6_label: Label = null
var _d4_label: Label = null


# -----------------------------------------------------------------------------
# Lifecycle
# -----------------------------------------------------------------------------
func _ready() -> void:
	_build_ui()
	reset()


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------

## Roll the dice with 3D animation
func roll() -> void:
	if is_rolling:
		return

	is_rolling = true
	AudioManager.play_sfx("dice_roll")

	# Generate results
	dice1_result = randi() % 6 + 1
	dice2_result = randi() % 4 + 1

	_result_label.text = "..."
	_d6_label.text = "D6"
	_d4_label.text = "D4"

	# Get roll duration
	var roll_duration = PolishConfig.get_duration("dice_roll_duration")
	var spin_duration = roll_duration * 0.75
	var land_duration = roll_duration * 0.25

	# Random spin target (multiple full rotations)
	var d6_spin = Vector3(
		randf_range(4.0, 6.0) * TAU,
		randf_range(3.0, 5.0) * TAU,
		randf_range(2.0, 4.0) * TAU
	)
	var d4_spin = Vector3(
		randf_range(3.0, 5.0) * TAU,
		randf_range(4.0, 6.0) * TAU,
		randf_range(2.0, 4.0) * TAU
	)

	# Landing rotations
	var d6_land = Dice3DBuilder.get_d6_landing_basis(dice1_result)
	var d4_land = Dice3DBuilder.get_d4_landing_basis(dice2_result)

	# Phase 1: Spin (fast rotation)
	var tween = create_tween()
	tween.set_parallel(true)

	# D6 spin
	tween.tween_method(_rotate_d6, Vector3.ZERO, d6_spin, spin_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# D4 spin
	tween.tween_method(_rotate_d4, Vector3.ZERO, d4_spin, spin_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await tween.finished

	# Phase 2: Land (snap to result face)
	var land_tween = create_tween()
	land_tween.set_parallel(true)

	land_tween.tween_method(_rotate_d6, _d6_mesh.rotation, d6_land, land_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	land_tween.tween_method(_rotate_d4, _d4_mesh.rotation, d4_land, land_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await land_tween.finished

	# Landing bounce
	AudioManager.play_sfx("dice_land")

	# Show results
	_d6_label.text = "D6: %d" % dice1_result
	_d4_label.text = "D4: %d" % dice2_result

	var sum = dice1_result + dice2_result
	_result_label.text = "Total: %d" % sum

	is_rolling = false
	dice_rolled.emit(sum)
	print("[Dice] Rolled D6=%d + D4=%d = %d" % [dice1_result, dice2_result, sum])


## Get current dice results
func get_results() -> Dictionary:
	return {
		"dice1": dice1_result,
		"dice2": dice2_result,
		"sum": dice1_result + dice2_result
	}


## Reset dice display
func reset() -> void:
	dice1_result = 0
	dice2_result = 0
	is_rolling = false
	if _d6_mesh:
		_d6_mesh.rotation = Vector3.ZERO
	if _d4_mesh:
		_d4_mesh.rotation = Vector3.ZERO
	if _result_label:
		_result_label.text = ""
	if _d6_label:
		_d6_label.text = "D6"
	if _d4_label:
		_d4_label.text = "D4"


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------

## Build the complete UI with 3D viewports
func _build_ui() -> void:
	# Ensure proper minimum size for parent layout
	custom_minimum_size = Vector2(D6_VIEWPORT_SIZE + D4_VIEWPORT_SIZE + 40, D6_VIEWPORT_SIZE + 50)

	# Load shader
	var pixel_shader = load("res://assets/shaders/pixel_art_3d.gdshader") as Shader

	# Main layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Dice row
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# D6 column
	var d6_col = VBoxContainer.new()
	d6_col.alignment = BoxContainer.ALIGNMENT_CENTER
	d6_col.add_theme_constant_override("separation", 4)
	hbox.add_child(d6_col)

	var d6_svc = _create_dice_viewport(true, pixel_shader)
	d6_col.add_child(d6_svc)

	_d6_label = Label.new()
	_d6_label.text = "D6"
	_d6_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d6_label.add_theme_font_size_override("font_size", 13)
	_d6_label.add_theme_color_override("font_color", Color(0.85, 0.68, 0.2))
	d6_col.add_child(_d6_label)

	# D4 column
	var d4_col = VBoxContainer.new()
	d4_col.alignment = BoxContainer.ALIGNMENT_CENTER
	d4_col.add_theme_constant_override("separation", 4)
	hbox.add_child(d4_col)

	var d4_svc = _create_dice_viewport(false, pixel_shader)
	d4_col.add_child(d4_svc)

	_d4_label = Label.new()
	_d4_label.text = "D4"
	_d4_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_d4_label.add_theme_font_size_override("font_size", 13)
	_d4_label.add_theme_color_override("font_color", Color(0.85, 0.68, 0.2))
	d4_col.add_child(_d4_label)

	# Result label
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 20)
	_result_label.add_theme_color_override("font_color", Color(0.85, 0.68, 0.2))
	vbox.add_child(_result_label)


## Create a SubViewportContainer with a 3D dice scene inside
func _create_dice_viewport(is_d6: bool, pixel_shader: Shader) -> SubViewportContainer:
	var vp_size = D6_VIEWPORT_SIZE if is_d6 else D4_VIEWPORT_SIZE

	var svc = SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(vp_size, vp_size)
	svc.stretch = true

	# Apply pixel art shader
	if pixel_shader:
		var mat = ShaderMaterial.new()
		mat.shader = pixel_shader
		mat.set_shader_parameter("pixel_size", 3.0 if is_d6 else 2.5)
		mat.set_shader_parameter("viewport_size", Vector2(vp_size, vp_size))
		mat.set_shader_parameter("edge_strength", 0.4)
		svc.material = mat

	# SubViewport — each needs its own World3D to isolate meshes
	var viewport = SubViewport.new()
	viewport.size = Vector2i(vp_size, vp_size)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = SubViewport.MSAA_DISABLED
	svc.add_child(viewport)

	# Camera
	var camera = Camera3D.new()
	camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 50
	viewport.add_child(camera)

	# Lighting
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	light.light_energy = 1.2
	light.shadow_enabled = false
	viewport.add_child(light)

	# Ambient fill light
	var fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, -60, 0)
	fill.light_energy = 0.4
	fill.shadow_enabled = false
	viewport.add_child(fill)

	# World environment for ambient light
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.ambient_light_energy = 0.5
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	# Dice mesh
	if is_d6:
		_d6_mesh = Dice3DBuilder.build_d6()
		viewport.add_child(_d6_mesh)
		_d6_viewport = viewport
	else:
		_d4_mesh = Dice3DBuilder.build_d4()
		viewport.add_child(_d4_mesh)
		_d4_viewport = viewport

	return svc


## Rotate D6 mesh (used by tween_method)
func _rotate_d6(rot: Vector3) -> void:
	if _d6_mesh:
		_d6_mesh.rotation = rot


## Rotate D4 mesh (used by tween_method)
func _rotate_d4(rot: Vector3) -> void:
	if _d4_mesh:
		_d4_mesh.rotation = rot
