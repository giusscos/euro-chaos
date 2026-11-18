class_name GreyboxMapBuilder
extends RefCounted
## Turns an ASCII map into a greybox level: ground, upper-town plateau,
## ramps, houses, shops, customer doors, trees, fountain, pier, sea, map
## bounds, MissionLocations and the player spawn.
## Same map + seed = same scene. See the legend at the top of
## res://minigames/vespa_delivery/levels/village_map.txt.
##
## Header lines "@key = value" override DEFAULTS; "@name.<char>" and
## "@id.<char>" name the shop/customer locations. Lines starting with ";"
## are comments. The grid starts after a line "[map]".

const BLOCK_SCRIPT: GDScript = preload("res://core/levels/greybox/greybox_block.gd")
const LOCATION_SCRIPT: GDScript = preload("res://core/missions/mission_location.gd")
const HAZARD_SCRIPT: GDScript = preload("res://core/interaction/hazard_zone.gd")
## Prop scenes placed by map characters.
const PROP_SCENES: Dictionary = {
	"k": preload("res://core/levels/props/cafe_set.tscn"),
	"f": preload("res://core/levels/props/fruit_stand.tscn"),
}

const DEFAULTS: Dictionary = {
	"cell_size": 4.0,
	"plateau_height": 6.0,
	"seed": 1,
	"spawn_heading": 0.0,
	"ground_thickness": 1.0,
	"floor_height": 3.2,
	"min_floors": 2,
	"max_floors": 4,
	"house_min_cells": 2,
	"house_max_cells": 3,
	"roof_overhang": 0.25,
	"roof_thickness": 0.3,
	"church_height": 12.0,
	"tower_height": 22.0,
	"shop_floors": 2,
	"kiosk_height": 3.2,
	"location_offset": 2.5,
	"boundary_height": 1.5,
	"water_level": -0.6,
	"sea_floor": -25.0,
	"sea_margin": 300.0,
	"spawn_lift": 0.3,
	"bollard_height": 0.9,
	"bollard_diameter": 0.25,
	## Bollards sit this far either side of the alley centre: the gaps let
	## scooters and pedestrians through, not cars.
	"bollard_offset": 0.65,
}

const DRIVABLE: String = ".=PSbghwtkf"
const RAMPS: String = "^v<>"
const DIGITS: String = "123456789"
## Doors face the most open street within this many cells.
const DOOR_SCAN_RADIUS: int = 2

const COLORS: Dictionary = {
	"street": Color(0.62, 0.58, 0.52),
	"road": Color(0.3, 0.3, 0.33),
	"piazza": Color(0.82, 0.78, 0.7),
	"sand": Color(0.93, 0.85, 0.62),
	"grass": Color(0.45, 0.62, 0.35),
	"plateau": Color(0.7, 0.64, 0.54),
	"wood": Color(0.55, 0.4, 0.26),
	"door": Color(0.33, 0.21, 0.14),
	"stone": Color(0.58, 0.56, 0.54),
	"church": Color(0.95, 0.93, 0.86),
	"pizzeria": Color(0.96, 0.9, 0.8),
	"awning": Color(0.82, 0.18, 0.16),
	"kiosk": Color(0.62, 0.9, 0.84),
	"kiosk_awning": Color(0.98, 0.6, 0.72),
	"trunk": Color(0.42, 0.3, 0.2),
	"leaves": Color(0.32, 0.55, 0.28),
	"water": Color(0.18, 0.45, 0.62),
	"roof": Color(0.66, 0.32, 0.22),
	"roof_dark": Color(0.52, 0.26, 0.2),
	"bollard": Color(0.25, 0.25, 0.27),
}
const HOUSE_PALETTE: Array[Color] = [
	Color(0.86, 0.66, 0.38), Color(0.82, 0.48, 0.34), Color(0.93, 0.72, 0.68),
	Color(0.93, 0.88, 0.75), Color(0.95, 0.84, 0.5), Color(0.68, 0.75, 0.6),
	Color(0.64, 0.74, 0.82), Color(0.95, 0.6, 0.47),
]
const DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## Problems found while building. Empty = success.
var errors: PackedStringArray = []
## Counts of what was built (for logs and tests).
var stats: Dictionary = {}

