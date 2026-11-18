class_name MissionData
extends Resource
## One delivery job. Pure data: locations are referenced by id and resolved
## at runtime from MissionLocation nodes in the level.

@export var id: StringName = &""
@export var title: String = ""
@export var customer_name: String = ""
## What the customer says when you pick up the order.
@export_multiline var request_text: String = ""
@export var pickup_location_id: StringName = &""
@export var dropoff_location_id: StringName = &""
@export var cargo: CargoType

@export_group("Timing and Pay")
## Seconds from pickup to delivery. 0 = MissionRunner computes it from distance.
@export_range(0.0, 600.0, 1.0, "suffix:s") var time_limit: float = 0.0
@export_range(0, 1000, 1) var base_payout: int = 10
@export_range(0, 1000, 1) var max_tip: int = 10

@export_group("Customer Lines")
@export_multiline var success_line: String = ""
@export_multiline var late_line: String = ""
@export_multiline var ruined_line: String = ""
