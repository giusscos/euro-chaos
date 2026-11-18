extends TestCase
## Scooter Delivery end to end, in the real village: a short shift, the
## results screen, saving, and falling into the sea.

const GAME_SCENE: String = "res://minigames/vespa_delivery/vespa_delivery.tscn"
const TEST_SAVE_DIR: String = "user://test_saves_delivery"
const WAIT_LIMIT: int = 240
const PARK_LIFT: float = 0.3
## A point above open sea, south of the beach.
const SEA_POINT := Vector3(-40.0, 3.0, 78.0)

var _saves: Node
var _original_save_dir: String = ""


func test_short_shift_end_to_end() -> void:
	var game: VespaDeliveryGame = await _start_game()
	var runner: MissionRunner = game.runner
	var vehicle: ArcadeVehicle = game.vehicle
	for i: int in game.shift.size():
		expect(await _wait_for(func() -> bool: return runner.state == MissionRunner.State.TO_PICKUP),
			"mission %d never started" % i)
		var mission: MissionData = runner.current_mission
		_park_at(vehicle, mission.pickup_location_id)
		expect(await _wait_for(func() -> bool: return runner.state == MissionRunner.State.DELIVERING),
			"%s: pickup never happened" % mission.id)
		_park_at(vehicle, mission.dropoff_location_id)
		var done: int = i + 1
		expect(await _wait_for(func() -> bool: return game.results.size() >= done),
			"%s: delivery never finished" % mission.id)
		if game.results.size() >= done:
			var result: DeliveryResult = game.results[i]
			note("%s -> %s, €%d, %d stars" % [mission.id, DeliveryResult.Outcome.keys()[result.outcome],
				result.total(), result.stars])
			expect(result.outcome == DeliveryResult.Outcome.DELIVERED, "%s not delivered cleanly" % mission.id)
	expect(await _wait_for(func() -> bool: return not game.is_running), "shift never ended")
	var results_root := game.results_screen.get_node(^"Root") as Control
	expect(results_root.visible, "results screen not shown")
	expect(_saves.call(&"get_int", VespaDeliveryGame.SAVE_SECTION, &"best_shift") > 0, "best shift not saved")
	expect(not game.pause_menu.enabled, "pause menu should be off on the results screen")
	await _stop_game()


func test_sea_respawns_on_land() -> void:
	var game: VespaDeliveryGame = await _start_game()
	var vehicle: ArcadeVehicle = game.vehicle
	await wait_physics_frames(90)
	vehicle.teleport(Transform3D(Basis.IDENTITY, SEA_POINT))
	var back_on_land: bool = await _wait_for(func() -> bool:
		return vehicle.global_position.z < 50.0 and vehicle.is_grounded())
	note("after the swim: %s, wheels %d" % [vehicle.global_position, vehicle.grounded_wheel_count])
	expect(back_on_land, "scooter was not put back on land after falling in the sea")
	await _stop_game()


func _start_game() -> VespaDeliveryGame:
	_saves = tree.root.get_node(^"SaveManager")
	_original_save_dir = _saves.get(&"save_dir")
	_saves.set(&"save_dir", TEST_SAVE_DIR)
	_saves.call(&"clear")
	var game := (load(GAME_SCENE) as PackedScene).instantiate() as VespaDeliveryGame
	game.shift_seed = 42
	game.missions_per_shift = 2
	game.intro_delay = 0.1
	game.next_mission_delay = 0.1
	add_node(game)
	await wait_physics_frames(30)
	return game


func _stop_game() -> void:
	await cleanup()
	var path: String = _saves.call(&"get_save_path")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TEST_SAVE_DIR)
	_saves.set(&"save_dir", _original_save_dir)
	_saves.call(&"load_game")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _park_at(vehicle: ArcadeVehicle, location_id: StringName) -> void:
	var location: MissionLocation = MissionLocation.find(tree, location_id)
	expect(location != null, "location %s missing" % location_id)
	if location != null:
		vehicle.teleport(Transform3D(location.global_basis, location.global_position + Vector3.UP * PARK_LIFT))


func _wait_for(condition: Callable) -> bool:
	for i: int in WAIT_LIMIT:
		if condition.call():
			return true
		await tree.physics_frame
	return bool(condition.call())
