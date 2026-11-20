extends TestCase
## Physics behaviour of every vehicle scene on flat ground.

const VEHICLE_SCENES: PackedStringArray = [
	"res://core/vehicle/vehicles/scooter.tscn",
	"res://core/vehicle/vehicles/test_van.tscn",
	"res://core/vehicle/vehicles/tiny_car.tscn",
	"res://core/vehicle/vehicles/formica.tscn",
	"res://core/vehicle/vehicles/saetta.tscn",
	"res://core/vehicle/vehicles/topolino.tscn",
]
const SPAWN_HEIGHT: float = 0.3
const SETTLE_FRAMES: int = 90
const UPRIGHT_AT_REST: float = 0.98
const UPRIGHT_WHILE_DRIVING: float = 0.9
const HARD_LANDING_HEIGHT: float = 10.0
const SUNK_HEIGHT: float = -0.4
## Deepest the body origin may dip below the ground on a landing (about full
## suspension compression). Deeper means wheels went into the ground.
const MAX_LANDING_DIP: float = 0.25
## Sudden yaw rate (rad/s) given to a vehicle at full speed.
const YAW_KICK: float = 0.5
## m/s below which a handbraked vehicle counts as stopped.
const HANDBRAKE_STOPPED_SPEED: float = 0.15
const RAMP_SIZE := Vector3(8.0, 1.0, 10.0)
const RAMP_ANGLE: float = 20.0
const RAMP_RUN_UP: float = 60.0


func test_scene_wiring() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		var label: String = path.get_file()
		expect(vehicle.stats != null, "%s: no stats" % label)
		expect(vehicle.visual != null, "%s: visual not assigned" % label)
		expect(not vehicle.wheels.is_empty(), "%s: no wheels" % label)
		for wheel: VehicleWheel in vehicle.wheels:
			expect(wheel.wheel_mesh != null, "%s/%s: wheel_mesh not assigned" % [label, wheel.name])
		await cleanup()


func test_rests_upright_on_all_wheels() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		await wait_physics_frames(SETTLE_FRAMES)
		var label: String = path.get_file()
		note("%s: upright %.3f, wheels %d/%d, speed %.2f m/s" % [label, _upright(vehicle),
			vehicle.grounded_wheel_count, vehicle.wheels.size(), vehicle.linear_velocity.length()])
		expect(_upright(vehicle) > UPRIGHT_AT_REST, "%s tilts at rest" % label)
		expect(vehicle.grounded_wheel_count == vehicle.wheels.size(), "%s: not all wheels grounded" % label)
		expect(vehicle.linear_velocity.length() < 0.2, "%s drifts at rest" % label)
		await cleanup()


func test_accelerates_straight() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		await wait_physics_frames(SETTLE_FRAMES)
		var start: Vector3 = vehicle.global_position
		vehicle.intent.throttle = 1.0
		await wait_physics_frames(180)
		var moved: Vector3 = vehicle.global_position - start
		var label: String = path.get_file()
		note("%s: 3 s full throttle -> %.1f m forward, %.2f m sideways, %.0f km/h" % [
			label, -moved.z, absf(moved.x), vehicle.get_speed_kmh()])
		expect(-moved.z > 12.0, "%s: too slow (%.1f m in 3 s)" % [label, -moved.z])
		expect(absf(moved.x) < 1.0, "%s: pulls sideways (%.2f m)" % [label, moved.x])
		expect(_upright(vehicle) > UPRIGHT_WHILE_DRIVING, "%s tilts while accelerating" % label)
		await cleanup()


func test_turns_both_ways_without_tipping() -> void:
	for path: String in VEHICLE_SCENES:
		for direction: float in [1.0, -1.0]:
			var vehicle: ArcadeVehicle = await _spawn(path)
			await wait_physics_frames(SETTLE_FRAMES)
			vehicle.intent.throttle = 1.0
			await wait_physics_frames(120)
			vehicle.intent.throttle = 0.7
			vehicle.intent.steer = direction
			var min_upright: float = 1.0
			for i: int in 120:
				await tree.physics_frame
				min_upright = minf(min_upright, _upright(vehicle))
			var heading: Vector3 = -vehicle.global_basis.z
			var label: String = "%s steer %+.0f" % [path.get_file(), direction]
			note("%s: heading x %.2f, min upright %.3f, %.0f km/h" % [
				label, heading.x, min_upright, vehicle.get_speed_kmh()])
			expect(heading.x * direction > 0.3, "%s: did not turn" % label)
			expect(min_upright > UPRIGHT_WHILE_DRIVING, "%s: tipped (%.2f)" % [label, min_upright])
			await cleanup()


