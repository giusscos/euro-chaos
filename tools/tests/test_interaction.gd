extends TestCase
## Interactable zones: stop-inside and press-interact activation.

const SCOOTER: String = "res://core/vehicle/vehicles/scooter.tscn"
const ZONE_POSITION := Vector3(0.0, 1.0, -30.0)
const ZONE_RADIUS: float = 3.0


func test_stop_inside_activates_only_when_slow() -> void:
	add_node(_make_ground())
	var zone: Interactable = _make_zone(Interactable.Mode.STOP_INSIDE)
	var activations: Array[Node3D] = []
	zone.activated.connect(func(body: Node3D) -> void: activations.append(body))
	var vehicle: ArcadeVehicle = await _spawn_player(Vector3(0.0, 0.3, 0.0))

	# Full throttle straight through the zone: must not trigger.
	vehicle.intent.throttle = 1.0
	await wait_physics_frames(240)
	note("drove through at %.0f km/h, z %.1f" % [vehicle.get_speed_kmh(), vehicle.global_position.z])
	expect(vehicle.global_position.z < ZONE_POSITION.z - ZONE_RADIUS, "vehicle never passed the zone")
	expect(activations.is_empty(), "activated while passing at speed")

	# Park inside it: must trigger once.
	vehicle.intent.clear()
	vehicle.teleport(Transform3D(Basis.IDENTITY, ZONE_POSITION + Vector3(0.0, -0.7, 0.0)))
	await wait_physics_frames(90)
	expect(activations.size() == 1, "expected 1 activation when stopped inside, got %d" % activations.size())
	await wait_physics_frames(60)
	expect(activations.size() == 1, "one-shot zone activated again")


func test_ignores_non_player_bodies() -> void:
	add_node(_make_ground())
	var zone: Interactable = _make_zone(Interactable.Mode.STOP_INSIDE)
	var activations: Array[Node3D] = []
	zone.activated.connect(func(body: Node3D) -> void: activations.append(body))
	var vehicle := (load(SCOOTER) as PackedScene).instantiate() as ArcadeVehicle
	vehicle.position = ZONE_POSITION + Vector3(0.0, -0.7, 0.0)
	add_node(vehicle)
	await wait_physics_frames(90)
	expect(activations.is_empty(), "a vehicle not in the player group activated the zone")


func test_press_interact_activates_inside() -> void:
	add_node(_make_ground())
	var zone: Interactable = _make_zone(Interactable.Mode.PRESS_INTERACT)
	var activations: Array[Node3D] = []
	zone.activated.connect(func(body: Node3D) -> void: activations.append(body))
	var prompts: Array[String] = []
	var on_prompt := func(_source: Node, text: String) -> void: prompts.append(text)
	Events.interaction_prompt_changed.connect(on_prompt)
	await _spawn_player(ZONE_POSITION + Vector3(0.0, -0.7, 0.0))
	await wait_physics_frames(60)
	expect(activations.is_empty(), "press-interact zone activated without a press")
	_press(InputActions.INTERACT)
	await wait_physics_frames(5)
	Events.interaction_prompt_changed.disconnect(on_prompt)
	expect(activations.size() == 1, "interact press did not activate")
	expect(prompts.has(zone.prompt), "prompt was not shown")
	expect(prompts.back() == "", "prompt was not hidden after activation")


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	tree.root.push_input(event)


func _make_zone(mode: Interactable.Mode) -> Interactable:
	var zone := Interactable.new()
	zone.mode = mode
	zone.prompt = "Test prompt"
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = ZONE_RADIUS
	cylinder.height = 4.0
	shape.shape = cylinder
	zone.add_child(shape)
	zone.position = ZONE_POSITION
	add_node(zone)
	return zone


func _spawn_player(at: Vector3) -> ArcadeVehicle:
	var vehicle := (load(SCOOTER) as PackedScene).instantiate() as ArcadeVehicle
	vehicle.position = at
	vehicle.add_to_group(Groups.PLAYER)
	add_node(vehicle)
	await wait_physics_frames(30)
	return vehicle


func _make_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500.0, 1.0, 500.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	return ground
