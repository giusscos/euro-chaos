class_name StreetEvent
extends Node3D
## Base for a temporary bit of street comedy (tour group, influencer...).
## The director calls begin(context); the event cleans itself up after
## `lifetime` seconds (or when it calls finish()).
## context keys: "grid" (LevelGrid), "player" (Node3D), "route"
## (PackedVector3Array from the player towards their objective), "rng".

signal finished

@export_range(1.0, 600.0, 1.0, "suffix:s") var lifetime: float = 60.0
## Shown on the HUD when the event starts.
@export var announcement: String = ""
## Placed this far along the player's route (so it gets in the way).
@export_range(0.0, 300.0, 1.0, "suffix:m") var distance_along_route: float = 45.0

## Direction of the player's route at the event (horizontal, unit).
var route_direction := Vector3.FORWARD

var _age: float = 0.0
var _done: bool = false


func begin(context: Dictionary) -> void:
	var route: PackedVector3Array = context.get("route", PackedVector3Array())
	var at: Vector3 = point_along(route, distance_along_route)
	var ahead: Vector3 = (point_along(route, distance_along_route + 1.0) - at) * Vector3(1, 0, 1)
	if ahead.length_squared() > 0.0001:
		route_direction = ahead.normalized()
	global_position = at
	_on_begin(context)
	if announcement != "":
		Events.street_event_started.emit(announcement, global_position)


func finish() -> void:
	if _done:
		return
	_done = true
	_on_finish()
	finished.emit()
	queue_free()


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		finish()


## Override: build the event at global_position.
func _on_begin(_context: Dictionary) -> void:
	pass


## Override: clean up anything not parented to the event.
func _on_finish() -> void:
	pass


## The point `distance` metres along a path (its end if shorter).
static func point_along(route: PackedVector3Array, distance: float) -> Vector3:
	if route.is_empty():
		return Vector3.ZERO
	var left: float = distance
	for i: int in range(1, route.size()):
		var step: float = route[i - 1].distance_to(route[i])
		if step >= left:
			return route[i - 1].lerp(route[i], left / step) if step > 0.0 else route[i]
		left -= step
	return route[route.size() - 1]
