class_name VehicleAudio
extends Node3D
## Engine loop pitched by speed and throttle, plus the horn. Child of an
## ArcadeVehicle (or set `vehicle`). Without an engine_stream it uses a
## procedural two-stroke buzz.

@export var vehicle: ArcadeVehicle
@export var engine_stream: AudioStream
@export var horn_id: StringName = &"horn"

@export_group("Engine")
@export_range(0.1, 4.0, 0.01) var idle_pitch: float = 0.7
@export_range(0.1, 4.0, 0.01) var top_speed_pitch: float = 2.1
## Extra pitch when the throttle is held (revving).
@export_range(0.0, 2.0, 0.01) var throttle_pitch: float = 0.25
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var idle_volume_db: float = -16.0
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var full_volume_db: float = -7.0
## How fast pitch and volume follow the engine (1/s).
@export_range(0.1, 50.0, 0.1) var response: float = 6.0
@export_range(0.1, 100.0, 0.1, "suffix:m") var unit_size: float = 6.0

var _engine: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _was_honking: bool = false


func _ready() -> void:
	if vehicle == null:
		vehicle = get_parent() as ArcadeVehicle
	_engine = AudioStreamPlayer3D.new()
	_engine.stream = engine_stream if engine_stream != null else ProceduralSfx.engine_loop()
	_engine.bus = AudioBuses.SFX
	_engine.unit_size = unit_size
	_engine.volume_db = idle_volume_db
	_engine.pitch_scale = idle_pitch
	add_child(_engine)
	_engine.play()
	_horn = AudioStreamPlayer3D.new()
	_horn.stream = AudioManager.get_stream(horn_id)
	_horn.bus = AudioBuses.SFX
	_horn.unit_size = unit_size
	add_child(_horn)


func _process(delta: float) -> void:
	if vehicle == null:
		return
	var speed_ratio: float = clampf(absf(vehicle.forward_speed) / vehicle.stats.top_speed(), 0.0, 1.0)
	var throttle: float = maxf(vehicle.intent.throttle, vehicle.intent.brake)
	var blend: float = 1.0 - exp(-response * delta)
	var target_pitch: float = lerpf(idle_pitch, top_speed_pitch, speed_ratio) + throttle * throttle_pitch
	var target_volume: float = lerpf(idle_volume_db, full_volume_db, maxf(speed_ratio, throttle))
	_engine.pitch_scale = lerpf(_engine.pitch_scale, target_pitch, blend)
	_engine.volume_db = lerpf(_engine.volume_db, target_volume, blend)

	var honking: bool = vehicle.intent.horn
	if honking and not _was_honking:
		_horn.play()
		Events.horn_honked.emit(vehicle)
	_was_honking = honking
