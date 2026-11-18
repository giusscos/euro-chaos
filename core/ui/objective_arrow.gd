class_name ObjectiveArrow
extends Node3D
## A 3D arrow floating above the player that points at the current
## objective, so you never need a minimap in a small village.
## Set `target_position` and `has_target`; it follows `follow`.

@export var follow: Node3D
@export_range(0.0, 10.0, 0.05, "suffix:m") var height: float = 2.3
@export_range(0.0, 1.0, 0.01, "suffix:m") var bob_amount: float = 0.12
@export_range(0.0, 5.0, 0.05, "suffix:Hz") var bob_speed: float = 1.3
## How fast it turns toward the target (1/s).
@export_range(0.1, 50.0, 0.1) var turn_sharpness: float = 10.0
## Hide when closer than this (the marker is right there).
@export_range(0.0, 50.0, 0.5, "suffix:m") var hide_distance: float = 6.0
@export var color: Color = Color(1.0, 0.85, 0.2):
	set(value):
		color = value
		_apply_color()

var target_position := Vector3.ZERO
var has_target: bool = false

@onready var _pivot: Node3D = $Pivot
var _time: float = 0.0
var _yaw: float = 0.0


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_apply_color()
	visible = false


func _process(delta: float) -> void:
	if follow == null or not has_target:
		visible = false
		return
	_time += delta
	var origin: Vector3 = follow.get_global_transform_interpolated().origin
	var to_target := Vector3(target_position.x - origin.x, 0.0, target_position.z - origin.z)
	visible = to_target.length() > hide_distance
	global_position = origin + Vector3.UP * (height + sin(_time * TAU * bob_speed) * bob_amount)
	if to_target.length_squared() > 0.0001:
		var target_yaw: float = atan2(-to_target.x, -to_target.z)
		_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-turn_sharpness * delta))
		rotation = Vector3(0.0, _yaw, 0.0)


func _apply_color() -> void:
	if not is_node_ready():
		return
	for child: Node in _pivot.get_children():
		var mesh := child as MeshInstance3D
		if mesh != null and mesh.material_override is StandardMaterial3D:
			var material := (mesh.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			material.albedo_color = color
			material.emission = color
			mesh.material_override = material
