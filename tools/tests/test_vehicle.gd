extends TestCase
## Physics behaviour of every vehicle scene on flat ground.

const VEHICLE_SCENES: PackedStringArray = [
	"res://core/vehicle/vehicles/scooter.tscn",
	"res://core/vehicle/vehicles/test_van.tscn",
]
const SPAWN_HEIGHT: float = 0.3
const SETTLE_FRAMES: int = 90
const UPRIGHT_AT_REST: float = 0.98
const UPRIGHT_WHILE_DRIVING: float = 0.9


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


func _upright(vehicle: ArcadeVehicle) -> float:
	return vehicle.global_basis.y.dot(Vector3.UP)
