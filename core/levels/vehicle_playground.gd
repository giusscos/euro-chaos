extends Node3D
## Vehicle test level: spawns the player's vehicle on the test level, wires
## controller, camera and overlay, and cycles vehicles with the
## debug_swap_vehicle action (Tab / RB).

@export var vehicle_scenes: Array[PackedScene] = []
@export var spawn_point: Node3D
@export var controller: PlayerVehicleController
@export var camera: ChaseCamera
@export var overlay: DebugOverlay
## Height added when swapping, so the new vehicle doesn't spawn in the ground.
@export_range(0.0, 5.0, 0.1, "suffix:m") var swap_lift: float = 0.5

var vehicle: ArcadeVehicle
var _index: int = 0


func _ready() -> void:
	assert(not vehicle_scenes.is_empty(), "VehiclePlayground needs at least one vehicle scene")
	_spawn(0, spawn_point.global_transform)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.DEBUG_SWAP_VEHICLE):
		var heading := Basis.looking_at(_flat_heading(), Vector3.UP)
		var position_now: Vector3 = vehicle.global_position + Vector3.UP * swap_lift
		_spawn((_index + 1) % vehicle_scenes.size(), Transform3D(heading, position_now))
		get_viewport().set_input_as_handled()


func _spawn(index: int, xform: Transform3D) -> void:
	if vehicle != null:
		remove_child(vehicle)
		vehicle.queue_free()
	_index = index
	vehicle = vehicle_scenes[index].instantiate() as ArcadeVehicle
	add_child(vehicle)
	vehicle.global_transform = xform
	vehicle.reset_physics_interpolation()
	controller.vehicle = vehicle
	controller.respawn_point = spawn_point
	camera.target = vehicle
	overlay.vehicle = vehicle


func _flat_heading() -> Vector3:
	var heading: Vector3 = -vehicle.global_basis.z
	heading.y = 0.0
	return heading.normalized() if heading.length_squared() > 0.0001 else Vector3.FORWARD
