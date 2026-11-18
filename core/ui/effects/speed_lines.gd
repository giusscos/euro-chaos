class_name SpeedLines
extends CanvasLayer
## Screen-space speed streaks that fade in as `target` goes fast.

@export var target: Node3D
## No streaks below this speed, full streaks at full_speed_kmh.
@export_range(0.0, 300.0, 1.0, "suffix:km/h") var start_speed_kmh: float = 40.0
@export_range(1.0, 300.0, 1.0, "suffix:km/h") var full_speed_kmh: float = 75.0
@export_range(0.1, 20.0, 0.1) var response: float = 4.0

const KMH_PER_MS: float = 3.6

var intensity: float = 0.0

@onready var _rect: ColorRect = $Lines


func _process(delta: float) -> void:
	var body := target as RigidBody3D
	var speed_kmh: float = body.linear_velocity.length() * KMH_PER_MS if body != null else 0.0
	var wanted: float = smoothstep(start_speed_kmh, full_speed_kmh, speed_kmh)
	intensity = lerpf(intensity, wanted, 1.0 - exp(-response * delta))
	(_rect.material as ShaderMaterial).set_shader_parameter(&"intensity", intensity)
	_rect.visible = intensity > 0.01
