class_name VespaDeliveryGame
extends MiniGame
## Scooter Delivery: a shift of N deliveries around the village, then a
## results screen. Owns the shift flow, money, saving and hazards (the sea);
## the MissionRunner owns each individual delivery.

const SAVE_SECTION: StringName = &"vespa_delivery"
const OFFENCE_LINES: Dictionary = {
	&"speeding": "Speeding!  Someone saw that.",
	&"wrong_way": "Wrong way!  Senso unico!",
	&"red_light": "Red light!  Very red.",
}

@export var mission_pool: Array[MissionData] = []
@export_range(1, 20, 1) var missions_per_shift: int = 5
## Location where the player starts; the first job is picked from here if possible.
@export var start_location_id: StringName = &"pizzeria"
## 0 = a different shift every time.
@export var shift_seed: int = 0
@export_range(0.0, 10.0, 0.1, "suffix:s") var intro_delay: float = 1.2
@export_range(0.0, 10.0, 0.1, "suffix:s") var next_mission_delay: float = 2.5

@export_group("Chaos")
## Chaos points for knocking over a pedestrian.
@export_range(0, 100, 1) var pedestrian_chaos: int = 15
@export var chaos_color: Color = Color(1.0, 0.45, 0.3)
## Floating chaos text appears this high above the spot.
@export_range(0.0, 5.0, 0.1, "suffix:m") var chaos_text_height: float = 1.5
## Camera shake (trauma 0..1) for knocking things over.
@export_range(0.0, 1.0, 0.05) var chaos_shake: float = 0.35

@export_group("Rival Courier")
@export var rival_scene: PackedScene = preload("res://minigames/vespa_delivery/events/rival_courier.tscn")
## Chance that FreedomBurger Express races you for a delivery.
@export_range(0.0, 1.0, 0.05) var rival_chance: float = 0.35
## The rival starts roughly as far from the customer as you are (times this).
@export_range(0.3, 3.0, 0.05) var rival_head_start: float = 0.9
@export_range(0.0, 200.0, 1.0, "suffix:m") var rival_min_player_distance: float = 20.0
@export_range(0, 100, 1) var rival_win_bonus: int = 3

@export_group("Near Misses")
@export_range(0, 100, 1) var near_miss_bonus: int = 1
@export var near_miss_color: Color = Color(0.5, 1.0, 0.6)

@export_group("Hazards")
## Cargo condition lost when the scooter ends up in the sea.
@export_range(0.0, 1.0, 0.05) var water_cargo_damage: float = 0.35
## Below this height the player is respawned even without a hazard zone.
@export_range(-200.0, 0.0, 1.0, "suffix:m") var fall_limit: float = -20.0
## How often the last safe position (on all wheels) is remembered.
@export_range(0.1, 10.0, 0.1, "suffix:s") var safe_point_interval: float = 1.0
@export_range(0.0, 5.0, 0.1, "suffix:m") var respawn_lift: float = 0.6
## Ignore further hazards for this long after a respawn.
@export_range(0.0, 5.0, 0.1, "suffix:s") var respawn_grace: float = 1.0

@export_group("Nodes")
@export var vehicle: ArcadeVehicle
@export var controller: PlayerVehicleController
@export var runner: MissionRunner
@export var cargo_monitor: CargoMonitor
@export var cargo_stack: CargoStack
@export var hud: DeliveryHud
@export var arrow: ObjectiveArrow
@export var camera: ChaseCamera
@export var event_director: StreetEventDirector
@export var law_monitor: LawMonitor
@export var wanted: WantedSystem
@export var police: PoliceDispatcher
@export var vehicle_catalog: VehicleCatalog = preload("res://minigames/vespa_delivery/data/vehicles/catalog.tres")
@export var garage_screen: GarageScreen
@export var results_screen: ResultsScreen
@export var pause_menu: PauseMenu

var shift: Array[MissionData] = []
var results: Array[DeliveryResult] = []

var _rng := RandomNumberGenerator.new()
var _safe_transform := Transform3D.IDENTITY
var _safe_timer: float = 0.0
var _grace_left: float = 0.0
var _shift_over: bool = false
var _rival: RivalCourier
var _garage: Garage


