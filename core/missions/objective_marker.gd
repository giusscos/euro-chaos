class_name ObjectiveMarker
extends Node3D
## A glowing ring + light beam + floating label, with an Interactable zone.
## Visible from far away so the player can find it.

signal reached(body: Node3D)

@export var color: Color = Color(0.3, 1.0, 0.5):
	set(value):
		color = value
		if is_node_ready():
			_apply_color()
@export var label_text: String = "":
	set(value):
		label_text = value
		if is_node_ready():
			_label.text = value
## Ring pulse: scale amplitude and speed (Hz).
@export_range(0.0, 0.5, 0.01) var pulse_amount: float = 0.06
@export_range(0.0, 5.0, 0.05, "suffix:Hz") var pulse_speed: float = 1.2

@onready var interactable: Interactable = $Interactable
@onready var _ring: MeshInstance3D = $Ring
@onready var _beam: MeshInstance3D = $Beam
@onready var _label: Label3D = $Label

var _time: float = 0.0


func _ready() -> void:
	# Each marker gets its own materials so colours don't leak between them.
	_ring.material_override = _ring.material_override.duplicate()
	_beam.material_override = _beam.material_override.duplicate()
	_label.text = label_text
	_apply_color()
	interactable.activated.connect(func(body: Node3D) -> void: reached.emit(body))


func _process(delta: float) -> void:
	_time += delta
	var pulse: float = 1.0 + sin(_time * TAU * pulse_speed) * pulse_amount
	_ring.scale = Vector3(pulse, 1.0, pulse)


func _apply_color() -> void:
	var ring_material := _ring.material_override as StandardMaterial3D
	ring_material.albedo_color = color
	ring_material.emission = color
	var beam_material := _beam.material_override as StandardMaterial3D
	beam_material.albedo_color = Color(color, beam_material.albedo_color.a)
	beam_material.emission = color
	_label.modulate = color.lightened(0.4)
