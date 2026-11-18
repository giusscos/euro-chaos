extends TestCase
## MissionRunner flow, scoring rules and CargoMonitor.

const SCOOTER: String = "res://core/vehicle/vehicles/scooter.tscn"
const PICKUP_POSITION := Vector3(0.0, 0.0, -30.0)
const DROPOFF_POSITION := Vector3(0.0, 0.0, -90.0)
const PARK_HEIGHT: float = 0.3


func test_scoring_rules() -> void:
	var runner := MissionRunner.new()
	var mission := _make_mission(&"pizza", 0.0)
	mission.base_payout = 10
	mission.max_tip = 8

	var perfect: DeliveryResult = runner.evaluate(mission, 10.0, 60.0, 1.0)
	expect(perfect.outcome == DeliveryResult.Outcome.DELIVERED, "fast delivery should be DELIVERED")
	expect(perfect.payout == 10 and perfect.tip == 8, "fast perfect delivery: full pay + tip (got %d + %d)" % [perfect.payout, perfect.tip])
	expect(perfect.stars == 5, "fast perfect delivery: 5 stars (got %d)" % perfect.stars)

	var slow: DeliveryResult = runner.evaluate(mission, 50.0, 60.0, 1.0)
	expect(slow.tip > 0 and slow.tip < 8, "slow delivery: partial tip (got %d)" % slow.tip)

	var bumpy: DeliveryResult = runner.evaluate(mission, 10.0, 60.0, 0.5)
	expect(bumpy.tip == 4, "half-ruined cargo halves the tip (got %d)" % bumpy.tip)

	var late: DeliveryResult = runner.evaluate(mission, 70.0, 60.0, 1.0)
	expect(late.outcome == DeliveryResult.Outcome.LATE, "over time should be LATE")
	expect(late.payout == 5 and late.tip == 0 and late.stars == 1, "late: half pay, no tip, 1 star")

	var ruined: DeliveryResult = runner.evaluate(mission, 10.0, 60.0, 0.0)
	expect(ruined.outcome == DeliveryResult.Outcome.RUINED and ruined.total() == 0, "ruined cargo pays nothing")
	runner.free()


func test_auto_time_limit_scales_with_distance() -> void:
	var runner := MissionRunner.new()
	var mission := _make_mission(&"pizza", 0.0)
	var near: float = runner.compute_time_limit(mission, Vector3.ZERO, Vector3(0, 0, 50))
	var far: float = runner.compute_time_limit(mission, Vector3.ZERO, Vector3(0, 0, 400))
	note("auto limits: 50 m -> %.0f s, 400 m -> %.0f s" % [near, far])
	expect(near >= runner.min_time_limit, "below minimum time limit")
	expect(far > near, "longer trips should get more time")
	mission.time_limit = 42.0
	expect(is_equal_approx(runner.compute_time_limit(mission, Vector3.ZERO, Vector3(0, 0, 400)), 42.0),
		"explicit time_limit should win")
	runner.free()


func test_full_delivery_flow() -> void:
	var setup: Dictionary = await _make_world()
	var runner: MissionRunner = setup["runner"]
	var vehicle: ArcadeVehicle = setup["vehicle"]
	var events: Array[String] = []
	var results: Array[DeliveryResult] = []
	runner.cargo_picked_up.connect(func(_m: MissionData) -> void: events.append("picked_up"))
	runner.mission_finished.connect(func(r: DeliveryResult) -> void: results.append(r))

	expect(runner.start_mission(_make_mission(&"pizza", 60.0)), "start_mission failed")
	expect(runner.state == MissionRunner.State.TO_PICKUP, "should head to pickup first")
	expect(runner.get_objective_position().is_equal_approx(PICKUP_POSITION), "objective should be the pickup")

	vehicle.teleport(Transform3D(Basis.IDENTITY, PICKUP_POSITION + Vector3.UP * PARK_HEIGHT))
	await wait_physics_frames(90)
	expect(events.has("picked_up"), "cargo not picked up after stopping at the pickup")
	expect(runner.state == MissionRunner.State.DELIVERING, "should be delivering after pickup")
	expect(runner.get_objective_position().is_equal_approx(DROPOFF_POSITION), "objective should be the dropoff")

	vehicle.teleport(Transform3D(Basis.IDENTITY, DROPOFF_POSITION + Vector3.UP * PARK_HEIGHT))
	await wait_physics_frames(90)
	expect(results.size() == 1, "mission did not finish at the dropoff")
	if results.size() == 1:
		var result: DeliveryResult = results[0]
		note("delivered in %.1f s, condition %.2f, %d + %d tip, %d stars" % [
			result.time_taken, result.condition, result.payout, result.tip, result.stars])
		expect(result.outcome == DeliveryResult.Outcome.DELIVERED, "outcome should be DELIVERED")
		expect(is_equal_approx(result.condition, 1.0), "teleports must not damage the cargo")
		expect(result.total() > 0, "delivery should pay")
	expect(runner.state == MissionRunner.State.IDLE, "runner should be idle after delivery")


