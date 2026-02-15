## Dice3DBuilder - Builds 3D dice meshes and face textures at runtime
class_name Dice3DBuilder
extends RefCounted


# Face texture size
const TEX_SIZE: int = 64


# =============================================================================
# D6 Mesh & Materials
# =============================================================================

## Build a BoxMesh with 6 face materials (classic white dice with black dots)
static func build_d6() -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()

	# Create ArrayMesh with 6 surfaces (one per face)
	var arr_mesh = ArrayMesh.new()
	var half := 0.5

	# Face definitions: [normal_axis, sign, vertices CCW when viewed from outside]
	var faces = [
		# Face 1 (front, +Z)
		{"verts": [Vector3(-half, -half, half), Vector3(half, -half, half), Vector3(half, half, half), Vector3(-half, half, half)], "normal": Vector3.FORWARD},
		# Face 6 (back, -Z)
		{"verts": [Vector3(half, -half, -half), Vector3(-half, -half, -half), Vector3(-half, half, -half), Vector3(half, half, -half)], "normal": Vector3.BACK},
		# Face 2 (right, +X)
		{"verts": [Vector3(half, -half, half), Vector3(half, -half, -half), Vector3(half, half, -half), Vector3(half, half, half)], "normal": Vector3.RIGHT},
		# Face 5 (left, -X)
		{"verts": [Vector3(-half, -half, -half), Vector3(-half, -half, half), Vector3(-half, half, half), Vector3(-half, half, -half)], "normal": Vector3.LEFT},
		# Face 3 (top, +Y)
		{"verts": [Vector3(-half, half, half), Vector3(half, half, half), Vector3(half, half, -half), Vector3(-half, half, -half)], "normal": Vector3.UP},
		# Face 4 (bottom, -Y)
		{"verts": [Vector3(-half, -half, -half), Vector3(half, -half, -half), Vector3(half, -half, half), Vector3(-half, -half, half)], "normal": Vector3.DOWN},
	]

	var face_numbers = [1, 6, 2, 5, 3, 4]
	var uvs_quad = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])

	for i in range(6):
		var face = faces[i]
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)

		var verts = PackedVector3Array(face.verts)
		var normals = PackedVector3Array([face.normal, face.normal, face.normal, face.normal])
		var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])

		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs_quad
		arrays[Mesh.ARRAY_INDEX] = indices

		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		# Create material with face texture
		var mat = StandardMaterial3D.new()
		mat.albedo_texture = _create_d6_face_texture(face_numbers[i])
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		arr_mesh.surface_set_material(i, mat)

	mesh_instance.mesh = arr_mesh
	return mesh_instance


# =============================================================================
# D4 Mesh & Materials
# =============================================================================