func _on_start() -> void:
	GameState.money = SaveManager.get_int(SAVE_SECTION, &"money")
	GameState.chaos = 0
	_garage = Garage.new(vehicle_catalog, SAVE_SECTION)
	var choice: VehicleDefinition = _garage.selected()
	if choice != null and choice.scene != null and choice.scene.resource_path != vehicle.scene_file_path:
		_swap_vehicle(choice.scene)
	_place_at_spawn()
	_build_shift()

	runner.objective_changed.connect(_on_objective_changed)
	runner.cargo_picked_up.connect(_on_cargo_picked_up)
	cargo_stack.item_lost.connect(_on_cargo_item_lost)
	runner.became_late.connect(func(_m: MissionData) -> void: AudioManager.play(&"late"))
	runner.mission_finished.connect(_on_mission_finished)
	cargo_monitor.damaged.connect(_on_cargo_damaged)
	Events.hazard_entered.connect(_on_hazard_entered)
	Events.chaos_caused.connect(_on_chaos_caused)
	Events.pedestrian_hit.connect(_on_pedestrian_hit)
	Events.near_miss.connect(_on_near_miss)
	Events.violation_committed.connect(_on_violation)
	Events.speed_camera_fined.connect(_on_speed_camera)
	Events.busted.connect(_on_busted)
	Events.police_escaped.connect(func() -> void:
		if is_running:
			hud.show_toast("You lost them!", Color(0.5, 1.0, 0.6), 1.6))
	Events.street_event_started.connect(func(message: String, _at: Vector3) -> void:
		hud.show_toast(message, Color(1.0, 0.85, 0.4), 1.8))
	if event_director != null:
		event_director.context_provider = _event_context
	results_screen.again_pressed.connect(func() -> void: SceneLoader.change_scene(scene_file_path))
	results_screen.menu_pressed.connect(_go_to_menu)
	results_screen.garage_pressed.connect(func() -> void:
		if garage_screen != null:
			garage_screen.open(_garage))

	hud.set_shift_progress(0, shift.size())
	hud.show_toast("Shift starts!  %d %s" % [shift.size(), "delivery" if shift.size() == 1 else "deliveries"],
		Color.WHITE, 1.6)
	_after(intro_delay, _start_next_mission)


func _physics_process(delta: float) -> void:
	if not is_running or vehicle == null:
		return
	_grace_left = maxf(_grace_left - delta, 0.0)
	_safe_timer += delta
	if _safe_timer >= safe_point_interval:
		_safe_timer = 0.0
		if vehicle.grounded_wheel_count == vehicle.wheels.size() and vehicle.global_basis.y.y > 0.9:
			_safe_transform = Transform3D(_flat_basis(vehicle.global_basis), vehicle.global_position)
	if vehicle.global_position.y < fall_limit:
		_respawn("You fell off the world!")


func _build_shift() -> void:
	if mission_pool.is_empty():
		push_error("VespaDeliveryGame: mission_pool is empty")
		return
	_rng.seed = shift_seed if shift_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0)
	var pool: Array[MissionData] = mission_pool.duplicate()
	# Fisher-Yates with our RNG (Array.shuffle() uses the global one).
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: MissionData = pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	# Start next to the player: first job picked up where they stand.
	for i: int in pool.size():
		if pool[i].pickup_location_id == start_location_id:
			pool.push_front(pool.pop_at(i))
			break
	shift = pool.slice(0, mini(missions_per_shift, pool.size()))


func _start_next_mission() -> void:
	if results.size() >= shift.size():
		_end_shift()
		return
	var mission: MissionData = shift[results.size()]
	if not runner.start_mission(mission):
		var skipped := DeliveryResult.new()
		skipped.mission = mission
		skipped.outcome = DeliveryResult.Outcome.ABANDONED
		results.append(skipped)
		_start_next_mission()


func _on_objective_changed(target: Vector3, _label: String) -> void:
	arrow.target_position = target
	arrow.has_target = true


func _on_cargo_picked_up(mission: MissionData) -> void:
	AudioManager.play(&"pickup")
	if mission.cargo != null:
		cargo_stack.load_cargo(mission.cargo)
	if rival_scene != null and _rng.randf() < rival_chance:
		_start_rival(mission)


func _start_rival(mission: MissionData) -> void:
	var grid: LevelGrid = LevelGridNode.find_grid(get_tree())
	var dropoff: MissionLocation = MissionLocation.find(get_tree(), mission.dropoff_location_id)
	if grid == null or dropoff == null:
		return
	var wanted: float = vehicle.global_position.distance_to(dropoff.global_position) * rival_head_start
	var best := Vector2i(-1, -1)
	var best_error: float = INF
	for attempt: int in 40:
		var cell: Vector2i = grid.random_cell(_rng, LevelGrid.Network.SCOOTERS)
		var at: Vector3 = grid.cell_to_world(cell)
		if at.distance_to(vehicle.global_position) < rival_min_player_distance:
			continue
		var error: float = absf(at.distance_to(dropoff.global_position) - wanted)
		if error < best_error:
			best_error = error
			best = cell
	if best.x < 0:
		return
	_dismiss_rival()
	_rival = rival_scene.instantiate() as RivalCourier
	add_child(_rival)
	var start_at: Vector3 = grid.cell_to_world(best) + Vector3.UP * 0.3
	var facing: Vector3 = (dropoff.global_position - start_at) * Vector3(1, 0, 1)
	_rival.race(Transform3D(Basis.looking_at(facing.normalized() if facing.length() > 0.1 else Vector3.FORWARD), start_at),
		dropoff.global_position, grid)
	_rival.arrived.connect(_on_rival_arrived)
	hud.show_toast("%s is racing you to\n%s!" % [_rival.brand_name, dropoff.display_name], Color(1.0, 0.5, 0.4), 2.2)


