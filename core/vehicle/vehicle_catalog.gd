class_name VehicleCatalog
extends Resource
## Every vehicle the player can own in a game.

@export var vehicles: Array[VehicleDefinition] = []
## Owned from the start.
@export var starter_id: StringName = &""


func find(id: StringName) -> VehicleDefinition:
	for vehicle: VehicleDefinition in vehicles:
		if vehicle.id == id:
			return vehicle
	return null
