class_name CargoMonitor
extends Node
## Tracks the condition of the cargo on a vehicle. Every physics tick it
## measures how hard the vehicle's velocity changed (landings, crashes, curbs)
## and damages the cargo above a threshold. Phase 2 replaces this abstract
## meter with real wobbling cargo, keeping the same signals.

signal damaged(amount: float, condition: float)
signal ruined

@export var vehicle: ArcadeVehicle
## Velocity changes gentler than this (m/s²) never hurt the cargo. Hard
## braking is about 13; a 10 cm curb at speed about 50.
@export_range(0.0, 500.0, 1.0, "suffix:m/s²") var impact_threshold: float = 40.0
## Condition lost per m/s² above the threshold, for fragility 1.
@export_range(0.0, 0.01, 0.0001) var damage_per_impact: float = 0.0009

## 1 = perfect, 0 = ruined.
var condition: float = 1.0
var fragility: float = 1.0
var is_active: bool = false

var _last_velocity := Vector3.ZERO
var _last_teleport_serial: int = 0


func start(cargo_fragility: float) -> void:
	condition = 1.0
	fragility = cargo_fragility
	is_active = true
	_resync()


func stop() -> void:
	is_active = false


## Direct damage (e.g. falling into the sea), 0..1 of full condition.
func apply_damage(amount: float) -> void:
	if not is_active or amount <= 0.0:
		return
	var before: float = condition
	condition = maxf(condition - amount, 0.0)
	damaged.emit(before - condition, condition)
	if condition <= 0.0 and before > 0.0:
		ruined.emit()


func _physics_process(delta: float) -> void:
	if not is_active or vehicle == null or delta <= 0.0:
		return
	if vehicle.teleport_serial != _last_teleport_serial:
		# Teleports zero the velocity: not an impact.
		_resync()
		return
	var velocity: Vector3 = vehicle.linear_velocity
	var impact: float = (velocity - _last_velocity).length() / delta
	_last_velocity = velocity
	if impact > impact_threshold:
		apply_damage((impact - impact_threshold) * damage_per_impact * fragility)


func _resync() -> void:
	if vehicle != null:
		_last_velocity = vehicle.linear_velocity
		_last_teleport_serial = vehicle.teleport_serial