func _on_rival_arrived() -> void:
	if runner.state == MissionRunner.State.DELIVERING:
		runner.tip_multiplier = 0.0
		hud.show_toast("%s got there first.\nNo tip for you!" % _rival.brand_name, Color(1.0, 0.4, 0.35), 2.2)
	_dismiss_rival()


func _dismiss_rival() -> void:
	if _rival != null and is_instance_valid(_rival):
		_rival.leave()
	_rival = null


func _event_context() -> Dictionary:
	var grid: LevelGrid = LevelGridNode.find_grid(get_tree())
	var route := PackedVector3Array()
	if grid != null:
		var toward: Vector3 = runner.get_objective_position() if runner.state != MissionRunner.State.IDLE \
			else grid.cell_to_world(grid.random_cell(_rng, LevelGrid.Network.PEDESTRIANS))
		route = grid.find_path(vehicle.global_position, toward, LevelGrid.Network.PEDESTRIANS)
	return {"grid": grid, "player": vehicle, "route": route}


func _on_cargo_item_lost(remaining: int) -> void:
	AudioManager.play_at(&"impact", vehicle.global_position)
	if remaining > 0:
		hud.show_toast("Overboard!  %d left" % remaining, Color(1.0, 0.75, 0.3), 1.2)


func _on_mission_finished(result: DeliveryResult) -> void:
	cargo_stack.clear()
	if _rival != null and is_instance_valid(_rival) and not _rival.has_arrived and result.is_success():
		GameState.add_money(rival_win_bonus)
		hud.show_toast("You beat %s!  +€%d" % [_rival.brand_name, rival_win_bonus], Color(0.5, 1.0, 0.6), 1.8)
	_dismiss_rival()
	results.append(result)
	arrow.has_target = false
	GameState.add_money(result.total())
	AudioManager.play(&"deliver" if result.is_success() else &"fail")
	hud.show_result(result)
	hud.set_shift_progress(results.size(), shift.size())
	_after(next_mission_delay, _start_next_mission)


func _on_cargo_damaged(amount: float, _condition: float) -> void:
	if amount > 0.02:
		AudioManager.play_at(&"impact", vehicle.global_position, linear_to_db(clampf(amount * 6.0, 0.2, 1.0)))


func _on_chaos_caused(amount: int, at: Vector3, label: String) -> void:
	if not is_running:
		return
	GameState.add_chaos(amount)
	FloatingText.spawn(self, "+%d  %s" % [amount, label], at + Vector3.UP * chaos_text_height, chaos_color)
	if camera != null:
		camera.add_trauma(chaos_shake)


func _on_violation(kind: StringName, _at: Vector3, _heat: float) -> void:
	if not is_running:
		return
	var line: String = OFFENCE_LINES.get(kind, "")
	if line != "":
		hud.show_toast(line, Color(1.0, 0.45, 0.35), 1.4)


func _on_busted(fine: int) -> void:
	if not is_running:
		return
	GameState.money = maxi(GameState.money - fine, 0)
	AudioManager.play(&"fail")
	if runner.state == MissionRunner.State.DELIVERING:
		cargo_monitor.apply_damage(1.0)
		hud.show_toast("BUSTED!  €%d fine.\nThe vigile confiscated the order." % fine, Color(1.0, 0.35, 0.3), 2.4)
	else:
		hud.show_toast("BUSTED!  €%d fine." % fine, Color(1.0, 0.35, 0.3), 2.0)


func _on_speed_camera(fine: int, _at: Vector3) -> void:
	if not is_running:
		return
	GameState.money = maxi(GameState.money - fine, 0)
	AudioManager.play(&"countdown")
	hud.show_toast("Autovelox!  €%d fine in the mail" % fine, Color(1.0, 0.85, 0.4), 1.6)


func _on_near_miss(thing: Node3D, _distance: float) -> void:
	if not is_running or near_miss_bonus <= 0:
		return
	GameState.add_money(near_miss_bonus)
	FloatingText.spawn(self, "+€%d  Near miss!" % near_miss_bonus,
		thing.global_position + Vector3.UP * chaos_text_height, near_miss_color)


