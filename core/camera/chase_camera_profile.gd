class_name ChaseCameraProfile
extends Resource
## How the chase camera frames one kind of target. Vehicles (and later
## characters) carry their own profile, so a van and a scooter each get a
## sensible view. "At speed" values are reached at reference_speed_kmh.

@export_range(0.5, 30.0, 0.1, "suffix:m") var distance: float = 4.2
@export_range(0.5, 30.0, 0.1, "suffix:m") var distance_at_speed: float = 5.8
@export_range(-5.0, 20.0, 0.05, "suffix:m") var height: float = 1.9
@export_range(-5.0, 20.0, 0.05, "suffix:m") var height_at_speed: float = 2.2
## Point on the target the camera looks at, above its origin.
@export_range(0.0, 5.0, 0.05, "suffix:m") var look_height: float = 1.1
@export_range(0.0, 20.0, 0.1, "suffix:m") var look_ahead_at_speed: float = 3.0
@export_range(1.0, 400.0, 1.0, "suffix:km/h") var reference_speed_kmh: float = 80.0
@export_range(20.0, 120.0, 0.5, "suffix:°") var fov: float = 70.0
@export_range(20.0, 120.0, 0.5, "suffix:°") var fov_at_speed: float = 80.0