func test_cargo_damage_from_impacts() -> void:
	var setup: Dictionary = await _make_world()
	var monitor: CargoMonitor = setup["monitor"]
	var vehicle: ArcadeVehicle = setup["vehicle"]
	monitor.start(1.0)

	# Hard braking only: no damage.
	vehicle.intent.throttle = 1.0
	await wait_physics_frames(120)
	vehicle.intent.throttle = 0.0
	vehicle.intent.brake = 1.0
	await wait_physics_frames(90)
	vehicle.intent.clear()
	note("after hard braking: condition %.3f" % monitor.condition)
	expect(is_equal_approx(monitor.condition, 1.0), "hard braking damaged the cargo")

	# A 5 m drop: damage, but not ruined.
	vehicle.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, 0.0)))
	await wait_physics_frames(120)
	note("after 5 m drop: condition %.3f" % monitor.condition)
	expect(monitor.condition < 0.95, "a 5 m drop should damage the cargo")
	expect(monitor.condition > 0.3, "a 5 m drop should not nearly ruin normal cargo")


func test_ruined_cargo_ends_mission() -> void:
	var setup: Dictionary = await _make_world()
	var runner: MissionRunner = setup["runner"]
	var monitor: CargoMonitor = setup["monitor"]
	var vehicle: ArcadeVehicle = setup["vehicle"]
	var results: Array[DeliveryResult] = []
	runner.mission_finished.connect(func(r: DeliveryResult) -> void: results.append(r))
	runner.start_mission(_make_mission(&"pizza", 60.0))
	vehicle.teleport(Transform3D(Basis.IDENTITY, PICKUP_POSITION + Vector3.UP * PARK_HEIGHT))
	await wait_physics_frames(90)
	monitor.apply_damage(1.0)
	await wait_physics_frames(2)
	expect(results.size() == 1 and results[0].outcome == DeliveryResult.Outcome.RUINED,
		"ruined cargo should end the mission as RUINED")


func _make_world() -> Dictionary:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600.0, 1.0, 600.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	add_node(ground)
	add_node(_make_location(&"test_pickup", "Test Pizzeria", PICKUP_POSITION))
	add_node(_make_location(&"test_dropoff", "Test House", DROPOFF_POSITION))

	var vehicle := (load(SCOOTER) as PackedScene).instantiate() as ArcadeVehicle
	vehicle.position = Vector3(0.0, PARK_HEIGHT, 0.0)
	vehicle.add_to_group(Groups.PLAYER)
	add_node(vehicle)

	var monitor := CargoMonitor.new()
	monitor.vehicle = vehicle
	add_node(monitor)
	var runner := MissionRunner.new()
	runner.cargo_monitor = monitor
	add_node(runner)
	await wait_physics_frames(30)
	return {"vehicle": vehicle, "monitor": monitor, "runner": runner}


func _make_location(id: StringName, display_name: String, at: Vector3) -> MissionLocation:
	var location := MissionLocation.new()
	location.location_id = id
	location.display_name = display_name
	location.position = at
	return location


func _make_mission(id: StringName, time_limit: float) -> MissionData:
	var cargo := CargoType.new()
	cargo.id = &"pizza"
	cargo.fragility = 1.0
	var mission := MissionData.new()
	mission.id = id
	mission.pickup_location_id = &"test_pickup"
	mission.dropoff_location_id = &"test_dropoff"
	mission.cargo = cargo
	mission.time_limit = time_limit
	return mission