func _on_pedestrian_hit(_pedestrian: Node3D, by: Node3D, _speed: float) -> void:
	if by == vehicle:
		Events.chaos_caused.emit(pedestrian_chaos, vehicle.global_position, "Pedestrian bowled!")


func _on_hazard_entered(hazard_id: StringName, body: Node3D) -> void:
	if body != vehicle or _grace_left > 0.0 or not is_running:
		return
	if hazard_id == &"water":
		AudioManager.play_at(&"splash", vehicle.global_position)
		cargo_monitor.apply_damage(water_cargo_damage)
		_respawn("Splash!  The cargo got wet." if cargo_monitor.is_active else "Splash!")
	else:
		_respawn("Oops!")


func _respawn(message: String) -> void:
	_grace_left = respawn_grace
	vehicle.teleport(_safe_transform.translated(Vector3.UP * respawn_lift))
	hud.show_toast(message, Color(0.6, 0.85, 1.0), 1.4)


func _end_shift() -> void:
	if _shift_over:
		return
	_shift_over = true
	var earned: int = 0
	var delivered: int = 0
	for result: DeliveryResult in results:
		earned += result.total()
		if result.is_success():
			delivered += 1
	var best: int = SaveManager.get_int(SAVE_SECTION, &"best_shift")
	var is_new_best: bool = earned > best
	SaveManager.set_value(SAVE_SECTION, &"best_chaos", maxi(SaveManager.get_int(SAVE_SECTION, &"best_chaos"), GameState.chaos))
	SaveManager.set_value(SAVE_SECTION, &"money", GameState.money)
	SaveManager.set_value(SAVE_SECTION, &"best_shift", maxi(best, earned))
	SaveManager.set_value(SAVE_SECTION, &"deliveries", SaveManager.get_int(SAVE_SECTION, &"deliveries") + delivered)
	SaveManager.save_game()

	controller.input_enabled = false
	vehicle.intent.brake = 1.0
	pause_menu.enabled = false
	if event_director != null:
		event_director.running = false
	if wanted != null:
		wanted.clear()
	_dismiss_rival()
	results_screen.show_results(results, earned, maxi(best, earned), is_new_best, GameState.chaos)
	finish({"earned": earned, "delivered": delivered, "chaos": GameState.chaos})


## Replaces the player's vehicle (garage choice) and re-points everything
## that follows it.
func _swap_vehicle(scene: PackedScene) -> void:
	var old: ArcadeVehicle = vehicle
	var replacement := scene.instantiate() as ArcadeVehicle
	replacement.name = "PlayerVehicle"
	add_child(replacement)
	replacement.global_transform = old.global_transform
	var mount := replacement.get_node_or_null(^"Visual/CargoMount") as Node3D
	cargo_stack.reparent(mount if mount != null else replacement, false)
	cargo_stack.vehicle = replacement
	controller.vehicle = replacement
	cargo_monitor.vehicle = replacement
	camera.target = replacement
	arrow.follow = replacement
	hud.player = replacement
	if law_monitor != null:
		law_monitor.vehicle = replacement
	if wanted != null:
		wanted.player = replacement
	if police != null:
		police.player = replacement
	for node_name: String in ["NearMissDetector", "DebugOverlay"]:
		var follower: Node = get_node_or_null(node_name)
		if follower != null:
			follower.set(&"vehicle", replacement)
	var lines := get_node_or_null(^"SpeedLines") as SpeedLines
	if lines != null:
		lines.target = replacement
	vehicle = replacement
	remove_child(old)
	old.queue_free()


func _place_at_spawn() -> void:
	var spawns: Array[Node] = get_tree().get_nodes_in_group(Groups.PLAYER_SPAWN)
	if spawns.is_empty():
		push_warning("VespaDeliveryGame: no player spawn in the level")
		_safe_transform = vehicle.global_transform
		return
	var spawn := spawns[0] as Node3D
	_safe_transform = spawn.global_transform
	vehicle.teleport(spawn.global_transform)
	controller.respawn_point = spawn


func _go_to_menu() -> void:
	SceneLoader.change_scene(ProjectSettings.get_setting("application/run/main_scene", ""))


## Runs `callback` after `delay` seconds of unpaused game time. Uses a child
## Timer so nothing fires after the scene is gone.
func _after(delay: float, callback: Callable) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(delay, 0.01)
	timer.timeout.connect(callback)
	timer.timeout.connect(timer.queue_free)
	add_child(timer)
	timer.start()


static func _flat_basis(basis: Basis) -> Basis:
	var forward: Vector3 = -basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Basis.IDENTITY
	return Basis.looking_at(forward.normalized(), Vector3.UP)
