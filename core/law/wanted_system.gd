class_name WantedSystem
extends Node
## Turns witnessed offences into heat (0..max_stars). Heat cools down once no
## police unit has seen the player for a while. Stars = heat rounded up.

signal heat_changed(heat: float, stars: int)

@export var player: Node3D
@export_range(1, 10, 1) var max_stars: int = 5
## Start cooling down after this long unseen by police...
@export_range(0.0, 60.0, 0.5, "suffix:s") var cool_down_delay: float = 6.0
## ...losing this much heat per second.
@export_range(0.0, 5.0, 0.05) var cool_down_rate: float = 0.3
@export_range(1.0, 200.0, 1.0, "suffix:m") var police_sight: float = 45.0
@export_flags_3d_physics var sight_blockers: int = 1

var heat: float = 0.0
var seen_by_police: bool = false

var _unseen_time: float = 0.0
var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	Events.violation_committed.connect(func(_kind: StringName, _at: Vector3, amount: float) -> void: add_heat(amount))


func get_stars() -> int:
	return clampi(ceili(heat - 0.01), 0, max_stars)


func add_heat(amount: float) -> void:
	set_heat(heat + amount)
	_unseen_time = 0.0


func set_heat(value: float) -> void:
	var before: int = get_stars()
	var old_heat: float = heat
	heat = clampf(value, 0.0, float(max_stars))
	if not is_equal_approx(old_heat, heat) or before != get_stars():
		heat_changed.emit(heat, get_stars())


func clear() -> void:
	set_heat(0.0)


func _physics_process(delta: float) -> void:
	seen_by_police = _police_can_see()
	if heat <= 0.0:
		return
	if seen_by_police:
		_unseen_time = 0.0
		return
	_unseen_time += delta
	if _unseen_time >= cool_down_delay:
		set_heat(heat - cool_down_rate * delta)


func _police_can_see() -> bool:
	if player == null:
		return false
	for node: Node in get_tree().get_nodes_in_group(Groups.POLICE):
		var unit := node as Node3D
		if unit == null or unit.global_position.distance_to(player.global_position) > police_sight:
			continue
		_query.from = unit.global_position + Vector3.UP * 1.4
		_query.to = player.global_position + Vector3.UP * 1.0
		_query.collision_mask = sight_blockers
		if unit.get_world_3d().direct_space_state.intersect_ray(_query).is_empty():
			return true
	return false
