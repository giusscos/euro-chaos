extends TestCase
## The visible cargo stack: survives normal riding, topples on abuse.

const SCOOTER: String = "res://core/vehicle/vehicles/scooter.tscn"
const PIZZA: String = "res://minigames/vespa_delivery/data/cargo/pizza.tres"
const TOWER: String = "res://minigames/vespa_delivery/data/cargo/pizza_tower.tres"


func test_pizza_survives_normal_riding() -> void:
	var setup: Array = await _setup(PIZZA)
	var scooter: ArcadeVehicle = setup[0]
	var stack: CargoStack = setup[1]
	var max_lean: float = 0.0
	# Accelerate, cruise with gentle turns, brake normally, teleport.
	scooter.intent.throttle = 0.8
	for i: int in 60 * 3:
		await tree.physics_frame
		max_lean = maxf(max_lean, stack.lean.length())
	scooter.intent.steer = 0.4
	for i: int in 60:
		await tree.physics_frame
		max_lean = maxf(max_lean, stack.lean.length())
	scooter.intent.clear()
	scooter.intent.brake = 0.6
	for i: int in 60 * 2:
		await tree.physics_frame
		max_lean = maxf(max_lean, stack.lean.length())
	scooter.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.3, 0.0)))
	await wait_physics_frames(30)
	note("pizza: %d/3 boxes left, max lean %.1f°" % [stack.item_count, rad_to_deg(max_lean)])
	expect(stack.item_count == 3, "normal riding should not lose pizzas")


func test_tower_topples_on_a_crash_stop() -> void:
	var setup: Array = await _setup(TOWER)
	var scooter: ArcadeVehicle = setup[0]
	var stack: CargoStack = setup[1]
	var monitor: CargoMonitor = setup[2]
	var lost: Array[int] = []
	stack.item_lost.connect(func(remaining: int) -> void: lost.append(remaining))
	scooter.intent.throttle = 1.0
	await wait_physics_frames(60 * 5)
	scooter.intent.clear()
	scooter.intent.brake = 1.0
	scooter.intent.handbrake = true
	var max_lean: float = 0.0
	for i: int in 60 * 2:
		await tree.physics_frame
		max_lean = maxf(max_lean, stack.lean.length())
	note("tower: lost %d of 9 on an emergency stop (max lean %.1f°), condition %.2f" % [
		lost.size(), rad_to_deg(max_lean), monitor.condition])
	expect(not lost.is_empty(), "an emergency stop with a 9-box tower should lose some boxes")
	expect(monitor.condition < 1.0, "lost boxes should cost condition")


func test_big_drop_shakes_boxes_off() -> void:
	var setup: Array = await _setup(TOWER)
	var scooter: ArcadeVehicle = setup[0]
	var stack: CargoStack = setup[1]
	scooter.teleport(Transform3D(Basis.IDENTITY, Vector3(0.0, 10.0, 0.0)))
	await wait_physics_frames(60 * 3)
	note("tower after a 10 m drop: %d of 9 left" % stack.item_count)
	expect(stack.item_count < 9, "a 10 m drop should shake boxes off a tower")
	var fallen: Array[Node] = tree.root.find_children("FallenCargo*", "RigidBody3D", true, false)
	expect(not fallen.is_empty(), "fallen boxes should be physics objects in the world")
	for box: Node in fallen:
		expect((box as Node3D).global_position.y > -0.5, "a fallen box went through the ground")
		box.queue_free()


func _setup(cargo_path: String) -> Array:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1000.0, 1.0, 1000.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	add_node(ground)
	var scooter := (load(SCOOTER) as PackedScene).instantiate() as ArcadeVehicle
	scooter.position = Vector3(0.0, 0.3, 0.0)
	add_node(scooter)
	var monitor := CargoMonitor.new()
	monitor.vehicle = scooter
	add_node(monitor)
	var stack := CargoStack.new()
	stack.random_seed = 1234
	stack.vehicle = scooter
	stack.cargo_monitor = monitor
	scooter.get_node(^"Visual/CargoMount").add_child(stack)
	await wait_physics_frames(30)
	var cargo := load(cargo_path) as CargoType
	monitor.start(cargo.fragility)
	stack.load_cargo(cargo)
	return [scooter, stack, monitor]
