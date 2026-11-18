class_name Groups
extends RefCounted
## Scene-tree group names used across systems (no raw strings in code).

## The body the player currently controls (vehicle now, character later).
const PLAYER: StringName = &"player"
## MissionLocation nodes, looked up by id.
const MISSION_LOCATION: StringName = &"mission_location"
## Where the player (re)appears in a level.
const PLAYER_SPAWN: StringName = &"player_spawn"
## The LevelGridNode of the current level.
const LEVEL_GRID: StringName = &"level_grid"
## Pedestrians (for horn scares, near misses, events).
const PEDESTRIANS: StringName = &"pedestrians"
## AI traffic vehicles.
const TRAFFIC: StringName = &"traffic"
