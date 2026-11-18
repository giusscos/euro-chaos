class_name MiniGame
extends Node
## Root script of every mini-game's main scene.
## Booted directly (F6 or as an app's main scene) it starts itself, so each
## mini-game runs on its own. Subclasses override _on_start / _on_finish.

signal started
signal finished(result: Dictionary)

@export var info: MiniGameInfo
## Start as soon as the scene is ready. Turn off if a launcher starts it.
@export var autostart: bool = true

var is_running: bool = false


func _ready() -> void:
	if info == null:
		push_warning("%s has no MiniGameInfo assigned" % name)
	if autostart:
		start()


func get_id() -> StringName:
	return info.id if info != null else StringName(name)


func start() -> void:
	if is_running:
		return
	is_running = true
	GameState.active_minigame_id = get_id()
	_on_start()
	started.emit()
	Events.minigame_started.emit(get_id())


func finish(result: Dictionary = {}) -> void:
	if not is_running:
		return
	is_running = false
	_on_finish(result)
	finished.emit(result)
	Events.minigame_finished.emit(get_id(), result)


## Override in subclasses.
func _on_start() -> void:
	pass


## Override in subclasses.
func _on_finish(_result: Dictionary) -> void:
	pass
