extends TestCase
## Camera shake, speed lines and near misses.

const SCOOTER: String = "res://core/vehicle/vehicles/scooter.tscn"
const CAMERA: String = "res://core/camera/chase_camera.tscn"
const SPEED_LINES: String = "res://core/ui/effects/speed_lines.tscn"
const PEDESTRIAN: String = "res://core/characters/pedestrian.tscn"
const NONNA: String = "res://core/characters/profiles/nonna.tres"


func test_camera_shakes_and_settles() -> void:
	var scooter: ArcadeVehicle = _setup_scooter()
	var camera := (load(CAMERA) as PackedScene).instantiate() as ChaseCamera
	camera.capture_mouse = false
	camera.target = scooter
	add_node(camera)
	await wait_physics_frames(30)
	camera.add_trauma(1.0)
	var max_offset: float = 0.0
	for i: int in 20:
		await tree.process_frame
		max_offset = maxf(max_offset, camera.camera.position.length())
	await wait_physics_frames(60 * 2)
	await tree.process_frame
	note("shake offset up to %.2f m, trauma after 2 s %.2f" % [max_offset, camera.trauma])
	expect(max_offset > 0.05, "trauma should shake the camera")
	expect(camera.trauma < 0.01, "shake should settle")
	# A hard landing shakes it by itself.
	scooter.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, 6.0, 0.0)))
	var landed_trauma: float = 0.0
	for i: int in 120:
		await tree.physics_frame
		landed_trauma = maxf(landed_trauma, camera.trauma)
	note("trauma from a 6 m drop: %.2f" % landed_trauma)
	expect(landed_trauma > 0.2, "a hard landing should shake the camera")


func test_speed_lines_follow_speed() -> void:
	var scooter: ArcadeVehicle = _setup_scooter()
	var lines := (load(SPEED_LINES) as PackedScene).instantiate() as SpeedLines
	lines.target = scooter
	add_node(lines)
	await wait_physics_frames(60)
	var at_rest: float = lines.intensity
	scooter.intent.throttle = 1.0
	await wait_physics_frames(60 * 6)
	note("speed lines: %.2f at rest, %.2f at %.0f km/h" % [at_rest, lines.intensity, scooter.get_speed_kmh()])
	expect(at_rest < 0.05, "no speed lines when parked")
	expect(lines.intensity > 0.5, "speed lines at speed")


func test_near_miss_rewards_close_passes_only() -> void:
	for case: Array in [["close pass", 1.4, 1], ["far pass", 6.0, 0], ["hit", 0.0, 0]]:
		var scooter: ArcadeVehicle = _setup_scooter()
		var detector := NearMissDetector.new()
		detector.vehicle = scooter
		add_node(detector)
		var pedestrian := (load(PEDESTRIAN) as PackedScene).instantiate() as Pedestrian
		pedestrian.profile = load(NONNA) as PedestrianProfile
		pedestrian.position = Vector3(float(case[1]), 0.05, -40.0)
		add_node(pedestrian)
		var misses: Array[float] = []
		var on_miss := func(_thing: Node3D, distance: float) -> void: misses.append(distance)
		Events.near_miss.connect(on_miss)
		await wait_physics_frames(30)
		scooter.intent.throttle = 1.0
		await wait_physics_frames(60 * 5)
		Events.near_miss.disconnect(on_miss)
		note("%s: %d near miss(es) %s" % [case[0], misses.size(), misses])
		expect(misses.size() == int(case[2]), "%s: expected %d near miss, got %d" % [case[0], case[2], misses.size()])
		await cleanup()


func _setup_scooter() -> ArcadeVehicle:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1000.0, 1.0, 1000.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	add_node(ground)
	var scooter := (load(SCOOTER) as PackedScene).instantiate() as ArcadeVehicle
	scooter.position = Vector3(0.0, 0.3, 0.0)
	scooter.add_to_group(Groups.PLAYER)
	add_node(scooter)
	return scooter
