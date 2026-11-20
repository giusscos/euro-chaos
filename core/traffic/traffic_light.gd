class_name TrafficLight
extends Node3D
## Controls a junction: one axis (X or Z) has green while the other waits,
## with yellow and an all-red gap in between. Cells it controls are marked
## in the LevelGrid (light index). Builds its own greybox poles and lamps.

enum Phase { GREEN, YELLOW, ALL_RED }

@export var light_index: int = 0
## Junction footprint (metres) to place the poles at its corners.
@export var junction_size: Vector2 = Vector2(8.0, 8.0)
@export_range(1.0, 60.0, 0.5, "suffix:s") var green_time: float = 8.0
@export_range(0.0, 10.0, 0.5, "suffix:s") var yellow_time: float = 2.0
@export_range(0.0, 10.0, 0.5, "suffix:s") var all_red_time: float = 1.0
## Desynchronises neighbouring lights.
@export_range(0.0, 60.0, 0.5, "suffix:s") var start_offset: float = 0.0
@export_range(0.5, 10.0, 0.1, "suffix:m") var pole_height: float = 3.2

## Which axis is (or was last) green: true = X (east-west), false = Z.
var x_axis_green: bool = true
var phase: Phase = Phase.GREEN

var _time: float = 0.0
var _lamps: Dictionary = {}


func _ready() -> void:
	add_to_group(Groups.TRAFFIC_LIGHTS)
	_time = start_offset
	_build_visual()
	_update_phase()


func _process(delta: float) -> void:
	_time += delta
	_update_phase()


## True if a vehicle moving along `direction` may enter now (green only).
func can_enter(direction: Vector3) -> bool:
	return phase == Phase.GREEN and _is_x(direction) == x_axis_green


## True if entering along `direction` now is running a red light.
func is_red_for(direction: Vector3) -> bool:
	if phase == Phase.ALL_RED:
		return true
	return _is_x(direction) != x_axis_green


static func find(tree: SceneTree, index: int) -> TrafficLight:
	for node: Node in tree.get_nodes_in_group(Groups.TRAFFIC_LIGHTS):
		var light := node as TrafficLight
		if light != null and light.light_index == index:
			return light
	return null


func _update_phase() -> void:
	var cycle: float = (green_time + yellow_time + all_red_time) * 2.0
	var t: float = fmod(_time, cycle)
	var half: float = cycle * 0.5
	x_axis_green = t < half
	var local: float = t - (0.0 if x_axis_green else half)
	if local < green_time:
		phase = Phase.GREEN
	elif local < green_time + yellow_time:
		phase = Phase.YELLOW
	else:
		phase = Phase.ALL_RED
	_update_lamps()


func _is_x(direction: Vector3) -> bool:
	return absf(direction.x) >= absf(direction.z)


func _build_visual() -> void:
	var half := Vector3(junction_size.x * 0.5 + 0.4, 0.0, junction_size.y * 0.5 + 0.4)
	for corner: Vector3 in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, half.z)]:
		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.06
		pole_mesh.bottom_radius = 0.06
		pole_mesh.height = pole_height
		pole.mesh = pole_mesh
		pole.position = corner + Vector3.UP * pole_height * 0.5
		add_child(pole)
		for axis_is_x: bool in [true, false]:
			var head_offset := Vector3(0.0, pole_height - 0.2, 0.0) + (Vector3(0, 0, 0.25) if axis_is_x else Vector3(0.25, 0, 0))
			for colour_index: int in 3:
				var lamp := MeshInstance3D.new()
				var sphere := SphereMesh.new()
				sphere.radius = 0.12
				sphere.height = 0.24
				lamp.mesh = sphere
				lamp.position = corner + head_offset + Vector3.DOWN * 0.28 * colour_index
				lamp.material_override = StandardMaterial3D.new()
				add_child(lamp)
				var key: String = "%s%d" % ["x" if axis_is_x else "z", colour_index]
				if not _lamps.has(key):
					_lamps[key] = []
				(_lamps[key] as Array).append(lamp)


func _update_lamps() -> void:
	for axis_is_x: bool in [true, false]:
		var green_here: bool = axis_is_x == x_axis_green
		var lit: int = 0  # 0 red, 1 yellow, 2 green
		if green_here and phase == Phase.GREEN:
			lit = 2
		elif green_here and phase == Phase.YELLOW:
			lit = 1
		for colour_index: int in 3:
			var base: Color = [Color(1, 0.15, 0.1), Color(1, 0.75, 0.1), Color(0.2, 1, 0.3)][colour_index]
			var on: bool = colour_index == lit
			for lamp: MeshInstance3D in _lamps.get("%s%d" % ["x" if axis_is_x else "z", colour_index], []):
				var material := lamp.material_override as StandardMaterial3D
				material.albedo_color = base if on else base.darkened(0.8)
				material.emission_enabled = on
				material.emission = base
