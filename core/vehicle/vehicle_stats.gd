class_name VehicleStats
extends Resource
## Everything that gives a vehicle its character. A new vehicle is a new
## .tres of this plus a scene, not new code. All values are SI units unless
## the name says otherwise. Physics runs at a fixed 60 Hz.

const KMH_PER_MS: float = 3.6

@export_group("Body")
@export_range(10.0, 10000.0, 1.0, "suffix:kg") var mass: float = 200.0
## Relative to the vehicle origin. Lower = harder to tip over.
@export var center_of_mass: Vector3 = Vector3(0.0, 0.5, 0.0)
## Air drag force = air_drag * speed². N per (m/s)².
@export_range(0.0, 5.0, 0.01) var air_drag: float = 0.3
## Godot's generic velocity damping, replacing the project default (which
## would cap top speed). Keep at 0 and use air_drag instead.
@export_range(0.0, 5.0, 0.01, "suffix:1/s") var linear_damp: float = 0.0
## Generic rotation damping (mostly felt in the air).
@export_range(0.0, 5.0, 0.01, "suffix:1/s") var angular_damp: float = 0.3

@export_group("Engine")
@export_range(0.0, 50000.0, 10.0, "suffix:N") var engine_force: float = 1400.0
@export_range(1.0, 400.0, 1.0, "suffix:km/h") var top_speed_kmh: float = 75.0
## X: speed / top speed (0..1). Y: share of engine_force available.
@export var torque_curve: Curve
@export_range(0.0, 50000.0, 10.0, "suffix:N") var reverse_force: float = 600.0
@export_range(1.0, 100.0, 1.0, "suffix:km/h") var reverse_top_speed_kmh: float = 15.0
## Below this forward speed, the brake input reverses instead of braking.
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var reverse_switch_speed: float = 0.8

@export_group("Brakes")
## Total brake force, split across all wheels.
@export_range(0.0, 50000.0, 10.0, "suffix:N") var brake_force: float = 2000.0
## Total handbrake force, split across rear wheels.
@export_range(0.0, 50000.0, 10.0, "suffix:N") var handbrake_force: float = 1500.0
## Rear lateral grip multiplier while the handbrake is held (lower = drift).
@export_range(0.0, 1.0, 0.01) var handbrake_rear_grip: float = 0.35
## Total braking when no pedal is pressed (engine braking, keeps it parked on slopes).
@export_range(0.0, 50000.0, 10.0, "suffix:N") var coast_brake_force: float = 250.0
## Per wheel, N per m/s of rolling speed.
@export_range(0.0, 500.0, 0.1) var rolling_resistance: float = 4.0

@export_group("Steering")
@export_range(0.0, 60.0, 0.5, "suffix:°") var max_steer_angle: float = 35.0
## Steering angle allowed at top speed (speed-sensitive steering).
@export_range(0.0, 60.0, 0.5, "suffix:°") var steer_angle_at_top_speed: float = 6.0
## How fast the front wheel turns toward the target angle.
@export_range(1.0, 1000.0, 1.0, "suffix:°/s") var steer_speed: float = 220.0

@export_group("Tires")
@export_range(0.05, 1.5, 0.01, "suffix:m") var wheel_radius: float = 0.22
## Max tire force = load * tire_friction (per direction).
@export_range(0.1, 5.0, 0.01) var tire_friction: float = 1.5
## Share of sideways slip removed each physics tick (1 = on rails).
@export_range(0.0, 1.0, 0.01) var lateral_grip: float = 0.85
@export_range(0.0, 2.0, 0.01) var front_grip: float = 1.0
@export_range(0.0, 2.0, 0.01) var rear_grip: float = 1.0
## X: slip ratio (sideways speed / speed, 0..1). Y: grip multiplier.
## A curve that drops at high slip makes slides keep sliding.
@export var grip_curve: Curve
## Below this speed slip is measured against this value (avoids jitter at rest).
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var slip_reference_speed: float = 2.0
## Where tire forces push: 0 = at the ground, 1 = at center-of-mass height.
## Higher = less body roll, less tipping.
@export_range(0.0, 1.0, 0.01) var tire_force_height: float = 0.7

@export_group("Suspension")
@export_range(0.01, 2.0, 0.01, "suffix:m") var suspension_rest_length: float = 0.25
@export_range(0.0, 500000.0, 10.0, "suffix:N/m") var spring_stiffness: float = 9800.0
@export_range(0.0, 50000.0, 10.0, "suffix:N·s/m") var spring_damping: float = 1100.0
## Wheel rays start this far above the mount, so a wheel still finds the
## ground when a hard landing pushes the mount below the surface. Keep the
## start point inside the chassis.
@export_range(0.0, 2.0, 0.01, "suffix:m") var ray_start_height: float = 0.4
## When the suspension runs out of travel the wheel acts as a solid contact:
## downward motion stops and the body is pushed back out at
## (overtravel × this) m/s. Higher = snappier recovery, lower = softer.
@export_range(0.0, 100.0, 0.5, "suffix:1/s") var bump_stop_recovery: float = 10.0

@export_group("Stability")
## Keeps the body's roll aligned with the ground. Essential for two-wheelers
## (they have no sideways support), small for cars (just anti-flip).
@export_range(0.0, 10.0, 0.05, "suffix:Hz") var roll_assist_frequency: float = 2.5
@export_range(0.0, 2.0, 0.05) var roll_assist_damping_ratio: float = 0.9
## Levels the pitch while airborne (0 = off).
@export_range(0.0, 10.0, 0.05, "suffix:Hz") var air_pitch_level_frequency: float = 0.6
@export_range(0.0, 2.0, 0.05) var air_pitch_level_damping_ratio: float = 0.7
## Angular acceleration from player input while airborne.
@export_range(0.0, 50.0, 0.1, "suffix:rad/s²") var air_control_pitch: float = 4.0
@export_range(0.0, 50.0, 0.1, "suffix:rad/s²") var air_control_yaw: float = 3.0

@export_group("Visual")
## Lean into turns (two-wheelers, ~1) or roll outward (cars, small negative).
## Physics-based: lean = atan(speed * yaw rate / g) * factor.
@export_range(-2.0, 2.0, 0.01) var visual_lean_factor: float = 1.0
@export_range(0.0, 60.0, 0.5, "suffix:°") var max_visual_lean: float = 35.0
## Nose up when accelerating, down when braking. Radians per m/s².
@export_range(-0.2, 0.2, 0.001) var visual_pitch_factor: float = 0.012
@export_range(0.0, 30.0, 0.5, "suffix:°") var max_visual_pitch: float = 6.0
## How quickly lean/pitch follow their targets (1/s).
@export_range(0.1, 50.0, 0.1) var visual_response: float = 8.0


func top_speed() -> float:
	return top_speed_kmh / KMH_PER_MS


func reverse_top_speed() -> float:
	return reverse_top_speed_kmh / KMH_PER_MS


## Engine force multiplier at the given forward speed (0 at/above top speed).
func torque_at(speed: float) -> float:
	var ratio: float = clampf(speed / top_speed(), 0.0, 1.0)
	if ratio >= 1.0:
		return 0.0
	if torque_curve == null:
		return 1.0 - ratio
	return torque_curve.sample_baked(ratio)


func grip_at(slip_ratio: float) -> float:
	if grip_curve == null:
		return 1.0
	return grip_curve.sample_baked(clampf(slip_ratio, 0.0, 1.0))
