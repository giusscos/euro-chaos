extends TestCase
## SaveManager, Settings and AudioManager autoloads.

const TEST_SAVE_DIR: String = "user://test_saves"
const TEST_SLOT: String = "test_slot"


func test_save_round_trip() -> void:
	var saves: Node = tree.root.get_node(^"SaveManager")
	var original_dir: String = saves.get(&"save_dir")
	var original_slot: String = saves.get(&"slot_name")
	saves.set(&"save_dir", TEST_SAVE_DIR)
	saves.set(&"slot_name", TEST_SLOT)

	saves.call(&"clear")
	saves.call(&"set_value", &"test", &"money", 1234)
	saves.call(&"set_value", &"test", &"name", "Nonna")
	expect(saves.call(&"save_game") == OK, "save_game failed")
	saves.call(&"clear")
	expect(saves.call(&"get_value", &"test", &"money") == null, "clear() did not clear")
	expect(saves.call(&"load_game") == OK, "load_game failed")
	expect(saves.call(&"get_int", &"test", &"money") == 1234, "money did not survive a round trip")
	expect(saves.call(&"get_value", &"test", &"name") == "Nonna", "string did not survive a round trip")
	expect(saves.call(&"get_int", &"test", &"missing", 7) == 7, "default not returned for missing key")

	# A corrupt file is moved aside and the game starts fresh.
	var path: String = saves.call(&"get_save_path")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	expect(saves.call(&"load_game") == ERR_FILE_CORRUPT, "corrupt save not reported")
	expect(saves.call(&"get_value", &"test", &"money") == null, "corrupt save left stale data")
	expect(FileAccess.file_exists(path + ".corrupt"), "corrupt save not kept aside")

	DirAccess.remove_absolute(path + ".corrupt")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TEST_SAVE_DIR)
	saves.set(&"save_dir", original_dir)
	saves.set(&"slot_name", original_slot)
	saves.call(&"load_game")


func test_bus_layout_and_volumes() -> void:
	for bus: StringName in [AudioBuses.MASTER, AudioBuses.MUSIC, AudioBuses.SFX, AudioBuses.UI]:
		expect(AudioServer.get_bus_index(bus) >= 0, "bus %s missing from default_bus_layout.tres" % bus)
	var settings: Node = tree.root.get_node(^"Settings")
	var before: float = settings.call(&"get_volume", AudioBuses.SFX)
	settings.call(&"set_volume", AudioBuses.SFX, 0.5)
	var index: int = AudioServer.get_bus_index(AudioBuses.SFX)
	expect(is_equal_approx(AudioServer.get_bus_volume_db(index), linear_to_db(0.5)), "SFX volume not applied")
	settings.call(&"set_volume", AudioBuses.SFX, 0.0)
	expect(AudioServer.is_bus_mute(index), "volume 0 should mute the bus")
	settings.call(&"set_volume", AudioBuses.SFX, before)


func test_placeholder_sounds_exist() -> void:
	var audio: Node = tree.root.get_node(^"AudioManager")
	for id: StringName in ProceduralSfx.IDS:
		var stream := audio.call(&"get_stream", id) as AudioStreamWAV
		expect(stream != null and stream.data.size() > 0, "no placeholder sound for %s" % id)
	var engine: AudioStreamWAV = ProceduralSfx.engine_loop()
	expect(engine.loop_mode == AudioStreamWAV.LOOP_FORWARD, "engine sound must loop")
	audio.call(&"play", &"pickup")
	audio.call(&"play_at", &"horn", Vector3.ZERO)
	await tree.process_frame
