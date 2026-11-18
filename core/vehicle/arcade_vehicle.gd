class_name ArcadeVehicle
extends RigidBody3D
## Arcade raycast vehicle shared by every wheeled thing in the game
## (scooters, cars, vans, police, traffic).
##
## Setup: VehicleWheel children (direct children), a VehicleStats resource,
## and an optional `visual` node holding all meshes. Something writes
## `intent` every physics tick (PlayerVehicleController, AI, tests).
## Lean and pitch are applied to `visual` only, so physics stays stable.

signal teleported

const GRAVITY_FALLBACK: float = 9.8

@export var stats: VehicleStats
## Parent of all meshes. Must sit at the vehicle origin with no rotation.
@export var visual: Node3D
## How a ChaseCamera frames this vehicle (bigger vehicles need more distance).
@export var camera_profile: ChaseCameraProfile
@export_flags_3d_physics var wheel_collision_mask: int = 0b111

var intent := VehicleIntent.new()
var wheels: Array[VehicleWheel] = []
var grounded_wheel_count: int = 0
## Radians, positive = right.
var steer_angle: float = 0.0
## Forward speed in m/s (negative when reversing).
var forward_speed: float = 0.0
## Increments on every teleport, in the same physics tick. Lets observers
## (e.g. CargoMonitor) ignore the instant velocity reset.
var teleport_serial: int = 0

var _driven_count: int = 0
var _rear_count: int = 0
var _pending_teleport: bool = false
var _teleport_target := Transform3D.IDENTITY
var _visual_lean: float = 0.0
var _visual_pitch: float = 0.0
var _last_forward_speed: float = 0.0
var _longitudinal_accel: float = 0.0
var _gravity: float = GRAVITY_FALLBACK


func _ready() -> void:
	assert(stats != null, "%s needs a VehicleStats resource" % name)
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", GRAVITY_FALLBACK)
	mass = stats.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = stats.center_of_mass
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = stats.linear_damp
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = stats.angular_damp
	can_sleep = false
	continuous_cd = true

	for child: Node in get_children():
		var wheel := child as VehicleWheel
		if wheel == null:
			continue
		wheel.setup(self, stats)
		wheels.append(wheel)
		if wheel.driven:
			_driven_count += 1
		if wheel.axle == VehicleWheel.Axle.REAR:
			_rear_count += 1
	if wheels.is_empty():
		push_warning("%s has no VehicleWheel children" % name)


## Speed along the vehicle's forward axis in km/h (negative when reversing).
func get_speed_kmh() -> float:
	return forward_speed * VehicleStats.KMH_PER_MS


func is_grounded() -> bool:
	return grounded_wheel_count > 0


## Moves the vehicle and stops it. Safe to call any time; applied on the
## next physics tick.
func teleport(target: Transform3D) -> void:
	_teleport_target = target
	_pending_teleport = true


