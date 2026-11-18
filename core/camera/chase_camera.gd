class_name ChaseCamera
extends Node3D
## Third-person chase camera. Follows any Node3D target (vehicle now,
## on-foot character later). Not parented to the target: it reads the
## target's interpolated transform every rendered frame, so it stays smooth
## at any refresh rate with physics interpolation on.
##
## Features: yaw lag, speed-based distance/height/FOV, look-ahead,
## mouse/right-stick orbit with auto-recenter, sphere-cast collision so it
## never ends up inside a wall.

const KMH_PER_MS: float = 3.6
const MIN_LOOK_DISTANCE: float = 0.01

@export var target: Node3D:
	set(value):
		_disconnect_target()
		target = value
		_connect_target()
		_resolve_profile()
		if is_inside_tree():
			snap()

## Used when the target has no `camera_profile` of its own.
@export var default_profile: ChaseCameraProfile

@export_group("Smoothing")
## Higher = camera swings behind the target faster (1/s).
@export_range(0.1, 50.0, 0.1) var yaw_sharpness: float = 5.0
## Higher = follows bumps and jumps more tightly (1/s).
@export_range(0.1, 50.0, 0.1) var vertical_sharpness: float = 6.0
## How quickly speed-based framing reacts (1/s).
@export_range(0.1, 50.0, 0.1) var speed_sharpness: float = 3.0

@export_group("Orbit")
@export var orbit_enabled: bool = true
## Capture the mouse when the scene starts and on click.
@export var capture_mouse: bool = true
@export_range(0.0001, 0.05, 0.0001, "suffix:rad/px") var mouse_sensitivity: float = 0.0025
@export_range(1.0, 720.0, 1.0, "suffix:°/s") var stick_speed: float = 160.0
@export var invert_y: bool = false
@export_range(0.0, 89.0, 1.0, "suffix:°") var max_look_up: float = 20.0
@export_range(0.0, 89.0, 1.0, "suffix:°") var max_look_down: float = 50.0
## Seconds without orbit input before the camera swings back behind.
@export_range(0.0, 10.0, 0.1, "suffix:s") var recenter_delay: float = 1.5
@export_range(0.1, 20.0, 0.1) var recenter_sharpness: float = 2.5

@export_group("Collision")
@export_range(0.0, 1.0, 0.01, "suffix:m") var collision_radius: float = 0.25
@export_flags_3d_physics var collision_mask: int = 1
## How fast the camera moves back out after an obstruction is gone (1/s).
@export_range(0.1, 50.0, 0.1) var collision_recover_sharpness: float = 4.0

@onready var camera: Camera3D = $Camera3D

## The profile in use (target's own, else default_profile).
var profile: ChaseCameraProfile

var _yaw: float = 0.0
var _pivot_height: float = 0.0
var _speed: float = 0.0
var _orbit_yaw: float = 0.0
var _orbit_pitch: float = 0.0
var _orbit_idle_time: float = 0.0
var _current_distance: float = 0.0
var _query := PhysicsShapeQueryParameters3D.new()
var _sphere := SphereShape3D.new()


func _ready() -> void:
	top_level = true
	# Moved in _process, so it must not be physics-interpolated itself.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_sphere.radius = collision_radius
	_query.shape = _sphere
	_query.collision_mask = collision_mask
	_resolve_profile()
	camera.make_current()
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	snap()


## Jumps straight to the resting position behind the target.
func snap() -> void:
	if target == null:
		return
	var xform: Transform3D = target.get_global_transform_interpolated()
	_yaw = _heading_yaw(xform, _yaw)
	_pivot_height = xform.origin.y
	_orbit_yaw = 0.0
	_orbit_pitch = 0.0
	_current_distance = profile.distance
	_speed = 0.0
	if camera != null:
		_update_camera(0.0, true)


