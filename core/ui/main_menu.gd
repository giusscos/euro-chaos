extends Control
## Dev main menu: one button per mini-game (found via info.tres files),
## plus the shared vehicle test level.

@export_dir var minigames_dir: String = "res://minigames"
@export_file("*.tscn") var test_level_scene: String = "res://core/levels/vehicle_playground.tscn"
@export var test_level_label: String = "Vehicle Test Level"

@onready var _list: VBoxContainer = %MiniGameList
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	for info: MiniGameInfo in find_minigames():
		_add_scene_button(info.title, info.description, info.main_scene)
	_add_scene_button(test_level_label, "Bare level for tuning vehicles and camera.", test_level_scene)

	_quit_button.pressed.connect(get_tree().quit)
	# Focus the first button so keyboard and gamepad work right away.
	if _list.get_child_count() > 0:
		(_list.get_child(0) as Button).grab_focus()


func find_minigames() -> Array[MiniGameInfo]:
	var result: Array[MiniGameInfo] = []
	for dir_name: String in DirAccess.get_directories_at(minigames_dir):
		var path: String = minigames_dir.path_join(dir_name).path_join("info.tres")
		if not ResourceLoader.exists(path):
			continue
		var info := load(path) as MiniGameInfo
		if info != null and info.main_scene != "":
			result.append(info)
	return result


func _add_scene_button(label: String, tooltip: String, scene_path: String) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.pressed.connect(SceneLoader.change_scene.bind(scene_path))
	_list.add_child(button)