var _config: Dictionary = {}
var _names: Dictionary = {}
var _ids: Dictionary = {}
var _grid: PackedStringArray = []
var _width: int = 0
var _height: int = 0
var _cell: float = 4.0
var _plateau: float = 6.0
var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _groups: Dictionary = {}
## Ramp cell -> [centre height, uphill direction (1..4, see LevelGrid)].
var _ramp_cells: Dictionary = {}


func build(map_text: String, source_name: String = "map") -> Node3D:
	errors.clear()
	stats.clear()
	_parse(map_text)
	if not errors.is_empty():
		return null
	_cell = _cfg_float("cell_size")
	_plateau = _cfg_float("plateau_height")
	_rng.seed = _cfg_int("seed")

	_root = Node3D.new()
	_root.name = source_name.get_file().get_basename().to_pascal_case()
	_root.editor_description = "Generated from %s by tools/levels/build_greybox_map.gd.\nDon't edit by hand: change the map and rebuild." % source_name
	for group_name: String in ["Ground", "Plateau", "Ramps", "Buildings", "Details", "Props", "Bounds", "Sea", "Locations"]:
		var group := Node3D.new()
		group.name = group_name
		_root.add_child(group)
		_groups[group_name] = group

	var doors: Dictionary = _find_doors()
	_build_ground()
	_build_plateau(doors)
	_build_ramps()
	_build_grid()
	_build_buildings(doors)
	_build_details()
	_build_bollards()
	_build_bounds()
	_build_sea()
	_build_spawn()
	if not errors.is_empty():
		_root.free()
		return null
	_set_owner_recursive(_root, _root)
	return _root


# --- Parsing ------------------------------------------------------------

func _parse(text: String) -> void:
	_config = DEFAULTS.duplicate()
	_grid.clear()
	var in_map: bool = false
	var line_number: int = 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line: String = raw_line.strip_edges(false, true)
		if in_map:
			if line != "":
				_grid.append(line)
			continue
		var trimmed: String = line.strip_edges()
		if trimmed == "" or trimmed.begins_with(";"):
			continue
		if trimmed == "[map]":
			in_map = true
			continue
		if trimmed.begins_with("@") and trimmed.contains("="):
			var key: String = trimmed.substr(1, trimmed.find("=") - 1).strip_edges()
			var value: String = trimmed.substr(trimmed.find("=") + 1).strip_edges()
			if key.begins_with("name."):
				_names[key.substr(5)] = value
			elif key.begins_with("id."):
				_ids[key.substr(3)] = value
			elif DEFAULTS.has(key):
				_config[key] = value
			else:
				errors.append("line %d: unknown setting '%s'" % [line_number, key])
			continue
		errors.append("line %d: unexpected text before [map]: %s" % [line_number, trimmed])
	if _grid.is_empty():
		errors.append("no [map] grid found")
		return
	_height = _grid.size()
	_width = _grid[0].length()
	for y: int in _height:
		if _grid[y].length() != _width:
			errors.append("map row %d is %d wide, expected %d" % [y, _grid[y].length(), _width])
	var known: String = DRIVABLE + RAMPS + DIGITS + "#HCZGF~"
	for y: int in _height:
		for x: int in _grid[y].length():
			if not known.contains(_grid[y][x]):
				errors.append("map row %d col %d: unknown character '%s'" % [y, x, _grid[y][x]])
	stats["size"] = Vector2(_width * _cfg_float("cell_size"), _height * _cfg_float("cell_size"))


func _cfg_float(key: String) -> float:
	return float(str(_config[key]))


func _cfg_int(key: String) -> int:
	return int(str(_config[key]))


func _at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= _width or y >= _height:
		return ""
	return _grid[y][x]


# --- Cell helpers -------------------------------------------------------

func _is_drivable(c: String) -> bool:
	return c != "" and (DRIVABLE.contains(c) or RAMPS.contains(c))


func _is_plateau_cell(x: int, y: int) -> bool:
	var c: String = _at(x, y)
	return c == "h" or c == "H"


## Top height of the walkable/buildable surface of a cell (ramps excluded).
func _level(x: int, y: int) -> float:
	return _plateau if _is_plateau_cell(x, y) else 0.0


func _cell_center(x: float, y: float) -> Vector3:
	return Vector3((x + 0.5) * _cell - _width * _cell * 0.5, 0.0, (y + 0.5) * _cell - _height * _cell * 0.5)


func _rect_center(rect: Rect2i) -> Vector3:
	return _cell_center(rect.position.x + (rect.size.x - 1) * 0.5, rect.position.y + (rect.size.y - 1) * 0.5)