## Build a tetrahedron mesh with 4 face materials
static func build_d4() -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var arr_mesh = ArrayMesh.new()

	# Regular tetrahedron vertices (inscribed in unit sphere)
	var s := 0.6
	var v0 = Vector3(0, s, 0)
	var v1 = Vector3(0, -s * 0.333, s * 0.943)
	var v2 = Vector3(s * 0.816, -s * 0.333, -s * 0.471)
	var v3 = Vector3(-s * 0.816, -s * 0.333, -s * 0.471)

	# 4 triangular faces with the number visible when that face is "up" (facing camera)
	var face_data = [
		{"verts": [v0, v1, v2], "number": 1},  # Front face
		{"verts": [v0, v3, v1], "number": 2},  # Left face
		{"verts": [v0, v2, v3], "number": 3},  # Back face
		{"verts": [v1, v3, v2], "number": 4},  # Bottom face
	]

	var uvs_tri = PackedVector2Array([Vector2(0.5, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])

	for i in range(4):
		var fd = face_data[i]
		var verts = PackedVector3Array(fd.verts)

		# Calculate face normal
		var edge1 = fd.verts[1] - fd.verts[0]
		var edge2 = fd.verts[2] - fd.verts[0]
		var normal = edge1.cross(edge2).normalized()
		var normals = PackedVector3Array([normal, normal, normal])

		var indices = PackedInt32Array([0, 1, 2])

		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs_tri
		arrays[Mesh.ARRAY_INDEX] = indices

		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var mat = StandardMaterial3D.new()
		mat.albedo_texture = _create_d4_face_texture(fd.number)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		arr_mesh.surface_set_material(i, mat)

	mesh_instance.mesh = arr_mesh
	return mesh_instance


# =============================================================================
# Landing Rotations
# =============================================================================

## Get the rotation (euler angles) so that face `number` is on top for d6
static func get_d6_landing_basis(face: int) -> Vector3:
	match face:
		1: return Vector3(0, 0, 0)               # Front face up → tilt X -90
		2: return Vector3(0, 0, deg_to_rad(-90))  # Right face up → tilt Z -90
		3: return Vector3(deg_to_rad(-90), 0, 0)  # Top face already up
		4: return Vector3(deg_to_rad(90), 0, 0)   # Bottom face → flip X +90
		5: return Vector3(0, 0, deg_to_rad(90))   # Left face up → tilt Z +90
		6: return Vector3(deg_to_rad(180), 0, 0)  # Back face → flip X 180
		_: return Vector3.ZERO


## Get the rotation so that face `number` faces the camera for d4
static func get_d4_landing_basis(face: int) -> Vector3:
	match face:
		1: return Vector3(0, 0, 0)                                  # Front face
		2: return Vector3(0, deg_to_rad(120), 0)                    # Left face
		3: return Vector3(0, deg_to_rad(-120), 0)                   # Right face
		4: return Vector3(deg_to_rad(180), 0, deg_to_rad(180))      # Bottom face
		_: return Vector3.ZERO


# =============================================================================
# Procedural Textures
# =============================================================================

## Create a d6 face texture with dot pattern
static func _create_d6_face_texture(number: int) -> ImageTexture:
	var img = Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var bg = Color(0.95, 0.92, 0.85)  # Ivory white
	var dot_color = Color(0.1, 0.1, 0.1)  # Dark gray/black

	# Fill background
	img.fill(bg)

	# Draw rounded border
	_draw_rect_border(img, dot_color.lerp(bg, 0.5))

	# Dot positions for each face (normalized 0-1, mapped to TEX_SIZE)
	var dot_positions = _get_dot_positions(number)
	var dot_radius := TEX_SIZE / 8

	for pos in dot_positions:
		_draw_circle(img, Vector2(pos.x * TEX_SIZE, pos.y * TEX_SIZE), dot_radius, dot_color)

	return ImageTexture.create_from_image(img)


## Create a d4 face texture with number
static func _create_d4_face_texture(number: int) -> ImageTexture:
	var img = Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var bg = Color(0.75, 0.15, 0.15)  # Deep red
	img.fill(bg)

	# Draw the number as a simple pixel pattern in the center
	var num_color = Color(1.0, 0.95, 0.8)  # Light gold
	_draw_number(img, number, num_color)

	return ImageTexture.create_from_image(img)


## Get dot positions for a d6 face (classic layout)
static func _get_dot_positions(number: int) -> Array[Vector2]:
	var c := 0.5   # center
	var t := 0.25  # top/left offset
	var b := 0.75  # bottom/right offset

	match number:
		1: return [Vector2(c, c)]
		2: return [Vector2(t, b), Vector2(b, t)]
		3: return [Vector2(t, b), Vector2(c, c), Vector2(b, t)]
		4: return [Vector2(t, t), Vector2(t, b), Vector2(b, t), Vector2(b, b)]
		5: return [Vector2(t, t), Vector2(t, b), Vector2(c, c), Vector2(b, t), Vector2(b, b)]
		6: return [Vector2(t, t), Vector2(t, c), Vector2(t, b), Vector2(b, t), Vector2(b, c), Vector2(b, b)]
		_: return []


## Draw a filled circle on an image
static func _draw_circle(img: Image, center: Vector2, radius: int, color: Color) -> void:
	var cx = int(center.x)
	var cy = int(center.y)
	for y in range(maxi(0, cy - radius), mini(img.get_height(), cy + radius + 1)):
		for x in range(maxi(0, cx - radius), mini(img.get_width(), cx + radius + 1)):
			if Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, color)


## Draw a simple border on the image
static func _draw_rect_border(img: Image, color: Color) -> void:
	var w = img.get_width()
	var h = img.get_height()
	for i in range(w):
		img.set_pixel(i, 0, color)
		img.set_pixel(i, 1, color)
		img.set_pixel(i, h - 1, color)
		img.set_pixel(i, h - 2, color)
	for i in range(h):
		img.set_pixel(0, i, color)
		img.set_pixel(1, i, color)
		img.set_pixel(w - 1, i, color)
		img.set_pixel(w - 2, i, color)


## Draw a number (1-4) as simple pixel art
static func _draw_number(img: Image, number: int, color: Color) -> void:
	var cx = TEX_SIZE / 2
	var cy = TEX_SIZE / 2
	var s := 3  # pixel scale

	# Simple 3x5 pixel font for digits 1-4
	var patterns = {
		1: [
			[0,1,0],
			[1,1,0],
			[0,1,0],
			[0,1,0],
			[1,1,1],
		],
		2: [
			[1,1,1],
			[0,0,1],
			[1,1,1],
			[1,0,0],
			[1,1,1],
		],
		3: [
			[1,1,1],
			[0,0,1],
			[1,1,1],
			[0,0,1],
			[1,1,1],
		],
		4: [
			[1,0,1],
			[1,0,1],
			[1,1,1],
			[0,0,1],
			[0,0,1],
		],
	}

	if not patterns.has(number):
		return

	var pattern = patterns[number]
	var pw = 3
	var ph = 5
	var ox = cx - (pw * s) / 2
	var oy = cy - (ph * s) / 2

	for py in range(ph):
		for px in range(pw):
			if pattern[py][px] == 1:
				for sy in range(s):
					for sx in range(s):
						var ix = ox + px * s + sx
						var iy = oy + py * s + sy
						if ix >= 0 and ix < TEX_SIZE and iy >= 0 and iy < TEX_SIZE:
							img.set_pixel(ix, iy, color)
