extends Node
## Changes scenes with background (threaded) loading and a simple
## loading overlay (autoload "SceneLoader").

signal scene_changed(path: String)

@export var overlay_color: Color = Color(0.08, 0.08, 0.1, 1.0)
@export var overlay_layer: int = 100

var _pending_path: String = ""
var _overlay: CanvasLayer
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	set_process(false)


func is_loading() -> bool:
	return _pending_path != ""


func change_scene(path: String) -> void:
	if is_loading():
		push_warning("SceneLoader: already loading %s" % _pending_path)
		return
	var err: Error = ResourceLoader.load_threaded_request(path, "PackedScene")
	if err != OK:
		push_error("SceneLoader: cannot load %s (%s)" % [path, error_string(err)])
		return
	_pending_path = path
	_label.text = "Loading…"
	_overlay.visible = true
	set_process(true)


func _process(_delta: float) -> void:
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_pending_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var ratio: float = progress[0] if not progress.is_empty() else 0.0
			_label.text = "Loading… %d%%" % roundi(ratio * 100.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(_pending_path) as PackedScene
			_finish(packed)
		_:
			push_error("SceneLoader: failed to load %s" % _pending_path)
			_finish(null)


func _finish(packed: PackedScene) -> void:
	var path: String = _pending_path
	_pending_path = ""
	set_process(false)
	_overlay.visible = false
	if packed == null:
		return
	get_tree().paused = false
	var err: Error = get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("SceneLoader: cannot open %s (%s)" % [path, error_string(err)])
		return
	scene_changed.emit(path)


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = overlay_layer
	_overlay.visible = false
	add_child(_overlay)

	var background := ColorRect.new()
	background.color = overlay_color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(background)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(_label)
