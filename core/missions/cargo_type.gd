class_name CargoType
extends Resource
## Something the player carries (pizza, gelato, espresso...). Fragility scales
## how much each bump damages it.

@export var id: StringName = &""
@export var display_name: String = ""
## 0 = indestructible, 1 = normal, 2 = very fragile.
@export_range(0.0, 2.0, 0.01) var fragility: float = 1.0
## Scales automatic time limits: below 1 for cargo that melts or goes cold.
@export_range(0.1, 3.0, 0.05) var time_multiplier: float = 1.0
## Tint for HUD and markers.
@export var color: Color = Color(1.0, 0.8, 0.3)
@export_multiline var flavor_text: String = ""

@export_group("Stack on the Rack")
## Items stacked on the scooter's rack (pizza boxes, crates...).
@export_range(1, 20, 1) var stack_count: int = 1
@export var item_size: Vector3 = Vector3(0.42, 0.07, 0.42)
@export var item_color: Color = Color(0.85, 0.7, 0.5)
## How far the stack leans per m/s² of acceleration (radians).
@export_range(0.0, 0.1, 0.001) var wobble_sensitivity: float = 0.012
## Past this lean the top item falls off.
@export_range(1.0, 89.0, 0.5, "suffix:°") var topple_angle: float = 30.0
## Cargo condition lost per fallen item (the last one ruins the order).
@export_range(0.0, 1.0, 0.01) var item_loss_damage: float = 0.3
