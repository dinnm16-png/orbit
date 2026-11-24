class_name ToneSynth
extends RefCounted
## Generates soft sounds in code (no audio files, no dependencies).
##
## Tones are "bells": a sine wave plus two quickly-decaying overtones, with a
## tiny attack (avoids clicks) and an exponential decay.
## Pure functions with no shared state, so they are safe to run on a worker
## thread (Feedback generates all sounds in the background at startup).

const MIX_RATE := 22050
## Peak level of generated sounds (0..1). Leaves headroom when several overlap.
const PEAK := 0.55

## A bell tone at `freq` Hz lasting `duration` seconds.
static func bell(freq: float, duration: float, decay: float = 5.0) -> AudioStreamWAV:
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var attack := int(MIX_RATE * 0.006)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := exp(-t * decay) * (minf(1.0, float(i) / attack) if attack > 0 else 1.0)
		var s := sin(TAU * freq * t) \
			+ 0.30 * sin(TAU * freq * 2.0 * t) * exp(-t * 9.0) \
			+ 0.12 * sin(TAU * freq * 3.0 * t) * exp(-t * 14.0)
		samples[i] = s * env
	return _to_wav(samples)


## Several bells mixed together (chords).
static func chord(freqs: Array, duration: float, decay: float = 3.0) -> AudioStreamWAV:
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for f in freqs:
		for i in n:
			var t := float(i) / MIX_RATE
			samples[i] += sin(TAU * f * t) * exp(-t * decay) * minf(1.0, t / 0.01)
	return _to_wav(samples)


## A soft rising "whoosh" for launches.
static func whoosh(duration: float = 0.14) -> AudioStreamWAV:
	var n := int(MIX_RATE * duration)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(180.0, 340.0, k) / MIX_RATE
		samples[i] = sin(phase) * sin(PI * k) * 0.6  # smooth in/out envelope
	return _to_wav(samples)


## Normalizes to PEAK and packs as 16-bit mono PCM.
static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := PEAK / peak if peak > 0.0 else 0.0
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


## Note for a merge result level: C major pentatonic, rising with level, so
## chain reactions naturally "climb" musically.
static func merge_frequency(level: int) -> float:
	var semitones := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26]
	var idx := clampi(level - 1, 0, semitones.size() - 1)
	return 261.63 * pow(2.0, semitones[idx] / 12.0)  # from C4
