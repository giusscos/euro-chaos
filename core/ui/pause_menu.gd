class_name PauseMenu
extends CanvasLayer
## Minimal pause menu: Resume / Main Menu / Quit. Owns mouse capture while
## the game is paused. "Main Menu" goes to the project's main scene, so a
## single mini-game app returns to its own title screen.

signal pause_changed(paused: bool)

@onready var _root: Control = %Root
@onready var _resume_button: Button = %ResumeButton
@onready var _menu_button: Button = %MenuButton
@onready var _quit_button: Button = %QuitButton

var _mouse_mode_before_pause: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_resume_button.pressed.connect(set_paused.bind(false))
	_menu_button.pressed.connect(_go_to_main_menu)
	_quit_button.pressed.connect(get_tree().quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.PAUSE):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	if paused == get_tree().paused:
		return
	get_tree().paused = paused
	_root.visible = paused
	if paused:
		_mouse_mode_before_pause = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_resume_button.grab_focus()
	else:
		Input.mouse_mode = _mouse_mode_before_pause
	pause_changed.emit(paused)


func _go_to_main_menu() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	if main_scene == "":
		return
	SceneLoader.change_scene(main_scene)