func _process(delta: float) -> void:
	if target == null:
		return
	_update_orbit_from_stick(delta)
	_update_camera(delta, false)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and orbit_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var vertical: float = motion.relative.y if invert_y else -motion.relative.y
		_add_orbit(-motion.relative.x * mouse_sensitivity, vertical * mouse_sensitivity)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and capture_mouse \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_camera(delta: float, instant: bool) -> void:
	var xform: Transform3D = target.get_global_transform_interpolated()
	var speed_ratio: float = _update_speed_ratio(delta, instant)

	_yaw = lerp_angle(_yaw, _heading_yaw(xform, _yaw), 1.0 if instant else _blend(yaw_sharpness, delta))
	_pivot_height = lerpf(_pivot_height, xform.origin.y, 1.0 if instant else _blend(vertical_sharpness, delta))
	var pivot := Vector3(xform.origin.x, _pivot_height + profile.look_height, xform.origin.z)

	var arm_length: float = lerpf(profile.distance, profile.distance_at_speed, speed_ratio)
	var arm_height: float = lerpf(profile.height, profile.height_at_speed, speed_ratio)
	var offset := Vector3(0.0, arm_height - profile.look_height, arm_length)
	offset = offset.rotated(Vector3.RIGHT, _orbit_pitch).rotated(Vector3.UP, _yaw + _orbit_yaw)

	var allowed: float = _collision_free_length(pivot, offset)
	if instant or allowed < _current_distance:
		_current_distance = allowed
	else:
		_current_distance = lerpf(_current_distance, allowed, _blend(collision_recover_sharpness, delta))
	var camera_position: Vector3 = pivot + offset.normalized() * _current_distance

	var look_direction := Vector3.FORWARD.rotated(Vector3.UP, _yaw)
	var look_point: Vector3 = pivot + look_direction * profile.look_ahead_at_speed * speed_ratio
	if camera_position.distance_to(look_point) > MIN_LOOK_DISTANCE:
		look_at_from_position(camera_position, look_point, Vector3.UP)
	camera.fov = lerpf(profile.fov, profile.fov_at_speed, speed_ratio)


func _update_speed_ratio(delta: float, instant: bool) -> float:
	var speed: float = 0.0
	var body := target as RigidBody3D
	if body != null:
		speed = body.linear_velocity.length()
	var character := target as CharacterBody3D
	if character != null:
		speed = character.velocity.length()
	_speed = speed if instant else lerpf(_speed, speed, _blend(speed_sharpness, delta))
	return clampf(_speed / (profile.reference_speed_kmh / KMH_PER_MS), 0.0, 1.0)


func _update_orbit_from_stick(delta: float) -> void:
	if not orbit_enabled:
		return
	var stick: Vector2 = Input.get_vector(InputActions.CAMERA_LEFT, InputActions.CAMERA_RIGHT,
		InputActions.CAMERA_DOWN, InputActions.CAMERA_UP)
	if stick != Vector2.ZERO:
		var rate: float = deg_to_rad(stick_speed) * delta
		_add_orbit(-stick.x * rate, (-stick.y if invert_y else stick.y) * rate)
		return
	_orbit_idle_time += delta
	if _orbit_idle_time >= recenter_delay:
		var blend: float = _blend(recenter_sharpness, delta)
		_orbit_yaw = lerp_angle(_orbit_yaw, 0.0, blend)
		_orbit_pitch = lerpf(_orbit_pitch, 0.0, blend)


## yaw: positive turns the view left. pitch: positive looks up.
func _add_orbit(yaw: float, pitch: float) -> void:
	_orbit_yaw = wrapf(_orbit_yaw + yaw, -PI, PI)
	_orbit_pitch = clampf(_orbit_pitch + pitch, -deg_to_rad(max_look_down), deg_to_rad(max_look_up))
	_orbit_idle_time = 0.0


func _collision_free_length(from: Vector3, offset: Vector3) -> float:
	var length: float = offset.length()
	if length <= 0.0 or not is_inside_tree():
		return length
	_query.transform = Transform3D(Basis.IDENTITY, from)
	_query.motion = offset
	var body := target as CollisionObject3D
	_query.exclude = [body.get_rid()] if body != null else []
	var fractions: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(_query)
	var safe: float = fractions[0] if not fractions.is_empty() else 1.0
	return length * safe


func _resolve_profile() -> void:
	var own: ChaseCameraProfile = null
	if target != null:
		own = target.get(&"camera_profile") as ChaseCameraProfile
	if own != null:
		profile = own
	elif default_profile != null:
		profile = default_profile
	elif profile == null:
		profile = ChaseCameraProfile.new()


func _heading_yaw(xform: Transform3D, fallback: float) -> float:
	var forward: Vector3 = -xform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return fallback
	return atan2(-forward.x, -forward.z)


func _blend(sharpness: float, delta: float) -> float:
	return 1.0 - exp(-sharpness * delta)


func _connect_target() -> void:
	if target != null and target.has_signal(&"teleported"):
		target.connect(&"teleported", snap)


func _disconnect_target() -> void:
	if target != null and target.has_signal(&"teleported") and target.is_connected(&"teleported", snap):
		target.disconnect(&"teleported", snap)
