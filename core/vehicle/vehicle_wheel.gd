class_name VehicleWheel
extends Node3D
## One raycast wheel. Must be a direct child of an ArcadeVehicle, placed at
## the top of the suspension (the ray goes down from here). Suspension and
## tire numbers come from the vehicle's VehicleStats; this node only says
## where the wheel is and what it does.

enum Axle { FRONT, REAR }

@export var axle: Axle = Axle.FRONT
@export var steers: bool = false
@export var driven: bool = false
## Optional visual pivot: moved by the suspension, spun by speed, turned by
## steering. Its parent must share the vehicle's local space at rest (e.g. the
## vehicle's Visual node). Orient the mesh under it so the axle is local X.
@export var wheel_mesh: Node3D

# Read-only state, updated every physics tick.
var is_grounded: bool = false
var contact_point: Vector3 = Vector3.ZERO
var contact_normal: Vector3 = Vector3.UP
var suspension_length: float = 0.0
## Force pressing the tire on the ground (N).
var tire_load: float = 0.0
var forward_speed: float = 0.0
var lateral_speed: float = 0.0
## Radians, positive = right. Set by the vehicle.
var steer_angle: float = 0.0

var _query := PhysicsRayQueryParameters3D.new()
var _spin_angle: float = 0.0
var _radius: float = 0.0


func setup(vehicle: ArcadeVehicle, stats: VehicleStats) -> void:
	_query.exclude = [vehicle.get_rid()]
	_query.collision_mask = vehicle.wheel_collision_mask
	_query.hit_back_faces = false
	suspension_length = stats.suspension_rest_length
	_radius = stats.wheel_radius


## Runs inside the vehicle's _integrate_forces. Applies suspension and tire
## forces for this wheel. drive_force and brake_force are this wheel's share (N).
func simulate(state: PhysicsDirectBodyState3D, stats: VehicleStats,
		drive_force: float, brake_force: float, grip_multiplier: float) -> void:
	var body_xform: Transform3D = state.transform
	var up: Vector3 = body_xform.basis.y
	var mount: Vector3 = body_xform * position
	var ray_origin: Vector3 = mount + up * stats.ray_start_height

	_query.from = ray_origin
	_query.to = mount - up * (stats.suspension_rest_length + stats.wheel_radius)
	var hit: Dictionary = state.get_space_state().intersect_ray(_query)
	if hit.is_empty():
		is_grounded = false
		tire_load = 0.0
		suspension_length = stats.suspension_rest_length
		return

	is_grounded = true
	contact_point = hit["position"]
	contact_normal = hit["normal"]
	# Negative when the wheel would have to sit above its mount: the
	# suspension has bottomed out and the ground is pushing into the wheel.
	var raw_length: float = ray_origin.distance_to(contact_point) - stats.ray_start_height \
		- stats.wheel_radius
	var overtravel: float = maxf(-raw_length, 0.0)
	suspension_length = clampf(raw_length, 0.0, stats.suspension_rest_length)

	var com_world: Vector3 = body_xform.origin + state.center_of_mass
	var point_offset: Vector3 = contact_point - body_xform.origin
	var point_velocity: Vector3 = state.linear_velocity \
		+ state.angular_velocity.cross(contact_point - com_world)
	var step: float = state.step

	# Suspension: spring + damper along the body's up axis.
	var compression: float = stats.suspension_rest_length - suspension_length
	var spring: float = stats.spring_stiffness * compression
	var damper: float = stats.spring_damping * point_velocity.dot(up)
	tire_load = maxf(spring - damper, 0.0)
	state.apply_force(up * tire_load, point_offset)

	# Bump stop: out of travel, the wheel behaves like a solid contact. It acts
	# one tick ahead, so fast landings stop at full compression instead of
	# sinking past it for a frame.
	var up_speed: float = point_velocity.dot(up)
	if raw_length + up_speed * step < 0.0:
		var target_speed: float = overtravel * stats.bump_stop_recovery if overtravel > 0.0 \
			else -raw_length / step
		if up_speed < target_speed:
			var impulse: float = (target_speed - up_speed) \
				* _effective_mass(state, contact_point - com_world, up)
			state.apply_impulse(up * impulse, point_offset)
			point_velocity += up * (target_speed - up_speed)
			tire_load += impulse / step

	# Tire frame on the contact plane.
	var forward: Vector3 = (-body_xform.basis.z).rotated(up, -steer_angle)
	forward = (forward - contact_normal * forward.dot(contact_normal)).normalized()
	var right: Vector3 = forward.cross(contact_normal)
	forward_speed = point_velocity.dot(forward)
	lateral_speed = point_velocity.dot(right)
	var max_force: float = tire_load * stats.tire_friction

	# Tire forces push higher than the contact point to reduce body roll.
	var com_height: float = (com_world - contact_point).dot(up)
	var push_point: Vector3 = contact_point + up * com_height * stats.tire_force_height
	var push_arm: Vector3 = push_point - com_world

	# Lateral grip: remove a share of the sideways slip, limited by friction.
	# Effective mass (not a share of total mass) accounts for the body turning
	# as well as sliding; without it light, narrow vehicles over-correct every
	# tick and start weaving at speed.
	var slip_ratio: float = absf(lateral_speed) / maxf(point_velocity.length(), stats.slip_reference_speed)
	var lateral_force: float = -lateral_speed * _effective_mass(state, push_arm, right) / step \
		* stats.lateral_grip * stats.grip_at(slip_ratio) * grip_multiplier
	lateral_force = clampf(lateral_force, -max_force, max_force)

	# Longitudinal: drive, brakes (never strong enough to reverse direction),
	# rolling resistance.
	var longitudinal_force: float = drive_force - forward_speed * stats.rolling_resistance
	if brake_force > 0.0:
		var stop_force: float = absf(forward_speed) * _effective_mass(state, push_arm, forward) / step
		longitudinal_force -= signf(forward_speed) * minf(brake_force, stop_force)
	longitudinal_force = clampf(longitudinal_force, -max_force, max_force)

	state.apply_force(forward * longitudinal_force + right * lateral_force,
		push_point - body_xform.origin)


## Mass the body "feels" when pushed at `arm` (from the center of mass) along
## `direction`: lower than the total mass because part of the push turns it.
func _effective_mass(state: PhysicsDirectBodyState3D, arm: Vector3, direction: Vector3) -> float:
	var angular: Vector3 = arm.cross(direction)
	var inverse: float = state.inverse_mass + angular.dot(state.inverse_inertia_tensor * angular)
	return 1.0 / inverse if inverse > 0.0 else 0.0


## Visual update, called from the vehicle's _process.
func update_visual(delta: float) -> void:
	if wheel_mesh == null:
		return
	wheel_mesh.position = position + Vector3.DOWN * suspension_length
	if _radius > 0.0:
		_spin_angle = wrapf(_spin_angle - forward_speed / _radius * delta, -PI, PI)
	wheel_mesh.rotation = Vector3(_spin_angle, -steer_angle, 0.0)
