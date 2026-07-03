extends SceneTree

## Compile check: loads every script under res://scripts with autoloads active.
## Fails (exit 1) if any script has a parse or compile error.
## Usage: godot --headless --path . -s res://tests/e2e/compile_check.gd

func _process(_delta: float) -> bool:
	var failed: int = 0
	var checked: int = 0
	var stack: Array = ["res://scripts"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			var full := dir_path + "/" + entry
			if dir.current_is_dir():
				stack.append(full)
			elif entry.ends_with(".gd"):
				checked += 1
				var res = ResourceLoader.load(full, "", ResourceLoader.CACHE_MODE_IGNORE)
				if res == null:
					print("COMPILE_FAIL: %s" % full)
					failed += 1
			entry = dir.get_next()
	print("[CompileCheck] %d scripts checked, %d failed" % [checked, failed])
	quit(1 if failed > 0 else 0)
	return true
