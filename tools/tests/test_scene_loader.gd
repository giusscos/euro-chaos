extends TestCase
## SceneLoader (autoload) loads a scene in the background and switches to it,
## which is how the main menu starts every mini-game.

const TARGET_SCENE: String = "res://core/levels/vehicle_playground.tscn"
const TIMEOUT_MSEC: int = 10000
## With --fixed-fps the main loop spins without pause and starves the loading
## thread; a short real-time yield per frame mimics a paced game loop.
const YIELD_MSEC: int = 1


func test_change_scene_loads_in_background() -> void:
	var loader: Node = tree.root.get_node(^"SceneLoader")
	expect(loader != null, "SceneLoader autoload missing")
	if loader == null:
		return
	var changed_to: Array[String] = []
	var on_changed := func(path: String) -> void: changed_to.append(path)
	loader.connect(&"scene_changed", on_changed)
	loader.call(&"change_scene", TARGET_SCENE)
	var started: int = Time.get_ticks_msec()
	var frames: int = 0
	while changed_to.is_empty() and Time.get_ticks_msec() - started < TIMEOUT_MSEC:
		OS.delay_msec(YIELD_MSEC)
		await tree.process_frame
		frames += 1
	await tree.process_frame
	loader.disconnect(&"scene_changed", on_changed)
	note("switched after %d frames, %d ms" % [frames, Time.get_ticks_msec() - started])
	expect(changed_to == [TARGET_SCENE], "scene_changed not emitted for %s" % TARGET_SCENE)
	expect(tree.current_scene != null and tree.current_scene.scene_file_path == TARGET_SCENE,
		"current scene is not %s" % TARGET_SCENE)
	expect(not loader.call(&"is_loading"), "SceneLoader still busy")
	tree.unload_current_scene()
	await tree.process_frame
