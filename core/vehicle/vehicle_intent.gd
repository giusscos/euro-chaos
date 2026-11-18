class_name VehicleIntent
extends RefCounted
## What a driver wants this physics tick. Written by a controller (player,
## traffic AI, police AI, test script), read by ArcadeVehicle.

## 0..1
var throttle: float = 0.0
## 0..1. Brakes while moving forward, reverses when (almost) stopped.
var brake: float = 0.0
## -1 (full left) .. +1 (full right)
var steer: float = 0.0
var handbrake: bool = false
var horn: bool = false


func clear() -> void:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	handbrake = false
	horn = false
