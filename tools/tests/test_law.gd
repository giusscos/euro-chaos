extends TestCase
## LawMonitor offences (with and without witnesses) and WantedSystem heat.

const SCOOTER: String = "res://core/vehicle/vehicles/scooter.tscn"
const PEDESTRIAN: String = "res://core/characters/pedestrian.tscn"
const NONNA: String = "res://core/characters/profiles/nonna.tres"

## Alley row 1 (20 km/h), road rows 3-4 with a junction light, one-way alley row 6 (eastbound).
const LAW_MAP: String = """
@light = 20, 3, 2, 2
@oneway = 1, 6, 30, 1, >
@camera = 34, 3
[map]
########################################
S.......................................
########################################
========================================
========================================
########################################
.......................................#
########################################
"""


func test_speeding_needs_a_witness() -> void:
	var setup: Dictionary = await _setup()
	var scooter: ArcadeVehicle = setup["scooter"]
	var grid: LevelGrid = setup["grid"]
	var offences: Array[StringName] = _listen()
	_place(scooter, grid, Vector2i(1, 1), Vector3.RIGHT)
	await _ride(scooter, 1.0, 60 * 4)
	expect(not offences.has(&"speeding"), "speeding with nobody around should go unnoticed")
	# Now with a nonna watching the alley.
	_spawn_nonna(grid.cell_to_world(Vector2i(8, 1)) + Vector3(0, 0, 1.2))
	_place(scooter, grid, Vector2i(1, 1), Vector3.RIGHT)
	await _ride(scooter, 1.0, 60 * 4)
	note("offences seen: %s" % [offences])
	expect(offences.has(&"speeding"), "speeding past a nonna should be reported")


func test_wrong_way_and_red_light() -> void:
	var setup: Dictionary = await _setup()
	var scooter: ArcadeVehicle = setup["scooter"]
	var grid: LevelGrid = setup["grid"]
	var offences: Array[StringName] = _listen()
	_spawn_nonna(grid.cell_to_world(Vector2i(24, 6)) + Vector3(0, 0, 1.2))
	_place(scooter, grid, Vector2i(28, 6), Vector3.LEFT)
	await _ride(scooter, 0.6, 60 * 3)
	expect(offences.has(&"wrong_way"), "riding west down an eastbound one-way should be reported")
	var light := (setup["level"] as Node).find_child("TrafficLight0", true, false) as TrafficLight
	light.green_time = 30.0
	light._time = light.green_time + light.yellow_time + light.all_red_time  # Z green: X red
	_spawn_nonna(grid.cell_to_world(Vector2i(16, 4)) + Vector3(0, 0, 1.5))
	_place(scooter, grid, Vector2i(15, 3), Vector3.RIGHT)
	await _ride(scooter, 1.0, 60 * 3)
	note("offences seen: %s" % [offences])
	expect(offences.has(&"red_light"), "crossing the junction on red should be reported")


func test_speed_camera_fines() -> void:
	var setup: Dictionary = await _setup()
	var scooter: ArcadeVehicle = setup["scooter"]
	var grid: LevelGrid = setup["grid"]
	var fines: Array[int] = []
	var on_fine := func(fine: int, _at: Vector3) -> void: fines.append(fine)
	Events.speed_camera_fined.connect(on_fine)
	_place(scooter, grid, Vector2i(26, 3), Vector3.RIGHT)
	await _ride(scooter, 1.0, 60 * 3)
	Events.speed_camera_fined.disconnect(on_fine)
	note("camera fines: %s" % [fines])
	expect(fines.size() == 1, "one pass past the camera should be one fine")


func test_heat_cools_down_out_of_sight() -> void:
	var wanted := WantedSystem.new()
	wanted.cool_down_delay = 1.0
	wanted.cool_down_rate = 1.0
	add_node(wanted)
	wanted.add_heat(2.5)
	expect(wanted.get_stars() == 3, "2.5 heat should show 3 stars")
	await wait_physics_frames(30)
	expect(wanted.get_stars() == 3, "no cooling before the delay")
	await wait_physics_frames(60 * 3)
	note("heat after 3.5 s unseen: %.2f" % wanted.heat)
	expect(wanted.get_stars() == 0, "heat should cool off when no police sees you")


func test_police_witness_doubles_heat() -> void:
	var setup: Dictionary = await _setup()
	var monitor: LawMonitor = setup["monitor"]
	var cop := Node3D.new()
	cop.add_to_group(Groups.POLICE)
	add_node(cop)
	cop.global_position = (setup["scooter"] as Node3D).global_position + Vector3(5, 0, 0)
	var heats: Array[float] = []
	var on_violation := func(_kind: StringName, _at: Vector3, heat: float) -> void: heats.append(heat)
	Events.violation_committed.connect(on_violation)
	Events.chaos_caused.emit(10, (setup["scooter"] as Node3D).global_position, "test")
	Events.violation_committed.disconnect(on_violation)
	expect(heats.size() == 1 and is_equal_approx(heats[0], 10 * monitor.heat_per_chaos * monitor.police_witness_multiplier),
		"mayhem seen by police should give doubled heat, got %s" % [heats])


var _offences: Array[StringName] = []


func _listen() -> Array[StringName]:
	_offences.clear()
	Events.violation_committed.connect(func(kind: StringName, _at: Vector3, _heat: float) -> void: _offences.append(kind))
	return _offences


func cleanup() -> void:
	for connection: Dictionary in Events.violation_committed.get_connections():
		Events.violation_committed.disconnect(connection["callable"])
	await super()


func _setup() -> Dictionary:
	var level: Node3D = GreyboxMapBuilder.new().build(LAW_MAP, "law")
	add_node(level)
	await wait_physics_frames(2)
	var grid: LevelGrid = LevelGridNode.find_grid(tree)
	var scooter := (load(SCOOTER) as PackedScene).instantiate() as ArcadeVehicle
	scooter.position = grid.cell_to_world(Vector2i(1, 1)) + Vector3.UP * 0.3
	scooter.add_to_group(Groups.PLAYER)
	add_node(scooter)
	var monitor := LawMonitor.new()
	monitor.vehicle = scooter
	monitor.grid = grid
	add_node(monitor)
	await wait_physics_frames(20)
	return {"level": level, "grid": grid, "scooter": scooter, "monitor": monitor}


func _place(scooter: ArcadeVehicle, grid: LevelGrid, cell: Vector2i, facing: Vector3) -> void:
	scooter.intent.clear()
	scooter.teleport(Transform3D(Basis.looking_at(facing), grid.cell_to_world(cell) + Vector3.UP * 0.3))


func _ride(scooter: ArcadeVehicle, throttle: float, frames: int) -> void:
	await wait_physics_frames(10)
	scooter.intent.throttle = throttle
	await wait_physics_frames(frames)
	scooter.intent.clear()


func _spawn_nonna(at: Vector3) -> void:
	var nonna := (load(PEDESTRIAN) as PackedScene).instantiate() as Pedestrian
	nonna.profile = load(NONNA) as PedestrianProfile
	nonna.position = at
	add_node(nonna)
