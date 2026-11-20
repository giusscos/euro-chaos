class_name Garage
extends RefCounted
## Owned vehicles, the selected one and buying, persisted through SaveManager
## in `save_section`. Money is GameState.money (saved with the same key the
## mini-game uses).

var catalog: VehicleCatalog
var save_section: StringName
var money_key: StringName = &"money"


func _init(vehicle_catalog: VehicleCatalog, section: StringName) -> void:
	catalog = vehicle_catalog
	save_section = section


func owned_ids() -> Array[StringName]:
	var result: Array[StringName] = [catalog.starter_id]
	var saved: Variant = SaveManager.get_value(save_section, &"owned_vehicles", [])
	if saved is Array:
		for id: Variant in saved:
			if not result.has(StringName(str(id))):
				result.append(StringName(str(id)))
	return result


func owns(id: StringName) -> bool:
	return owned_ids().has(id)


func selected() -> VehicleDefinition:
	var id := StringName(str(SaveManager.get_value(save_section, &"selected_vehicle", catalog.starter_id)))
	var vehicle: VehicleDefinition = catalog.find(id)
	return vehicle if vehicle != null and owns(id) else catalog.find(catalog.starter_id)


## Buys a vehicle with GameState.money. Returns false if not affordable,
## unknown or already owned.
func buy(id: StringName) -> bool:
	var vehicle: VehicleDefinition = catalog.find(id)
	if vehicle == null or owns(id) or GameState.money < vehicle.price:
		return false
	GameState.money -= vehicle.price
	var owned: Array = []
	for owned_id: StringName in owned_ids():
		owned.append(String(owned_id))
	owned.append(String(id))
	SaveManager.set_value(save_section, &"owned_vehicles", owned)
	SaveManager.set_value(save_section, money_key, GameState.money)
	SaveManager.save_game()
	return true


func select(id: StringName) -> bool:
	if not owns(id):
		return false
	SaveManager.set_value(save_section, &"selected_vehicle", String(id))
	SaveManager.save_game()
	return true
