class_name LevelGrid
extends Resource
## Walkable/drivable layout of a grid level, written by GreyboxMapBuilder.
## Pedestrians and traffic ask it for paths (AStar2D over cell centres).
## Two cells connect only if you can really move between them: same height,
## or along a ramp (never up a cliff).

enum Kind { BLOCKED, STREET, ROAD, PIAZZA, PLATEAU, RAMP, BEACH, GRASS, PIER, WATER }
## Uphill direction of ramp cells (index into DIRECTIONS + 1; 0 = not a ramp).
const DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Ramp ends may differ from the cell beyond them by up to this much.
const RAMP_END_TOLERANCE: float = 1.0

## Kinds traffic may drive on (piazzas, beaches and grass are off limits).
const DRIVE_KINDS: Array[Kind] = [Kind.STREET, Kind.ROAD, Kind.PLATEAU, Kind.RAMP]
## Kinds pedestrians may walk on.
const WALK_KINDS: Array[Kind] = [Kind.STREET, Kind.ROAD, Kind.PIAZZA, Kind.PLATEAU, Kind.RAMP,
	Kind.BEACH, Kind.GRASS, Kind.PIER]

@export var cell_size: float = 4.0
@export var size: Vector2i = Vector2i.ZERO
## World position of the corner of cell (0, 0) (minimum x and z).
@export var origin: Vector3 = Vector3.ZERO
## One Kind per cell, row-major.
@export var kinds: PackedByteArray = []
## Surface height per cell centre (ramps interpolated), row-major.
@export var heights: PackedFloat32Array = []
## Uphill direction per cell (0 = none, 1..4 = DIRECTIONS index + 1).
@export var ramp_dirs: PackedByteArray = []

var _astar_cache: Dictionary = {}


func setup(grid_size: Vector2i, cell: float, corner: Vector3) -> void:
	size = grid_size
	cell_size = cell
	origin = corner
	kinds.resize(size.x * size.y)
	kinds.fill(Kind.BLOCKED)
	heights.resize(size.x * size.y)
	heights.fill(0.0)
	ramp_dirs.resize(size.x * size.y)
	ramp_dirs.fill(0)
	_astar_cache.clear()


func set_cell(cell: Vector2i, kind: Kind, height: float, ramp_dir: int = 0) -> void:
	var i: int = _index(cell)
	kinds[i] = kind
	heights[i] = height
	ramp_dirs[i] = ramp_dir
	_astar_cache.clear()


func has_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func get_kind(cell: Vector2i) -> Kind:
	return kinds[_index(cell)] as Kind if has_cell(cell) else Kind.BLOCKED


func get_height(cell: Vector2i) -> float:
	return heights[_index(cell)] if has_cell(cell) else 0.0


func is_walkable(cell: Vector2i) -> bool:
	return WALK_KINDS.has(get_kind(cell))


func is_drivable(cell: Vector2i) -> bool:
	return DRIVE_KINDS.has(get_kind(cell))


func cell_to_world(cell: Vector2i) -> Vector3:
	return origin + Vector3((cell.x + 0.5) * cell_size, get_height(cell), (cell.y + 0.5) * cell_size)


func world_to_cell(position: Vector3) -> Vector2i:
	return Vector2i(floori((position.x - origin.x) / cell_size), floori((position.z - origin.z) / cell_size))


## Path of world points (cell centres) from one position to another, or empty
## if there is none. for_vehicles uses the drivable cells only.
func find_path(from: Vector3, to: Vector3, for_vehicles: bool) -> PackedVector3Array:
	var astar: AStar2D = _get_astar(for_vehicles)
	var start: int = _nearest_point(astar, world_to_cell(from))
	var goal: int = _nearest_point(astar, world_to_cell(to))
	var result := PackedVector3Array()
	if start < 0 or goal < 0:
		return result
	for id: int in astar.get_id_path(start, goal):
		result.append(cell_to_world(_cell_of(id)))
	return result


## A random cell traffic or pedestrians can use, or (-1, -1) if there is none.
func random_cell(rng: RandomNumberGenerator, for_vehicles: bool) -> Vector2i:
	var astar: AStar2D = _get_astar(for_vehicles)
	var ids: PackedInt64Array = astar.get_point_ids()
	if ids.is_empty():
		return Vector2i(-1, -1)
	return _cell_of(ids[rng.randi_range(0, ids.size() - 1)])


## Number of cells reachable for vehicles or pedestrians.
func usable_cell_count(for_vehicles: bool) -> int:
	return _get_astar(for_vehicles).get_point_count()


func are_connected(a: Vector2i, b: Vector2i) -> bool:
	if absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false
	var dir_a: int = ramp_dirs[_index(a)]
	var dir_b: int = ramp_dirs[_index(b)]
	var step: Vector2i = b - a
	var height_gap: float = absf(get_height(a) - get_height(b))
	if dir_a == 0 and dir_b == 0:
		return height_gap < 0.01
	# At least one ramp: only along its slope, never off its sides.
	for ramp: Array in [[dir_a, step], [dir_b, -step]]:
		var dir: int = ramp[0]
		if dir == 0:
			continue
		var uphill: Vector2i = DIRECTIONS[dir - 1]
		var along: Vector2i = ramp[1]
		if along != uphill and along != -uphill:
			return false
	# Two cells of the same ramp always connect; a ramp end must meet the
	# ground (or plateau) at about its own height.
	if dir_a != 0 and dir_b != 0:
		return dir_a == dir_b
	return height_gap <= RAMP_END_TOLERANCE


func _get_astar(for_vehicles: bool) -> AStar2D:
	if _astar_cache.has(for_vehicles):
		return _astar_cache[for_vehicles]
	var astar := AStar2D.new()
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			if (is_drivable(cell) if for_vehicles else is_walkable(cell)):
				astar.add_point(_index(cell), Vector2(x, y))
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			if not astar.has_point(_index(cell)):
				continue
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var next: Vector2i = cell + step
				if has_cell(next) and astar.has_point(_index(next)) and are_connected(cell, next):
					astar.connect_points(_index(cell), _index(next))
	_astar_cache[for_vehicles] = astar
	return astar


func _nearest_point(astar: AStar2D, cell: Vector2i) -> int:
	if astar.get_point_count() == 0:
		return -1
	if has_cell(cell) and astar.has_point(_index(cell)):
		return _index(cell)
	return astar.get_closest_point(Vector2(cell))


func _index(cell: Vector2i) -> int:
	return cell.y * size.x + cell.x


func _cell_of(id: int) -> Vector2i:
	return Vector2i(id % size.x, floori(float(id) / size.x))
