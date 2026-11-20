class_name SpeedCamera
extends Node3D
## An "Autovelox": anyone it sees going over its limit nearby gets fined by
## mail. LawMonitor asks it; it flashes when it catches someone.

@export_range(1.0, 200.0, 1.0, "suffix:km/h") var speed_limit_kmh: float = 30.0
@export_range(1.0, 50.0, 0.5, "suffix:m") var radius: float = 10.0
@export_range(0.0, 1000.0, 1.0) var fine: int = 5
## Won't fine the same driver again for this long.
@export_range(0.0, 60.0, 1.0, "suffix:s") var cooldown: float = 8.0

var _cooldown_left: float = 0.0
var _flash: MeshInstance3D


func _ready() -> void:
	add_to_group(Groups.SPEED_CAMERAS)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.07
	pole_mesh.height = 2.6
	pole.mesh = pole_mesh
	pole.position = Vector3(1.6, 1.3, 0.0)
	add_child(pole)
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.45, 0.6, 0.45)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.6, 0.1)
	box_mesh.material = material
	box.mesh = box_mesh
	box.position = Vector3(1.6, 2.8, 0.0)
	add_child(box)
	_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.5
	flash_mesh.height = 1.0
	var flash_material := StandardMaterial3D.new()
	flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_material.albedo_color = Color(1, 1, 1)
	flash_mesh.material = flash_material
	_flash.mesh = flash_mesh
	_flash.position = Vector3(1.6, 2.8, 0.0)
	_flash.visible = false
	add_child(_flash)


func _process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_flash.visible = _cooldown_left > cooldown - 0.15


## Fines (returns true) if `body` is in range, over the limit and not on cooldown.
func check(body: Node3D, speed_kmh: float) -> bool:
	if _cooldown_left > 0.0 or speed_kmh <= speed_limit_kmh:
		return false
	if body.global_position.distance_to(global_position) > radius:
		return false
	_cooldown_left = cooldown
	return true