## Greedy merge of cells into rectangles, per key. keys: Vector2i -> String.
func _merge(keys: Dictionary) -> Array[Array]:
	var used: Dictionary = {}
	var result: Array[Array] = []
	for y: int in _height:
		for x: int in _width:
			var start := Vector2i(x, y)
			if used.has(start) or not keys.has(start):
				continue
			var key: String = keys[start]
			var x_end: int = x
			while keys.get(Vector2i(x_end + 1, y), "") == key and not used.has(Vector2i(x_end + 1, y)):
				x_end += 1
			var y_end: int = y
			var can_grow: bool = true
			while can_grow:
				for xx: int in range(x, x_end + 1):
					var next := Vector2i(xx, y_end + 1)
					if keys.get(next, "") != key or used.has(next):
						can_grow = false
						break
				if can_grow:
					y_end += 1
			for yy: int in range(y, y_end + 1):
				for xx: int in range(x, x_end + 1):
					used[Vector2i(xx, yy)] = true
			result.append([key, Rect2i(x, y, x_end - x + 1, y_end - y + 1)])
	return result


func _block(group: String, node_name: String, size: Vector3, center: Vector3, color: Color,
		basis: Basis = Basis.IDENTITY, shape: int = 0, grid: float = 1.0, collision: bool = true,
		shadows: bool = true) -> StaticBody3D:
	var block := BLOCK_SCRIPT.new() as StaticBody3D
	block.name = node_name
	block.set(&"shape", shape)
	block.set(&"size", size)
	block.set(&"color", color)
	block.set(&"grid_strength", grid)
	block.set(&"has_collision", collision)
	block.set(&"cast_shadows", shadows)
	block.transform = Transform3D(basis, center)
	(_groups[group] as Node3D).add_child(block, true)
	stats[group] = int(stats.get(group, 0)) + 1
	return block


# --- Layers -------------------------------------------------------------

func _build_ground() -> void:
	var keys: Dictionary = {}
	for y: int in _height:
		for x: int in _width:
			var c: String = _at(x, y)
			var key: String = ""
			if "=".contains(c):
				key = "road"
			elif "PSFCk".contains(c):
				key = "piazza"
			elif "bG".contains(c):
				key = "sand"
			elif "gt".contains(c):
				key = "grass"
			elif c != "~" and c != "w":
				key = "street"
			if key != "":
				keys[Vector2i(x, y)] = key
	var thickness: float = _cfg_float("ground_thickness")
	for entry: Array in _merge(keys):
		var rect: Rect2i = entry[1]
		var center: Vector3 = _rect_center(rect) + Vector3.DOWN * thickness * 0.5
		_block("Ground", "Ground", Vector3(rect.size.x * _cell, thickness, rect.size.y * _cell),
			center, COLORS[entry[0]], Basis.IDENTITY, 0, 1.0, true, false)


func _build_plateau(doors: Dictionary) -> void:
	var keys: Dictionary = {}
	for y: int in _height:
		for x: int in _width:
			if _is_plateau_cell(x, y):
				keys[Vector2i(x, y)] = "plateau"
	# Customer houses whose door opens on the upper town stand on it too.
	for c: String in doors:
		var door: Dictionary = doors[c]
		if float(door["level"]) > 0.0:
			for cell: Vector2i in door["cells"]:
				keys[cell] = "plateau"
	for entry: Array in _merge(keys):
		var rect: Rect2i = entry[1]
		_block("Plateau", "Plateau", Vector3(rect.size.x * _cell, _plateau, rect.size.y * _cell),
			_rect_center(rect) + Vector3.UP * _plateau * 0.5, COLORS["plateau"])


