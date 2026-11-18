class_name Pedestrian
extends CharacterBody3D
## A villager or tourist. Wanders the level's pedestrian network, hops out of
## the way of a horn, gets knocked over (cartoon tumble) by vehicles and gets
## back up cross. Vehicles don't physically collide with pedestrians (that
## would stop a scooter dead); the HitZone detects them instead.

signal knocked_over(by: Node3D, speed: float)

enum State { IDLE, WALK, DODGE, TUMBLE, ANGRY }

const KMH_PER_MS: float = 3.6

@export var profile: PedestrianProfile
## Optional: defaults to the level's grid.
@export var grid: LevelGrid
## Random seed for this pedestrian (0 = random).
@export var random_seed: int = 0

@export_group("Getting Hit")
## Vehicles slower than this (relative) just nudge past.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var hit_min_speed: float = 1.5
## Launch speed = vehicle speed × this, plus hit_lift upwards.
@export_range(0.0, 3.0, 0.05) var hit_transfer: float = 0.7
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var hit_lift: float = 4.0
@export_range(0.0, 50.0, 0.5, "suffix:rad/s") var tumble_spin: float = 12.0
## Time on the ground before getting up.
@export_range(0.0, 10.0, 0.1, "suffix:s") var tumble_time: float = 1.6
@export_range(0.0, 10.0, 0.1, "suffix:s") var angry_time: float = 2.5
## Share of the hitting vehicle's speed it loses (felt as a bump).
@export_range(0.0, 1.0, 0.01) var vehicle_slowdown: float = 0.12

@export_group("Horn")
@export_range(0.0, 50.0, 0.5, "suffix:m") var horn_hear_distance: float = 12.0
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var dodge_speed: float = 3.2
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var dodge_hop: float = 3.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var dodge_time: float = 0.6

@export_group("Animation")
@export_range(0.0, 0.3, 0.005, "suffix:m") var walk_bob: float = 0.05
@export_range(0.0, 10.0, 0.1, "suffix:Hz") var step_rate: float = 1.8
@export_range(0.0, 3.0, 0.05, "suffix:s") var speech_time: float = 2.2

var state: State = State.IDLE
var walk_speed: float = 1.3

@onready var _visual: Node3D = $Visual
@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _head_mesh: MeshInstance3D = $Visual/Head
@onready var _hat_mesh: MeshInstance3D = $Visual/Hat
@onready var _speech: Label3D = $Speech
@onready var _hit_zone: Area3D = $HitZone

var _rng := RandomNumberGenerator.new()
var _gravity: float = 9.8
var _path := PackedVector3Array()
var _path_index: int = 0
## Each pedestrian keeps to one side of the street.
var _side_offset: float = 0.0
var _state_time: float = 0.0
var _idle_duration: float = 0.0
var _speech_left: float = 0.0
var _anim_time: float = 0.0
var _home := Vector3.ZERO
var _yell_cooldown: float = 0.0


func _ready() -> void:
	add_to_group(Groups.PEDESTRIANS)
	_rng.seed = random_seed if random_seed != 0 else hash(get_instance_id())
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", _gravity)
	if profile == null:
		profile = PedestrianProfile.new()
	if grid == null:
		grid = LevelGridNode.find_grid(get_tree())
	walk_speed = _rng.randf_range(profile.min_walk_speed, profile.max_walk_speed)
	_side_offset = _rng.randf_range(-1.2, 1.2)
	_home = global_position
	_apply_look()
	_speech.visible = false
	_hit_zone.body_entered.connect(_on_hit_zone_body_entered)
	Events.horn_honked.connect(_on_horn_honked)
	_enter_idle()


func is_down() -> bool:
	return state == State.TUMBLE


## Knock over from `source` moving at `velocity` (also used by props/events).
func knock_over(source: Node3D, source_velocity: Vector3) -> void:
	if state == State.TUMBLE:
		return
	var away: Vector3 = global_position - source.global_position
	away.y = 0.0
	var push: Vector3 = source_velocity * hit_transfer
	if away.length_squared() > 0.01:
		push += away.normalized() * source_velocity.length() * 0.3
	velocity = push + Vector3.UP * hit_lift
	state = State.TUMBLE
	_state_time = 0.0
	_path.clear()
	_say(_pick(profile.hit_lines))
	knocked_over.emit(source, source_velocity.length())
	Events.pedestrian_hit.emit(self, source, source_velocity.length())


func _physics_process(delta: float) -> void:
	_state_time += delta
	_yell_cooldown = maxf(_yell_cooldown - delta, 0.0)
	var horizontal := Vector3.ZERO
	match state:
		State.IDLE:
			if _state_time > _idle_duration and not profile.stationary:
				_start_walk()
			_check_speeders()
		State.WALK:
			horizontal = _walk_velocity()
		State.DODGE:
			horizontal = Vector3(velocity.x, 0.0, velocity.z)
			if _state_time > dodge_time and is_on_floor():
				_enter_idle()
		State.TUMBLE:
			horizontal = Vector3(velocity.x, 0.0, velocity.z)
			if is_on_floor():
				horizontal = horizontal.move_toward(Vector3.ZERO, 12.0 * delta)
				if _state_time > tumble_time:
					state = State.ANGRY
					_state_time = 0.0
		State.ANGRY:
			if _state_time > angry_time:
				_enter_idle()
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()


