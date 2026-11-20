class_name CargoStack
extends Node3D
## The cargo you can see on the rack: a stack of items that sways like a
## spring with the vehicle's acceleration, gets jolted by landings, and
## loses its top item when it leans past the cargo's topple angle. Each lost
## item costs condition (via CargoMonitor); losing the last one ruins it.
## Place it on the vehicle's cargo mount (it leans with the visual).

signal item_lost(remaining: int)

@export var vehicle: ArcadeVehicle
@export var cargo_monitor: CargoMonitor
## Natural sway frequency of the stack and how quickly it settles.
@export_range(0.1, 10.0, 0.05, "suffix:Hz") var wobble_frequency: float = 1.6
@export_range(0.0, 2.0, 0.01) var wobble_damping: float = 0.35
## Vertical jolts above this (landings, curbs) shake the stack...
@export_range(0.0, 200.0, 1.0, "suffix:m/s²") var jolt_threshold: float = 25.0
## ...by this much sway speed per m/s² of jolt.
@export_range(0.0, 0.05, 0.0005) var jolt_sensitivity: float = 0.013
## Fallen items are removed after this long.
@export_range(1.0, 60.0, 1.0, "suffix:s") var fallen_item_lifetime: float = 10.0
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var fall_push: float = 2.0
@export_range(0.1, 50.0, 0.1, "suffix:kg") var fallen_item_mass: float = 1.0
## Seed for jolt directions (0 = random).
@export var random_seed: int = 0

var cargo: CargoType
## Current lean (x: sideways, y: forward/back), radians.
var lean := Vector2.ZERO
var item_count: int = 0

var _lean_speed := Vector2.ZERO
var _items: Array[MeshInstance3D] = []
var _last_velocity := Vector3.ZERO
var _last_teleport_serial: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed if random_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0)


## Shows a fresh stack for this cargo.
func load_cargo(type: CargoType) -> void:
	clear()
	cargo = type
	lean = Vector2.ZERO
	_lean_speed = Vector2.ZERO
	for i: int in type.stack_count:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = type.item_size * Vector3(1.0, 0.92, 1.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = type.item_color.darkened(0.08 * (i % 2))
		box.material = material
		mesh.mesh = box
		add_child(mesh)
		_items.append(mesh)
	item_count = _items.size()
	_resync()
	_layout()


func clear() -> void:
	for item: MeshInstance3D in _items:
		item.queue_free()
	_items.clear()
	item_count = 0
	cargo = null


func _physics_process(delta: float) -> void:
	if cargo == null or vehicle == null or item_count == 0 or delta <= 0.0:
		return
	if vehicle.teleport_serial != _last_teleport_serial:
		_resync()
		return
	var velocity: Vector3 = vehicle.linear_velocity
	var accel: Vector3 = (velocity - _last_velocity) / delta
	_last_velocity = velocity
	var local: Vector3 = vehicle.global_basis.inverse() * accel
	# Inertia: accelerating forward (-Z) leans the stack back (+Z), etc.
	var multiplier: float = vehicle.stats.cargo_wobble_multiplier if vehicle.stats != null else 1.0
	var push := Vector2(-local.x, -local.z) * cargo.wobble_sensitivity * multiplier
	var omega: float = TAU * wobble_frequency
	_lean_speed += (omega * omega * (push - lean) - 2.0 * wobble_damping * omega * _lean_speed) * delta
	var jolt: float = absf(local.y) - jolt_threshold
	if jolt > 0.0:
		_lean_speed += Vector2.from_angle(_rng.randf() * TAU) * jolt * jolt_sensitivity * multiplier
	lean += _lean_speed * delta
	if lean.length() > deg_to_rad(cargo.topple_angle):
		_drop_top_item()


func _process(_delta: float) -> void:
	_layout()


## Bends the stack: higher items lean (and shift) more.
func _layout() -> void:
	if cargo == null:
		return
	var y: float = 0.0
	for i: int in _items.size():
		var height: float = y + cargo.item_size.y * 0.5
		var bend: float = float(i + 1) / maxf(_items.size(), 1)
		_items[i].position = Vector3(lean.x * height, height, lean.y * height)
		_items[i].rotation = Vector3(lean.y * bend, 0.0, -lean.x * bend)
		y += cargo.item_size.y


func _drop_top_item() -> void:
	var top: MeshInstance3D = _items.pop_back()
	item_count = _items.size()
	var falling := RigidBody3D.new()
	falling.name = "FallenCargo"
	falling.collision_layer = 4
	falling.collision_mask = 5
	falling.mass = fallen_item_mass
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = cargo.item_size
	shape.shape = box_shape
	falling.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = top.mesh
	falling.add_child(mesh)
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent.add_child(falling)
	falling.global_transform = top.global_transform
	var direction := global_basis * Vector3(lean.x, 0.0, lean.y).normalized()
	falling.linear_velocity = vehicle.linear_velocity + direction * fall_push + Vector3.UP
	falling.angular_velocity = Vector3(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-3.0, 3.0), _rng.randf_range(-6.0, 6.0))
	get_tree().create_timer(fallen_item_lifetime, false).timeout.connect(falling.queue_free)
	top.queue_free()
	# The lighter stack swings back a bit.
	lean *= 0.4
	_lean_speed *= 0.4
	if cargo_monitor != null:
		cargo_monitor.apply_damage(1.0 if item_count == 0 else cargo.item_loss_damage)
	item_lost.emit(item_count)


func _resync() -> void:
	if vehicle != null:
		_last_velocity = vehicle.linear_velocity
		_last_teleport_serial = vehicle.teleport_serial
