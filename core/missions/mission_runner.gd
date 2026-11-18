class_name MissionRunner
extends Node
## Runs one delivery at a time:
##   start_mission() -> marker at pickup -> player stops there (cargo loaded,
##   timer starts) -> marker at dropoff -> player stops there -> result.
## Locations come from MissionLocation nodes in the tree. Timing and pay
## rules are exports so each mini-game can tune them.

signal mission_started(mission: MissionData)
signal cargo_picked_up(mission: MissionData)
## The place the player should head to now changed.
signal objective_changed(target: Vector3, label: String)
## The delivery timer ran out (the mission continues, but pays less).
signal became_late(mission: MissionData)
signal mission_finished(result: DeliveryResult)

enum State { IDLE, TO_PICKUP, DELIVERING }

const KMH_PER_MS: float = 3.6

@export var marker_scene: PackedScene = preload("res://core/missions/objective_marker.tscn")
@export var cargo_monitor: CargoMonitor
@export var pickup_color: Color = Color(0.35, 1.0, 0.5)
@export var dropoff_color: Color = Color(1.0, 0.6, 0.2)
@export var pickup_prompt: String = "Stop here to pick up the order"
@export var dropoff_prompt: String = "Stop here to deliver"

@export_group("Automatic Time Limit")
## Used when a mission's time_limit is 0: straight-line distance at this
## average speed...
@export_range(1.0, 200.0, 1.0, "suffix:km/h") var reference_speed_kmh: float = 28.0
## ...plus this many seconds of slack...
@export_range(0.0, 300.0, 1.0, "suffix:s") var time_bonus: float = 12.0
## ...but never less than this.
@export_range(0.0, 300.0, 1.0, "suffix:s") var min_time_limit: float = 25.0

@export_group("Pay Rules")
## Late deliveries pay this share of the base payout and no tip.
@export_range(0.0, 1.0, 0.05) var late_payout_multiplier: float = 0.5
## Delivering within this share of the time limit earns the full time tip;
## it then falls linearly to 0 at the limit.
@export_range(0.0, 1.0, 0.05) var full_tip_time_ratio: float = 0.5

var state: State = State.IDLE
var current_mission: MissionData
var time_limit: float = 0.0
var elapsed: float = 0.0
var is_late: bool = false

var _marker: ObjectiveMarker
var _pickup: MissionLocation
var _dropoff: MissionLocation


func _ready() -> void:
	if cargo_monitor != null:
		cargo_monitor.ruined.connect(_on_cargo_ruined)


## Starts a mission. Returns false (and logs an error) if its locations are
## missing from the level.
func start_mission(mission: MissionData) -> bool:
	if state != State.IDLE:
		abandon()
	_pickup = MissionLocation.find(get_tree(), mission.pickup_location_id)
	_dropoff = MissionLocation.find(get_tree(), mission.dropoff_location_id)
	if _pickup == null or _dropoff == null:
		push_error("Mission %s: missing location %s" % [mission.id,
			mission.pickup_location_id if _pickup == null else mission.dropoff_location_id])
		return false
	current_mission = mission
	state = State.TO_PICKUP
	elapsed = 0.0
	is_late = false
	time_limit = compute_time_limit(mission, _pickup.global_position, _dropoff.global_position)
	_place_marker(_pickup, pickup_color, "PICKUP\n%s" % _pickup.display_name, pickup_prompt, _on_pickup_reached)
	mission_started.emit(mission)
	return true


## Stops the current mission without pay.
func abandon() -> void:
	if state == State.IDLE:
		return
	_finish(DeliveryResult.Outcome.ABANDONED)


func get_time_left() -> float:
	return time_limit - elapsed


func get_objective_position() -> Vector3:
	match state:
		State.TO_PICKUP:
			return _pickup.global_position
		State.DELIVERING:
			return _dropoff.global_position
	return Vector3.ZERO


func get_objective_name() -> String:
	match state:
		State.TO_PICKUP:
			return _pickup.display_name
		State.DELIVERING:
			return _dropoff.display_name
	return ""


