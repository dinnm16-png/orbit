extends "res://tests/test_case.gd"


func _peak(wav: AudioStreamWAV) -> float:
	var peak := 0
	for i in range(0, wav.data.size(), 2):
		peak = maxi(peak, absi(wav.data.decode_s16(i)))
	return peak / 32767.0


func test_bell_has_expected_length_and_format() -> void:
	var wav := ToneSynth.bell(440.0, 0.5)
	assert_eq(wav.format, AudioStreamWAV.FORMAT_16_BITS, "16-bit")
	assert_eq(wav.data.size(), int(ToneSynth.MIX_RATE * 0.5) * 2, "0.5 s of mono samples")


func test_sounds_are_audible_and_never_clip() -> void:
	for wav in [ToneSynth.bell(261.63, 0.7), ToneSynth.whoosh(), ToneSynth.chord([220.0, 330.0], 1.0)]:
		var peak := _peak(wav)
		assert_true(peak > 0.3, "not silent (peak %.2f)" % peak)
		assert_true(peak <= ToneSynth.PEAK + 0.01, "headroom kept, no clipping (peak %.2f)" % peak)


func test_sound_starts_without_click() -> void:
	# A click happens when the first sample jumps straight to a loud value.
	var wav := ToneSynth.bell(523.25, 0.5)
	assert_true(absi(wav.data.decode_s16(0)) < 200, "first sample near silence")


func test_merge_notes_rise_with_level() -> void:
	for level in range(2, 12):
		assert_true(ToneSynth.merge_frequency(level) > ToneSynth.merge_frequency(level - 1),
			"level %d higher than level %d" % [level, level - 1])


