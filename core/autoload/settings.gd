extends Node
## Player preferences in user://settings.cfg (autoload "Settings").
## Phase 1: audio volumes and camera options. The settings menu comes in
## Phase 5; until then edit the file or call set_volume().

signal changed

const SETTINGS_PATH: String = "user://settings.cfg"
const AUDIO_SECTION: String = "audio"
const CAMERA_SECTION: String = "camera"

## Linear 0..1 volume per bus.
var volumes: Dictionary[StringName, float] = {
	AudioBuses.MASTER: 1.0,
	AudioBuses.MUSIC: 0.8,
	AudioBuses.SFX: 1.0,
	AudioBuses.UI: 1.0,
}
var camera_invert_y: bool = false
var mouse_sensitivity_scale: float = 1.0


func _ready() -> void:
	load_settings()
	apply()


func set_volume(bus: StringName, linear: float) -> void:
	volumes[bus] = clampf(linear, 0.0, 1.0)
	apply()
	changed.emit()


func get_volume(bus: StringName) -> float:
	return volumes.get(bus, 1.0)


func apply() -> void:
	for bus: StringName in volumes:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var linear: float = volumes[bus]
		AudioServer.set_bus_mute(index, linear <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


func save_settings() -> Error:
	var config := ConfigFile.new()
	for bus: StringName in volumes:
		config.set_value(AUDIO_SECTION, String(bus), volumes[bus])
	config.set_value(CAMERA_SECTION, "invert_y", camera_invert_y)
	config.set_value(CAMERA_SECTION, "mouse_sensitivity_scale", mouse_sensitivity_scale)
	return config.save(SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for bus: StringName in volumes.keys():
		volumes[bus] = clampf(float(config.get_value(AUDIO_SECTION, String(bus), volumes[bus])), 0.0, 1.0)
	camera_invert_y = bool(config.get_value(CAMERA_SECTION, "invert_y", camera_invert_y))
	mouse_sensitivity_scale = float(config.get_value(CAMERA_SECTION, "mouse_sensitivity_scale", mouse_sensitivity_scale))
