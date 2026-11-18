extends Node
## Plays sound effects by id from pooled players (autoload "AudioManager").
## Ids map to streams in `library`; any standard id without a stream gets a
## procedural placeholder (ProceduralSfx), so the game always has sound.
## Music: one track at a time with a crossfade.

const SILENT_DB: float = -80.0

@export var library: Dictionary[StringName, AudioStream] = {}
@export_range(1, 64, 1) var pool_size: int = 12
@export_range(1, 64, 1) var pool_size_3d: int = 12
@export_range(0.0, 10.0, 0.1, "suffix:s") var music_fade_time: float = 1.5
## 3D sounds: distance (m) where volume starts to drop.
@export_range(0.1, 100.0, 0.1, "suffix:m") var unit_size: float = 8.0

var _players: Array[AudioStreamPlayer] = []
var _players_3d: Array[AudioStreamPlayer3D] = []
var _music_players: Array[AudioStreamPlayer] = []
var _active_music: int = 0
var _next_player: int = 0
var _next_player_3d: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in pool_size:
		var player := AudioStreamPlayer.new()
		player.bus = AudioBuses.SFX
		add_child(player)
		_players.append(player)
	for i: int in pool_size_3d:
		var player_3d := AudioStreamPlayer3D.new()
		player_3d.bus = AudioBuses.SFX
		player_3d.unit_size = unit_size
		add_child(player_3d)
		_players_3d.append(player_3d)
	for i: int in 2:
		var music := AudioStreamPlayer.new()
		music.bus = AudioBuses.MUSIC
		add_child(music)
		_music_players.append(music)


func register(id: StringName, stream: AudioStream) -> void:
	library[id] = stream


## The stream for an id: from the library, else a procedural placeholder.
func get_stream(id: StringName) -> AudioStream:
	if library.has(id):
		return library[id]
	var generated: AudioStreamWAV = ProceduralSfx.generate(id)
	if generated == null:
		push_warning("AudioManager: no sound for id '%s'" % id)
		return null
	library[id] = generated
	return generated


## Non-positional sound (UI, stingers).
func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0, bus: StringName = AudioBuses.SFX) -> void:
	var stream: AudioStream = get_stream(id)
	if stream == null:
		return
	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.bus = bus
	player.play()


## Sound at a point in the world.
func play_at(id: StringName, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = get_stream(id)
	if stream == null:
		return
	var player: AudioStreamPlayer3D = _players_3d[_next_player_3d]
	_next_player_3d = (_next_player_3d + 1) % _players_3d.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.global_position = position
	player.play()


func play_music(stream: AudioStream) -> void:
	var outgoing: AudioStreamPlayer = _music_players[_active_music]
	_active_music = 1 - _active_music
	var incoming: AudioStreamPlayer = _music_players[_active_music]
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(incoming, "volume_db", 0.0, music_fade_time)
	if outgoing.playing:
		tween.tween_property(outgoing, "volume_db", SILENT_DB, music_fade_time)
		tween.chain().tween_callback(outgoing.stop)


func stop_music() -> void:
	for player: AudioStreamPlayer in _music_players:
		player.stop()
