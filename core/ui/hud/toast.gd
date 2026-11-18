class_name Toast
extends Label
## Big centred message that pops in, holds, and fades out. Messages queue up
## so none are lost.

@export_range(0.1, 10.0, 0.1, "suffix:s") var hold_time: float = 2.6
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_time: float = 0.4
@export_range(1.0, 2.0, 0.01) var pop_scale: float = 1.15

var _queue: Array[Dictionary] = []
var _showing: bool = false


func _ready() -> void:
	modulate.a = 0.0
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func show_message(message: String, color: Color = Color.WHITE, duration: float = -1.0) -> void:
	_queue.append({"text": message, "color": color, "duration": hold_time if duration < 0.0 else duration})
	if not _showing:
		_show_next()


func clear() -> void:
	_queue.clear()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var item: Dictionary = _queue.pop_front()
	text = item["text"]
	self_modulate = item["color"]
	scale = Vector2.ONE * pop_scale
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_time)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, fade_time).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(item["duration"])
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(_show_next)
