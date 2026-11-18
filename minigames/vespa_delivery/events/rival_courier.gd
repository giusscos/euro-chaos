class_name RivalCourier
extends Node3D
## FreedomBurger Express: a rival delivery scooter (all fictional) that
## races the player to the same customer. Reports `arrived` if it gets
## there first.

signal arrived

@export var scooter_scene: PackedScene = preload("res://core/vehicle/vehicles/scooter.tscn")
@export var brand_name: String = "FreedomBurger Express"
@export var paint_color: Color = Color(0.85, 0.12, 0.15)
@export var box_color: Color = Color(0.95, 0.75, 0.15)
@export_range(1.0, 100.0, 1.0, "suffix:km/h") var cruise_speed_kmh: float = 36.0
@export_range(0.5, 20.0, 0.5, "suffix:m") var arrive_distance: float = 5.0
@export_range(0.0, 30.0, 0.5, "suffix:s") var leave_delay: float = 3.0

const PAINTED_PARTS: Array[NodePath] = [^"Visual/RearBody", ^"Visual/Floorboard", ^"Visual/LegShield",
	^"Visual/Stem", ^"Visual/FrontFender"]

var scooter: ArcadeVehicle
var driver: AiVehicleController
var destination := Vector3.ZERO
var has_arrived: bool = false


## Spawns the rival at `start` and sends it to `target` on the scooter network.
func race(start: Transform3D, target: Vector3, grid: LevelGrid) -> void:
	destination = target
	scooter = scooter_scene.instantiate() as ArcadeVehicle
	scooter.name = "RivalScooter"
	scooter.add_to_group(Groups.TRAFFIC)
	var paint := VehiclePaint.new()
	paint.name = "Paint"
	for part: NodePath in PAINTED_PARTS:
		var mesh := scooter.get_node_or_null(part) as MeshInstance3D
		if mesh != null:
			paint.meshes.append(mesh)
	paint.color = paint_color
	scooter.add_child(paint)
	_add_branding(scooter)
	add_child(scooter)
	# Place it now (routes are planned before the teleport's physics tick).
	scooter.global_transform = start
	scooter.teleport(start)
	driver = AiVehicleController.new()
	driver.name = "Driver"
	driver.vehicle = scooter
	driver.grid = grid
	driver.network = LevelGrid.Network.SCOOTERS
	driver.cruise_speed_kmh = cruise_speed_kmh
	# Scooters ride the middle of alleys: that's where the gap between the
	# limited-traffic-zone bollards is.
	driver.lane_offset = 0.0
	scooter.add_child(driver)
	driver.gave_up.connect(func() -> void: driver.drive_to(destination))
	(func() -> void: driver.drive_to(destination)).call_deferred()


## Stops racing and disappears after a moment.
func leave() -> void:
	if driver != null:
		driver.stop()
	get_tree().create_timer(leave_delay, false).timeout.connect(queue_free)


func _physics_process(_delta: float) -> void:
	if has_arrived or scooter == null:
		return
	var gap := Vector2(scooter.global_position.x - destination.x, scooter.global_position.z - destination.z)
	if gap.length() < arrive_distance:
		has_arrived = true
		arrived.emit()


func _add_branding(vehicle: ArcadeVehicle) -> void:
	var brand_label := Label3D.new()
	brand_label.name = "Brand"
	brand_label.text = brand_name
	brand_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	brand_label.font_size = 40
	brand_label.outline_size = 10
	brand_label.pixel_size = 0.008
	brand_label.modulate = Color(1.0, 0.9, 0.3)
	brand_label.position = Vector3.UP * 2.3
	vehicle.add_child(brand_label)
	var mount := vehicle.get_node_or_null(^"Visual/CargoMount") as Node3D
	if mount == null:
		return
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.45, 0.4, 0.45)
	var material := StandardMaterial3D.new()
	material.albedo_color = box_color
	box_mesh.material = material
	box.mesh = box_mesh
	box.position = Vector3.UP * 0.2
	mount.add_child(box)
