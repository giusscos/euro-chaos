class_name TourGroupEvent
extends StreetEvent
## A guide with a raised umbrella leads a cluster of tourists slowly along
## the street, right across the player's route.

@export var pedestrian_scene: PackedScene = preload("res://core/characters/pedestrian.tscn")
@export var guide_profile: PedestrianProfile = preload("res://core/characters/profiles/guide.tres")
@export var tourist_profile: PedestrianProfile = preload("res://core/characters/profiles/tourist.tres")
@export_range(1, 30, 1) var group_size: int = 10
## How far the guide leads them.
@export_range(5.0, 300.0, 1.0, "suffix:m") var walk_distance: float = 60.0
@export var umbrella_color: Color = Color(0.95, 0.25, 0.3)

var guide: Pedestrian
var tourists: Array[Pedestrian] = []


func _on_begin(context: Dictionary) -> void:
	var rng: RandomNumberGenerator = context.get("rng", RandomNumberGenerator.new())
	guide = _spawn(guide_profile, global_position, rng)
	_add_umbrella(guide)
	# Tourists bunch up behind the guide, along the street (not into walls).
	var side: Vector3 = route_direction.cross(Vector3.UP)
	for i: int in group_size:
		var lateral: float = rng.randf_range(-1.4, 1.4)
		var back: float = rng.randf_range(1.0, 4.5)
		var tourist: Pedestrian = _spawn(tourist_profile,
			global_position + side * lateral - route_direction * back, rng)
		tourist.leader = guide
		tourist.follow_offset = Vector3(lateral, 0.0, back)
		tourists.append(tourist)
	# The guide strolls off somewhere along the walkable streets.
	var grid: LevelGrid = context.get("grid")
	if grid != null:
		guide.profile = guide_profile.duplicate() as PedestrianProfile
		guide.profile.wander_radius = walk_distance


func _on_finish() -> void:
	for tourist: Pedestrian in tourists:
		if is_instance_valid(tourist):
			tourist.leader = null


func _spawn(profile: PedestrianProfile, at: Vector3, rng: RandomNumberGenerator) -> Pedestrian:
	var pedestrian := pedestrian_scene.instantiate() as Pedestrian
	pedestrian.profile = profile
	pedestrian.random_seed = rng.randi()
	add_child(pedestrian)
	pedestrian.global_position = at + Vector3.UP * 0.05
	return pedestrian


func _add_umbrella(holder: Pedestrian) -> void:
	var umbrella := Node3D.new()
	umbrella.name = "Umbrella"
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.02
	pole_mesh.bottom_radius = 0.02
	pole_mesh.height = 1.3
	pole.mesh = pole_mesh
	pole.position = Vector3.UP * 0.65
	umbrella.add_child(pole)
	var canopy := MeshInstance3D.new()
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.04
	canopy_mesh.bottom_radius = 0.55
	canopy_mesh.height = 0.28
	var material := StandardMaterial3D.new()
	material.albedo_color = umbrella_color
	canopy_mesh.material = material
	canopy.mesh = canopy_mesh
	canopy.position = Vector3.UP * 1.35
	umbrella.add_child(canopy)
	umbrella.position = Vector3(0.3, 1.1, 0.0)
	holder.get_node(^"Visual").add_child(umbrella)
