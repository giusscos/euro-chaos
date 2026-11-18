class_name Interactable
extends Area3D
## A zone the player activates, either by stopping inside it (vehicles) or by
## pressing interact (on foot, later). While the player is inside, the prompt
## is broadcast through Events so any HUD can show it.
## Needs a CollisionShape3D child that defines the zone.

signal player_entered(body: Node3D)
signal player_exited(body: Node3D)
signal activated(body: Node3D)

enum Mode { STOP_INSIDE, PRESS_INTERACT }

@export var mode: Mode = Mode.STOP_INSIDE
@export var prompt: String = "Stop here"
## STOP_INSIDE: the player must be slower than this...
@export_range(0.0, 100.0, 0.5, "suffix:km/h") var max_speed_kmh: float = 8.0
## ...for this long.
@export_range(0.0, 5.0, 0.05, "suffix:s") var dwell_time: float = 0.4
## Deactivate after the first activation.
@export var one_shot: bool = true
@export var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_dwell = 0.0
			_set_prompt_visible(false)
## Physics layers of bodies that can activate it (vehicles + characters).
@export_flags_3d_physics var detect_mask: int = 0b1010

const KMH_PER_MS: float = 3.6

var _body: Node3D = null
var _dwell: float = 0.0
var _used: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = detect_mask
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_player_inside() -> bool:
	return _body != null and is_instance_valid(_body)


## Seconds the player has been slow enough inside (STOP_INSIDE), 0..dwell_time.
func get_dwell_progress() -> float:
	return clampf(_dwell / dwell_time, 0.0, 1.0) if dwell_time > 0.0 else 0.0


func _physics_process(delta: float) -> void:
	if not _can_activate() or mode != Mode.STOP_INSIDE:
		return
	if _speed_kmh(_body) <= max_speed_kmh:
		_dwell += delta
		if _dwell >= dwell_time:
			_activate()
	else:
		_dwell = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.PRESS_INTERACT and _can_activate() and event.is_action_pressed(InputActions.INTERACT):
		_activate()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_set_prompt_visible(false)


func _can_activate() -> bool:
	return enabled and is_player_inside() and not (one_shot and _used)


func _activate() -> void:
	_used = true
	_dwell = 0.0
	var body: Node3D = _body
	if one_shot:
		_set_prompt_visible(false)
	activated.emit(body)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(Groups.PLAYER):
		return
	_body = body
	_dwell = 0.0
	if enabled and not (one_shot and _used):
		_set_prompt_visible(true)
	player_entered.emit(body)


func _on_body_exited(body: Node3D) -> void:
	if body != _body:
		return
	_body = null
	_dwell = 0.0
	_set_prompt_visible(false)
	player_exited.emit(body)


func _set_prompt_visible(shown: bool) -> void:
	if not is_inside_tree():
		return
	Events.interaction_prompt_changed.emit(self, prompt if shown else "")


func _speed_kmh(body: Node3D) -> float:
	var rigid := body as RigidBody3D
	if rigid != null:
		return rigid.linear_velocity.length() * KMH_PER_MS
	var character := body as CharacterBody3D
	if character != null:
		return character.velocity.length() * KMH_PER_MS
	return 0.0
