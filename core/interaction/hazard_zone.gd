class_name HazardZone
extends Area3D
## A volume the player shouldn't be in (the sea, a canal, off the map).
## When the player's body enters it emits `player_entered` and the global
## Events.hazard_entered, and the mini-game decides what happens (respawn,
## splash, penalty). Needs a CollisionShape3D child.

signal player_entered(body: Node3D)

@export var hazard_id: StringName = &"water"
## Physics layers of bodies it reacts to (vehicles + characters).
@export_flags_3d_physics var detect_mask: int = 0b1010


func _ready() -> void:
	collision_layer = 0
	collision_mask = detect_mask
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(Groups.PLAYER):
		return
	player_entered.emit(body)
	Events.hazard_entered.emit(hazard_id, body)
