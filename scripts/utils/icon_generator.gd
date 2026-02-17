## IconGenerator - Procedural pixel art icon generator
## Generates 16x16 pixel art icons for UI buttons
@tool
extends Node


# =============================================================================
# ICON GENERATORS
# =============================================================================

## Generate "reveal" icon (eye)
static func create_reveal_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var black = Color.BLACK
	var white = Color.WHITE
	var blue = Color(0.3, 0.6, 1.0)

	# Eye outline
	var eye_pixels = [
		[6, [5, 6, 7, 8, 9, 10]],
		[7, [4, 5, 6, 7, 8, 9, 10, 11]],
		[8, [4, 5, 6, 7, 8, 9, 10, 11]],
		[9, [5, 6, 7, 8, 9, 10]],
	]
	for row in eye_pixels:
		for x in row[1]:
			img.set_pixel(x, row[0], black)

	# Iris (blue)
	img.set_pixel(7, 7, blue)
	img.set_pixel(8, 7, blue)
	img.set_pixel(7, 8, blue)
	img.set_pixel(8, 8, blue)

	# Pupil (black)
	img.set_pixel(8, 7, black)

	# Highlight
	img.set_pixel(7, 7, white)

	return img


## Generate "ability" icon (star/spark)
static func create_ability_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var yellow = Color(1.0, 0.9, 0.2)
	var orange = Color(1.0, 0.6, 0.0)

	# Star center
	img.set_pixel(8, 8, yellow)

	# Cross rays
	for i in range(3, 13):
		if i != 8:
			img.set_pixel(8, i, orange if i % 2 == 0 else yellow)
			img.set_pixel(i, 8, orange if i % 2 == 0 else yellow)

	# Diagonal rays (shorter)
	for offset in [[-1,-1], [1,-1], [-1,1], [1,1]]:
		img.set_pixel(8 + offset[0], 8 + offset[1], orange)
		img.set_pixel(8 + offset[0]*2, 8 + offset[1]*2, yellow)

	return img


## Generate "attack" icon (sword)
static func create_attack_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var blade = Color(0.8, 0.8, 0.9)
	var handle = Color(0.6, 0.3, 0.1)
	var guard = Color(0.7, 0.6, 0.3)

	# Blade (diagonal)
	for i in range(7):
		img.set_pixel(4 + i, 3 + i, blade)
		img.set_pixel(5 + i, 3 + i, blade)

	# Guard
	for x in range(9, 13):
		img.set_pixel(x, 9, guard)

	# Handle
	for i in range(4):
		img.set_pixel(11 + i, 10 + i, handle)

	return img


## Generate "end_turn" icon (circular arrow)
static func create_end_turn_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var green = Color(0.3, 0.9, 0.3)

	# Circle arc (top and right)
	var arc = [
		[5, 7], [6, 6], [7, 5], [8, 5], [9, 5],
		[10, 6], [11, 7], [11, 8], [11, 9],
		[10, 10], [9, 11]
	]
	for p in arc:
		img.set_pixel(p[0], p[1], green)

	# Arrow head
	img.set_pixel(8, 11, green)
	img.set_pixel(8, 12, green)
	img.set_pixel(9, 12, green)

	return img


## Generate "resume" icon (play triangle)
static func create_resume_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var green = Color(0.3, 1.0, 0.3)

	# Triangle (pointing right)
	for y in range(5, 12):
		var x_start = 6
		var width = abs(8 - y) + 1
		for x in range(x_start, x_start + (8 - width)):
			img.set_pixel(x, y, green)

	return img


## Generate "save" icon (floppy disk)
static func create_save_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var disk_body = Color(0.3, 0.3, 0.8)
	var metal = Color(0.6, 0.6, 0.7)
	var label = Color.WHITE

	# Disk body
	for y in range(4, 13):
		for x in range(4, 12):
			img.set_pixel(x, y, disk_body)

	# Metal shutter
	for y in range(4, 7):
		for x in range(5, 11):
			img.set_pixel(x, y, metal)

	# Label area
	for y in range(8, 11):
		for x in range(5, 11):
			img.set_pixel(x, y, label)

	return img


