extends TestCase
## LevelGrid pathfinding (ramps yes, cliffs no) and village connectivity.

const VILLAGE_GENERATED: String = "res://minigames/vespa_delivery/levels/village_greybox.tscn"

## Upper town (h) on the left, reachable only by the ramp in column 4.
const RAMP_MAP: String = """
@cell_size = 4
@plateau_height = 4
[map]
hhhhh....
hhhhh....
####^....
####^....
S........
"""


func test_paths_use_ramps_not_cliffs() -> void:
	var grid: LevelGrid = _build_grid(RAMP_MAP)
	if grid == null:
		return
	var low: Vector3 = grid.cell_to_world(Vector2i(8, 0))
	var high: Vector3 = grid.cell_to_world(Vector2i(0, 0))
	for for_vehicles: bool in [true, false]:
		var path: PackedVector3Array = grid.find_path(low, high, for_vehicles)
		expect(path.size() > 1, "no path to the upper town (vehicles=%s)" % for_vehicles)
		var used_ramp: bool = false
		for i: int in range(1, path.size()):
			var a: Vector2i = grid.world_to_cell(path[i - 1])
			var b: Vector2i = grid.world_to_cell(path[i])
			expect(grid.are_connected(a, b), "path jumps %s -> %s" % [a, b])
			expect(absf(path[i].y - path[i - 1].y) <= grid.cell_size * 0.5,
				"path climbs %.1f m between %s and %s" % [absf(path[i].y - path[i - 1].y), a, b])
			if grid.get_kind(b) == LevelGrid.Kind.RAMP:
				used_ramp = true
		expect(used_ramp, "path to the upper town should use the ramp (vehicles=%s)" % for_vehicles)
	expect(not grid.are_connected(Vector2i(5, 1), Vector2i(4, 1)), "cliff edge should not connect")
	expect(not grid.are_connected(Vector2i(5, 2), Vector2i(4, 2)), "ramp side should not connect")
	expect(grid.are_connected(Vector2i(4, 3), Vector2i(4, 4)), "ramp bottom should connect to the street")
	expect(grid.are_connected(Vector2i(4, 2), Vector2i(4, 1)), "ramp top should connect to the upper town")


func test_piazza_is_walkable_not_drivable() -> void:
	var grid: LevelGrid = _build_grid("[map]\n..PP..\n..PS..\n")
	if grid == null:
		return
	expect(grid.is_walkable(Vector2i(2, 0)) and not grid.is_drivable(Vector2i(2, 0)),
		"piazza should be walk-only")
	expect(grid.is_drivable(Vector2i(0, 0)), "street should be drivable")


func test_village_networks_are_connected() -> void:
	var holder: Node = (load(VILLAGE_GENERATED) as PackedScene).instantiate()
	var grid: LevelGrid = (holder.find_child("LevelGrid", false) as LevelGridNode).grid
	for for_vehicles: bool in [true, false]:
		var cells: Array[Vector2i] = []
		for y: int in grid.size.y:
			for x: int in grid.size.x:
				var cell := Vector2i(x, y)
				if (grid.is_drivable(cell) if for_vehicles else grid.is_walkable(cell)):
					cells.append(cell)
		var start: Vector3 = grid.cell_to_world(cells[0])
		var unreachable: Array[Vector2i] = []
		for cell: Vector2i in cells:
			var path: PackedVector3Array = grid.find_path(start, grid.cell_to_world(cell), for_vehicles)
			if path.is_empty() or grid.world_to_cell(path[path.size() - 1]) != cell:
				unreachable.append(cell)
		note("%s: %d cells, %d unreachable %s" % ["drive" if for_vehicles else "walk", cells.size(),
			unreachable.size(), unreachable.slice(0, 6)])
		expect(unreachable.is_empty(), "%d %s cells are cut off from the rest" % [unreachable.size(),
			"drive" if for_vehicles else "walk"])
	holder.free()


func _build_grid(map_text: String) -> LevelGrid:
	var builder := GreyboxMapBuilder.new()
	var root: Node3D = builder.build(map_text, "grid_test")
	expect(root != null, "map failed: %s" % [builder.errors])
	if root == null:
		return null
	var grid: LevelGrid = (root.find_child("LevelGrid", false) as LevelGridNode).grid
	root.free()
	return grid
