extends TestCase
## Road rules from the map: one-ways, traffic lights, speed cameras.

const VILLAGE_GENERATED: String = "res://minigames/vespa_delivery/levels/village_greybox.tscn"
const CAR: String = "res://core/vehicle/vehicles/tiny_car.tscn"

const RULES_MAP: String = """
@light = 6, 1, 2, 2
@oneway = 2, 4, 1, 2, v
@camera = 10, 1
[map]
##############
S=============
==============
##.###########
##.###########
##.###########
"""


func test_map_rules_reach_the_grid() -> void:
	var builder := GreyboxMapBuilder.new()
	var root: Node3D = builder.build(RULES_MAP, "rules")
	expect(root != null, "map failed: %s" % [builder.errors])
	if root == null:
		return
	var grid: LevelGrid = (root.find_child("LevelGrid", false) as LevelGridNode).grid
	expect(grid.get_light(Vector2i(6, 1)) == 0 and grid.get_light(Vector2i(7, 2)) == 0, "junction cells should belong to light 0")
	expect(grid.get_light(Vector2i(3, 1)) == -1, "other road cells have no light")
	expect(grid.get_oneway(Vector2i(2, 4)) == Vector2i(0, 1), "alley should be one-way southbound")
	expect(grid.get_oneway(Vector2i(2, 3)) == Vector2i.ZERO, "outside the rect it's two-way")
	var traffic: Node = root.find_child("Traffic", false)
	expect(traffic.get_child_count() == 2, "expected a light and a camera")
	root.free()
	var bad := GreyboxMapBuilder.new()
	expect(bad.build("@light = 0, 0, 1, 1\n[map]\n#S\n", "bad") == null, "a light off the road should be an error")


func test_light_cycles_axes() -> void:
	var light := TrafficLight.new()
	light.green_time = 1.0
	light.yellow_time = 0.5
	light.all_red_time = 0.5
	add_node(light)
	await tree.process_frame
	expect(light.can_enter(Vector3.RIGHT) and not light.can_enter(Vector3.FORWARD), "X green first")
	expect(light.is_red_for(Vector3.FORWARD), "Z red while X green")
	await wait_physics_frames(60 * 2 + 10)
	expect(light.can_enter(Vector3.FORWARD) and light.is_red_for(Vector3.RIGHT), "then Z green, X red")


func test_ai_car_waits_at_red() -> void:
	var builder := GreyboxMapBuilder.new()
	var level: Node3D = builder.build(RULES_MAP, "rules")
	add_node(level)
	await wait_physics_frames(2)
	var grid: LevelGrid = LevelGridNode.find_grid(tree)
	var light := level.find_child("TrafficLight0", true, false) as TrafficLight
	light.green_time = 30.0
	light.start_offset = 0.0
	# Force "Z axis green" for a while: our car drives along X, so it's red.
	light._time = (light.green_time + light.yellow_time + light.all_red_time)
	var car := (load(CAR) as PackedScene).instantiate() as ArcadeVehicle
	car.transform = Transform3D(Basis.looking_at(Vector3.RIGHT), grid.cell_to_world(Vector2i(1, 2)) + Vector3.UP * 0.4)
	add_node(car)
	var driver := AiVehicleController.new()
	driver.vehicle = car
	driver.grid = grid
	car.add_child(driver)
	await wait_physics_frames(20)
	driver.drive_to(grid.cell_to_world(Vector2i(13, 2)))
	await wait_physics_frames(60 * 6)
	var cell: Vector2i = grid.world_to_cell(car.global_position)
	note("car waiting at cell %s, speed %.1f km/h, light X red: %s" % [cell, car.get_speed_kmh(), light.is_red_for(Vector3.RIGHT)])
	expect(cell.x < 6, "the car ran the red light (now at %s)" % cell)
	expect(absf(car.get_speed_kmh()) < 3.0, "the car should be stopped")


func test_speed_camera_catches_speeders() -> void:
	var camera := SpeedCamera.new()
	add_node(camera)
	var driver := Node3D.new()
	add_node(driver)
	await tree.process_frame
	expect(not camera.check(driver, 25.0), "under the limit: no fine")
	expect(camera.check(driver, 55.0), "over the limit nearby: fine")
	expect(not camera.check(driver, 60.0), "cooldown: not fined twice in a row")
	driver.position = Vector3(50, 0, 0)


func test_village_has_rules() -> void:
	var village: Node = (load(VILLAGE_GENERATED) as PackedScene).instantiate()
	var traffic: Node = village.find_child("Traffic", false)
	var lights: int = 0
	var cameras: int = 0
	for child: Node in traffic.get_children():
		lights += 1 if child is TrafficLight else 0
		cameras += 1 if child is SpeedCamera else 0
	expect(lights == 2 and cameras == 2, "village: %d lights, %d cameras" % [lights, cameras])
	village.free()
