class_name PoliceDispatcher
extends Node3D
## Sends police after the player: one unit per wanted star (up to
## max_units; from scooter_from_stars on, one is a scooter that can follow
## into alleys). Units chase with AiVehicleController (re-planning towards
## the player), ignore red lights and run a siren. Staying slow next to a
## unit gets you busted (fine, heat cleared); letting the heat cool off
## means you escaped. Either way the units drive off and disappear.

signal player_busted(fine: int)
signal player_escaped

@export var wanted: WantedSystem
@export var player: ArcadeVehicle
@export var car_scene: PackedScene = preload("res://core/law/police_car.tscn")
@export var scooter_scene: PackedScene = preload("res://core/law/police_scooter.tscn")
@export_range(1, 10, 1) var max_units: int = 3
@export_range(1, 10, 1) var scooter_from_stars: int = 3
## Delay before the first unit arrives after you become wanted.
@export_range(0.0, 30.0, 0.5, "suffix:s") var dispatch_delay: float = 3.0
@export_range(5.0, 300.0, 1.0, "suffix:m") var min_spawn_distance: float = 50.0
@export_range(5.0, 300.0, 1.0, "suffix:m") var max_spawn_distance: float = 85.0
## How often units re-plan their route towards the player.
@export_range(0.1, 10.0, 0.1, "suffix:s") var repath_interval: float = 1.0
@export_range(1.0, 200.0, 1.0, "suffix:km/h") var car_chase_speed_kmh: float = 70.0
@export_range(1.0, 200.0, 1.0, "suffix:km/h") var scooter_chase_speed_kmh: float = 55.0

@export_group("Busted")
@export_range(1.0, 30.0, 0.5, "suffix:m") var bust_distance: float = 7.0
@export_range(0.0, 50.0, 1.0, "suffix:km/h") var bust_speed_kmh: float = 10.0
@export_range(0.1, 20.0, 0.1, "suffix:s") var bust_time: float = 2.5
@export_range(0, 1000, 1) var fine_per_star: int = 10
## Units vanish once this far away after the chase is over.
@export_range(10.0, 500.0, 5.0, "suffix:m") var despawn_distance: float = 60.0

const KMH_PER_MS: float = 3.6

var units: Array[ArcadeVehicle] = []
## 0..1 towards being busted (for the HUD).
var bust_progress: float = 0.0

var _grid: LevelGrid
var _rng := RandomNumberGenerator.new()
var _wanted_time: float = 0.0
var _repath_left: float = 0.0
var _retreating: bool = false
var _was_wanted: bool = false


func _ready() -> void:
	_rng.seed = int(Time.get_unix_time_from_system() * 1000.0)
	_grid = LevelGridNode.find_grid(get_tree())


func _physics_process(delta: float) -> void:
	if wanted == null or player == null or _grid == null:
		return
	_prune()
	var stars: int = wanted.get_stars()
	if stars > 0:
		_was_wanted = true
		_retreating = false
		_wanted_time += delta
		if _wanted_time >= dispatch_delay and units.size() < mini(stars, max_units):
			_spawn_unit(stars >= scooter_from_stars and not _has_scooter())
		_repath_left -= delta
		if _repath_left <= 0.0:
			_repath_left = repath_interval
			_chase()
		_check_bust(delta, stars)
	else:
		_wanted_time = 0.0
		bust_progress = 0.0
		if _was_wanted:
			_was_wanted = false
			if not _retreating:
				player_escaped.emit()
				Events.police_escaped.emit()
			_retreat()
		_despawn_far_units()


func _spawn_unit(as_scooter: bool) -> void:
	var network: LevelGrid.Network = LevelGrid.Network.SCOOTERS if as_scooter else LevelGrid.Network.CARS
	var cell: Vector2i = _pick_spawn_cell(network)
	if cell.x < 0:
		return
	var unit := (scooter_scene if as_scooter else car_scene).instantiate() as ArcadeVehicle
	unit.name = "Police%s%d" % ["Scooter" if as_scooter else "Car", units.size()]
	unit.add_to_group(Groups.POLICE)
	unit.add_to_group(Groups.TRAFFIC)
	unit.set_meta(&"police_scooter", as_scooter)
	add_child(unit)
	var at: Vector3 = _grid.cell_to_world(cell) + Vector3.UP * 0.4
	var facing: Vector3 = (player.global_position - at) * Vector3(1, 0, 1)
	var start := Transform3D(Basis.looking_at(facing.normalized() if facing.length() > 0.1 else Vector3.FORWARD), at)
	unit.global_transform = start
	unit.teleport(start)
	var driver := AiVehicleController.new()
	driver.name = "Driver"
	driver.vehicle = unit
	driver.grid = _grid
	driver.network = network
	driver.obey_lights = false
	driver.lane_offset = 0.0
	driver.cruise_speed_kmh = scooter_chase_speed_kmh if as_scooter else car_chase_speed_kmh
	driver.honk_delay = 0.4
	unit.add_child(driver)
	units.append(unit)
	_repath_left = 0.0


func _chase() -> void:
	for unit: ArcadeVehicle in units:
		var driver := unit.get_node_or_null(^"Driver") as AiVehicleController
		if driver != null:
			driver.drive_to(player.global_position)


func _check_bust(delta: float, stars: int) -> void:
	var slow: bool = player.linear_velocity.length() * KMH_PER_MS < bust_speed_kmh
	var close: bool = false
	for unit: ArcadeVehicle in units:
		if unit.global_position.distance_to(player.global_position) < bust_distance:
			close = true
			break
	bust_progress = clampf(bust_progress + (delta if slow and close else -delta) / bust_time, 0.0, 1.0)
	if bust_progress >= 1.0:
		var fine: int = fine_per_star * stars
		bust_progress = 0.0
		_retreating = true
		wanted.clear()
		player_busted.emit(fine)
		Events.busted.emit(fine)
		_retreat()


func _retreat() -> void:
	for unit: ArcadeVehicle in units:
		var lights := unit.find_child("Lights", true, false) as PoliceLights
		if lights != null:
			lights.siren_on = false
		var driver := unit.get_node_or_null(^"Driver") as AiVehicleController
		if driver == null:
			continue
		var away: Vector2i = _pick_spawn_cell(driver.network)
		if away.x >= 0:
			driver.drive_to(_grid.cell_to_world(away))
		else:
			driver.stop()


func _despawn_far_units() -> void:
	for unit: ArcadeVehicle in units.duplicate():
		if unit.global_position.distance_to(player.global_position) > despawn_distance:
			units.erase(unit)
			unit.queue_free()


func _prune() -> void:
	for unit: ArcadeVehicle in units.duplicate():
		if not is_instance_valid(unit):
			units.erase(unit)


func _has_scooter() -> bool:
	for unit: ArcadeVehicle in units:
		if unit.get_meta(&"police_scooter", false):
			return true
	return false


func _pick_spawn_cell(network: LevelGrid.Network) -> Vector2i:
	var fallback := Vector2i(-1, -1)
	for attempt: int in 40:
		var cell: Vector2i = _grid.random_cell(_rng, network)
		if cell.x < 0:
			return fallback
		var distance: float = _grid.cell_to_world(cell).distance_to(player.global_position)
		if distance >= min_spawn_distance:
			fallback = cell
			if distance <= max_spawn_distance:
				return cell
	return fallback
