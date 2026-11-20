extends TestCase
## Vehicle catalog, buying/selecting, and starting a shift on the chosen vehicle.

const CATALOG: String = "res://minigames/vespa_delivery/data/vehicles/catalog.tres"
const GAME: String = "res://minigames/vespa_delivery/vespa_delivery.tscn"
const TEST_SAVE_DIR: String = "user://test_saves_garage"
const SECTION: StringName = &"garage_test"

var _saves: Node
var _original_dir: String = ""


func test_catalog_is_consistent() -> void:
	var catalog := load(CATALOG) as VehicleCatalog
	expect(catalog.find(catalog.starter_id) != null, "starter vehicle missing")
	expect(catalog.vehicles.size() >= 4, "expected at least 4 vehicles")
	for vehicle: VehicleDefinition in catalog.vehicles:
		var instance := vehicle.scene.instantiate() as ArcadeVehicle
		expect(instance != null, "%s: scene is not a vehicle" % vehicle.id)
		if instance == null:
			continue
		expect(instance.stats == vehicle.stats, "%s: definition stats differ from the scene's" % vehicle.id)
		expect(instance.get_node_or_null(^"Visual/CargoMount") != null, "%s: no cargo mount" % vehicle.id)
		var ratings: Dictionary = vehicle.ratings()
		for key: String in ratings:
			expect(int(ratings[key]) >= 1 and int(ratings[key]) <= 5, "%s: %s rating out of range" % [vehicle.id, key])
		note("%s €%d %s alleys=%s" % [vehicle.id, vehicle.price, ratings, vehicle.fits_alleys])
		instance.free()


func test_buy_and_select() -> void:
	_use_test_save()
	var garage := Garage.new(load(CATALOG) as VehicleCatalog, SECTION)
	GameState.money = 150
	expect(garage.owned_ids() == [garage.catalog.starter_id], "only the starter is owned at first")
	expect(not garage.buy(&"saetta"), "can't afford the Saetta with 150")
	expect(garage.buy(&"formica"), "buying the Formica for 120 should work")
	expect(GameState.money == 30, "money should drop to 30, is %d" % GameState.money)
	expect(not garage.buy(&"formica"), "can't buy it twice")
	expect(garage.select(&"formica") and garage.selected().id == &"formica", "select an owned vehicle")
	expect(not garage.select(&"topolino"), "can't select what you don't own")
	SaveManager.load_game()
	expect(Garage.new(garage.catalog, SECTION).owns(&"formica"), "ownership should be saved")
	_restore_save()


func test_shift_starts_on_the_selected_vehicle() -> void:
	_use_test_save()
	SaveManager.set_value(VespaDeliveryGame.SAVE_SECTION, &"owned_vehicles", ["topolino"])
	SaveManager.set_value(VespaDeliveryGame.SAVE_SECTION, &"selected_vehicle", "topolino")
	var game := (load(GAME) as PackedScene).instantiate() as VespaDeliveryGame
	game.shift_seed = 3
	add_node(game)
	await wait_physics_frames(20)
	expect(game.vehicle.scene_file_path.ends_with("topolino.tscn"), "the shift should use the Topolino, got %s" % game.vehicle.scene_file_path)
	expect(game.controller.vehicle == game.vehicle, "controller should drive the new vehicle")
	expect(game.camera.target == game.vehicle, "camera should follow the new vehicle")
	expect(game.cargo_stack.get_parent() == game.vehicle.get_node(^"Visual/CargoMount"), "cargo should sit on the roof rack")
	expect(game.vehicle.is_in_group(Groups.PLAYER), "the new vehicle should be the player")
	expect(game.get_node_or_null(^"Scooter") == null, "the old scooter should be gone")
	await cleanup()
	_restore_save()


func test_cargo_calm_vehicle_keeps_stack_still() -> void:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500, 1, 500)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(0, -0.5, 0)
	add_node(ground)
	var car := (load("res://core/vehicle/vehicles/topolino.tscn") as PackedScene).instantiate() as ArcadeVehicle
	car.stats = car.stats.duplicate() as VehicleStats
	car.stats.cargo_wobble_multiplier = 0.0
	car.position = Vector3(0, 0.4, 0)
	add_node(car)
	var stack := CargoStack.new()
	stack.vehicle = car
	car.get_node(^"Visual/CargoMount").add_child(stack)
	await wait_physics_frames(30)
	stack.load_cargo(load("res://minigames/vespa_delivery/data/cargo/pizza_tower.tres") as CargoType)
	car.intent.throttle = 1.0
	await wait_physics_frames(120)
	car.intent.clear()
	car.intent.brake = 1.0
	await wait_physics_frames(90)
	expect(stack.lean.length() < 0.01 and stack.item_count == 9, "zero wobble multiplier should keep the stack still")


func test_bollards_match_fits_alleys() -> void:
	var catalog := load(CATALOG) as VehicleCatalog
	for vehicle: VehicleDefinition in catalog.vehicles:
		var level: Node3D = GreyboxMapBuilder.new().build("[map]\n#######\n###.###\n###.###\n###.###\n=======\n===S===\n", "alley")
		add_node(level)
		await wait_physics_frames(2)
		var grid: LevelGrid = LevelGridNode.find_grid(tree)
		var car := vehicle.scene.instantiate() as ArcadeVehicle
		car.transform = Transform3D(Basis.IDENTITY, grid.cell_to_world(Vector2i(3, 5)) + Vector3.UP * 0.4)
		add_node(car)
		await wait_physics_frames(20)
		car.intent.throttle = 0.6
		await wait_physics_frames(60 * 3)
		var got_in: bool = grid.world_to_cell(car.global_position).y <= 2
		note("%s: %s the alley" % [vehicle.id, "got into" if got_in else "was stopped at"])
		expect(got_in == vehicle.fits_alleys, "%s: fits_alleys is %s but it %s the bollards" % [vehicle.id,
			vehicle.fits_alleys, "passed" if got_in else "was stopped by"])
		await cleanup()


func _use_test_save() -> void:
	_saves = tree.root.get_node(^"SaveManager")
	_original_dir = _saves.get(&"save_dir")
	_saves.set(&"save_dir", TEST_SAVE_DIR)
	_saves.call(&"clear")


func _restore_save() -> void:
	var path: String = _saves.call(&"get_save_path")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TEST_SAVE_DIR)
	_saves.set(&"save_dir", _original_dir)
	_saves.call(&"load_game")
	GameState.money = 0
