extends SceneTree
## Writes the project's input map into project.godot.
## Keys use physical keycodes, so WASD stays in the same place on
## AZERTY / QWERTZ keyboards (important for European players).
##
## Run from the project folder:
##   $GODOT --headless --path . --script res://tools/setup_input_map.gd

const Actions := preload("res://core/input/input_actions.gd")

const STICK_DEADZONE: float = 0.2
const TRIGGER_DEADZONE: float = 0.1
const BUTTON_DEADZONE: float = 0.5


func _initialize() -> void:
	# Driving
	_set_action(Actions.ACCELERATE, TRIGGER_DEADZONE, [
		_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0),
	])
	_set_action(Actions.BRAKE_REVERSE, TRIGGER_DEADZONE, [
		_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0),
	])
	_set_action(Actions.STEER_LEFT, STICK_DEADZONE, [
		_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _button(JOY_BUTTON_DPAD_LEFT),
	])
	_set_action(Actions.STEER_RIGHT, STICK_DEADZONE, [
		_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _button(JOY_BUTTON_DPAD_RIGHT),
	])
	_set_action(Actions.HANDBRAKE, BUTTON_DEADZONE, [_key(KEY_SPACE), _button(JOY_BUTTON_A)])
	_set_action(Actions.HORN, BUTTON_DEADZONE, [_key(KEY_H), _button(JOY_BUTTON_Y)])
	_set_action(Actions.RESET_VEHICLE, BUTTON_DEADZONE, [_key(KEY_R), _button(JOY_BUTTON_BACK)])

	# General
	_set_action(Actions.INTERACT, BUTTON_DEADZONE, [_key(KEY_E), _button(JOY_BUTTON_X)])
	_set_action(Actions.PAUSE, BUTTON_DEADZONE, [_key(KEY_ESCAPE), _key(KEY_P), _button(JOY_BUTTON_START)])

	# Camera
	_set_action(Actions.CAMERA_LEFT, STICK_DEADZONE, [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_set_action(Actions.CAMERA_RIGHT, STICK_DEADZONE, [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_set_action(Actions.CAMERA_UP, STICK_DEADZONE, [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_set_action(Actions.CAMERA_DOWN, STICK_DEADZONE, [_axis(JOY_AXIS_RIGHT_Y, 1.0)])

	# Debug
	_set_action(Actions.DEBUG_SWAP_VEHICLE, BUTTON_DEADZONE, [_key(KEY_TAB), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_set_action(Actions.DEBUG_RESPAWN, BUTTON_DEADZONE, [_key(KEY_BACKSPACE), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_set_action(Actions.DEBUG_TOGGLE_OVERLAY, BUTTON_DEADZONE, [_key(KEY_O), _button(JOY_BUTTON_LEFT_STICK)])

	var err: Error = ProjectSettings.save()
	if err != OK:
		push_error("Could not save project.godot: %s" % error_string(err))
		quit(1)
		return
	print("Input map written to project.godot")
	quit(0)


func _set_action(action: StringName, deadzone: float, events: Array[InputEvent]) -> void:
	ProjectSettings.set_setting("input/" + String(action), {
		"deadzone": deadzone,
		"events": events,
	})


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.device = -1
	event.physical_keycode = code
	return event


func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	return event


func _axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = direction
	return event