func _build_ramps() -> void:
	var keys: Dictionary = {}
	for y: int in _height:
		for x: int in _width:
			if RAMPS.contains(_at(x, y)):
				keys[Vector2i(x, y)] = _at(x, y)
	for entry: Array in _merge(keys):
		var c: String = entry[0]
		var rect: Rect2i = entry[1]
		var uphill: Vector3 = {"^": Vector3.FORWARD, "v": Vector3.BACK, "<": Vector3.LEFT, ">": Vector3.RIGHT}[c]
		var vertical: bool = c == "^" or c == "v"
		var run: float = (rect.size.y if vertical else rect.size.x) * _cell
		var across: float = (rect.size.x if vertical else rect.size.y) * _cell
		var angle: float = atan2(_plateau, run)
		var side: Vector3 = Vector3.UP.cross(uphill).normalized()
		var along: Vector3 = uphill * cos(angle) + Vector3.UP * sin(angle)
		var normal: Vector3 = along.cross(side)
		var thickness: float = _plateau + _cfg_float("ground_thickness")
		var top_center: Vector3 = _rect_center(rect) + Vector3.UP * _plateau * 0.5
		var basis := Basis(side, normal, side.cross(normal))
		_block("Ramps", "Ramp", Vector3(across, thickness, sqrt(run * run + _plateau * _plateau)),
			top_center - normal * thickness * 0.5, COLORS["street"], basis)
		_record_ramp_cells(c, rect)


## Remembers each ramp cell's centre height and uphill direction for the grid.
func _record_ramp_cells(c: String, rect: Rect2i) -> void:
	var dir: int = "^>v<".find(c) + 1
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var fraction: float = 0.0
			match c:
				"^":
					fraction = (rect.end.y - (y + 0.5)) / rect.size.y
				"v":
					fraction = (y + 0.5 - rect.position.y) / rect.size.y
				"<":
					fraction = (rect.end.x - (x + 0.5)) / rect.size.x
				">":
					fraction = (x + 0.5 - rect.position.x) / rect.size.x
			_ramp_cells[Vector2i(x, y)] = [_plateau * fraction, dir]


## Writes the walkable/drivable layout (LevelGrid) into the scene.
func _build_grid() -> void:
	var grid := LevelGrid.new()
	grid.setup(Vector2i(_width, _height), _cell, Vector3(-_width * _cell * 0.5, 0.0, -_height * _cell * 0.5))
	var kinds: Dictionary = {
		".": LevelGrid.Kind.STREET, "=": LevelGrid.Kind.ROAD, "P": LevelGrid.Kind.PIAZZA,
		"S": LevelGrid.Kind.PIAZZA, "h": LevelGrid.Kind.PLATEAU, "b": LevelGrid.Kind.BEACH,
		"g": LevelGrid.Kind.GRASS, "w": LevelGrid.Kind.PIER, "~": LevelGrid.Kind.WATER,
		"k": LevelGrid.Kind.PIAZZA, "f": LevelGrid.Kind.STREET,
	}
	for y: int in _height:
		for x: int in _width:
			var cell := Vector2i(x, y)
			var c: String = _at(x, y)
			if _ramp_cells.has(cell):
				var ramp: Array = _ramp_cells[cell]
				grid.set_cell(cell, LevelGrid.Kind.RAMP, ramp[0], ramp[1])
			else:
				grid.set_cell(cell, kinds.get(c, LevelGrid.Kind.BLOCKED), _level(x, y))
	var holder := LevelGridNode.new()
	holder.name = "LevelGrid"
	holder.grid = grid
	_root.add_child(holder)
	stats["CarCells"] = grid.usable_cell_count(LevelGrid.Network.CARS)
	stats["ScooterCells"] = grid.usable_cell_count(LevelGrid.Network.SCOOTERS)
	stats["WalkCells"] = grid.usable_cell_count(LevelGrid.Network.PEDESTRIANS)


## For every shop/customer building: the best street cell in front of it.
## Returns building char -> {cells, door_cell, street_cell, direction, level}.
func _find_doors() -> Dictionary:
	var doors: Dictionary = {}
	var specials: Dictionary = {}
	for y: int in _height:
		for x: int in _width:
			var c: String = _at(x, y)
			if DIGITS.contains(c) or c == "Z" or c == "G":
				if not specials.has(c):
					specials[c] = []
				(specials[c] as Array).append(Vector2i(x, y))
	for c: String in specials:
		var cells: Array = specials[c]
		var best: Dictionary = {}
		var best_score: int = -1
		for cell: Vector2i in cells:
			for dir: Vector2i in DIRECTIONS:
				var street: Vector2i = cell + dir
				var street_char: String = _at(street.x, street.y)
				if not _is_drivable(street_char) or RAMPS.contains(street_char) or cells.has(street):
					continue
				# Prefer doors on open spaces: count drivable (non-ramp) cells nearby.
				var score: int = 0
				for dy: int in range(-DOOR_SCAN_RADIUS, DOOR_SCAN_RADIUS + 1):
					for dx: int in range(-DOOR_SCAN_RADIUS, DOOR_SCAN_RADIUS + 1):
						var around: String = _at(street.x + dx, street.y + dy)
						if _is_drivable(around) and not RAMPS.contains(around):
							score += 1
				if score > best_score:
					best_score = score
					best = {"door_cell": cell, "street_cell": street, "direction": dir}
		if best.is_empty():
			errors.append("'%s' at %s has no street next to it for a door" % [c, cells[0]])
			continue
		var street_cell: Vector2i = best["street_cell"]
		best["cells"] = cells
		best["level"] = _level(street_cell.x, street_cell.y)
		doors[c] = best
	return doors


