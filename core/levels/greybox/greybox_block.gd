@tool
class_name GreyboxBlock
extends StaticBody3D
## A static box, cylinder or sphere with matching collision and a grid material.
## Set size and color in the inspector; the mesh and shape are rebuilt live
## in the editor. Building block for test levels and greybox layouts.
## Position is the center of the block.

enum Shape { BOX, CYLINDER, SPHERE }

const MATERIAL: ShaderMaterial = preload("res://core/levels/greybox/greybox_material.tres")

## BOX: size is (width, height, depth). CYLINDER: x = diameter, y = height
## along the local Y axis (rotate the block to lay it down). SPHERE: x = diameter.
@export var shape: Shape = Shape.BOX:
	set(value):
		shape = value
		_rebuild()
@export var size: Vector3 = Vector3.ONE:
	set(value):
		size = value.max(Vector3(0.01, 0.01, 0.01))
		_rebuild()
@export var color: Color = Color(0.6, 0.6, 0.6):
	set(value):
		color = value
		_apply_color()
@export var cast_shadows: bool = true:
	set(value):
		cast_shadows = value
		_rebuild()
## Off for purely decorative pieces.
@export var has_collision: bool = true:
	set(value):
		has_collision = value
		_rebuild()
## 1 = full prototype grid, 0 = plain colour.
@export_range(0.0, 1.0, 0.01) var grid_strength: float = 1.0:
	set(value):
		grid_strength = value
		_apply_color()

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_ensure_children()
	match shape:
		Shape.BOX:
			var box_mesh := BoxMesh.new()
			box_mesh.size = size
			_mesh_instance.mesh = box_mesh
			var box_shape := BoxShape3D.new()
			box_shape.size = size
			_collision.shape = box_shape
		Shape.CYLINDER:
			var cylinder_mesh := CylinderMesh.new()
			cylinder_mesh.top_radius = size.x * 0.5
			cylinder_mesh.bottom_radius = size.x * 0.5
			cylinder_mesh.height = size.y
			_mesh_instance.mesh = cylinder_mesh
			var cylinder_shape := CylinderShape3D.new()
			cylinder_shape.radius = size.x * 0.5
			cylinder_shape.height = size.y
			_collision.shape = cylinder_shape
		Shape.SPHERE:
			var sphere_mesh := SphereMesh.new()
			sphere_mesh.radius = size.x * 0.5
			sphere_mesh.height = size.x
			_mesh_instance.mesh = sphere_mesh
			var sphere_shape := SphereShape3D.new()
			sphere_shape.radius = size.x * 0.5
			_collision.shape = sphere_shape
	_collision.disabled = not has_collision
	_mesh_instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	_apply_color()


func _apply_color() -> void:
	if _mesh_instance != null:
		_mesh_instance.set_instance_shader_parameter(&"base_color", color)
		_mesh_instance.set_instance_shader_parameter(&"grid_strength", grid_strength)


func _ensure_children() -> void:
	# Built at runtime and never saved into the scene (no owner).
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Mesh"
		_mesh_instance.material_override = MATERIAL
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "Collision"
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