## Generate "load" icon (folder)
static func create_load_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var folder = Color(0.9, 0.7, 0.2)
	var dark = Color(0.7, 0.5, 0.1)

	# Folder tab
	for y in range(4, 6):
		for x in range(4, 8):
			img.set_pixel(x, y, dark)

	# Folder body
	for y in range(6, 12):
		for x in range(3, 13):
			img.set_pixel(x, y, folder)

	# Shading
	for x in range(3, 13):
		img.set_pixel(x, 11, dark)

	return img


## Generate "quit" icon (door with arrow)
static func create_quit_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var door = Color(0.6, 0.3, 0.1)
	var red = Color(1.0, 0.3, 0.3)

	# Door frame
	for y in range(3, 13):
		img.set_pixel(10, y, door)
		img.set_pixel(11, y, door)

	# Exit arrow
	for x in range(4, 9):
		img.set_pixel(x, 7, red)
		img.set_pixel(x, 8, red)

	# Arrow head
	img.set_pixel(4, 6, red)
	img.set_pixel(4, 9, red)
	img.set_pixel(3, 7, red)
	img.set_pixel(3, 8, red)

	return img


## Generate "roll_dice" icon (die showing 6)
static func create_roll_dice_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var dice = Color.WHITE
	var dot = Color.BLACK

	# Die body
	for y in range(4, 12):
		for x in range(4, 12):
			img.set_pixel(x, y, dice)

	# Six dots (3x2 pattern)
	var dot_positions = [
		[5, 5], [5, 8], [5, 10],
		[10, 5], [10, 8], [10, 10]
	]
	for pos in dot_positions:
		img.set_pixel(pos[0], pos[1], dot)

	return img


## Generate "heal" icon (heart)
static func create_heal_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var red = Color(1.0, 0.2, 0.2)
	var pink = Color(1.0, 0.5, 0.5)

	# Heart shape
	var heart = [
		[5, [6, 7, 9, 10]],
		[6, [5, 6, 7, 8, 9, 10, 11]],
		[7, [5, 6, 7, 8, 9, 10, 11]],
		[8, [6, 7, 8, 9, 10]],
		[9, [7, 8, 9]],
		[10, [8]],
	]
	for row in heart:
		for x in row[1]:
			img.set_pixel(x, row[0], red)

	# Highlight
	img.set_pixel(6, 6, pink)
	img.set_pixel(10, 6, pink)

	return img


## Generate "steal" icon (hand grabbing)
static func create_steal_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var skin = Color(0.9, 0.7, 0.5)
	var gold = Color(1.0, 0.85, 0.2)

	# Hand/arm
	for y in range(7, 12):
		for x in range(4, 8):
			img.set_pixel(x, y, skin)

	# Fingers grasping
	img.set_pixel(8, 6, skin)
	img.set_pixel(8, 7, skin)
	img.set_pixel(9, 8, skin)
	img.set_pixel(9, 9, skin)

	# Coin being grabbed
	for y in range(5, 8):
		for x in range(9, 12):
			img.set_pixel(x, y, gold)

	return img


## Generate "cancel" icon (X)
static func create_cancel_icon() -> Image:
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var red = Color(1.0, 0.3, 0.3)

	# X shape (diagonal lines)
	for i in range(8):
		# Top-left to bottom-right
		img.set_pixel(5 + i, 5 + i, red)
		img.set_pixel(6 + i, 5 + i, red)
		# Top-right to bottom-left
		img.set_pixel(11 - i, 5 + i, red)
		img.set_pixel(10 - i, 5 + i, red)

	return img


# =============================================================================
# UTILITY
# =============================================================================

## Generate all icons and save them to assets/sprites/icons/
static func generate_all_icons() -> void:
	var icons = {
		"reveal": create_reveal_icon(),
		"ability": create_ability_icon(),
		"attack": create_attack_icon(),
		"end_turn": create_end_turn_icon(),
		"resume": create_resume_icon(),
		"save": create_save_icon(),
		"load": create_load_icon(),
		"quit": create_quit_icon(),
		"roll_dice": create_roll_dice_icon(),
		"heal": create_heal_icon(),
		"steal": create_steal_icon(),
		"cancel": create_cancel_icon(),
	}

	var base_path = "res://assets/sprites/icons/"
	for icon_name in icons.keys():
		var img: Image = icons[icon_name]
		var path = base_path + icon_name + ".png"
		img.save_png(path.replace("res://", ""))
		print("[IconGenerator] Saved: %s" % path)
