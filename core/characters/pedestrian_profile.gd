class_name PedestrianProfile
extends Resource
## A kind of pedestrian (tourist, local, nonna...): how they move, look and
## what they shout. Pure data, so new kinds need no code.

@export var id: StringName = &""
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var min_walk_speed: float = 1.1
@export_range(0.0, 5.0, 0.05, "suffix:m/s") var max_walk_speed: float = 1.5
## Stands still (e.g. a nonna on her doorstep) instead of wandering.
@export var stationary: bool = false
## Seconds spent looking around between walks.
@export_range(0.0, 60.0, 0.5, "suffix:s") var min_idle_time: float = 1.0
@export_range(0.0, 60.0, 0.5, "suffix:s") var max_idle_time: float = 4.0
## Wander targets are picked within this distance.
@export_range(4.0, 300.0, 1.0, "suffix:m") var wander_radius: float = 50.0
## Yells at vehicles passing faster than this nearby (0 = never).
@export_range(0.0, 200.0, 1.0, "suffix:km/h") var yell_at_speed_kmh: float = 0.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var yell_distance: float = 7.0

@export_group("Look")
@export var shirt_colors: Array[Color] = [Color(0.9, 0.4, 0.3)]
@export var skin_colors: Array[Color] = [Color(0.95, 0.78, 0.62), Color(0.78, 0.58, 0.42), Color(0.5, 0.36, 0.26)]
@export var hat_colors: Array[Color] = []
## 0..1: chance of wearing a hat (if hat_colors is not empty).
@export_range(0.0, 1.0, 0.05) var hat_chance: float = 0.0
@export_range(0.5, 1.5, 0.01) var min_height_scale: float = 0.92
@export_range(0.5, 1.5, 0.01) var max_height_scale: float = 1.08

@export_group("Lines")
## Shouted after being knocked over.
@export var hit_lines: PackedStringArray = ["Hey!"]
## Shouted at speeders (if yell_at_speed_kmh > 0).
@export var yell_lines: PackedStringArray = []
## Said when jumping out of the way of a horn.
@export var dodge_lines: PackedStringArray = []
