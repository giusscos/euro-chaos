extends TestCase
## Street events (tour group, influencer), the director, the rival courier.

const VILLAGE_SCENE: String = "res://minigames/vespa_delivery/levels/village.tscn"
const TOUR: String = "res://core/events/tour_group_event.tscn"
const INFLUENCER: String = "res://core/events/influencer_event.tscn"
const RIVAL: String = "res://minigames/vespa_delivery/events/rival_courier.tscn"
const SCOOTER: String = "res://core/vehicle/vehicles/scooter.tscn"
## A long walk through the lower town (pedestrian network).
const ROUTE_FROM := Vector2i(1, 25)
const ROUTE_TO := Vector2i(45, 25)


func test_point_along_a_route() -> void:
	var route := PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0), Vector3(10, 0, 10)])
	expect(StreetEvent.point_along(route, 5.0).is_equal_approx(Vector3(5, 0, 0)), "5 m along")
	expect(StreetEvent.point_along(route, 15.0).is_equal_approx(Vector3(10, 0, 5)), "15 m along (after the corner)")
	expect(StreetEvent.point_along(route, 99.0).is_equal_approx(Vector3(10, 0, 10)), "past the end clamps")


func test_tour_group_sticks_together_and_moves() -> void:
	var context: Dictionary = await _village_context()
	var event := (load(TOUR) as PackedScene).instantiate() as TourGroupEvent
	event.lifetime = 25.0
	add_node(event)
	event.begin(context)
	var start: Vector3 = event.guide.global_position
	await wait_physics_frames(60 * 15)
	var grid: LevelGrid = context["grid"]
	var spread: float = 0.0
	var off_network: int = 0
	for tourist: Pedestrian in event.tourists:
		spread += tourist.global_position.distance_to(event.guide.global_position)
		if not grid.is_walkable(grid.world_to_cell(tourist.global_position)):
			off_network += 1
	spread /= event.tourists.size()
	var guide_moved: float = event.guide.global_position.distance_to(start)
	note("guide moved %.1f m, tourists on average %.1f m from the guide, %d off the walkable cells" % [
		guide_moved, spread, off_network])
	expect(guide_moved > 3.0, "the guide should lead the group somewhere")
	expect(spread < 7.0, "tourists should follow the umbrella")
	expect(off_network <= 1, "tourists ended up inside buildings")
	await wait_physics_frames(60 * 12)
	expect(not is_instance_valid(event), "the event should clean itself up after its lifetime")


func test_influencer_blocks_the_route_and_yells() -> void:
	var context: Dictionary = await _village_context()
	var event := (load(INFLUENCER) as PackedScene).instantiate() as InfluencerEvent
	add_node(event)
	event.begin(context)
	var route: PackedVector3Array = context["route"]
	var expected: Vector3 = StreetEvent.point_along(route, event.distance_along_route)
	expect(event.influencer.global_position.distance_to(expected) < 1.0, "influencer should stand on the route")
	var scooter := context["player"] as ArcadeVehicle
	scooter.teleport(Transform3D(Basis.looking_at(Vector3.RIGHT), expected + Vector3(-25.0, 0.3, 0.0)))
	await wait_physics_frames(20)
	scooter.intent.throttle = 1.0
	var yelled: bool = false
	for i: int in 60 * 4:
		await tree.physics_frame
		var speech := event.influencer.get_node(^"Speech") as Label3D
		yelled = yelled or (speech.visible and event.influencer.profile.yell_lines.has(speech.text))
	note("influencer yelled: %s" % yelled)
	expect(yelled, "the influencer should yell at a speeding scooter")


func test_director_starts_events_one_at_a_time() -> void:
	var context: Dictionary = await _village_context()
	var director := StreetEventDirector.new()
	director.event_scenes = [load(TOUR) as PackedScene, load(INFLUENCER) as PackedScene]
	director.first_event_delay = 0.5
	director.min_interval = 1.0
	director.max_interval = 1.0
	director.random_seed = 4
	director.context_provider = func() -> Dictionary: return context
	add_node(director)
	var announced: Array[String] = []
	var on_event := func(message: String, _at: Vector3) -> void: announced.append(message)
	Events.street_event_started.connect(on_event)
	await wait_physics_frames(60 * 5)
	Events.street_event_started.disconnect(on_event)
	note("announced %s, active %d" % [announced, director.active.size()])
	expect(announced.size() == 1, "max_active 1: exactly one event should run")
	expect(director.active.size() == 1, "the event should still be active")


func test_rival_courier_races_to_the_customer() -> void:
	var context: Dictionary = await _village_context()
	var grid: LevelGrid = context["grid"]
	var rival := (load(RIVAL) as PackedScene).instantiate() as RivalCourier
	add_node(rival)
	var target: Vector3 = grid.cell_to_world(Vector2i(24, 30))
	rival.race(Transform3D(Basis.looking_at(Vector3.RIGHT), grid.cell_to_world(Vector2i(3, 25)) + Vector3.UP * 0.3),
		target, grid)
	var frames: int = 0
	while not rival.has_arrived and frames < 60 * 45:
		await tree.physics_frame
		frames += 1
	note("rival %s after %.1f s" % ["arrived" if rival.has_arrived else "did NOT arrive", frames / 60.0])
	expect(rival.has_arrived, "the rival should reach the customer")
	var paint := rival.scooter.get_node(^"Paint") as VehiclePaint
	expect(paint != null and not paint.meshes.is_empty(), "the rival should be repainted")


func test_tip_multiplier_removes_the_tip() -> void:
	var runner := MissionRunner.new()
	var mission := MissionData.new()
	mission.base_payout = 10
	mission.max_tip = 8
	runner.tip_multiplier = 0.0
	var result: DeliveryResult = runner.evaluate(mission, 5.0, 60.0, 1.0)
	expect(result.tip == 0 and result.payout == 10, "a rival win should cost the tip only")
	runner.free()


func _village_context() -> Dictionary:
	add_node((load(VILLAGE_SCENE) as PackedScene).instantiate())
	await wait_physics_frames(2)
	var grid: LevelGrid = LevelGridNode.find_grid(tree)
	var scooter := (load(SCOOTER) as PackedScene).instantiate() as ArcadeVehicle
	scooter.position = grid.cell_to_world(ROUTE_FROM) + Vector3.UP * 0.3
	scooter.add_to_group(Groups.PLAYER)
	add_node(scooter)
	await wait_physics_frames(10)
	var route: PackedVector3Array = grid.find_path(scooter.global_position, grid.cell_to_world(ROUTE_TO),
		LevelGrid.Network.PEDESTRIANS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	return {"grid": grid, "player": scooter, "route": route, "rng": rng}
