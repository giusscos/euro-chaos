class_name VehiclePaint
extends Node
## Recolours a vehicle's body panels (traffic variety, later the garage).
## Child of the vehicle, named "Paint".

@export var meshes: Array[MeshInstance3D] = []
@export var color: Color = Color(0.85, 0.2, 0.2):
	set(value):
		color = value
		if is_node_ready():
			_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	for mesh: MeshInstance3D in meshes:
		if mesh == null:
			continue
		var source := mesh.get_active_material(0) as StandardMaterial3D
		if source == null:
			continue
		var material := source.duplicate() as StandardMaterial3D
		material.albedo_color = color
		mesh.material_override = material
