extends Node
## Versioned JSON save file in user:// (autoload "SaveManager").
## Data is namespaced per system or mini-game ("core", "vespa_delivery"...),
## so mini-games shipped as separate apps don't collide.
## JSON rather than .tres: loading a .tres from disk can run embedded scripts.
## Writes go to a temp file first, then replace the save (no half-written saves).

signal saved
signal loaded

const SAVE_VERSION: int = 1

@export var save_dir: String = "user://saves"
@export var slot_name: String = "slot_0"

var _data: Dictionary = {}


func _ready() -> void:
	load_game()


func get_save_path() -> String:
	return save_dir.path_join(slot_name + ".json")


func get_value(section: StringName, key: StringName, default: Variant = null) -> Variant:
	var values: Dictionary = _data.get(String(section), {})
	return values.get(String(key), default)


## JSON stores every number as float; this returns it as int.
func get_int(section: StringName, key: StringName, default: int = 0) -> int:
	var value: Variant = get_value(section, key, default)
	return int(value) if (value is int or value is float) else default


func set_value(section: StringName, key: StringName, value: Variant) -> void:
	var section_key: String = String(section)
	if not _data.has(section_key):
		_data[section_key] = {}
	(_data[section_key] as Dictionary)[String(key)] = value


func clear() -> void:
	_data = {}


func save_game() -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		push_error("SaveManager: cannot create %s (%s)" % [save_dir, error_string(err)])
		return err
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"data": _data,
	}
	var temp_path: String = get_save_path() + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write %s (%s)" % [temp_path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	err = DirAccess.rename_absolute(temp_path, get_save_path())
	if err != OK:
		push_error("SaveManager: cannot replace %s (%s)" % [get_save_path(), error_string(err)])
		return err
	saved.emit()
	return OK


## Loads the slot. A missing file is a fresh game; an unreadable one is moved
## aside as .corrupt and also starts fresh.
func load_game() -> Error:
	_data = {}
	var path: String = get_save_path()
	if not FileAccess.file_exists(path):
		loaded.emit()
		return OK
	var text: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var payload: Dictionary = {}
	if json.parse(text) == OK and json.data is Dictionary:
		payload = json.data
	if not payload.get("data") is Dictionary:
		push_warning("SaveManager: %s is unreadable (%s at line %d); starting fresh (kept as .corrupt)" % [
			path, json.get_error_message(), json.get_error_line()])
		DirAccess.rename_absolute(path, path + ".corrupt")
		loaded.emit()
		return ERR_FILE_CORRUPT
	var data: Dictionary = payload["data"]
	_data = _migrate(int(payload.get("version", 0)), data)
	loaded.emit()
	return OK


## Upgrades data written by older versions. Add steps here when the format changes.
func _migrate(_from_version: int, data: Dictionary) -> Dictionary:
	return data
