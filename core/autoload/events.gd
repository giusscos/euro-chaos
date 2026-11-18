extends Node
## Global signal bus (autoload "Events").
## Only for events that cross system boundaries. Inside a scene, prefer
## direct signals between nodes.

@warning_ignore("unused_signal")
signal minigame_started(id: StringName)

@warning_ignore("unused_signal")
signal minigame_finished(id: StringName, result: Dictionary)

@warning_ignore("unused_signal")
signal vehicle_teleported(vehicle: Node3D)