func _process(delta: float) -> void:
	_anim_time += delta
	_speech_left = maxf(_speech_left - delta, 0.0)
	_speech.visible = _speech_left > 0.0
	match state:
		State.TUMBLE:
			_visual.rotation.x += tumble_spin * delta * (0.2 if is_on_floor() else 1.0)
			if is_on_floor():
				_visual.rotation.x = lerp_angle(_visual.rotation.x, -PI * 0.5, 1.0 - exp(-10.0 * delta))
			_visual.position.y = 0.0
		State.ANGRY:
			_visual.rotation = Vector3(0.0, _visual.rotation.y, sin(_anim_time * 18.0) * 0.12)
			_visual.position.y = absf(sin(_anim_time * 9.0)) * 0.08
		State.WALK:
			_visual.rotation = Vector3(0.0, _visual.rotation.y, sin(_anim_time * TAU * step_rate * 0.5) * 0.04)
			_visual.position.y = absf(sin(_anim_time * TAU * step_rate)) * walk_bob
		_:
			_visual.rotation = Vector3(0.0, _visual.rotation.y, 0.0)
			_visual.position.y = 0.0
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if state != State.TUMBLE and flat.length() > 0.3:
		var target_yaw: float = atan2(-flat.x, -flat.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-8.0 * delta))


func _walk_velocity() -> Vector3:
	if _path_index >= _path.size():
		_enter_idle()
		return Vector3.ZERO
	var target: Vector3 = _path[_path_index]
	if _path_index > 0:
		var segment: Vector3 = (target - _path[_path_index - 1]) * Vector3(1, 0, 1)
		if segment.length_squared() > 0.01:
			target += segment.normalized().cross(Vector3.UP) * _side_offset
	var to_target: Vector3 = (target - global_position) * Vector3(1, 0, 1)
	if to_target.length() < 0.6:
		_path_index += 1
		return Vector3(velocity.x, 0.0, velocity.z)
	return to_target.normalized() * walk_speed


func _start_walk() -> void:
	if grid == null:
		_enter_idle()
		return
	for attempt: int in 6:
		var cell: Vector2i = grid.random_cell(_rng, LevelGrid.Network.PEDESTRIANS)
		var target: Vector3 = grid.cell_to_world(cell)
		if Vector2(target.x - _home.x, target.z - _home.z).length() > profile.wander_radius:
			continue
		_path = grid.find_path(global_position, target, LevelGrid.Network.PEDESTRIANS)
		if _path.size() > 1:
			_path_index = 1
			state = State.WALK
			_state_time = 0.0
			return
	_enter_idle()


func _enter_idle() -> void:
	state = State.IDLE
	_state_time = 0.0
	_idle_duration = _rng.randf_range(profile.min_idle_time, profile.max_idle_time)
	_visual.rotation.x = 0.0


func _on_hit_zone_body_entered(body: Node3D) -> void:
	var vehicle := body as RigidBody3D
	if vehicle == null or state == State.TUMBLE:
		return
	var relative: Vector3 = vehicle.linear_velocity - velocity
	if relative.length() < hit_min_speed:
		return
	knock_over(vehicle, vehicle.linear_velocity)
	vehicle.apply_central_impulse(-vehicle.linear_velocity * vehicle.mass * vehicle_slowdown)


func _on_horn_honked(source: Node3D) -> void:
	if state == State.TUMBLE or state == State.DODGE or not is_instance_valid(source):
		return
	var offset: Vector3 = global_position - source.global_position
	if offset.length() > horn_hear_distance:
		return
	# Hop sideways, away from the vehicle's path.
	var forward: Vector3 = -source.global_basis.z
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	if side.dot(offset) < 0.0:
		side = -side
	velocity = side * dodge_speed + Vector3.UP * dodge_hop
	state = State.DODGE
	_state_time = 0.0
	_path.clear()
	_say(_pick(profile.dodge_lines))


func _check_speeders() -> void:
	if profile.yell_at_speed_kmh <= 0.0 or _yell_cooldown > 0.0:
		return
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as RigidBody3D
	if player == null:
		return
	if player.global_position.distance_to(global_position) < profile.yell_distance \
			and player.linear_velocity.length() * KMH_PER_MS > profile.yell_at_speed_kmh:
		_say(_pick(profile.yell_lines))
		_yell_cooldown = speech_time * 2.0
		state = State.ANGRY
		_state_time = 0.0


func _say(line: String) -> void:
	if line == "":
		return
	_speech.text = line
	_speech_left = speech_time


func _pick(lines: PackedStringArray) -> String:
	return lines[_rng.randi() % lines.size()] if not lines.is_empty() else ""


func _apply_look() -> void:
	var height: float = _rng.randf_range(profile.min_height_scale, profile.max_height_scale)
	_visual.scale = Vector3(1.0, height, 1.0)
	_tint(_body_mesh, profile.shirt_colors)
	_tint(_head_mesh, profile.skin_colors)
	var wears_hat: bool = not profile.hat_colors.is_empty() and _rng.randf() < profile.hat_chance
	_hat_mesh.visible = wears_hat
	if wears_hat:
		_tint(_hat_mesh, profile.hat_colors)


func _tint(mesh: MeshInstance3D, colors: Array[Color]) -> void:
	if colors.is_empty():
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = colors[_rng.randi() % colors.size()]
	mesh.material_override = material