func _build_buildings(doors: Dictionary) -> void:
	var keys: Dictionary = {}
	for y: int in _height:
		for x: int in _width:
			var c: String = _at(x, y)
			if c == "#":
				keys[Vector2i(x, y)] = "house@0"
			elif c == "H":
				keys[Vector2i(x, y)] = "house@1"
			elif c == "C":
				keys[Vector2i(x, y)] = "church"
	for entry: Array in _merge(keys):
		var key: String = entry[0]
		var rect: Rect2i = entry[1]
		if key == "church":
			_build_church(rect)
		else:
			var base: float = _plateau if key == "house@1" else 0.0
			for part: Rect2i in _split_block(rect):
				_build_house(part, base, _random_floors())
	for c: String in doors:
		var door: Dictionary = doors[c]
		var cells: Array = door["cells"]
		var rect := Rect2i(cells[0], Vector2i.ONE)
		for cell: Vector2i in cells:
			rect = rect.expand(cell).expand(cell + Vector2i.ONE)
		var level: float = door["level"]
		match c:
			"Z":
				_build_house(rect, level, _cfg_int("shop_floors"), COLORS["pizzeria"])
				_build_shop_front(door, COLORS["awning"], 3.2)
			"G":
				_build_kiosk(rect, level)
				_build_shop_front(door, COLORS["kiosk_awning"], 2.4)
			_:
				_build_house(rect, level, _random_floors())
		_build_door(door, c)


func _random_floors() -> int:
	return _rng.randi_range(_cfg_int("min_floors"), _cfg_int("max_floors"))


## Splits a long block of houses into individual houses.
func _split_block(rect: Rect2i) -> Array[Rect2i]:
	var parts: Array[Rect2i] = []
	var rows: Array[Rect2i] = [rect]
	# Deep blocks become two rows of houses back to back.
	if rect.size.y >= 4 and rect.size.x * 2 >= rect.size.y:
		var half: int = floori(rect.size.y / 2.0)
		rows = [Rect2i(rect.position, Vector2i(rect.size.x, half)),
			Rect2i(rect.position + Vector2i(0, half), Vector2i(rect.size.x, rect.size.y - half))]
	elif rect.size.x >= 4 and rect.size.y > rect.size.x:
		var half_x: int = floori(rect.size.x / 2.0)
		rows = [Rect2i(rect.position, Vector2i(half_x, rect.size.y)),
			Rect2i(rect.position + Vector2i(half_x, 0), Vector2i(rect.size.x - half_x, rect.size.y))]
	var min_cells: int = _cfg_int("house_min_cells")
	var max_cells: int = _cfg_int("house_max_cells")
	for row: Rect2i in rows:
		var along_x: bool = row.size.x >= row.size.y
		var length: int = row.size.x if along_x else row.size.y
		var start: int = 0
		while start < length:
			var piece: int = mini(_rng.randi_range(min_cells, max_cells), length - start)
			if length - start - piece < min_cells and length - start - piece > 0:
				piece = length - start
			if along_x:
				parts.append(Rect2i(row.position + Vector2i(start, 0), Vector2i(piece, row.size.y)))
			else:
				parts.append(Rect2i(row.position + Vector2i(0, start), Vector2i(row.size.x, piece)))
			start += piece
	return parts


