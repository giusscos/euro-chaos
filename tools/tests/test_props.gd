extends TestCase
## Chaos props: placed by the map builder, scatter and score when the
## player (and only the player) crashes into them.

const CAFE_SET: String = "res://core/levels/props/cafe_set.tscn"
const SCOOTER: String = "res://core/vehicle/vehicles/scooter.tscn"
const PROP_DISTANCE: float = 18.0


func test_map_places_prop_scenes() -> void:
	var builder := GreyboxMapBuilder.new()
	var root: Node3D = builder.build("[map]\n.k.f.\n..S..\n", "props")
	expect(root != null, "map failed: %s" % [builder.errors])
	if root == null:
		return
	var props: Node = root.find_child("Props", false)
	expect(props.get_child_count() == 2, "expected 2 props, got %d" % props.get_child_count())
	# Pack and reload like the build tool does: props must stay scene
	# instances, not copies of their children.
	var packed := PackedScene.new()
	expect(packed.pack(root) == OK, "could not pack the level")
	var reloaded: Node = packed.instantiate()
	for prop: Node in reloaded.find_child("Props", false).get_children():
		expect(prop.scene_file_path != "", "%s lost its scene" % prop.name)
		var original: Node = (load(prop.scene_file_path) as PackedScene).instantiate()
		expect(prop.get_child_count() == original.get_child_count(),
			"%s has %d children, its scene has %d (duplicated on save?)" % [prop.name,
			prop.get_child_count(), original.get_child_count()])
		original.free()
	reloaded.free()
	root.free()


func test_player_scatters_props_for_chaos() -> void:
	var scores: Array[int] = []
	var on_chaos := func(amount: int, _at: Vector3, _label: String) -> void: scores.append(amount)
	Events.chaos_caused.connect(on_chaos)
	var cafe: Node3D = await _drive_into_cafe(true)
	Events.chaos_caused.disconnect(on_chaos)
	var table := cafe.get_node(^"Table") as RigidBody3D
	var moved: float = table.global_position.distance_to(cafe.global_position)
	note("chaos events %s, table moved %.1f m" % [scores, moved])
	expect(not scores.is_empty(), "crashing into the café set should score chaos")
	expect(moved > 0.5, "the table should go flying")


func test_other_vehicles_do_not_score() -> void:
	var scores: Array[int] = []
	var on_chaos := func(amount: int, _at: Vector3, _label: String) -> void: scores.append(amount)
	Events.chaos_caused.connect(on_chaos)
	await _drive_into_cafe(false)
	Events.chaos_caused.disconnect(on_chaos)
	expect(scores.is_empty(), "props hit by traffic should not score chaos for the player")


func _drive_into_cafe(as_player: bool) -> Node3D:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0.0, -0.5, 0.0)
	add_node(ground)
	var cafe := (load(CAFE_SET) as PackedScene).instantiate() as Node3D
	cafe.position = Vector3(0.0, 0.0, -PROP_DISTANCE)
	add_node(cafe)
	var scooter := (load(SCOOTER) as PackedScene).instantiate() as ArcadeVehicle
	scooter.position = Vector3(0.0, 0.3, 0.0)
	if as_player:
		scooter.add_to_group(Groups.PLAYER)
	add_node(scooter)
	await wait_physics_frames(30)
	scooter.intent.throttle = 1.0
	await wait_physics_frames(60 * 3)
	scooter.intent.clear()
	await wait_physics_frames(60)
	return cafe
