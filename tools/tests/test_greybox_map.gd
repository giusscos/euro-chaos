extends TestCase
## GreyboxMapBuilder on small maps, and the generated village.

const VILLAGE_SCENE: String = "res://minigames/vespa_delivery/levels/village.tscn"
const VILLAGE_MAP: String = "res://minigames/vespa_delivery/levels/village_map.txt"
const VILLAGE_GENERATED: String = "res://minigames/vespa_delivery/levels/village_greybox.tscn"
## Height above a location from which the ground must be found.
const PROBE_HEIGHT: float = 3.0
## Room the scooter needs at a location (sphere radius, metres).
const CLEARANCE_RADIUS: float = 1.2

const SMALL_MAP: String = """
@cell_size = 4
@plateau_height = 4
@name.1 = Test Street 1
@id.Z = pizzeria
[map]
hhhH1
hhhhh
^^...
^^.Z.
^^S..
"""


func test_small_map_builds() -> void:
	var builder := GreyboxMapBuilder.new()
	var root: Node3D = builder.build(SMALL_MAP, "small")
	expect(root != null and builder.errors.is_empty(), "small map failed: %s" % [builder.errors])
	if root == null:
		return
	var ids: Array[StringName] = []
	for location: Node in root.find_child("Locations", false).get_children():
		ids.append((location as MissionLocation).location_id)
	note("locations %s, stats %s" % [ids, builder.stats])
	expect(ids.has(&"address_1") and ids.has(&"pizzeria"), "expected address_1 and pizzeria locations")
	expect(int(builder.stats.get("Ramps", 0)) == 1, "expected one merged ramp")
	var address := _location(root, &"address_1")
	expect(address != null and is_equal_approx(address.position.y, 4.0),
		"upper-town address should sit at plateau height")
	expect(root.find_child("PlayerSpawn", false) != null, "spawn missing")
	root.free()


func test_bad_maps_report_errors() -> void:
	var cases: Dictionary = {
		"uneven rows": "[map]\n..S\n..\n",
		"unknown char": "[map]\n.S?\n",
		"no spawn": "[map]\n...\n",
		"walled-in door": "[map]\n###\n#1#\n###\n.S.\n",
		"unknown setting": "@colour = red\n[map]\n.S\n",
	}
	for label: String in cases:
		var builder := GreyboxMapBuilder.new()
		var root: Node3D = builder.build(cases[label], label)
		expect(root == null and not builder.errors.is_empty(), "%s: should fail" % label)
		if root != null:
			root.free()


func test_generated_village_is_up_to_date() -> void:
	# Rebuild in memory and compare the node count with the saved scene, so a
	# map edit without a rebuild is caught.
	var builder := GreyboxMapBuilder.new()
	var fresh: Node3D = builder.build(FileAccess.get_file_as_string(VILLAGE_MAP), VILLAGE_MAP)
	expect(fresh != null, "village map no longer builds: %s" % [builder.errors])
	if fresh == null:
		return
	var saved: Node = (load(VILLAGE_GENERATED) as PackedScene).instantiate()
	var fresh_count: int = _count_nodes(fresh)
	var saved_count: int = _count_nodes(saved)
	note("village nodes: fresh %d, saved %d" % [fresh_count, saved_count])
	expect(fresh_count == saved_count,
		"village_greybox.tscn is stale: rebuild it from village_map.txt (see tools/levels/build_greybox_map.gd)")
	fresh.free()
	saved.free()


func test_village_locations_are_reachable_spots() -> void:
	var village: Node = (load(VILLAGE_SCENE) as PackedScene).instantiate()
	add_node(village)
	await wait_physics_frames(3)
	var space: PhysicsDirectSpaceState3D = (village as Node3D).get_world_3d().direct_space_state
	var locations: Array[Node] = tree.get_nodes_in_group(Groups.MISSION_LOCATION)
	expect(locations.size() >= 11, "expected 9 customers + 2 shops, found %d locations" % locations.size())
	var probe := SphereShape3D.new()
	probe.radius = CLEARANCE_RADIUS
	for node: Node in locations:
		var location := node as MissionLocation
		var at: Vector3 = location.global_position
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * PROBE_HEIGHT, at + Vector3.DOWN * 1.0)
		var hit: Dictionary = space.intersect_ray(ray)
		var ground_gap: float = INF if hit.is_empty() else absf((hit["position"] as Vector3).y - at.y)
		expect(ground_gap < 0.2, "%s floats or is buried (gap %.2f m)" % [location.location_id, ground_gap])
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = probe
		query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (CLEARANCE_RADIUS + 0.2))
		var blocked: Array[Dictionary] = space.intersect_shape(query, 1)
		expect(blocked.is_empty(), "%s is inside or against a building" % location.location_id)
	var spawns: Array[Node] = tree.get_nodes_in_group(Groups.PLAYER_SPAWN)
	expect(spawns.size() == 1, "expected exactly one player spawn, found %d" % spawns.size())


func _location(root: Node, id: StringName) -> MissionLocation:
	for node: Node in root.find_child("Locations", false).get_children():
		if (node as MissionLocation).location_id == id:
			return node as MissionLocation
	return null


func _count_nodes(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count
