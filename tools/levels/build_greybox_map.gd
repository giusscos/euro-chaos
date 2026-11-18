extends SceneTree
## Builds a greybox level scene from an ASCII map (see GreyboxMapBuilder).
##   $GODOT --headless --path . --script res://tools/levels/build_greybox_map.gd -- <map.txt> <out.tscn>
## The output is generated: change the map and rebuild instead of editing it.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("usage: -- <map.txt> <out.tscn>")
		quit(2)
		return
	var map_path: String = args[0]
	var out_path: String = args[1]
	if not FileAccess.file_exists(map_path):
		printerr("map not found: %s" % map_path)
		quit(2)
		return
	# Loaded at runtime: the builder's classes use autoloads, which a --script
	# entry script can't reference at compile time.
	var builder: RefCounted = (load("res://core/levels/greybox_map/greybox_map_builder.gd") as GDScript).new()
	var root := builder.call(&"build", FileAccess.get_file_as_string(map_path), map_path) as Node3D
	var errors: PackedStringArray = builder.get(&"errors")
	if root == null or not errors.is_empty():
		for error: String in errors:
			printerr("  ", error)
		printerr("Build failed: %d problem(s)" % errors.size())
		if root != null:
			root.free()
		quit(1)
		return
	root.name = out_path.get_file().get_basename().to_pascal_case()
	var packed := PackedScene.new()
	var err: Error = packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, out_path)
	root.free()
	if err != OK:
		printerr("Could not save %s: %s" % [out_path, error_string(err)])
		quit(1)
		return
	print("Built %s: %s" % [out_path, builder.get(&"stats")])
	quit(0)
