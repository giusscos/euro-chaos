class_name MissionLocation
extends Marker3D
## A named place in a level where missions start or end (a shop door, a
## customer's house). Missions refer to it by location_id. The marker sits on
## the drivable surface; its -Z axis faces the door.

@export var location_id: StringName = &""
@export var display_name: String = ""


func _enter_tree() -> void:
	add_to_group(Groups.MISSION_LOCATION)


## Returns the location with this id in the current tree, or null.
static func find(tree: SceneTree, id: StringName) -> MissionLocation:
	for node: Node in tree.get_nodes_in_group(Groups.MISSION_LOCATION):
		var location := node as MissionLocation
		if location != null and location.location_id == id:
			return location
	return null
