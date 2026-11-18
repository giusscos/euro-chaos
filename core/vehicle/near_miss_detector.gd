class_name NearMissDetector
extends Node
## Notices when the player's vehicle whizzes past a pedestrian or a car at
## speed without touching it, and reports Events.near_miss.

@export var vehicle: ArcadeVehicle
@export_range(0.0, 200.0, 1.0, "suffix:km/h") var min_speed_kmh: float = 30.0
## Pedestrians closer than this (but not hit) count...
@export_range(0.5, 10.0, 0.1, "suffix:m") var pedestrian_distance: float = 2.2
## ...cars closer than this (centre to centre) and further than car_contact.
@export_range(0.5, 10.0, 0.1, "suffix:m") var car_distance: float = 3.2
@export_range(0.5, 10.0, 0.1, "suffix:m") var car_contact: float = 1.9
## The same thing can't be near-missed again for this long.
@export_range(0.0, 30.0, 0.5, "suffix:s") var cooldown: float = 4.0

const KMH_PER_MS: float = 3.6

## Things currently close: instance id -> closest distance so far.
var _close: Dictionary = {}
var _cooldowns: Dictionary = {}


func _physics_process(delta: float) -> void:
	if vehicle == null:
		return
	for id: Variant in _cooldowns.keys():
		_cooldowns[id] = float(_cooldowns[id]) - delta
		if float(_cooldowns[id]) <= 0.0:
			_cooldowns.erase(id)
	var fast: bool = vehicle.linear_velocity.length() * KMH_PER_MS >= min_speed_kmh
	var here: Vector3 = vehicle.global_position
	var seen: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(Groups.PEDESTRIANS):
		_track(node as Node3D, here, pedestrian_distance, 0.0, fast, seen)
	for node: Node in get_tree().get_nodes_in_group(Groups.TRAFFIC):
		if node != vehicle:
			_track(node as Node3D, here, car_distance, car_contact, fast, seen)
	# Whatever was close and isn't any more: judge it.
	for id: Variant in _close.keys():
		if seen.has(id):
			continue
		var closest: float = _close[id]
		_close.erase(id)
		var thing := instance_from_id(int(id)) as Node3D
		if thing == null or _cooldowns.has(id) or closest < 0.0:
			continue
		_cooldowns[id] = cooldown
		Events.near_miss.emit(thing, closest)


func _track(thing: Node3D, here: Vector3, radius: float, contact: float, fast: bool, seen: Dictionary) -> void:
	if thing == null:
		return
	var distance: float = Vector2(thing.global_position.x - here.x, thing.global_position.z - here.z).length()
	if distance > radius:
		return
	var id: int = thing.get_instance_id()
	seen[id] = true
	var pedestrian := thing as Pedestrian
	var touched: bool = distance < contact or (pedestrian != null and pedestrian.is_down())
	if not fast or touched:
		_close[id] = -1.0  # Too slow or a hit: this pass doesn't count.
	elif not _close.has(id):
		_close[id] = distance
	elif float(_close[id]) >= 0.0:
		_close[id] = minf(float(_close[id]), distance)
