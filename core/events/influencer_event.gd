class_name InfluencerEvent
extends StreetEvent
## An influencer filming in the middle of the street with a ring light.
## Yells at anyone who speeds through the shot.

@export var pedestrian_scene: PackedScene = preload("res://core/characters/pedestrian.tscn")
@export var influencer_profile: PedestrianProfile = preload("res://core/characters/profiles/influencer.tres")
@export var ring_light_color: Color = Color(1.0, 0.97, 0.9)

var influencer: Pedestrian


func _on_begin(context: Dictionary) -> void:
	var rng: RandomNumberGenerator = context.get("rng", RandomNumberGenerator.new())
	influencer = pedestrian_scene.instantiate() as Pedestrian
	influencer.profile = influencer_profile
	influencer.random_seed = rng.randi()
	add_child(influencer)
	influencer.global_position = global_position + Vector3.UP * 0.05
	# Facing back down the route, towards the oncoming player.
	var player := context.get("player") as Node3D
	if player != null:
		var look: Vector3 = (player.global_position - global_position) * Vector3(1, 0, 1)
		if look.length_squared() > 0.01:
			influencer.get_node(^"Visual").rotation.y = atan2(-look.x, -look.z)
	_add_ring_light(influencer)


func _add_ring_light(holder: Pedestrian) -> void:
	var rig := Node3D.new()
	rig.name = "RingLight"
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.23
	var material := StandardMaterial3D.new()
	material.albedo_color = ring_light_color
	material.emission_enabled = true
	material.emission = ring_light_color
	material.emission_energy_multiplier = 2.0
	torus.material = material
	ring.mesh = torus
	ring.rotation.x = PI * 0.5
	rig.add_child(ring)
	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.015
	stick_mesh.bottom_radius = 0.015
	stick_mesh.height = 0.6
	stick.mesh = stick_mesh
	stick.position = Vector3.DOWN * 0.45
	rig.add_child(stick)
	rig.position = Vector3(0.0, 1.62, -0.55)
	holder.get_node(^"Visual").add_child(rig)
