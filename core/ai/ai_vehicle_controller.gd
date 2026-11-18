class_name AiVehicleController
extends Node
## Drives an ArcadeVehicle along LevelGrid paths by writing its intent, just
## like PlayerVehicleController does from the keyboard. Used by traffic now,
## by police and rivals later.
##
## Steering: head for the next corner of the path (straight runs are merged),
## offset to the right of the street so oncoming cars can pass. Speed: cruise,
## slow down near corners, brake for anything in front, reverse when stuck.

signal destination_reached
signal gave_up

@export var vehicle: ArcadeVehicle
## Optional: defaults to the level's grid.
@export var grid: LevelGrid
## Cars keep to two-lane roads; scooters also use alleys, ramps and piazzas.
@export var network: LevelGrid.Network = LevelGrid.Network.CARS

@export_group("Speed")
@export_range(1.0, 200.0, 1.0, "suffix:km/h") var cruise_speed_kmh: float = 32.0
@export_range(1.0, 200.0, 1.0, "suffix:km/h") var corner_speed_kmh: float = 12.0
## Start slowing this far before a corner.
@export_range(0.0, 50.0, 0.5, "suffix:m") var corner_slow_distance: float = 9.0
## Throttle/brake per km/h of speed error.
@export_range(0.01, 1.0, 0.01) var speed_gain: float = 0.12

@export_group("Steering")
## Waypoint counts as reached within this distance.
@export_range(0.5, 10.0, 0.1, "suffix:m") var waypoint_radius: float = 1.8
## Start left turns this far before the corner (about the turning radius),
## so the car comes out of the turn lined up with the new street.
@export_range(0.5, 10.0, 0.1, "suffix:m") var turn_in_distance: float = 2.8
## Keep this far right of the path. Cars on two-lane roads: ~1 m. Scooters
## in alleys: 0 (the gap between bollards is in the middle).
@export_range(0.0, 3.0, 0.05, "suffix:m") var lane_offset: float = 1.0
@export_range(0.1, 10.0, 0.05) var steer_gain: float = 1.8
## A path corner sharper than this is a turn (slow down for it).
@export_range(1.0, 90.0, 1.0, "suffix:°") var corner_angle: float = 25.0
## Route behind the car by more than this while (nearly) stopped: three-point turn.
@export_range(60.0, 180.0, 1.0, "suffix:°") var u_turn_angle: float = 100.0
## After backing up, drive forward at least this long before backing up again.
@export_range(0.0, 5.0, 0.1, "suffix:s") var forward_leg_time: float = 1.0

@export_group("Obstacles")
@export_range(0.5, 30.0, 0.5, "suffix:m") var look_ahead: float = 7.0
## Sensor range when stopped (it grows with speed up to look_ahead).
@export_range(0.5, 30.0, 0.5, "suffix:m") var min_look_ahead: float = 3.5
## Stay "blocked" until the road has been clear this long (no flicker).
@export_range(0.0, 3.0, 0.05, "suffix:s") var unblock_delay: float = 0.5
@export_range(0.0, 3.0, 0.05, "suffix:m") var sensor_height: float = 0.7
@export_flags_3d_physics var obstacle_mask: int = 0b1010
## Honk after being blocked this long, then again every honk_interval.
@export_range(0.0, 10.0, 0.1, "suffix:s") var honk_delay: float = 1.2
@export_range(0.1, 10.0, 0.1, "suffix:s") var honk_interval: float = 2.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var honk_length: float = 0.35
## Blocked or stuck this long: reverse a bit and pick a new route.
@export_range(0.5, 30.0, 0.5, "suffix:s") var give_up_time: float = 3.5
@export_range(0.1, 5.0, 0.1, "suffix:s") var reverse_time: float = 1.4
## Three-point-turn attempts before giving up on the route.
@export_range(1, 10, 1) var max_unstick_attempts: int = 3
## Moving this far counts as progress (resets the attempts).
@export_range(0.5, 20.0, 0.5, "suffix:m") var progress_distance: float = 4.0
## Only reverse while there is ground this close below the rear...
@export_range(0.1, 3.0, 0.05, "suffix:m") var max_rear_drop: float = 0.6
## ...and nothing within this distance behind.
@export_range(0.5, 10.0, 0.1, "suffix:m") var rear_clearance: float = 2.2
## A car ahead moving away faster than this is followed, not a jam.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var follow_speed: float = 0.8

const KMH_PER_MS: float = 3.6

var path := PackedVector3Array()
var is_blocked: bool = false
## What is in front when blocked (null if nothing / not a body).
var blocker: Node3D
## Why the last give-up happened: &"stuck" or &"blocked".
var last_give_up_reason: StringName = &""

var _index: int = 0
var _blocked_time: float = 0.0
var _clear_time: float = 0.0
var _next_honk: float = 0.0
var _stuck_time: float = 0.0
var _honk_left: float = 0.0
var _reverse_left: float = 0.0
var _reverse_steer: float = 0.0
var _since_reverse: float = INF
var _unstick_attempts: int = 0
var _progress_anchor := Vector3.ZERO
var _last_heading_error: float = 0.0
var _query := PhysicsRayQueryParameters3D.new()


