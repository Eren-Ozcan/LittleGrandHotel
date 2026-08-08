class_name Sfx
extends RefCounted
## Prosedürel ses üretimi — dış ses dosyası gerektirmez.
## Her efekt, üstel sönümlü sinüs adımlarından 16-bit mono WAV olarak sentezlenir.

const RATE := 22050


## steps: [[frekans_hz, süre_sn], ...] — adımlar art arda çalınır.
## decay: sönüm hızı (büyük = kısa tıng, küçük = uzun çınlama)
static func tone_stream(steps: Array, decay: float = 6.0, gain: float = 0.5) -> AudioStreamWAV:
	var n := 0
	for s in steps:
		n += int(float(s[1]) * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var idx := 0
	for s in steps:
		var f := float(s[0])
		var d := float(s[1])
		var ns := int(d * RATE)
		for i in ns:
			var t := float(i) / RATE
			var env := exp(-decay * t / d)
			var v := sin(TAU * f * t) * env * gain
			data.encode_s16(idx * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
			idx += 1
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## Yumuşak lobi müziği: pentatonik arpej döngüsü (loop'lu WAV).
static func lobby_music() -> AudioStreamWAV:
	var seq := [262.0, 330.0, 392.0, 494.0, 392.0, 330.0, 294.0, 330.0,
		262.0, 330.0, 440.0, 494.0, 440.0, 392.0, 330.0, 294.0]
	var steps := []
	for f in seq:
		steps.append([f, 0.5])
	var wav := tone_stream(steps, 3.0, 0.18)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	# loop_end is an inclusive sample index, so it must stay one below the frame
	# count. The resampler reads pos + 1 to interpolate, and pointing loop_end at
	# the frame count makes it read one sample past the buffer when the loop
	# wraps. Android 9's allocator absorbs that; Android 11+ (Scudo) places large
	# buffers against a guard page and turns it into a SIGSEGV.
	wav.loop_end = wav.data.size() / 2 - 1
	return wav
