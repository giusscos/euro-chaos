extends TestCase
## AI drivers: route through the real village, stop for obstacles.

const VILLAGE_SCENE: String = "res://minigames/vespa_delivery/levels/village.tscn"
const CAR_SCENE: String = "res://core/vehicle/vehicles/tiny_car.tscn"
const SCOOTER_SCENE: String = "res://core/vehicle/vehicles/scooter.tscn"
const SPAWN_LIFT: float = 0.4
## Coast road (west end) to an upper-town street: alleys, corners and a ramp
## (scooter network: cars aren't allowed up there).
const TRIP_FROM := Vector2i(2, 33)
const TRIP_TO := Vector2i(10, 12)
const TRIP_TIME_LIMIT: int = 60 * 60
const TRAFFIC_CARS: int = 4
const TRAFFIC_TEST_FRAMES: int = 60 * 90
## Lights and long random trips: judge flow by trips overall and distance per car.
const TRAFFIC_MIN_TRIPS: int = 6
const TRAFFIC_MIN_DRIVEN: float = 40.0

const STREET_MAP: String = """
[map]
############################################
S===========================================
============================================
############################################
"""


func test_ai_scooter_rides_to_the_upper_town() -> void:
	var village: Node = (load(VILLAGE_SCENE) as PackedScene).instantiate()
	add_node(village)
	await wait_physics_frames(2)
	var grid: LevelGrid = LevelGridNode.find_grid(tree)
	var car: ArcadeVehicle = _spawn_car(grid.cell_to_world(TRIP_FROM), Vector3.RIGHT, SCOOTER_SCENE)
	var driver: AiVehicleController = _add_driver(car, grid)
	driver.network = LevelGrid.Network.SCOOTERS
	driver.lane_offset = 0.0
	await wait_physics_frames(30)
	var arrived: Array[bool] = [false]
	driver.destination_reached.connect(func() -> void: arrived[0] = true)
	expect(driver.drive_to(grid.cell_to_world(TRIP_TO)), "no route to the upper town")
	var lowest: float = INF
	var min_upright: float = 1.0
	var gave_up: Array[int] = [0]
	driver.gave_up.connect(func() -> void:
		gave_up[0] += 1
		driver.drive_to(grid.cell_to_world(TRIP_TO)))
	var frames: int = 0
	while not arrived[0] and frames < TRIP_TIME_LIMIT:
		await tree.physics_frame
		frames += 1
		lowest = minf(lowest, car.global_position.y)
		min_upright = minf(min_upright, car.global_basis.y.dot(Vector3.UP))
	note("trip: %s in %.1f s, gave up %d times, end %s (cell %s), lowest y %.2f, min upright %.2f" % [
		"arrived" if arrived[0] else "NOT arrived", frames / 60.0, gave_up[0], car.global_position,
		grid.world_to_cell(car.global_position), lowest, min_upright])
	expect(arrived[0], "AI scooter never reached the upper town")
	expect(gave_up[0] == 0, "AI scooter got stuck %d times" % gave_up[0])
	expect(lowest > -0.5, "AI scooter fell somewhere")
	expect(min_upright > 0.7, "AI scooter fell over")


func test_ai_car_stops_for_obstacle_and_honks() -> void:
	var builder := GreyboxMapBuilder.new()
	var street: Node3D = builder.build(STREET_MAP, "street")
	add_node(street)
	await wait_physics_frames(2)
	var grid: LevelGrid = LevelGridNode.find_grid(tree)
	var scooter := (load(SCOOTER_SCENE) as PackedScene).instantiate() as ArcadeVehicle
	scooter.position = grid.cell_to_world(Vector2i(14, 1)) + Vector3(0.0, SPAWN_LIFT, 0.8)
	scooter.add_to_group(Groups.PLAYER)
	add_node(scooter)
	var car: ArcadeVehicle = _spawn_car(grid.cell_to_world(Vector2i(3, 1)), Vector3.RIGHT)
	var driver: AiVehicleController = _add_driver(car, grid)
	await wait_physics_frames(30)
	expect(driver.drive_to(grid.cell_to_world(Vector2i(42, 1))), "no route along the road")
	var honked: bool = false
	var closest: float = INF
	for i: int in 60 * 10:
		await tree.physics_frame
		honked = honked or car.intent.horn
		closest = minf(closest, car.global_position.distance_to(scooter.global_position))
	note("closest approach %.2f m, honked %s, blocked %s" % [closest, honked, driver.is_blocked])
	expect(closest > 2.2, "AI car hit the scooter (closest %.2f m)" % closest)
	expect(honked, "AI car should honk when blocked")