func _init() -> void:
	_next_honk = honk_delay


func _ready() -> void:
	if grid == null:
		grid = LevelGridNode.find_grid(get_tree())


## Plans a route to `target`, preferably starting straight ahead (no
## U-turn: it goes round the block instead). Returns false if there is none.
func drive_to(target: Vector3) -> bool:
	if grid == null or vehicle == null:
		return false
	var here: Vector3 = vehicle.global_position
	var here_cell: Vector2i = grid.world_to_cell(here)
	var ahead: Vector3 = here - vehicle.global_basis.z * grid.cell_size
	var ahead_cell: Vector2i = grid.world_to_cell(ahead)
	var route := PackedVector3Array()
	if grid.is_usable(ahead_cell, network) and grid.are_connected(here_cell, ahead_cell):
		route = grid.find_path(ahead, target, network, here_cell)
		if not route.is_empty():
			route.insert(0, grid.cell_to_world(here_cell))
	if route.is_empty():
		route = grid.find_path(here, target, network)
	path = _simplify(route)
	_index = 1 if path.size() > 1 else 0
	_blocked_time = 0.0
	_stuck_time = 0.0
	_unstick_attempts = 0
	_progress_anchor = vehicle.global_position
	return path.size() > 1


func has_route() -> bool:
	return _index < path.size()


func stop() -> void:
	path.clear()
	_index = 0
	if vehicle != null:
		vehicle.intent.clear()


func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	var intent: VehicleIntent = vehicle.intent
	_honk_left = maxf(_honk_left - delta, 0.0)
	intent.horn = _honk_left > 0.0
	_since_reverse += delta
	if _reverse_left > 0.0:
		_since_reverse = 0.0
		_reverse_left -= delta
		if not _safe_to_reverse():
			_reverse_left = 0.0
		intent.throttle = 0.0
		intent.brake = 1.0 if _reverse_left > 0.0 else 0.0
		intent.steer = _reverse_steer
		if _reverse_left <= 0.0 and _unstick_attempts >= max_unstick_attempts:
			_unstick_attempts = 0
			path.clear()
			gave_up.emit()
		return
	if not has_route():
		intent.throttle = 0.0
		intent.brake = 0.0
		intent.steer = 0.0
		return

	var position: Vector3 = vehicle.global_position
	while _index < path.size():
		# Left turns (inside corner across the road) start early; right turns
		# swing wide first and turn late so they don't clip the corner.
		var reach: float = turn_in_distance if _turn_sign(_index) > 0.0 else waypoint_radius
		if _flat_distance(position, path[_index]) >= reach:
			break
		_index += 1
	if _index >= path.size():
		stop()
		destination_reached.emit()
		return
	var waypoint: Vector3 = path[_index]

	# Keep right, except just before a turn: swing to the outside of it
	# (left before a right turn), so the car doesn't clip the inside corner.
	var segment: Vector3 = waypoint - path[_index - 1] if _index > 0 else waypoint - position
	segment.y = 0.0
	var right: Vector3 = segment.normalized().cross(Vector3.UP) if segment.length_squared() > 0.01 else Vector3.ZERO
	var side: float = 1.0
	if _flat_distance(position, waypoint) < corner_slow_distance and _turn_sign(_index) < 0.0:
		side = -1.0
	var target: Vector3 = waypoint + right * lane_offset * side
	var local: Vector3 = vehicle.global_basis.inverse() * (target - position)
	var heading_error: float = atan2(local.x, -local.z)
	_last_heading_error = heading_error
	intent.steer = clampf(heading_error * steer_gain, -1.0, 1.0)
	if _flat_distance(position, _progress_anchor) > progress_distance:
		_progress_anchor = position
		_unstick_attempts = 0
	if absf(heading_error) > deg_to_rad(u_turn_angle) and absf(vehicle.forward_speed) < 1.5 \
			and _since_reverse > forward_leg_time and _safe_to_reverse():
		# Facing the wrong way: back up with counter-steer (first leg of a
		# three-point turn). If it can't back up, the forward code below
		# turns at full lock instead.
		_reverse_left = reverse_time
		_reverse_steer = -signf(heading_error)
		return

	var desired_kmh: float = cruise_speed_kmh
	if _flat_distance(position, waypoint) < corner_slow_distance and _is_corner(_index):
		desired_kmh = corner_speed_kmh
	if absf(heading_error) > deg_to_rad(45.0):
		desired_kmh = minf(desired_kmh, corner_speed_kmh)

	var hit: bool = _obstacle_ahead()
	_clear_time = 0.0 if hit else _clear_time + delta
	is_blocked = hit or (is_blocked and _clear_time < unblock_delay)
	var speed_kmh: float = vehicle.get_speed_kmh()
	if is_blocked:
		desired_kmh = 0.0
		if not _blocker_moving_away():
			_blocked_time += delta
		if _blocked_time >= _next_honk:
			_honk_left = honk_length
			_next_honk += honk_interval
	else:
		_blocked_time = 0.0
		_next_honk = honk_delay
	var error: float = desired_kmh - speed_kmh
	intent.throttle = clampf(error * speed_gain, 0.0, 1.0)
	# Only brake while still rolling forward (braking at a standstill reverses).
	intent.brake = clampf(-error * speed_gain, 0.0, 1.0) if vehicle.forward_speed > 0.5 else 0.0

	# Stuck: trying to move but not moving.
	if intent.throttle > 0.3 and absf(speed_kmh) < 1.0:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
	if _stuck_time > give_up_time or _blocked_time > give_up_time:
		_start_unstick(_blocked_time > give_up_time)


