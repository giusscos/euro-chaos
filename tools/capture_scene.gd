extends SceneTree
## Opens a scene in a real window, waits, saves a screenshot, quits with
## exit code 1 if any engine/script/shader error was logged.
## Needs a GPU (no --headless). Usage:
##   $GODOT --path . --script res://tools/capture_scene.gd -- <scene.tscn> <out.png> [frames]

const DEFAULT_FRAMES: int = 90

var _counter := ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_counter)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <scene.tscn> <out.png> [frames]")
		quit(2)
		return
	var frames: int = int(args[2]) if args.size() > 2 else DEFAULT_FRAMES
	_capture.call_deferred(args[0], args[1], frames)


func _capture(scene_path: String, out_path: String, frames: int) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		quit(1)
		return
	change_scene_to_packed(packed)
	for i: int in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(out_path)
	var errors: PackedStringArray = _counter.take_errors()
	for e: String in errors:
		print("ERROR ", e)
	print("Saved %s (%s), %d errors" % [out_path, error_string(err), errors.size()])
	OS.remove_logger(_counter)
	quit(1 if err != OK or not errors.is_empty() else 0)
