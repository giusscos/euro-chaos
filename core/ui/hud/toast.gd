class_name Toast
extends Label
## Big centred message that pops in, holds, and fades out. Newest wins: a
## message stays at least min_display_time, then a newer one replaces it
## (stale news is useless in a race). At most max_pending wait.

@export_range(0.1, 10.0, 0.1, "suffix:s") var hold_time: float = 2.6
@export_range(0.0, 2.0, 0.05, "suffix:s") var fade_time: float = 0.35
## A newer message can replace this one after this long.
@export_range(0.0, 5.0, 0.05, "suffix:s") var min_display_time: float = 0.6
@export_range(0.0, 1.0, 0.01, "suffix:s") var replace_fade_time: float = 0.12
@export_range(1, 10, 1) var max_pending: int = 1
@export_range(1.0, 2.0, 0.01) var pop_scale: float = 1.15

var _queue: Array[Dictionary] = []
var _showing: bool = false
var _leaving: bool = false
var _age: float = 0.0
var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func show_message(message: String, color: Color = Color.WHITE, duration: float = -1.0) -> void:
	_queue.append({"text": message, "color": color, "duration": hold_time if duration < 0.0 else duration})
	while _queue.size() > max_pending:
		_queue.pop_front()
	if not _showing:
		_show_next()


func clear() -> void:
	_queue.clear()


func _process(delta: float) -> void:
	if not _showing:
		return
	_age += delta
	if not _queue.is_empty() and not _leaving and _age >= min_display_time:
		_leaving = true
		if _tween != null:
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 0.0, replace_fade_time)
		_tween.tween_callback(_show_next)


func _show_next() -> void:
	_leaving = false
	_age = 0.0
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var item: Dictionary = _queue.pop_front()
	text = item["text"]
	self_modulate = item["color"]
	scale = Vector2.ONE * pop_scale
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, fade_time)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, fade_time).set_trans(Tween.TRANS_BACK)
	_tween.tween_interval(item["duration"])
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)
	_tween.tween_callback(_show_next)