## Reverse with counter-steer (the nose swings toward the route), then
## carry on. A jam (something in the way that won't move) gives up after
## one reverse so the car can find another route.
func _start_unstick(jammed: bool) -> void:
	last_give_up_reason = &"blocked" if jammed else &"stuck"
	_unstick_attempts = max_unstick_attempts if jammed else _unstick_attempts + 1
	_reverse_left = reverse_time
	_reverse_steer = -signf(_last_heading_error) if absf(_last_heading_error) > 0.1 else 0.0
	_stuck_time = 0.0
	_blocked_time = 0.0
	_next_honk = honk_delay


func _safe_to_reverse() -> bool:
	var basis: Basis = vehicle.global_basis
	var space: PhysicsDirectSpaceState3D = vehicle.get_world_3d().direct_space_state
	var origin: Vector3 = vehicle.global_position + basis.y * sensor_height
	_query.collision_mask = vehicle.wheel_collision_mask | obstacle_mask
	_query.exclude = [vehicle.get_rid()]
	_query.from = origin
	_query.to = origin + basis.z * rear_clearance
	if not space.intersect_ray(_query).is_empty():
		return false
	var behind: Vector3 = origin + basis.z * rear_clearance
	# Don't back from the network into places this vehicle doesn't belong
	# (alleys for cars). Already off it? Backing out is the way back.
	if grid != null and grid.is_usable(grid.world_to_cell(vehicle.global_position), network) \
			and not grid.is_usable(grid.world_to_cell(behind), network):
		return false
	_query.from = behind
	_query.to = behind - Vector3.UP * (sensor_height + max_rear_drop)
	return not space.intersect_ray(_query).is_empty()


func _blocker_moving_away() -> bool:
	var other := blocker as RigidBody3D
	if other == null:
		return false
	return other.linear_velocity.dot(-vehicle.global_basis.z) > follow_speed


func _obstacle_ahead() -> bool:
	var basis: Basis = vehicle.global_basis
	var from: Vector3 = vehicle.global_position + basis.y * sensor_height
	var speed_ratio: float = clampf(absf(vehicle.forward_speed) / (cruise_speed_kmh / KMH_PER_MS), 0.0, 1.0)
	var reach: float = lerpf(min_look_ahead, look_ahead, speed_ratio)
	_query.from = from
	_query.to = from - basis.z * reach
	_query.collision_mask = obstacle_mask
	_query.exclude = [vehicle.get_rid()]
	var hit: Dictionary = vehicle.get_world_3d().direct_space_state.intersect_ray(_query)
	blocker = hit.get("collider") as Node3D if not hit.is_empty() else null
	return not hit.is_empty()


func _is_corner(index: int) -> bool:
	if index <= 0 or index >= path.size() - 1:
		return index == path.size() - 1
	var incoming: Vector3 = (path[index] - path[index - 1]) * Vector3(1, 0, 1)
	var outgoing: Vector3 = (path[index + 1] - path[index]) * Vector3(1, 0, 1)
	return incoming.angle_to(outgoing) > deg_to_rad(corner_angle)


## +1 for a left turn at path[index], -1 for a right turn, 0 for none.
func _turn_sign(index: int) -> float:
	if index <= 0 or index >= path.size() - 1 or not _is_corner(index):
		return 0.0
	var incoming: Vector3 = (path[index] - path[index - 1]) * Vector3(1, 0, 1)
	var outgoing: Vector3 = (path[index + 1] - path[index]) * Vector3(1, 0, 1)
	return signf(incoming.cross(outgoing).y)


## Removes points in the middle of straight runs: only corners remain.
static func _simplify(points: PackedVector3Array) -> PackedVector3Array:
	if points.size() < 3:
		return points
	var result := PackedVector3Array([points[0]])
	for i: int in range(1, points.size() - 1):
		var incoming: Vector3 = points[i] - points[i - 1]
		var outgoing: Vector3 = points[i + 1] - points[i]
		incoming.y = 0.0
		outgoing.y = 0.0
		if incoming.normalized().dot(outgoing.normalized()) < 0.999:
			result.append(points[i])
	result.append(points[points.size() - 1])
	return result


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