func test_brakes_to_a_stop() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		await wait_physics_frames(SETTLE_FRAMES)
		vehicle.intent.throttle = 1.0
		await wait_physics_frames(120)
		var speed_before: float = vehicle.get_speed_kmh()
		vehicle.intent.throttle = 0.0
		vehicle.intent.brake = 1.0
		var frames: int = 0
		while vehicle.forward_speed > 0.5 and frames < 300:
			await tree.physics_frame
			frames += 1
		var label: String = path.get_file()
		note("%s: %.0f km/h -> stop in %.2f s" % [label, speed_before, frames / 60.0])
		expect(frames < 180, "%s: braking takes %.1f s" % [label, frames / 60.0])
		expect(_upright(vehicle) > UPRIGHT_WHILE_DRIVING, "%s tips when braking" % label)
		await cleanup()


func test_reverses() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		await wait_physics_frames(SETTLE_FRAMES)
		vehicle.intent.brake = 1.0
		await wait_physics_frames(120)
		var label: String = path.get_file()
		note("%s: reverse speed %.1f km/h" % [label, vehicle.get_speed_kmh()])
		expect(vehicle.get_speed_kmh() < -3.0, "%s does not reverse" % label)
		expect(vehicle.get_speed_kmh() > -vehicle.stats.reverse_top_speed_kmh * 1.1,
			"%s reverses too fast" % label)
		await cleanup()


func test_respects_top_speed() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		await wait_physics_frames(SETTLE_FRAMES)
		vehicle.intent.throttle = 1.0
		await wait_physics_frames(60 * 20)
		var label: String = path.get_file()
		note("%s: after 20 s %.1f km/h (top %.0f)" % [label, vehicle.get_speed_kmh(), vehicle.stats.top_speed_kmh])
		expect(vehicle.get_speed_kmh() <= vehicle.stats.top_speed_kmh * 1.02, "%s exceeds top speed" % label)
		expect(vehicle.get_speed_kmh() >= vehicle.stats.top_speed_kmh * 0.8, "%s never gets near top speed" % label)
		await cleanup()


func test_reset_upright_recovers_from_side() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		await wait_physics_frames(10)
		vehicle.teleport(Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 1.5, 0.0)))
		await wait_physics_frames(60)
		vehicle.reset_upright()
		await wait_physics_frames(SETTLE_FRAMES)
		var label: String = path.get_file()
		note("%s: upright after reset %.3f" % [label, _upright(vehicle)])
		expect(_upright(vehicle) > UPRIGHT_AT_REST, "%s still tipped after reset" % label)
		await cleanup()


func test_handbrake_overrides_throttle() -> void:
	for path: String in VEHICLE_SCENES:
		var label: String = path.get_file()
		# From standstill: gas + handbrake must not creep forward.
		var vehicle: ArcadeVehicle = await _spawn(path)
		await wait_physics_frames(SETTLE_FRAMES)
		var start: Vector3 = vehicle.global_position
		vehicle.intent.throttle = 1.0
		vehicle.intent.handbrake = true
		await wait_physics_frames(120)
		var crept: float = vehicle.global_position.distance_to(start)
		note("%s: gas + handbrake from rest for 2 s -> moved %.2f m, %.1f km/h" % [
			label, crept, vehicle.get_speed_kmh()])
		expect(crept < 0.1, "%s: creeps %.2f m with gas + handbrake" % [label, crept])
		expect(absf(vehicle.get_speed_kmh()) < 0.5, "%s: still moving with gas + handbrake" % label)
		await cleanup()

		# From speed: gas + handbrake must bring it to a stop.
		vehicle = await _spawn(path)
		await wait_physics_frames(SETTLE_FRAMES)
		vehicle.intent.throttle = 1.0
		await wait_physics_frames(120)
		var speed_before: float = vehicle.get_speed_kmh()
		vehicle.intent.handbrake = true
		var frames: int = 0
		while vehicle.forward_speed > HANDBRAKE_STOPPED_SPEED and frames < 60 * 6:
			await tree.physics_frame
			frames += 1
		note("%s: gas + handbrake from %.0f km/h -> stopped in %.2f s" % [label, speed_before, frames / 60.0])
		expect(frames < 60 * 6, "%s: gas + handbrake never stops it" % label)
		expect(_upright(vehicle) > UPRIGHT_WHILE_DRIVING, "%s: tipped under handbrake" % label)
		await cleanup()


func test_stays_straight_at_speed_after_a_kick() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		await wait_physics_frames(SETTLE_FRAMES)
		vehicle.intent.throttle = 1.0
		await wait_physics_frames(60 * 12)
		var label: String = path.get_file()
		var heading_before: float = _heading_degrees(vehicle)
		var drift_before: float = vehicle.global_position.x
		# Disturb it (like a bump or a clipped crate), then let go.
		vehicle.angular_velocity += Vector3.UP * YAW_KICK
		await wait_physics_frames(60)
		var yaw_rate_after: float = absf(vehicle.angular_velocity.y)
		var heading_change: float = absf(_heading_degrees(vehicle) - heading_before)
		note("%s at %.0f km/h: drift before kick %.2f m, yaw rate 1 s after kick %.3f rad/s, heading moved %.1f°" % [
			label, vehicle.get_speed_kmh(), drift_before, yaw_rate_after, heading_change])
		expect(absf(drift_before) < 0.5, "%s: drifts sideways at speed (%.1f m)" % [label, drift_before])
		expect(yaw_rate_after < 0.05, "%s: kick did not die out (yaw rate %.2f)" % [label, yaw_rate_after])
		expect(heading_change < 20.0, "%s: kick turned it %.0f°" % [label, heading_change])
		expect(_upright(vehicle) > UPRIGHT_WHILE_DRIVING, "%s: tipped after kick" % label)
		await cleanup()


