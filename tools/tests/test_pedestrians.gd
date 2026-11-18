extends TestCase
## Pedestrians: wandering, getting knocked over, horn dodges, angry nonnas.

const VILLAGE_SCENE: String = "res://minigames/vespa_delivery/levels/village.tscn"
const PEDESTRIAN_SCENE: String = "res://core/characters/pedestrian.tscn"
const SCOOTER_SCENE: String = "res://core/vehicle/vehicles/scooter.tscn"
const TOURIST: String = "res://core/characters/profiles/tourist.tres"
const LOCAL: String = "res://core/characters/profiles/local.tres"
const NONNA: String = "res://core/characters/profiles/nonna.tres"


func test_wanders_the_village() -> void:
	add_node((load(VILLAGE_SCENE) as PackedScene).instantiate())
	await wait_physics_frames(2)
	var grid: LevelGrid = LevelGridNode.find_grid(tree)
	var start: Vector3 = grid.cell_to_world(Vector2i(28, 20))
	var walker: Pedestrian = _spawn(LOCAL, start, 11)
	var farthest: float = 0.0
	var lowest: float = INF
	for i: int in 60 * 30:
		await tree.physics_frame
		farthest = maxf(farthest, walker.global_position.distance_to(start))
		lowest = minf(lowest, walker.global_position.y)
	note("walked up to %.1f m from the start, lowest y %.2f, now %s" % [farthest, lowest,
		Pedestrian.State.keys()[walker.state]])
	expect(farthest > 8.0, "pedestrian barely moved (%.1f m)" % farthest)
	expect(lowest > -0.3, "pedestrian fell through or into the sea")


func test_knocked_over_and_gets_up() -> void:
	add_node(_make_ground())
	var victim: Pedestrian = _spawn(NONNA, Vector3(0.0, 0.05, -25.0), 5)
	var scooter: ArcadeVehicle = _spawn_player(Vector3(0.0, 0.3, 0.0))
	var hits: Array[float] = []
	var on_hit := func(_p: Node3D, _by: Node3D, speed: float) -> void: hits.append(speed)
	Events.pedestrian_hit.connect(on_hit)
	await wait_physics_frames(30)
	scooter.intent.throttle = 1.0
	var tumbled: bool = false
	var speed_before_hit: float = 0.0
	for i: int in 60 * 4:
		if hits.is_empty():
			speed_before_hit = scooter.get_speed_kmh()
		await tree.physics_frame
		tumbled = tumbled or victim.state == Pedestrian.State.TUMBLE
	scooter.intent.clear()
	scooter.intent.brake = 1.0
	await wait_physics_frames(60 * 4)
	Events.pedestrian_hit.disconnect(on_hit)
	note("hit at %.0f km/h, tumbled %s, now %s, on floor %s" % [speed_before_hit, tumbled,
		Pedestrian.State.keys()[victim.state], victim.is_on_floor()])
	expect(hits.size() == 1, "expected exactly one hit event, got %d" % hits.size())
	expect(tumbled, "pedestrian should tumble when hit")
	expect(victim.state != Pedestrian.State.TUMBLE, "pedestrian should get back up")
	expect(victim.global_position.y > -0.3, "pedestrian fell through the ground")


func test_horn_makes_pedestrians_hop_aside() -> void:
	add_node(_make_ground())
	var walker: Pedestrian = _spawn(TOURIST, Vector3(0.3, 0.05, -6.0), 7)
	var scooter: ArcadeVehicle = _spawn_player(Vector3(0.0, 0.3, 0.0))
	await wait_physics_frames(30)
	var before: Vector3 = walker.global_position
	scooter.intent.horn = true
	await wait_physics_frames(2)
	var dodged: bool = walker.state == Pedestrian.State.DODGE
	scooter.intent.horn = false
	await wait_physics_frames(60)
	var sideways: float = absf(walker.global_position.x - before.x)
	note("dodged %s, moved %.2f m sideways" % [dodged, sideways])
	expect(dodged, "pedestrian should dodge the horn")
	expect(sideways > 0.8, "pedestrian should hop out of the scooter's path")
	expect(walker.global_position.x > before.x, "pedestrian should hop away from the scooter's path, not across it")


func test_nonna_yells_at_speeders() -> void:
	add_node(_make_ground())
	var nonna: Pedestrian = _spawn(NONNA, Vector3(3.0, 0.05, -40.0), 3)
	var scooter: ArcadeVehicle = _spawn_player(Vector3(0.0, 0.3, 0.0))
	await wait_physics_frames(30)
	scooter.intent.throttle = 1.0
	var yelled: bool = false
	for i: int in 60 * 5:
		await tree.physics_frame
		var speech := nonna.get_node(^"Speech") as Label3D
		yelled = yelled or (speech.visible and nonna.profile.yell_lines.has(speech.text))
	note("nonna yelled: %s" % yelled)
	expect(yelled, "nonna should yell at a speeding scooter")


func test_spawner_fills_the_village() -> void:
	add_node((load(VILLAGE_SCENE) as PackedScene).instantiate())
	await wait_physics_frames(2)
	var grid: LevelGrid = LevelGridNode.find_grid(tree)
	var spawner := PedestrianSpawner.new()
	spawner.profiles = [load(TOURIST) as PedestrianProfile, load(LOCAL) as PedestrianProfile,
		load(NONNA) as PedestrianProfile]
	spawner.counts = PackedInt32Array([6, 6, 2])
	spawner.random_seed = 9
	add_node(spawner)
	await wait_physics_frames(60)
	expect(spawner.pedestrians.size() == 14, "expected 14 pedestrians, got %d" % spawner.pedestrians.size())
	for pedestrian: Pedestrian in spawner.pedestrians:
		var cell: Vector2i = grid.world_to_cell(pedestrian.global_position)
		expect(grid.is_walkable(cell), "%s spawned off the pedestrian network at %s" % [pedestrian.name, cell])
		expect(pedestrian.global_position.y > -0.3, "%s fell through the ground" % pedestrian.name)


func _spawn(profile_path: String, at: Vector3, seed_value: int) -> Pedestrian:
	var pedestrian := (load(PEDESTRIAN_SCENE) as PackedScene).instantiate() as Pedestrian
	pedestrian.profile = load(profile_path) as PedestrianProfile
	pedestrian.random_seed = seed_value
	pedestrian.position = at
	add_node(pedestrian)
	return pedestrian


func _spawn_player(at: Vector3) -> ArcadeVehicle:
	var scooter := (load(SCOOTER_SCENE) as PackedScene).instantiate() as ArcadeVehicle
	scooter.position = at
	scooter.add_to_group(Groups.PLAYER)
	add_node(scooter)
	return scooter


func _make_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 400.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	return ground
