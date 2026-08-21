extends Node
## Prosedürel ses sentezinin (src/sfx.gd) testi — ve 09941a7'deki Android 11+
## çökmesinin kalıcı regresyon kapanı.
##
## O çökmenin hikâyesi kısaca: `lobby_music()` `loop_end`'i kare **sayısına**
## (176400) eşitliyordu, oysa `loop_end` kapsayıcı bir **indeks**tir. Godot'un
## yeniden örnekleyicisi ara değer için `pos + 1` okur, döngü başa sardığında
## 352800 baytlık tamponun bir örnek ötesine taşardı. Android 9 (jemalloc) bunu
## yutuyordu; Android 11+ (Scudo) bu boyuttaki ayırmaları bir koruma sayfasına
## yaslıyor ve aynı taşma `SIGSEGV`e dönüşüyordu — açılıştan 10-16 sn sonra.
## Buradaki `loop_end < kare_sayısı` iddiası, o hatanın geri gelmesini engeller.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/sfx_check.tscn

var failures := 0
var checks := 0


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


## Bir AudioStreamWAV'ın kare sayısı: 16-bit mono'da bayt / 2.
func _frames(wav: AudioStreamWAV) -> int:
	return wav.data.size() / 2


## Döngülü HER akış için geçerli olması gereken tek kural (bkz. dosya başlığı).
func _check_loop_safety(wav: AudioStreamWAV, label: String) -> void:
	if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		return
	var frames := _frames(wav)
	check(wav.loop_begin >= 0, "%s: loop_begin negatif değil" % label)
	check(wav.loop_end < frames,
		"%s: loop_end (%d) kare sayısının (%d) ALTINDA — pos+1 taşmıyor"
			% [label, wav.loop_end, frames])
	check(wav.loop_end > wav.loop_begin, "%s: loop_end > loop_begin" % label)


func _ready() -> void:
	print("Little Grand Hotel — ses sentezi testi")
	print("=".repeat(64))

	_test_tone_stream_shape()
	_test_sample_range()
	_test_envelope_decays()
	_test_degenerate_inputs()
	_test_lobby_music_loop()
	_test_main_scene_effects()

	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


## Tampon boyutu adımların toplam süresiyle birebir örtüşmeli: kısa keserse ses
## tıkırdar, uzun bırakırsa sonda sessizlik/çöp kalır.
func _test_tone_stream_shape() -> void:
	print("\n[1] tone_stream — tampon biçimi")
	var steps := [[440.0, 0.1], [880.0, 0.25], [660.0, 0.05]]
	var wav := Sfx.tone_stream(steps)
	var expected := 0
	for s in steps:
		expected += int(float(s[1]) * Sfx.RATE)
	check(_frames(wav) == expected,
		"kare sayısı adım sürelerinin toplamı (%d)" % expected)
	check(wav.data.size() == expected * 2, "bayt sayısı = kare × 2 (16-bit)")
	check(wav.data.size() % 2 == 0, "bayt sayısı çift — yarım örnek yok")
	check(wav.format == AudioStreamWAV.FORMAT_16_BITS, "format 16-bit")
	check(wav.mix_rate == Sfx.RATE, "mix_rate %d" % Sfx.RATE)
	check(wav.stereo == false, "mono")
	check(wav.loop_mode == AudioStreamWAV.LOOP_DISABLED,
		"efektler döngüsüz (yalnız müzik döngülü)")


## `int(clampf(v, -1, 1) * 32767)` kapısı: gain 1.0'da bile int16'ya sığmalı.
## Sığmazsa encode_s16 sarar ve ses cızırtıya döner.
func _test_sample_range() -> void:
	print("\n[2] tone_stream — örnek aralığı")
	var wav := Sfx.tone_stream([[440.0, 0.2]], 0.0, 1.0)  # sönüm yok, tam gain
	var frames := _frames(wav)
	var min_v := 32767
	var max_v := -32768
	var out_of_range := 0
	for i in frames:
		var v := wav.data.decode_s16(i * 2)
		min_v = mini(min_v, v)
		max_v = maxi(max_v, v)
		if v > 32767 or v < -32768:
			out_of_range += 1
	check(out_of_range == 0, "hiçbir örnek int16 dışına taşmadı")
	check(max_v <= 32767 and min_v >= -32767,
		"tepe değerler ±32767 içinde (min %d, max %d)" % [min_v, max_v])
	check(max_v > 30000 and min_v < -30000,
		"sönümsüz tam gain gerçekten tepeye çıkıyor — sinyal sessiz değil")