## Puts the vehicle back on its wheels where it is, keeping its heading.
func reset_upright(lift: float = 1.0) -> void:
	var heading: Vector3 = -global_basis.z
	heading.y = 0.0
	if heading.length_squared() < 0.0001:
		heading = Vector3.FORWARD
	var target := Transform3D(Basis.looking_at(heading.normalized(), Vector3.UP), global_position + Vector3.UP * lift)
	teleport(target)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_teleport:
		_apply_teleport(state)
		return

	var step: float = state.step
	var body_basis: Basis = state.transform.basis
	var forward: Vector3 = -body_basis.z
	forward_speed = state.linear_velocity.dot(forward)

	_update_steering(step)

	# Engine, reverse and brakes.
	var throttle: float = clampf(intent.throttle, 0.0, 1.0)
	var brake_input: float = clampf(intent.brake, 0.0, 1.0)
	var drive_total: float = 0.0
	var brake_total: float = 0.0
	if throttle > 0.0:
		drive_total += throttle * stats.engine_force * stats.torque_at(forward_speed)
	if brake_input > 0.0:
		if forward_speed > stats.reverse_switch_speed:
			brake_total += brake_input * stats.brake_force
		else:
			var reverse_ratio: float = clampf(-forward_speed / stats.reverse_top_speed(), 0.0, 1.0)
			drive_total -= brake_input * stats.reverse_force * (1.0 - reverse_ratio)
	if throttle == 0.0 and brake_input == 0.0:
		brake_total += stats.coast_brake_force

	var brake_per_wheel: float = brake_total / maxf(wheels.size(), 1)
	var handbrake_per_wheel: float = stats.handbrake_force / maxf(_rear_count, 1)

	grounded_wheel_count = 0
	var ground_normal := Vector3.ZERO
	for wheel: VehicleWheel in wheels:
		wheel.steer_angle = steer_angle if wheel.steers else 0.0
		var is_rear: bool = wheel.axle == VehicleWheel.Axle.REAR
		var drive: float = drive_total / _driven_count if wheel.driven and _driven_count > 0 else 0.0
		var brake: float = brake_per_wheel
		var grip: float = stats.rear_grip if is_rear else stats.front_grip
		if intent.handbrake and is_rear:
			# The handbrake locks the rear wheels, and a locked wheel can't be
			# driven: no engine force reaches it, whatever the throttle says.
			drive = 0.0
			brake = maxf(brake, handbrake_per_wheel)
			grip *= stats.handbrake_rear_grip
		wheel.simulate(state, stats, drive, brake, grip)
		if wheel.is_grounded:
			grounded_wheel_count += 1
			ground_normal += wheel.contact_normal

	# Air drag.
	var velocity: Vector3 = state.linear_velocity
	state.apply_central_force(-velocity * velocity.length() * stats.air_drag)

	# Stability and air control (applied as angular acceleration, so tuning
	# doesn't depend on mass or shape).
	var target_up: Vector3 = ground_normal.normalized() if grounded_wheel_count > 0 else Vector3.UP
	_apply_level_assist(state, forward, target_up,
		stats.roll_assist_frequency, stats.roll_assist_damping_ratio)
	if grounded_wheel_count == 0:
		_apply_level_assist(state, body_basis.x, Vector3.UP,
			stats.air_pitch_level_frequency, stats.air_pitch_level_damping_ratio)
		var pitch_input: float = brake_input - throttle
		var yaw_input: float = -clampf(intent.steer, -1.0, 1.0)
		state.angular_velocity += (body_basis.x * pitch_input * stats.air_control_pitch
			+ body_basis.y * yaw_input * stats.air_control_yaw) * step

	_longitudinal_accel = (forward_speed - _last_forward_speed) / step
	_last_forward_speed = forward_speed


func _process(delta: float) -> void:
	for wheel: VehicleWheel in wheels:
		wheel.update_visual(delta)
	_update_visual_body(delta)


func _update_steering(step: float) -> void:
	var speed_ratio: float = clampf(absf(forward_speed) / stats.top_speed(), 0.0, 1.0)
	var max_angle: float = deg_to_rad(lerpf(stats.max_steer_angle, stats.steer_angle_at_top_speed, speed_ratio))
	var target: float = clampf(intent.steer, -1.0, 1.0) * max_angle
	steer_angle = move_toward(steer_angle, target, deg_to_rad(stats.steer_speed) * step)


## Rotates the body around `axis` so its up vector moves toward `target_up`,
## like a damped spring with the given frequency.
func _apply_level_assist(state: PhysicsDirectBodyState3D, axis: Vector3, target_up: Vector3,
		frequency: float, damping_ratio: float) -> void:
	if frequency <= 0.0:
		return
	var projected: Vector3 = target_up - axis * target_up.dot(axis)
	if projected.length_squared() < 0.0001:
		return
	var up: Vector3 = state.transform.basis.y
	var error: float = up.signed_angle_to(projected.normalized(), axis)
	var rate: float = state.angular_velocity.dot(axis)
	var omega: float = TAU * frequency
	var accel: float = omega * omega * error - 2.0 * damping_ratio * omega * rate
	state.angular_velocity += axis * accel * state.step


func _apply_teleport(state: PhysicsDirectBodyState3D) -> void:
	_pending_teleport = false
	teleport_serial += 1
	state.transform = _teleport_target
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	steer_angle = 0.0
	forward_speed = 0.0
	_last_forward_speed = 0.0
	_finish_teleport.call_deferred()


func _finish_teleport() -> void:
	reset_physics_interpolation()
	teleported.emit()
	Events.vehicle_teleported.emit(self)


func _update_visual_body(delta: float) -> void:
	if visual == null:
		return
	var yaw_rate: float = angular_velocity.dot(global_basis.y)
	var lean_target: float = 0.0
	var pitch_target: float = 0.0
	if is_grounded():
		var max_lean: float = deg_to_rad(stats.max_visual_lean)
		lean_target = clampf(atan(forward_speed * yaw_rate / _gravity) * stats.visual_lean_factor,
			-max_lean, max_lean)
		var max_pitch: float = deg_to_rad(stats.max_visual_pitch)
		pitch_target = clampf(_longitudinal_accel * stats.visual_pitch_factor, -max_pitch, max_pitch)
	var blend: float = 1.0 - exp(-stats.visual_response * delta)
	_visual_lean = lerpf(_visual_lean, lean_target, blend)
	_visual_pitch = lerpf(_visual_pitch, pitch_target, blend)
	visual.rotation = Vector3(_visual_pitch, 0.0, _visual_lean)
