class_name TrafficSpawner
extends Node3D
## Keeps a few AI cars wandering the level's drivable streets. Each car gets
## an AiVehicleController and a new random destination whenever it arrives
## or gives up.

@export var car_scenes: Array[PackedScene] = []
@export var network: LevelGrid.Network = LevelGrid.Network.CARS
@export_range(0, 50, 1) var car_count: int = 4
## Cars never spawn closer than this to the player.
@export_range(0.0, 200.0, 1.0, "suffix:m") var min_spawn_distance: float = 30.0
## Destinations at least this far away, so cars actually travel.
@export_range(0.0, 200.0, 1.0, "suffix:m") var min_trip_distance: float = 40.0
@export_range(0.0, 3.0, 0.05, "suffix:m") var spawn_lift: float = 0.4
## Random paint colours.
@export var colors: Array[Color] = [
	Color(0.85, 0.2, 0.2), Color(0.95, 0.85, 0.3), Color(0.3, 0.55, 0.9),
	Color(0.95, 0.95, 0.92), Color(0.35, 0.7, 0.45), Color(0.15, 0.15, 0.18),
]
## 0 = random every run.
@export var random_seed: int = 0

var cars: Array[ArcadeVehicle] = []

var _grid: LevelGrid
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed if random_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0)
	_grid = LevelGridNode.find_grid(get_tree())
	if _grid == null or car_scenes.is_empty():
		push_warning("TrafficSpawner: no LevelGrid or no car scenes; no traffic")
		return
	for i: int in car_count:
		_spawn_car()


func _spawn_car() -> void:
	var cell: Vector2i = _pick_cell(_player_position(), min_spawn_distance)
	if cell.x < 0:
		return
	var car := car_scenes[_rng.randi() % car_scenes.size()].instantiate() as ArcadeVehicle
	car.name = "TrafficCar%d" % cars.size()
	car.add_to_group(Groups.TRAFFIC)
	var paint := car.get_node_or_null(^"Paint") as VehiclePaint
	if paint != null and not colors.is_empty():
		paint.color = colors[_rng.randi() % colors.size()]
	add_child(car)
	var spawn_at: Vector3 = _grid.cell_to_world(cell) + Vector3.UP * spawn_lift
	car.teleport(Transform3D(_street_heading(cell), spawn_at))
	var driver := AiVehicleController.new()
	driver.name = "Driver"
	driver.vehicle = car
	driver.grid = _grid
	driver.network = network
	car.add_child(driver)
	driver.destination_reached.connect(_new_trip.bind(driver))
	driver.gave_up.connect(_new_trip.bind(driver))
	cars.append(car)
	_new_trip.call_deferred(driver)


func _new_trip(driver: AiVehicleController) -> void:
	for attempt: int in 10:
		var cell: Vector2i = _pick_cell(driver.vehicle.global_position, min_trip_distance)
		if cell.x >= 0 and driver.drive_to(_grid.cell_to_world(cell)):
			return


func _pick_cell(away_from: Vector3, min_distance: float) -> Vector2i:
	var fallback := Vector2i(-1, -1)
	for attempt: int in 40:
		var cell: Vector2i = _grid.random_cell(_rng, network)
		if cell.x < 0:
			return fallback
		# Never a dead end: cars can't turn around in a 4 m street.
		if _connected_neighbours(cell) < 2:
			continue
		fallback = cell
		var at: Vector3 = _grid.cell_to_world(cell)
		if Vector2(at.x - away_from.x, at.z - away_from.z).length() >= min_distance:
			return cell
	return fallback


func _connected_neighbours(cell: Vector2i) -> int:
	return _grid.connected_neighbours(cell, network).size()


## Faces along the street (towards a drivable neighbour), not into a wall.
func _street_heading(cell: Vector2i) -> Basis:
	var options: Array[Vector2i] = _grid.connected_neighbours(cell, network)
	if options.is_empty():
		return Basis.IDENTITY
	var dir: Vector2i = options[_rng.randi() % options.size()] - cell
	return Basis.looking_at(Vector3(dir.x, 0.0, dir.y))


func _player_position() -> Vector3:
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	return player.global_position if player != null else Vector3(INF, 0.0, INF)