func _build_house(rect: Rect2i, base: float, floors: int, color: Color = Color(0, 0, 0, 0)) -> void:
	var height: float = floors * _cfg_float("floor_height") + _rng.randf_range(-0.4, 0.4)
	var wall_color: Color = color if color.a > 0.0 else HOUSE_PALETTE[_rng.randi() % HOUSE_PALETTE.size()]
	var size := Vector3(rect.size.x * _cell, height, rect.size.y * _cell)
	var center: Vector3 = _rect_center(rect) + Vector3.UP * (base + height * 0.5)
	_block("Buildings", "House", size, center, wall_color, Basis.IDENTITY, 0, 0.2)
	var overhang: float = _cfg_float("roof_overhang")
	# Slightly random thickness so touching roofs never share a plane (z-fighting).
	var roof: float = _cfg_float("roof_thickness") + _rng.randf_range(0.0, 0.08)
	var roof_color: Color = COLORS["roof"] if _rng.randf() < 0.7 else COLORS["roof_dark"]
	_block("Buildings", "Roof", Vector3(size.x + overhang * 2.0, roof, size.z + overhang * 2.0),
		center + Vector3.UP * (height * 0.5 + roof * 0.5), roof_color, Basis.IDENTITY, 0, 0.3)


func _build_church(rect: Rect2i) -> void:
	var height: float = _cfg_float("church_height")
	_block("Buildings", "Church", Vector3(rect.size.x * _cell, height, rect.size.y * _cell),
		_rect_center(rect) + Vector3.UP * height * 0.5, COLORS["church"], Basis.IDENTITY, 0, 0.15)
	var tower: float = _cfg_float("tower_height")
	var corner := Rect2i(rect.position + Vector2i(rect.size.x - 1, 0), Vector2i.ONE)
	_block("Buildings", "BellTower", Vector3(_cell, tower, _cell),
		_rect_center(corner) + Vector3.UP * tower * 0.5, COLORS["church"], Basis.IDENTITY, 0, 0.15)
	_block("Buildings", "TowerRoof", Vector3(_cell + 0.6, 0.6, _cell + 0.6),
		_rect_center(corner) + Vector3.UP * (tower + 0.3), COLORS["roof_dark"], Basis.IDENTITY, 0, 0.3)


func _build_kiosk(rect: Rect2i, base: float) -> void:
	var height: float = _cfg_float("kiosk_height")
	var inset: float = 0.6
	var size := Vector3(rect.size.x * _cell - inset * 2.0, height, rect.size.y * _cell - inset * 2.0)
	_block("Buildings", "Kiosk", size, _rect_center(rect) + Vector3.UP * (base + height * 0.5),
		COLORS["kiosk"], Basis.IDENTITY, 0, 0.2)


func _door_frame(door: Dictionary) -> Dictionary:
	var dir: Vector2i = door["direction"]
	var facing := Vector3(dir.x, 0, dir.y)
	var door_cell: Vector2i = door["door_cell"]
	var facade: Vector3 = _cell_center(door_cell.x, door_cell.y) + facing * _cell * 0.5
	return {"facing": facing, "facade": facade, "basis": Basis.looking_at(-facing)}


func _build_door(door: Dictionary, c: String) -> void:
	var frame: Dictionary = _door_frame(door)
	var facing: Vector3 = frame["facing"]
	var facade: Vector3 = frame["facade"]
	var level: float = door["level"]
	_block("Details", "Door", Vector3(1.4, 2.4, 0.2), facade + facing * 0.1 + Vector3.UP * (level + 1.2),
		COLORS["door"], frame["basis"], 0, 0.0, false)

	var display_name: String = _names.get(c, "Address %s" % c)
	var label := Label3D.new()
	label.name = "Sign"
	label.text = display_name
	label.font_size = 36
	label.pixel_size = 0.01
	label.outline_size = 10
	label.double_sided = false
	label.transform = Transform3D(frame["basis"], facade + facing * 0.15 + Vector3.UP * (level + 3.0))
	(_groups["Details"] as Node3D).add_child(label, true)

	var location := LOCATION_SCRIPT.new() as Marker3D
	location.name = "Location_%s" % c
	location.set(&"location_id", StringName(_ids.get(c, "address_%s" % c)))
	location.set(&"display_name", display_name)
	location.transform = Transform3D(frame["basis"],
		facade + facing * _cfg_float("location_offset") + Vector3.UP * level)
	(_groups["Locations"] as Node3D).add_child(location, true)
	stats["Locations"] = int(stats.get("Locations", 0)) + 1


