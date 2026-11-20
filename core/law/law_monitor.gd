class_name LawMonitor
extends Node
## Watches the player's vehicle for offences: speeding (limit per kind of
## street), going the wrong way down a one-way street, running a red light,
## and mayhem (chaos). An offence only counts if someone sees it: a police
## unit or a pedestrian with line of sight. Speed cameras fine directly.

@export var vehicle: ArcadeVehicle
@export var grid: LevelGrid

@export_group("Limits")
## Speed limits per LevelGrid.Kind (km/h). Missing kinds: no limit.
@export var speed_limits: Dictionary[int, float] = {
	LevelGrid.Kind.ROAD: 50.0,
	LevelGrid.Kind.STREET: 20.0,
	LevelGrid.Kind.PLATEAU: 20.0,
	LevelGrid.Kind.RAMP: 25.0,
	LevelGrid.Kind.PIAZZA: 10.0,
}
@export_range(0.0, 30.0, 1.0, "suffix:km/h") var speed_tolerance: float = 6.0
## Must be over the limit this long to count as speeding.
@export_range(0.0, 5.0, 0.1, "suffix:s") var speeding_time: float = 1.0
## Moving against a one-way faster than this counts.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var wrong_way_speed: float = 2.0
## Entering a junction on red faster than this counts.
@export_range(0.0, 50.0, 1.0, "suffix:km/h") var red_light_speed: float = 8.0
## Same offence again within this time is ignored.
@export_range(0.0, 30.0, 0.5, "suffix:s") var repeat_cooldown: float = 4.0

@export_group("Heat")
@export var heat_per_kind: Dictionary[StringName, float] = {
	&"speeding": 0.3,
	&"wrong_way": 0.5,
	&"red_light": 0.8,
}
## Mayhem heat per chaos point (a knocked-over pedestrian is 15 points).
@export_range(0.0, 1.0, 0.005) var heat_per_chaos: float = 0.04
## Police seeing it themselves multiplies the heat.
@export_range(1.0, 5.0, 0.1) var police_witness_multiplier: float = 2.0

@export_group("Witnesses")
@export_range(1.0, 100.0, 1.0, "suffix:m") var pedestrian_sight: float = 22.0
@export_range(1.0, 200.0, 1.0, "suffix:m") var police_sight: float = 45.0
@export_flags_3d_physics var sight_blockers: int = 1

const KMH_PER_MS: float = 3.6

var _over_limit_time: float = 0.0
var _cooldowns: Dictionary = {}
var _last_cell := Vector2i(-1, -1)
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	if grid == null:
		grid = LevelGridNode.find_grid(get_tree())
	Events.chaos_caused.connect(_on_chaos)


func _physics_process(delta: float) -> void:
	if vehicle == null or grid == null:
		return
	for key: Variant in _cooldowns.keys():
		_cooldowns[key] = float(_cooldowns[key]) - delta
		if float(_cooldowns[key]) <= 0.0:
			_cooldowns.erase(key)
	var velocity: Vector3 = vehicle.linear_velocity
	var speed_kmh: float = velocity.length() * KMH_PER_MS
	var cell: Vector2i = grid.world_to_cell(vehicle.global_position)

	var limit: float = speed_limits.get(int(grid.get_kind(cell)), INF)
	if speed_kmh > limit + speed_tolerance:
		_over_limit_time += delta
		if _over_limit_time >= speeding_time:
			_offence(&"speeding", heat_per_kind.get(&"speeding", 0.0))
	else:
		_over_limit_time = 0.0

	var oneway: Vector2i = grid.get_oneway(cell)
	if oneway != Vector2i.ZERO and velocity.dot(Vector3(oneway.x, 0.0, oneway.y)) < -wrong_way_speed:
		_offence(&"wrong_way", heat_per_kind.get(&"wrong_way", 0.0))

	var light_index: int = grid.get_light(cell)
	if light_index >= 0 and grid.get_light(_last_cell) != light_index and speed_kmh > red_light_speed:
		var light: TrafficLight = TrafficLight.find(get_tree(), light_index)
		if light != null and light.is_red_for(velocity):
			_offence(&"red_light", heat_per_kind.get(&"red_light", 0.0))
	_last_cell = cell

	for node: Node in get_tree().get_nodes_in_group(Groups.SPEED_CAMERAS):
		var camera := node as SpeedCamera
		if camera != null and camera.check(vehicle, speed_kmh):
			Events.speed_camera_fined.emit(camera.fine, camera.global_position)


func _on_chaos(amount: int, at: Vector3, _label: String) -> void:
	_report(&"mayhem", amount * heat_per_chaos, at)


## Ongoing offences are reported as soon as someone sees them; the repeat
## cooldown only starts once one has been witnessed.
func _offence(kind: StringName, heat: float) -> void:
	if _cooldowns.has(kind):
		return
	if _report(kind, heat, vehicle.global_position):
		_cooldowns[kind] = repeat_cooldown


func _report(kind: StringName, heat: float, at: Vector3) -> bool:
	var witness: int = witness_at(at)
	if witness == 0:
		return false
	Events.violation_committed.emit(kind, at, heat * (police_witness_multiplier if witness == 2 else 1.0))
	return true


## 0 = nobody saw `at`, 1 = a pedestrian, 2 = the police.
func witness_at(at: Vector3) -> int:
	for node: Node in get_tree().get_nodes_in_group(Groups.POLICE):
		if _can_see(node as Node3D, at, police_sight):
			return 2
	for node: Node in get_tree().get_nodes_in_group(Groups.PEDESTRIANS):
		var pedestrian := node as Pedestrian
		if pedestrian != null and not pedestrian.is_down() and _can_see(pedestrian, at, pedestrian_sight):
			return 1
	return 0


func _can_see(watcher: Node3D, at: Vector3, sight: float) -> bool:
	if watcher == null or watcher.global_position.distance_to(at) > sight:
		return false
	_query.from = watcher.global_position + Vector3.UP * 1.6
	_query.to = at + Vector3.UP * 1.0
	_query.collision_mask = sight_blockers
	return watcher.get_world_3d().direct_space_state.intersect_ray(_query).is_empty()
