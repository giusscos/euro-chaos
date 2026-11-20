class_name PoliceLights
extends Node3D
## Flashing roof lights and siren for police vehicles.

@export var flash_rate: float = 3.0
@export var siren_on: bool = true:
	set(value):
		siren_on = value
		if is_node_ready():
			_update_siren()
@export var bar_width: float = 0.9
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var siren_volume_db: float = -6.0
@export_range(0.1, 100.0, 0.1, "suffix:m") var siren_unit_size: float = 12.0

var _left: StandardMaterial3D
var _right: StandardMaterial3D
var _siren: AudioStreamPlayer3D
var _time: float = 0.0


func _ready() -> void:
	_left = _lamp(Vector3(-bar_width * 0.5, 0.0, 0.0), Color(1.0, 0.15, 0.1))
	_right = _lamp(Vector3(bar_width * 0.5, 0.0, 0.0), Color(0.15, 0.35, 1.0))
	_siren = AudioStreamPlayer3D.new()
	_siren.stream = ProceduralSfx.siren_loop()
	_siren.bus = AudioBuses.SFX
	_siren.volume_db = siren_volume_db
	_siren.unit_size = siren_unit_size
	add_child(_siren)
	_update_siren()


func _process(delta: float) -> void:
	_time += delta
	var left_on: bool = fmod(_time * flash_rate, 1.0) < 0.5
	_left.emission_enabled = left_on
	_right.emission_enabled = not left_on


func _update_siren() -> void:
	if siren_on and not _siren.playing:
		_siren.play()
	elif not siren_on:
		_siren.stop()


func _lamp(at: Vector3, color: Color) -> StandardMaterial3D:
	var lamp := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(bar_width * 0.45, 0.12, 0.25)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = 3.0
	box.material = material
	lamp.mesh = box
	lamp.position = at
	add_child(lamp)
	return material