func _build_shop_front(door: Dictionary, awning_color: Color, height: float) -> void:
	var frame: Dictionary = _door_frame(door)
	var facing: Vector3 = frame["facing"]
	var level: float = door["level"]
	_block("Details", "Awning", Vector3(_cell * 0.9, 0.15, 1.6),
		frame["facade"] + facing * 0.8 + Vector3.UP * (level + height), awning_color, frame["basis"],
		0, 0.0, false)


func _build_details() -> void:
	var fountain_keys: Dictionary = {}
	var pier_keys: Dictionary = {}
	for y: int in _height:
		for x: int in _width:
			var c: String = _at(x, y)
			if c == "t":
				var base: Vector3 = _cell_center(x, y)
				_block("Details", "TreeTrunk", Vector3(0.5, 3.0, 0.5), base + Vector3.UP * 1.5,
					COLORS["trunk"], Basis.IDENTITY, 1, 0.0)
				_block("Details", "TreeTop", Vector3(3.4, 3.4, 3.4), base + Vector3.UP * 4.0,
					COLORS["leaves"], Basis.IDENTITY, 2, 0.0)
			elif c == "F":
				fountain_keys[Vector2i(x, y)] = "fountain"
			elif c == "w":
				pier_keys[Vector2i(x, y)] = "pier"
			elif PROP_SCENES.has(c):
				var prop := (PROP_SCENES[c] as PackedScene).instantiate() as Node3D
				prop.name = "Prop"
				prop.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), _cell_center(x, y) + Vector3.UP * _level(x, y))
				(_groups["Props"] as Node3D).add_child(prop, true)
				stats["Props"] = int(stats.get("Props", 0)) + 1
	for entry: Array in _merge(fountain_keys):
		var rect: Rect2i = entry[1]
		var center: Vector3 = _rect_center(rect)
		var diameter: float = mini(rect.size.x, rect.size.y) * _cell * 0.9
		_block("Details", "FountainBasin", Vector3(diameter, 0.7, diameter), center + Vector3.UP * 0.35,
			COLORS["stone"], Basis.IDENTITY, 1, 0.3)
		_block("Details", "FountainWater", Vector3(diameter * 0.85, 0.05, diameter * 0.85),
			center + Vector3.UP * 0.62, COLORS["water"], Basis.IDENTITY, 1, 0.0, false, false)
		_block("Details", "FountainColumn", Vector3(0.6, 2.4, 0.6), center + Vector3.UP * 1.2,
			COLORS["stone"], Basis.IDENTITY, 1, 0.3)
		_block("Details", "FountainTop", Vector3(0.9, 0.9, 0.9), center + Vector3.UP * 2.6,
			COLORS["stone"], Basis.IDENTITY, 2, 0.3)
	for entry: Array in _merge(pier_keys):
		var rect: Rect2i = entry[1]
		_block("Details", "PierDeck", Vector3(rect.size.x * _cell, 0.4, rect.size.y * _cell),
			_rect_center(rect) + Vector3.DOWN * 0.2, COLORS["wood"], Basis.IDENTITY, 0, 0.6)
		for row: int in rect.size.y:
			for side: int in [0, 1]:
				var x: float = rect.position.x - 0.5 + side * rect.size.x
				var post: Vector3 = _cell_center(x, rect.position.y + row) + Vector3(0.3 if side == 0 else -0.3, 0, 0)
				_block("Details", "PierPost", Vector3(0.35, 6.0, 0.35), post + Vector3.DOWN * 3.0,
					COLORS["wood"], Basis.IDENTITY, 1, 0.0)


## Posts across every alley mouth that opens onto a road ("=" cells), like
## the entrance of an Italian limited-traffic zone.
func _build_bollards() -> void:
	var height: float = _cfg_float("bollard_height")
	var diameter: float = _cfg_float("bollard_diameter")
	var offset: float = _cfg_float("bollard_offset")
	for y: int in _height:
		for x: int in _width:
			if _at(x, y) != "=":
				continue
			for dir: Vector2i in DIRECTIONS:
				var next: Vector2i = Vector2i(x, y) + dir
				var c: String = _at(next.x, next.y)
				if c == "" or c == "=" or not _is_drivable(c) or "bgw".contains(c):
					continue
				var boundary: Vector3 = _cell_center(x, y) + Vector3(dir.x, 0, dir.y) * _cell * 0.5
				var across := Vector3(absf(dir.y), 0, absf(dir.x))
				for side: float in [-1.0, 1.0]:
					_block("Details", "Bollard", Vector3(diameter, height, diameter),
						boundary + across * offset * side + Vector3.UP * (_level(next.x, next.y) + height * 0.5),
						COLORS["bollard"], Basis.IDENTITY, 1, 0.0)