func test_survives_hard_landing() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		vehicle.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, HARD_LANDING_HEIGHT, 0.0)))
		var lowest: float = await _track_lowest(vehicle, 240)
		_expect_on_wheels(vehicle, path.get_file() + " after %.0f m drop" % HARD_LANDING_HEIGHT, lowest)
		await cleanup()


func test_recovers_when_pushed_into_ground() -> void:
	for path: String in VEHICLE_SCENES:
		var vehicle: ArcadeVehicle = await _spawn(path)
		# Wheel mounts below the surface: the state seen after bad landings.
		vehicle.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, SUNK_HEIGHT, 0.0)))
		await wait_physics_frames(120)
		_expect_on_wheels(vehicle, path.get_file() + " started sunk", vehicle.global_position.y)
		await cleanup()


func test_jumps_ramp_at_speed() -> void:
	for path: String in VEHICLE_SCENES:
		add_node(_make_ramp())
		var vehicle: ArcadeVehicle = await _spawn(path)
		vehicle.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, SPAWN_HEIGHT, RAMP_RUN_UP)))
		await wait_physics_frames(SETTLE_FRAMES)
		vehicle.intent.throttle = 1.0
		var airborne_frames: int = 0
		var max_height: float = 0.0
		for i: int in 60 * 8:
			await tree.physics_frame
			max_height = maxf(max_height, vehicle.global_position.y)
			if not vehicle.is_grounded():
				airborne_frames += 1
		vehicle.intent.throttle = 0.0
		var lowest: float = await _track_lowest(vehicle, 120)
		var label: String = path.get_file() + " ramp jump"
		note("%s: airborne %.2f s, peak %.1f m, lowest after %.2f m" % [
			label, airborne_frames / 60.0, max_height, lowest])
		expect(airborne_frames > 20, "%s: never left the ground" % label)
		_expect_on_wheels(vehicle, label, lowest)
		await cleanup()


## Watches the vehicle for `frames` ticks and returns the lowest origin height
## seen once it has come back down near the ground.
func _track_lowest(vehicle: ArcadeVehicle, frames: int) -> float:
	var lowest: float = INF
	for i: int in frames:
		await tree.physics_frame
		lowest = minf(lowest, vehicle.global_position.y)
	return lowest


func _expect_on_wheels(vehicle: ArcadeVehicle, label: String, lowest: float) -> void:
	note("%s: wheels %d/%d, height %.3f (lowest %.3f), upright %.3f" % [label,
		vehicle.grounded_wheel_count, vehicle.wheels.size(), vehicle.global_position.y,
		lowest, _upright(vehicle)])
	expect(vehicle.grounded_wheel_count == vehicle.wheels.size(), "%s: wheels not on the ground" % label)
	expect(vehicle.global_position.y > -0.05, "%s: body sunk into the ground (y %.2f)" % [
		label, vehicle.global_position.y])
	expect(_upright(vehicle) > UPRIGHT_WHILE_DRIVING, "%s: not upright" % label)
	expect(lowest > -MAX_LANDING_DIP, "%s: dipped %.2f m into the ground on landing" % [label, -lowest])


## A 20° ramp rising toward -Z, its low edge on the ground at z = 0.
func _make_ramp() -> StaticBody3D:
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = RAMP_SIZE
	shape.shape = box
	ramp.add_child(shape)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(RAMP_ANGLE))
	var low_top_edge := Vector3(0.0, RAMP_SIZE.y * 0.5, RAMP_SIZE.z * 0.5)
	ramp.transform = Transform3D(tilt, -(tilt * low_top_edge))
	return ramp


func _spawn(path: String) -> ArcadeVehicle:
	add_node(_make_ground())
	var vehicle := (load(path) as PackedScene).instantiate() as ArcadeVehicle
	vehicle.position = Vector3(0.0, SPAWN_HEIGHT, 0.0)
	add_node(vehicle)
	await tree.physics_frame
	return vehicle


func _make_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2000.0, 1.0, 2000.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	return ground


func _heading_degrees(vehicle: ArcadeVehicle) -> float:
	var forward: Vector3 = -vehicle.global_basis.z
	return rad_to_deg(atan2(-forward.x, -forward.z))


func _upright(vehicle: ArcadeVehicle) -> float:
	return vehicle.global_basis.y.dot(Vector3.UP)
