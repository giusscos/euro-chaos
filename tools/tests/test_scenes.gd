extends TestCase
## Smoke test: every scene in the project loads, enters the tree and runs a
## few frames without logging an error. Also checks the mini-game contract.

const SKIP_DIRS: PackedStringArray = [".godot", ".git", "build"]
const FRAMES_PER_SCENE: int = 30
const MAIN_MENU_SCRIPT: String = "res://core/ui/main_menu.gd"


func test_every_scene_runs() -> void:
	var scenes: PackedStringArray = []
	_collect_scenes("res://", scenes)
	expect(not scenes.is_empty(), "no scenes found")
	for path: String in scenes:
		var packed := load(path) as PackedScene
		if packed == null:
			expect(false, "%s does not load" % path)
			continue
		var instance: Node = packed.instantiate()
		expect(instance != null, "%s does not instantiate" % path)
		if instance == null:
			continue
		add_node(instance)
		await wait_physics_frames(FRAMES_PER_SCENE)
		note("%s ok" % path)
		await cleanup()
		tree.paused = false


func test_minigames_follow_contract() -> void:
	var menu_script := load(MAIN_MENU_SCRIPT) as GDScript
	var menu := menu_script.new() as Control
	var infos: Array[MiniGameInfo] = menu.call(&"find_minigames")
	menu.free()
	expect(not infos.is_empty(), "main menu finds no mini-games")
	for info: MiniGameInfo in infos:
		expect(info.id != &"", "%s has no id" % info.resource_path)
		expect(info.title != "", "%s has no title" % info.resource_path)
		var packed := load(info.main_scene) as PackedScene
		expect(packed != null, "%s: main scene %s does not load" % [info.id, info.main_scene])
		if packed == null:
			continue
		var root: Node = packed.instantiate()
		expect(root is MiniGame, "%s: main scene root is not a MiniGame" % info.id)
		if root is MiniGame:
			expect((root as MiniGame).info == info, "%s: main scene points at a different info" % info.id)
		root.free()
		note("%s -> %s" % [info.id, info.main_scene])


func _collect_scenes(dir_path: String, out: PackedStringArray) -> void:
	for dir_name: String in DirAccess.get_directories_at(dir_path):
		if dir_name in SKIP_DIRS:
			continue
		_collect_scenes(dir_path.path_join(dir_name), out)
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() == "tscn":
			out.append(dir_path.path_join(file_name))
