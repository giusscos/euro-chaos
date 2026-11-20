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

## A vehicle honked (pedestrians hop aside).
@warning_ignore("unused_signal")
signal horn_honked(source: Node3D)

## A pedestrian was knocked over.
@warning_ignore("unused_signal")
signal pedestrian_hit(pedestrian: Node3D, by: Node3D, speed: float)

## The player caused chaos worth `amount` points at `position`.
@warning_ignore("unused_signal")
signal chaos_caused(amount: int, position: Vector3, label: String)

## The player whizzed past something without hitting it.
@warning_ignore("unused_signal")
signal near_miss(thing: Node3D, distance: float)

## A street event started (tour group, influencer...): a line for the HUD.
@warning_ignore("unused_signal")
signal street_event_started(message: String, position: Vector3)

## A witnessed offence by the player (kind: &"speeding", &"wrong_way",
## &"red_light", &"mayhem"); `heat` is how much wanted level it adds.
@warning_ignore("unused_signal")
signal violation_committed(kind: StringName, position: Vector3, heat: float)

## A speed camera fined the player.
@warning_ignore("unused_signal")
signal speed_camera_fined(fine: int, position: Vector3)

## The player was busted by the police (fine charged) or escaped.
@warning_ignore("unused_signal")
signal busted(fine: int)
@warning_ignore("unused_signal")
signal police_escaped

## The player entered a HazardZone (e.g. &"water").
@warning_ignore("unused_signal")
signal hazard_entered(hazard_id: StringName, body: Node3D)

## An Interactable wants its prompt shown (text) or hidden (empty text).
@warning_ignore("unused_signal")
signal interaction_prompt_changed(source: Node, text: String)