func compute_time_limit(mission: MissionData, from: Vector3, to: Vector3) -> float:
	if mission.time_limit > 0.0:
		return mission.time_limit
	var travel: float = from.distance_to(to) / (reference_speed_kmh / KMH_PER_MS)
	var multiplier: float = mission.cargo.time_multiplier if mission.cargo != null else 1.0
	return maxf((travel + time_bonus) * multiplier, min_time_limit)


## Pure scoring rules, used at the end of every delivery (and by tests).
func evaluate(mission: MissionData, time_taken: float, limit: float, condition: float,
		outcome_hint: DeliveryResult.Outcome = DeliveryResult.Outcome.DELIVERED) -> DeliveryResult:
	var result := DeliveryResult.new()
	result.mission = mission
	result.time_taken = time_taken
	result.time_limit = limit
	result.condition = clampf(condition, 0.0, 1.0)
	if outcome_hint == DeliveryResult.Outcome.ABANDONED:
		result.outcome = DeliveryResult.Outcome.ABANDONED
	elif result.condition <= 0.0:
		result.outcome = DeliveryResult.Outcome.RUINED
	elif time_taken > limit:
		result.outcome = DeliveryResult.Outcome.LATE
		result.payout = roundi(mission.base_payout * late_payout_multiplier)
		result.stars = 1
	else:
		result.outcome = DeliveryResult.Outcome.DELIVERED
		var tip_window: float = maxf(limit * (1.0 - full_tip_time_ratio), 0.001)
		var time_score: float = clampf((limit - time_taken) / tip_window, 0.0, 1.0)
		result.payout = mission.base_payout
		result.tip = roundi(mission.max_tip * time_score * result.condition)
		result.stars = clampi(1 + roundi(4.0 * (time_score + result.condition) * 0.5), 1, 5)
	return result


func _physics_process(delta: float) -> void:
	if state != State.DELIVERING:
		return
	elapsed += delta
	if not is_late and elapsed > time_limit:
		is_late = true
		became_late.emit(current_mission)


func _on_pickup_reached(_body: Node3D) -> void:
	if state != State.TO_PICKUP:
		return
	state = State.DELIVERING
	elapsed = 0.0
	if cargo_monitor != null:
		var fragility: float = current_mission.cargo.fragility if current_mission.cargo != null else 1.0
		cargo_monitor.start(fragility)
	_place_marker.call_deferred(_dropoff, dropoff_color, "DELIVER\n%s" % _dropoff.display_name,
		dropoff_prompt, _on_dropoff_reached)
	cargo_picked_up.emit(current_mission)


func _on_dropoff_reached(_body: Node3D) -> void:
	if state != State.DELIVERING:
		return
	_finish(DeliveryResult.Outcome.DELIVERED)


func _on_cargo_ruined() -> void:
	if state == State.DELIVERING:
		_finish(DeliveryResult.Outcome.RUINED)


func _finish(hint: DeliveryResult.Outcome) -> void:
	var condition: float = cargo_monitor.condition if cargo_monitor != null and state == State.DELIVERING else 1.0
	if hint == DeliveryResult.Outcome.RUINED:
		condition = 0.0
	var result: DeliveryResult = evaluate(current_mission, elapsed, time_limit, condition, hint)
	if cargo_monitor != null:
		cargo_monitor.stop()
	_clear_marker()
	state = State.IDLE
	mission_finished.emit(result)


func _place_marker(location: MissionLocation, color: Color, text: String, prompt: String,
		on_reached: Callable) -> void:
	_clear_marker()
	_marker = marker_scene.instantiate() as ObjectiveMarker
	_marker.color = color
	_marker.label_text = text
	add_child(_marker)
	_marker.global_transform = location.global_transform
	_marker.interactable.prompt = prompt
	_marker.reached.connect(on_reached)
	objective_changed.emit(location.global_position, location.display_name)


func _clear_marker() -> void:
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
	_marker = null