func _build_bounds() -> void:
	var extra: float = _cfg_float("boundary_height")
	var thickness: float = 1.0
	# side: [cells along the edge, outward direction]
	var sides: Array = [
		[_edge_cells(Vector2i(0, 0), Vector2i(1, 0), _width), Vector3.FORWARD],
		[_edge_cells(Vector2i(0, _height - 1), Vector2i(1, 0), _width), Vector3.BACK],
		[_edge_cells(Vector2i(0, 0), Vector2i(0, 1), _height), Vector3.LEFT],
		[_edge_cells(Vector2i(_width - 1, 0), Vector2i(0, 1), _height), Vector3.RIGHT],
	]
	for side: Array in sides:
		var cells: Array = side[0]
		var outward: Vector3 = side[1]
		var run_start: int = 0
		while run_start < cells.size():
			var cell: Vector2i = cells[run_start]
			var top: float = _level(cell.x, cell.y) + extra
			if _at(cell.x, cell.y) == "~":
				run_start += 1
				continue
			var run_end: int = run_start
			while run_end + 1 < cells.size():
				var next: Vector2i = cells[run_end + 1]
				if _at(next.x, next.y) == "~" or not is_equal_approx(_level(next.x, next.y) + extra, top):
					break
				run_end += 1
			var first: Vector3 = _cell_center(cells[run_start].x, cells[run_start].y)
			var last: Vector3 = _cell_center(cells[run_end].x, cells[run_end].y)
			var length: float = first.distance_to(last) + _cell
			var center: Vector3 = (first + last) * 0.5 + outward * (_cell * 0.5 + thickness * 0.5)
			var size := Vector3(length, top, thickness) if outward.x == 0.0 else Vector3(thickness, top, length)
			_block("Bounds", "Wall", size, center + Vector3.UP * top * 0.5, COLORS["stone"], Basis.IDENTITY, 0, 0.5)
			run_start = run_end + 1


func _edge_cells(start: Vector2i, step: Vector2i, count: int) -> Array:
	var cells: Array = []
	for i: int in count:
		cells.append(start + step * i)
	return cells


func _build_sea() -> void:
	var margin: float = _cfg_float("sea_margin")
	var extent := Vector2(_width * _cell + margin * 2.0, _height * _cell + margin * 2.0)
	var water_level: float = _cfg_float("water_level")
	var sea_floor: float = _cfg_float("sea_floor")
	var sea: Node3D = _groups["Sea"]

	var water := MeshInstance3D.new()
	water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = extent
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS["water"]
	material.roughness = 0.15
	plane.material = material
	water.mesh = plane
	water.position = Vector3.UP * water_level
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.add_child(water)

	var hazard := HAZARD_SCRIPT.new() as Area3D
	hazard.name = "WaterHazard"
	hazard.set(&"hazard_id", &"water")
	var top: float = water_level - 0.3
	var shape := CollisionShape3D.new()
	shape.name = "Volume"
	var box := BoxShape3D.new()
	box.size = Vector3(extent.x, top - sea_floor, extent.y)
	shape.shape = box
	hazard.add_child(shape)
	hazard.position = Vector3.UP * (sea_floor + top) * 0.5
	sea.add_child(hazard)

	_block("Sea", "SeaFloor", Vector3(extent.x, 1.0, extent.y), Vector3.UP * (sea_floor - 0.5),
		COLORS["sand"], Basis.IDENTITY, 0, 0.0, true, false)


func _build_spawn() -> void:
	for y: int in _height:
		for x: int in _width:
			if _at(x, y) != "S":
				continue
			var spawn := Marker3D.new()
			spawn.name = "PlayerSpawn"
			var heading: float = deg_to_rad(-_cfg_float("spawn_heading"))
			spawn.transform = Transform3D(Basis(Vector3.UP, heading),
				_cell_center(x, y) + Vector3.UP * (_level(x, y) + _cfg_float("spawn_lift")))
			spawn.add_to_group(Groups.PLAYER_SPAWN, true)
			_root.add_child(spawn)
			return
	errors.append("no player spawn 'S' in the map")


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		# Instanced scenes (props) keep their own children.
		if child.scene_file_path == "":
			_set_owner_recursive(child, owner)
