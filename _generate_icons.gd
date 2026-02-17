@tool
extends EditorScript


func _run() -> void:
	# Import the generator
	var IconGenerator = load("res://scripts/utils/icon_generator.gd")

	# Generate all icons
	print("[Generate Icons] Starting icon generation...")
	IconGenerator.generate_all_icons()
	print("[Generate Icons] Done! Icons saved to assets/sprites/icons/")
