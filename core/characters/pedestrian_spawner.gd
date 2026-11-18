class_name PedestrianSpawner
extends Node3D
## Populates the level's pedestrian network: `counts[i]` pedestrians of
## `profiles[i]`, on random walkable cells away from the player.

@export var pedestrian_scene: PackedScene = preload("res://core/characters/pedestrian.tscn")
@export var profiles: Array[PedestrianProfile] = []
@export var counts: PackedInt32Array = []
@export_range(0.0, 200.0, 1.0, "suffix:m") var min_spawn_distance: float = 15.0
## 0 = random every run.
@export var random_seed: int = 0

var pedestrians: Array[Pedestrian] = []

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = random_seed if random_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0)
	var grid: LevelGrid = LevelGridNode.find_grid(get_tree())
	if grid == null:
		push_warning("PedestrianSpawner: no LevelGrid; no pedestrians")
		return
	var player := get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D
	for i: int in mini(profiles.size(), counts.size()):
		for n: int in counts[i]:
			var cell: Vector2i = _pick_cell(grid, player)
			if cell.x < 0:
				continue
			var pedestrian := pedestrian_scene.instantiate() as Pedestrian
			pedestrian.name = "%s%d" % [String(profiles[i].id).capitalize(), n]
			pedestrian.profile = profiles[i]
			pedestrian.grid = grid
			pedestrian.random_seed = _rng.randi()
			pedestrian.position = grid.cell_to_world(cell) + Vector3(
				_rng.randf_range(-1.2, 1.2), 0.05, _rng.randf_range(-1.2, 1.2))
			add_child(pedestrian)
			pedestrians.append(pedestrian)


func _pick_cell(grid: LevelGrid, player: Node3D) -> Vector2i:
	var cell := Vector2i(-1, -1)
	for attempt: int in 30:
		cell = grid.random_cell(_rng, LevelGrid.Network.PEDESTRIANS)
		if player == null or grid.cell_to_world(cell).distance_to(player.global_position) >= min_spawn_distance:
			return cell
	return cell
