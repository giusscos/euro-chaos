class_name ChaosProp
extends RigidBody3D
## A loose physics prop (café chair, fruit crate...). The first time the
## player hits it hard enough it reports chaos points (Events.chaos_caused).
## Starts asleep so stacks don't jitter before anyone touches them.

@export_range(0, 100, 1) var chaos_points: int = 3
@export var chaos_label: String = "Crash!"
## The player must be moving at least this fast when they hit it. (The
## contact is reported after the prop has already been launched, so the
## hitter's own speed is the reliable measure.)
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var min_impact_speed: float = 2.0

var has_scored: bool = false


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	sleeping = true


func _on_body_entered(body: Node) -> void:
	if has_scored or not body.is_in_group(Groups.PLAYER):
		return
	var other := body as RigidBody3D
	if other == null or other.linear_velocity.length() < min_impact_speed:
		return
	has_scored = true
	Events.chaos_caused.emit(chaos_points, global_position, chaos_label)
