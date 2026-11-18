class_name PlayerVehicleController
extends Node
## Reads the input map and writes the vehicle's intent. Swap this node for
## an AI controller and the same vehicle drives itself.

signal horn_pressed

@export var vehicle: ArcadeVehicle:
	set(value):
		if vehicle != null and vehicle != value:
			vehicle.intent.clear()
		vehicle = value
## Optional: where the debug respawn action puts the vehicle.
@export var respawn_point: Node3D
## How high above the ground "reset upright" lifts the vehicle.
@export_range(0.0, 5.0, 0.1, "suffix:m") var reset_lift: float = 1.0
@export var input_enabled: bool = true:
	set(value):
		input_enabled = value
		if not value and vehicle != null:
			vehicle.intent.clear()


func _physics_process(_delta: float) -> void:
	if vehicle == null or not input_enabled:
		return
	var intent: VehicleIntent = vehicle.intent
	intent.throttle = Input.get_action_strength(InputActions.ACCELERATE)
	intent.brake = Input.get_action_strength(InputActions.BRAKE_REVERSE)
	intent.steer = Input.get_axis(InputActions.STEER_LEFT, InputActions.STEER_RIGHT)
	intent.handbrake = Input.is_action_pressed(InputActions.HANDBRAKE)
	intent.horn = Input.is_action_pressed(InputActions.HORN)


func _unhandled_input(event: InputEvent) -> void:
	if vehicle == null or not input_enabled:
		return
	if event.is_action_pressed(InputActions.RESET_VEHICLE):
		vehicle.reset_upright(reset_lift)
	elif event.is_action_pressed(InputActions.DEBUG_RESPAWN) and respawn_point != null:
		vehicle.teleport(respawn_point.global_transform)
	elif event.is_action_pressed(InputActions.HORN):
		horn_pressed.emit()
