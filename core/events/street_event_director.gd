class_name StreetEventDirector
extends Node
## Every so often, starts a random street event (from `event_scenes`) a bit
## further along the player's route. The game supplies the context with
## `context_provider` (a Callable returning the context Dictionary).

@export var event_scenes: Array[PackedScene] = []
@export_range(0.0, 600.0, 1.0, "suffix:s") var first_event_delay: float = 20.0
@export_range(1.0, 600.0, 1.0, "suffix:s") var min_interval: float = 35.0
@export_range(1.0, 600.0, 1.0, "suffix:s") var max_interval: float = 60.0
@export_range(1, 10, 1) var max_active: int = 1
## 0 = random every run.
@export var random_seed: int = 0

var context_provider: Callable
var active: Array[StreetEvent] = []
var running: bool = true

var _rng := RandomNumberGenerator.new()
var _next_in: float = 0.0


func _ready() -> void:
	_rng.seed = random_seed if random_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0)
	_next_in = first_event_delay


func _process(delta: float) -> void:
	if not running or event_scenes.is_empty():
		return
	_next_in -= delta
	if _next_in > 0.0:
		return
	_next_in = _rng.randf_range(min_interval, max_interval)
	if active.size() < max_active:
		start_event(event_scenes[_rng.randi() % event_scenes.size()])


## Starts an event now (also handy for testing and scripted moments).
func start_event(scene: PackedScene) -> StreetEvent:
	var event := scene.instantiate() as StreetEvent
	var context: Dictionary = context_provider.call() if context_provider.is_valid() else {}
	context["rng"] = _rng
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(event)
	active.append(event)
	event.finished.connect(func() -> void: active.erase(event))
	event.begin(context)
	return event
