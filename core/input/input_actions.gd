class_name InputActions
extends RefCounted
## Names of every input action, so code never uses raw strings.
## The bindings themselves live in project.godot and are written by
## res://tools/setup_input_map.gd.

# Driving
const ACCELERATE: StringName = &"accelerate"
const BRAKE_REVERSE: StringName = &"brake_reverse"
const STEER_LEFT: StringName = &"steer_left"
const STEER_RIGHT: StringName = &"steer_right"
const HANDBRAKE: StringName = &"handbrake"
const HORN: StringName = &"horn"
const RESET_VEHICLE: StringName = &"reset_vehicle"

# General
const INTERACT: StringName = &"interact"
const PAUSE: StringName = &"pause"

# Camera (gamepad right stick; mouse is read directly by the camera)
const CAMERA_LEFT: StringName = &"camera_left"
const CAMERA_RIGHT: StringName = &"camera_right"
const CAMERA_UP: StringName = &"camera_up"
const CAMERA_DOWN: StringName = &"camera_down"

# Debug helpers (test levels only)
const DEBUG_SWAP_VEHICLE: StringName = &"debug_swap_vehicle"
const DEBUG_RESPAWN: StringName = &"debug_respawn"
const DEBUG_TOGGLE_OVERLAY: StringName = &"debug_toggle_overlay"
