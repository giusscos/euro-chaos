extends SceneTree
## Compiles every .gd script in the project with autoloads
## available (unlike --check-only) and exits 1 if any fails.
## Typed-GDScript warnings set to Error in project settings fail here too.
##
##   $GODOT --headless --path . --script res://tools/check_scripts.gd

const SKIP_DIRS: PackedStringArray = [".godot", ".git", "build"]

var _counter := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_counter)
	var scripts: PackedStringArray = []
	_collect("res://", scripts)
	var failed: int = 0
	var self_path: String = (get_script() as Script).resource_path
	for path: String in scripts:
		if path == self_path:
			continue
		var script := ResourceLoader.load(path) as Script
		var errors: PackedStringArray = _counter.take_errors()
		if script == null or not errors.is_empty():
			failed += 1
			print("FAIL ", path)
			for e: String in errors:
				print("    ", e)
	print("Checked %d scripts, %d failed" % [scripts.size(), failed])
	OS.remove_logger(_counter)
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	for dir_name: String in DirAccess.get_directories_at(dir_path):
		if dir_name in SKIP_DIRS:
			continue
		_collect(dir_path.path_join(dir_name), out)
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == "gd":
			out.append(dir_path.path_join(file_name))
