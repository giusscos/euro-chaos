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
