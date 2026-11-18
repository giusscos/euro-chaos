class_name FloatingText
extends Label3D
## A short world-space message ("+5 Chaos!") that rises and fades away.

@export_range(0.1, 10.0, 0.1, "suffix:s") var lifetime: float = 1.4
@export_range(0.0, 10.0, 0.1, "suffix:m/s") var rise_speed: float = 1.6

var _age: float = 0.0


## Spawns a floating message at `at` under `parent`.
static func spawn(parent: Node, message: String, at: Vector3, color: Color = Color.WHITE) -> FloatingText:
	var label := FloatingText.new()
	label.text = message
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56
	label.outline_size = 14
	label.pixel_size = 0.01
	parent.add_child(label)
	label.global_position = at
	return label


func _process(delta: float) -> void:
	_age += delta
	position.y += rise_speed * delta
	modulate.a = clampf(1.0 - _age / lifetime, 0.0, 1.0)
	if _age >= lifetime:
		queue_free()
