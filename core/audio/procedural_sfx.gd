class_name ProceduralSfx
extends RefCounted
## Placeholder sound effects synthesized in code: no files, no licences.
## Swap any of them for a real CC0 recording by registering a stream with
## the same id in AudioManager.

enum Wave { SINE, SQUARE, TRIANGLE, BELL }

const MIX_RATE: int = 22050
const PEAK: float = 32767.0

const IDS: Array[StringName] = [
	&"horn", &"pickup", &"deliver", &"late", &"fail", &"impact", &"splash",
	&"ui_click", &"countdown",
]


static func generate(id: StringName) -> AudioStreamWAV:
	match id:
		&"horn":
			# Two-tone scooter "meep meep".
			return _sequence([[523.0, 0.16], [0.0, 0.05], [659.0, 0.2]], Wave.SQUARE, 0.35, 0.01)
		&"pickup":
			return _sequence([[523.0, 0.09], [659.0, 0.09], [784.0, 0.18]], Wave.SINE, 0.6, 0.12)
		&"deliver":
			# Cash-register-ish ding-ding.
			return _sequence([[1318.0, 0.12], [1975.0, 0.5]], Wave.BELL, 0.55, 0.35)
		&"late":
			return _sequence([[196.0, 0.35]], Wave.SQUARE, 0.3, 0.05)
		&"fail":
			# Sad trombone, more or less.
			return _sequence([[392.0, 0.28], [370.0, 0.28], [349.0, 0.28], [330.0, 0.6]], Wave.TRIANGLE, 0.5, 0.2)
		&"impact":
			return _noise_burst(0.22, 0.9, 900.0, 70.0)
		&"splash":
			return _noise_burst(0.9, 0.7, 2500.0, 0.0)
		&"ui_click":
			return _sequence([[1400.0, 0.03]], Wave.SINE, 0.4, 0.02)
		&"countdown":
			return _sequence([[880.0, 0.1]], Wave.SINE, 0.5, 0.05)
	return null


## A seamless engine loop at `base_hz` (a whole number of cycles, so it can
## be pitch-shifted by speed without clicks).
static func engine_loop(base_hz: float = 55.0, cycles: int = 22) -> AudioStreamWAV:
	var frames: int = roundi(cycles * MIX_RATE / base_hz)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	for i: int in frames:
		var phase: float = float(i) * cycles / frames
		# Two-stroke buzz: saw + a bit of second harmonic, plus a putter wobble.
		var saw: float = fposmod(phase, 1.0) * 2.0 - 1.0
		var second: float = sin(phase * TAU * 2.0) * 0.3
		var putter: float = 0.75 + 0.25 * sin(phase * TAU / cycles * 4.0)
		samples[i] = (saw * 0.55 + second) * putter * 0.5
	var stream: AudioStreamWAV = _to_stream(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream


static func _sequence(notes: Array, wave: Wave, volume: float, release: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for note: Array in notes:
		var hz: float = note[0]
		var duration: float = note[1]
		var count: int = roundi(duration * MIX_RATE)
		var release_count: int = roundi(minf(release, duration) * MIX_RATE)
		for i: int in count:
			var t: float = float(i) / MIX_RATE
			var envelope: float = 1.0
			var attack: float = minf(float(i) / (0.005 * MIX_RATE), 1.0)
			if i > count - release_count and release_count > 0:
				envelope = float(count - i) / release_count
			var value: float = 0.0 if hz <= 0.0 else _wave(wave, t * hz)
			samples.append(value * envelope * attack * volume)
	return _to_stream(samples)


static func _noise_burst(duration: float, volume: float, brightness_hz: float, thump_hz: float) -> AudioStreamWAV:
	var count: int = roundi(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	# One-pole low-pass; brightness sets the cutoff.
	var alpha: float = clampf(brightness_hz / MIX_RATE * TAU, 0.0, 1.0)
	var filtered: float = 0.0
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var decay: float = pow(1.0 - float(i) / count, 2.0)
		filtered += alpha * (rng.randf_range(-1.0, 1.0) - filtered)
		var thump: float = sin(t * TAU * thump_hz) * 0.8 if thump_hz > 0.0 else 0.0
		samples[i] = (filtered * 1.5 + thump) * decay * volume
	return _to_stream(samples)


static func _wave(kind: Wave, cycles: float) -> float:
	match kind:
		Wave.SQUARE:
			return 0.6 if fposmod(cycles, 1.0) < 0.5 else -0.6
		Wave.TRIANGLE:
			return 1.0 - 4.0 * absf(fposmod(cycles, 1.0) - 0.5)
		Wave.BELL:
			return sin(cycles * TAU) * 0.7 + sin(cycles * TAU * 2.76) * 0.3
	return sin(cycles * TAU)


static func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * PEAK))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
