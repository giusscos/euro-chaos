extends TestCase
## Police dispatch, pursuit, busted and escape, in the real village.

const VILLAGE_SCENE: String = "res://minigames/vespa_delivery/levels/village.tscn"
const SCOOTER: String = "res://core/vehicle/vehicles/scooter.tscn"
## On the ring road, reachable by police cars.
const PLAYER_CELL := Vector2i(20, 30)


func test_one_star_unit_catches_a_parked_player() -> void:
	var setup: Dictionary = await _setup()
	var dispatcher: PoliceDispatcher = setup["dispatcher"]
	var wanted: WantedSystem = setup["wanted"]
	var fines: Array[int] = []
	dispatcher.player_busted.connect(func(fine: int) -> void: fines.append(fine))
	wanted.cool_down_delay = 999.0  # Let the unit arrive: one star cools off fast by design.
	wanted.add_heat(1.0)
	var frames: int = 0
	var closest: float = INF
	while fines.is_empty() and frames < 60 * 50:
		await tree.physics_frame
		frames += 1
		for unit: ArcadeVehicle in dispatcher.units:
			closest = minf(closest, unit.global_position.distance_to((setup["player"] as Node3D).global_position))
	note("units %d, closest %.1f m, busted after %.1f s, fines %s" % [dispatcher.units.size(), closest, frames / 60.0, fines])
	expect(fines == [dispatcher.fine_per_star], "a parked 1-star player should get busted for one star's fine")
	expect(wanted.get_stars() == 0, "busted clears the heat")
	for unit: ArcadeVehicle in dispatcher.units:
		var lights := unit.find_child("Lights", true, false) as PoliceLights
		expect(lights != null and not lights.siren_on, "sirens go off after the bust")


func test_three_stars_bring_a_scooter() -> void:
	var setup: Dictionary = await _setup()
	var dispatcher: PoliceDispatcher = setup["dispatcher"]
	var wanted: WantedSystem = setup["wanted"]
	wanted.cool_down_delay = 999.0
	wanted.add_heat(3.0)
	await wait_physics_frames(60)
	var scooters: int = 0
	for unit: ArcadeVehicle in dispatcher.units:
		scooters += 1 if unit.get_meta(&"police_scooter", false) else 0
		expect(unit.is_in_group(Groups.POLICE), "units should be in the police group")
	note("units at 3 stars: %d (%d scooter)" % [dispatcher.units.size(), scooters])
	expect(dispatcher.units.size() == 3, "3 stars should send 3 units")
	expect(scooters == 1, "one of them should be a scooter")


func test_cooling_off_is_an_escape() -> void:
	var setup: Dictionary = await _setup()
	var dispatcher: PoliceDispatcher = setup["dispatcher"]
	var wanted: WantedSystem = setup["wanted"]
	dispatcher.dispatch_delay = 999.0
	wanted.cool_down_delay = 0.5
	wanted.cool_down_rate = 2.0
	var escaped: Array[bool] = [false]
	dispatcher.player_escaped.connect(func() -> void: escaped[0] = true)
	wanted.add_heat(1.0)
	await wait_physics_frames(60 * 3)
	expect(escaped[0], "heat cooling to zero should count as an escape")


func _setup() -> Dictionary:
	add_node((load(VILLAGE_SCENE) as PackedScene).instantiate())
	await wait_physics_frames(2)
	var grid: LevelGrid = LevelGridNode.find_grid(tree)
	var player := (load(SCOOTER) as PackedScene).instantiate() as ArcadeVehicle
	player.position = grid.cell_to_world(PLAYER_CELL) + Vector3.UP * 0.3
	player.add_to_group(Groups.PLAYER)
	add_node(player)
	var wanted := WantedSystem.new()
	wanted.player = player
	add_node(wanted)
	var dispatcher := PoliceDispatcher.new()
	dispatcher.wanted = wanted
	dispatcher.player = player
	dispatcher.dispatch_delay = 0.2
	add_node(dispatcher)
	await wait_physics_frames(10)
	return {"grid": grid, "player": player, "wanted": wanted, "dispatcher": dispatcher}