## Üstel zarf: adımın sonu başından belirgin şekilde sessiz olmalı, yoksa
## "tıng" değil düz bir bip duyulur.
func _test_envelope_decays() -> void:
	print("\n[3] tone_stream — zarf sönümü")
	var wav := Sfx.tone_stream([[440.0, 0.4]], 6.0, 0.5)
	var frames := _frames(wav)
	var head := 0
	var tail := 0
	# İlk ve son %10'un tepe genliği.
	var span := maxi(1, frames / 10)
	for i in span:
		head = maxi(head, absi(wav.data.decode_s16(i * 2)))
		tail = maxi(tail, absi(wav.data.decode_s16((frames - 1 - i) * 2)))
	check(head > 0, "adımın başı sessiz değil (tepe %d)" % head)
	check(tail < head / 4, "adımın sonu başın çeyreğinden sessiz (%d < %d)"
		% [tail, head / 4])

	var slow := Sfx.tone_stream([[440.0, 0.4]], 1.0, 0.5)
	var slow_tail := 0
	for i in span:
		slow_tail = maxi(slow_tail, absi(slow.data.decode_s16((frames - 1 - i) * 2)))
	check(slow_tail > tail, "küçük decay daha uzun çınlıyor (%d > %d)"
		% [slow_tail, tail])


## Sınır girdileri çökmemeli. Tek örneklik tampon özellikle önemli: özgün
## çökmede taşan tam da "son örneğin bir ötesi" idi.
func _test_degenerate_inputs() -> void:
	print("\n[4] tone_stream — sınır girdileri")
	var empty := Sfx.tone_stream([])
	check(empty != null and _frames(empty) == 0, "boş adım listesi 0 kareli akış")

	var zero := Sfx.tone_stream([[440.0, 0.0]])
	check(_frames(zero) == 0, "sıfır süreli adım 0 kare üretir")

	var one := Sfx.tone_stream([[440.0, 1.0 / Sfx.RATE]])
	check(_frames(one) == 1, "tek örneklik akış tam 1 kare")
	check(one.data.size() == 2, "tek örnek = 2 bayt")

	var silent := Sfx.tone_stream([[440.0, 0.05]], 6.0, 0.0)
	var loud := 0
	for i in _frames(silent):
		loud = maxi(loud, absi(silent.data.decode_s16(i * 2)))
	check(loud == 0, "gain 0 gerçekten sessiz")

	var dc := Sfx.tone_stream([[0.0, 0.05]])
	check(_frames(dc) > 0, "0 Hz adımı çökmüyor (sin(0) = düz sessizlik)")


## Asıl regresyon kapanı.
func _test_lobby_music_loop() -> void:
	print("\n[5] lobby_music — döngü güvenliği (09941a7 regresyonu)")
	var wav := Sfx.lobby_music()
	var frames := _frames(wav)
	check(frames > 0, "müzik tamponu boş değil (%d kare)" % frames)
	check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "LOOP_FORWARD")
	check(wav.loop_begin == 0, "loop_begin 0")
	check(wav.loop_end == frames - 1,
		"loop_end TAM OLARAK kare-1 (%d) — kare sayısı DEĞİL" % (frames - 1))
	_check_loop_safety(wav, "lobby_music")
	# Özgün hatanın tam ifadesi: loop_end kare sayısına eşit olsaydı,
	# yeniden örnekleyicinin okuduğu pos+1 tamponun dışına düşerdi.
	check((wav.loop_end + 1) * 2 <= wav.data.size(),
		"pos+1 ara değeri hâlâ tamponun İÇİNDE ((%d+1)×2 ≤ %d)"
			% [wav.loop_end, wav.data.size()])
	check(frames == 16 * int(0.5 * Sfx.RATE),
		"16 nota × 0,5 sn = %d kare" % (16 * int(0.5 * Sfx.RATE)))


## main.gd'nin _init_sfx()'inde tanımlı YEDİ efektin tamamı: her biri gerçekten
## ses üretmeli. Tablo burada aynen tekrarlanır, çünkü main.gd'yi örneklemek
## tüm sahneyi (ve pencereyi) ayağa kaldırmayı gerektirirdi.
const EFFECT_DEFS := {
	"tap": [[660.0, 0.05]],
	"buy": [[440.0, 0.06], [880.0, 0.1]],
	"collect": [[784.0, 0.07], [1047.0, 0.09], [1319.0, 0.12]],
	"clean": [[1319.0, 0.08], [1760.0, 0.14]],
	"shift": [[988.0, 0.1], [659.0, 0.2]],
	"quest": [[784.0, 0.08], [988.0, 0.14]],
	"level": [[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1047.0, 0.22]],
}


func _test_main_scene_effects() -> void:
	print("\n[6] main.gd'deki efekt tablosu")
	# Tablonun main.gd ile aynı kaldığını doğrula — kopya sessizce kaymasın.
	var src := FileAccess.get_file_as_string("res://src/main.gd")
	for k in EFFECT_DEFS:
		check(src.contains("\"%s\": [[" % k),
			"main.gd hâlâ '%s' efektini tanımlıyor" % k)
	for k in EFFECT_DEFS:
		var wav := Sfx.tone_stream(EFFECT_DEFS[k])
		var frames := _frames(wav)
		var peak := 0
		for i in frames:
			peak = maxi(peak, absi(wav.data.decode_s16(i * 2)))
		check(frames > 0 and peak > 1000,
			"'%s' duyulur bir akış üretiyor (%d kare, tepe %d)" % [k, frames, peak])
		_check_loop_safety(wav, k)