func test_traffic_keeps_moving_in_the_village() -> void:
	var village: Node = (load(VILLAGE_SCENE) as PackedScene).instantiate()
	add_node(village)
	await wait_physics_frames(2)
	var spawner := TrafficSpawner.new()
	spawner.car_scenes = [load(CAR_SCENE) as PackedScene]
	spawner.car_count = TRAFFIC_CARS
	spawner.random_seed = 3
	add_node(spawner)
	await wait_physics_frames(5)
	var arrivals: Array[int] = [0]
	var give_ups: Array[int] = [0]
	var trips_per_car: Dictionary = {}
	for car: ArcadeVehicle in spawner.cars:
		var driver := car.get_node(^"Driver") as AiVehicleController
		trips_per_car[car.name] = 0
		driver.destination_reached.connect(func() -> void:
			arrivals[0] += 1
			trips_per_car[car.name] = int(trips_per_car[car.name]) + 1)
		driver.gave_up.connect(func() -> void: give_ups[0] += 1)
	var lowest: float = INF
	var min_upright: float = 1.0
	var driven: Dictionary = {}
	var last_seen: Dictionary = {}
	for car: ArcadeVehicle in spawner.cars:
		driven[car.name] = 0.0
		last_seen[car.name] = car.global_position
	for i: int in TRAFFIC_TEST_FRAMES:
		await tree.physics_frame
		for car: ArcadeVehicle in spawner.cars:
			lowest = minf(lowest, car.global_position.y)
			min_upright = minf(min_upright, car.global_basis.y.dot(Vector3.UP))
			if i % 30 == 0:
				driven[car.name] = float(driven[car.name]) + car.global_position.distance_to(last_seen[car.name])
				last_seen[car.name] = car.global_position
	var driven_text: PackedStringArray = []
	for car_name: String in driven:
		driven_text.append("%s %.0f m" % [car_name, driven[car_name]])
	note("%d cars, %.0f s: %d trips %s, driven %s, %d give-ups, lowest y %.2f, min upright %.2f" % [
		spawner.cars.size(), TRAFFIC_TEST_FRAMES / 60.0, arrivals[0], trips_per_car, ", ".join(driven_text),
		give_ups[0], lowest, min_upright])
	expect(spawner.cars.size() == TRAFFIC_CARS, "spawner made %d cars" % spawner.cars.size())
	expect(arrivals[0] >= TRAFFIC_MIN_TRIPS, "traffic barely moves (%d trips)" % arrivals[0])
	for car_name: String in driven:
		expect(float(driven[car_name]) >= TRAFFIC_MIN_DRIVEN, "%s only drove %.0f m (stuck for good?)" % [
			car_name, driven[car_name]])
	expect(lowest > -0.5, "a car fell off the map")
	expect(min_upright > 0.5, "a car rolled over")


func _spawn_car(at: Vector3, facing: Vector3, scene: String = CAR_SCENE) -> ArcadeVehicle:
	var car := (load(scene) as PackedScene).instantiate() as ArcadeVehicle
	car.transform = Transform3D(Basis.looking_at(facing), at + Vector3.UP * SPAWN_LIFT)
	add_node(car)
	return car


func _add_driver(car: ArcadeVehicle, grid: LevelGrid) -> AiVehicleController:
	var driver := AiVehicleController.new()
	driver.vehicle = car
	driver.grid = grid
	car.add_child(driver)
	return driver
