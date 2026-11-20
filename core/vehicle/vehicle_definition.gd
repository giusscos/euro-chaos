class_name VehicleDefinition
extends Resource
## A vehicle you can own: shop data plus the scene to spawn. Ratings for the
## shop are derived from its VehicleStats, so they never drift from reality.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_range(0, 100000, 1) var price: int = 0
@export var scene: PackedScene
## Must be the stats the scene uses (checked by tests).
@export var stats: VehicleStats
## Narrow enough for the gaps between alley bollards.
@export var fits_alleys: bool = true

const RATING_MAX: int = 5
## Values that score a full 5.
const TOP_SPEED_FULL: float = 100.0
const ACCELERATION_FULL: float = 10.0
const HANDLING_FULL: float = 60.0


## 0..5 ratings for the shop.
func ratings() -> Dictionary:
	return {
		"Top speed": _rate(stats.top_speed_kmh / TOP_SPEED_FULL),
		"Acceleration": _rate(stats.engine_force / stats.mass / ACCELERATION_FULL),
		"Handling": _rate(stats.max_steer_angle * stats.tire_friction * stats.lateral_grip / HANDLING_FULL),
		"Cargo care": _rate(1.0 / maxf(stats.cargo_wobble_multiplier, 0.2) / 2.5),
	}


func _rate(value: float) -> int:
	return clampi(roundi(value * RATING_MAX), 1, RATING_MAX)
