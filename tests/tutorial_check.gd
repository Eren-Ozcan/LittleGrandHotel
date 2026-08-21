extends Node
## Zorunlu açılış tutorial'ının otomatik testi (bkz. main.gd TUTORIAL_STEPS).
## Kullanıcı isteği: "zorunlu oynanan, sadece oyun ilk açıldığında gelen".
##
## 2026-08-12'de (24cc37f) tutorial modal-only bir dizi olmaktan çıkıp iki adım
## tipine ayrıldı; bu test o tasarımı sürer:
##   "modal" — _show_simple_modal ile açılır, gövdesindeki tek eylem butonu
##             ilerletir. Bu sırada _tutorial_step_index -1'dir.
##   "tap"   — spotlight (tutorial_layer) açılır, ilerlemek için oyuncunun
##             GERÇEK arayüz elemanına dokunması gerekir; kodda karşılığı
##             _tutorial_advance_on(event). Bu sırada _tutorial_step_index
##             adımın sırasıdır.
##
## Doğrulananlar: (1) yepyeni kayıtta açılıyor, (2) her adım kendi tipine göre
## bloklayıcı ve YALNIZCA kendi eylemiyle ilerliyor, (3) "Skip tutorial" tüm
## diziyi kapatıyor, (4) bittikten sonra bir daha GELMİYOR (kalıcı olarak).
##
## Çalıştırma (pencere açar, headless DEĞİL):
##   tools\Godot_v4.7-stable_win64_console.exe --path . res://tests/tutorial_check.tscn
##
## Çıkış kodu 0 = geçti. Son satır olarak TÜM TESTLER GEÇTİ / TEST BAŞARISIZ
## basılır; bir GDScript çalışma zamanı hatası _ready'nin coroutine'ini sessizce
## öldürebildiği için bu satırın YOKLUĞU da başarısızlıktır — o durumda aşağıdaki
## watchdog devreye girip 1 ile çıkar (bkz. _on_timeout).

const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.tutcheck.bak"
## Testin tamamı saniyeler sürer; bu yalnızca "coroutine öldü, kimse quit
## çağırmayacak" hâline karşı emniyet kemeri.
const TIMEOUT_SEC := 45.0

var failures := 0
var checks := 0
var _finished := false
var _main: Node


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


# --- Kayıt koruması -----------------------------------------------------
# Test gerçek oyunu (ve gerçek user://save.json'u) çalıştırır — tutorial'ı
# bitirmek Game.save_game() tetiklediği için oyuncunun kaydını EZER. Kayıt teste
# girerken bir yana alınır, çıkarken geri konur. Geri koyma _exit_tree
# içindedir: düz bir "en sonda çağır" satırı, test ortasında ölürse yedeği öksüz
# bırakıyor ve canlı kaydı new_game()'in bıraktığı hâlde saklıyordu.

func _stash_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH),
			ProjectSettings.globalize_path(BACKUP_PATH))


func _restore_save() -> void:
	if not FileAccess.file_exists(BACKUP_PATH):
		return
	DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH),
		ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	print("  (test öncesi kayıt geri yüklendi)")


func _exit_tree() -> void:
	_restore_save()


# --- Sahne gezinme yardımcıları ----------------------------------------

## Açık modal'ın kökü: _show_modal tam ekran bir ColorRect'i (z_index 90)
## doğrudan main'in çocuğu yapar. Kapatılan modal aynı karede hâlâ ağaçtadır
## (queue_free), o yüzden silinmeye işaretlenenler atlanır.
func _modal_root() -> ColorRect:
	if _main == null:
		return null
	for c in _main.get_children():
		if c is ColorRect and c.z_index >= 90 and not c.is_queued_for_deletion():
			return c
	return null


## Modal gövdesindeki birincil eylem butonu (VBox'a ilk eklenen buton).
func _modal_button() -> Button:
	var root := _modal_root()
	if root == null:
		return null
	for node in root.find_children("*", "Button", true, false):
		return node
	return null


## Spotlight katmanındaki tek buton: "Skip tutorial" (bkz. _build_tutorial_layer).
func _skip_button() -> Button:
	if _main.tutorial_layer == null or not is_instance_valid(_main.tutorial_layer):
		return null
	for node in _main.tutorial_layer.find_children("*", "Button", true, false):
		return node
	return null


func _dim_strips() -> Array:
	return [_main._tutorial_dim_top, _main._tutorial_dim_bottom,
		_main._tutorial_dim_left, _main._tutorial_dim_right]


# --- Adım doğrulamaları -------------------------------------------------

## Bir "modal" adımı: buton var mı, metni adımın btn alanı mı, spotlight kapalı
## mı. Butona basıp ilerletir.
func _run_modal_step(i: int, s: Dictionary) -> void:
	check(_main._tutorial_step_index == -1,
		"adım %d modal — spotlight indeksi boşta (-1)" % i)
	check(not _main.tutorial_layer.visible, "adım %d modal — spotlight gizli" % i)
	var b := _modal_button()
	if b == null:
		check(false, "adım %d için modal butonu bulunamadı" % i)
		return
	check(b.text == String(s.btn),
		"adım %d butonu '%s' (beklenen '%s')" % [i, b.text, String(s.btn)])
	b.pressed.emit()
	await get_tree().process_frame


## Bir "tap" adımı: spotlight açık, hedef gerçekten sahnede, ring hedefin
## üstüne oturmuş, karartma şeritleri dokunuşu yutuyor ve YANLIŞ bir event
## ilerletmiyor. Sonra doğru event ateşlenip adım geçilir.
func _run_tap_step(i: int, s: Dictionary) -> void:
	check(_main._tutorial_step_index == i, "adım %d tap — indeks doğru" % i)
	check(_main.tutorial_layer.visible, "adım %d tap — spotlight görünür" % i)
	check(_modal_root() == null, "adım %d tap — açık modal yok" % i)

	var target: Control = _main._tutorial_target_control(String(s.get("target", "")))
	check(target != null and is_instance_valid(target),
		"adım %d hedefi '%s' sahnede var" % [i, String(s.get("target", ""))])

	# Karartma bloklayıcı mı: girdi oyuna sızmamalı (MOUSE_FILTER_STOP).
	var all_stop := true
	for d in _dim_strips():
		if d == null or d.mouse_filter != Control.MOUSE_FILTER_STOP:
			all_stop = false
	check(all_stop, "adım %d — karartma şeritleri tüm dokunuşları yutuyor" % i)

	# Ring hedefin rect'ine 6 px pay ile oturur (bkz. _tutorial_reposition_spotlight).
	# Layout bir kare sonra oturduğu için yeniden konumlandırma burada zorlanır.
	await get_tree().process_frame
	_main._tutorial_reposition_spotlight()
	if target != null and target.size != Vector2.ZERO:
		var pad := 6.0
		var expected_pos: Vector2 = target.global_position \
			- _main.tutorial_layer.global_position - Vector2(pad, pad)
		check(_main._tutorial_ring.position.distance_to(expected_pos) < 1.0,
			"adım %d — ring hedefin üstünde" % i)
		check(_main._tutorial_ring.size.is_equal_approx(target.size + Vector2(pad, pad) * 2.0),
			"adım %d — ring hedef boyutunda" % i)

	# Zorunluluk: başka bir adımın event'i bu adımı ilerletmiyor.
	_main._tutorial_advance_on("tutcheck_bogus_event")
	await get_tree().process_frame
	check(_main._tutorial_step_index == i, "adım %d — yabancı event ilerletmiyor" % i)

	_main._tutorial_advance_on(String(s.event))
	await get_tree().process_frame


# --- Akış ---------------------------------------------------------------

## Tutorial'ı sıfırdan başlatır: yepyeni kayıt + zincirdeki diğer açılış
## popup'ları (günlük ödül, çevrimdışı kazanç) susturulmuş hâlde — bu test
## tutorial'ı ölçer, _after_tutorial zincirini değil.
func _restart_tutorial(game: Node) -> void:
	game.new_game()
	game.last_daily_claim_day = game.daily_day_index()
	game.offline_earned = 0
	game.auto_renew_count = 0
	_main._maybe_show_tutorial()
	await get_tree().process_frame


func _on_timeout() -> void:
	if _finished:
		return
	printerr("  FAIL test %.0f sn içinde bitmedi — büyük olasılıkla bir SCRIPT " % TIMEOUT_SEC
		+ "ERROR _ready coroutine'ini öldürdü; yukarıdaki çıktıyı oku")
	get_tree().quit(1)


func _ready() -> void:
	print("Little Grand Hotel — zorunlu tutorial testi")
	_stash_save()
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(_on_timeout)

	var game := get_node("/root/Game")
	# Yepyeni kayıt durumu: tutorial hiç görülmemiş.
	game.new_game()
	game.last_daily_claim_day = game.daily_day_index()
	game.offline_earned = 0
	game.auto_renew_count = 0
	check(game.tutorial_seen == false, "yeni oyunda tutorial_seen false")

	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_main._finish_loading_screen()
	# Açılış ekranı 0.28 sn soluklaşıp KAPANINCA tutorial başlar (bkz.
	# _finish_loading_screen) — tek kare beklemek yetmez.
	await get_tree().create_timer(0.6).timeout

	check(_main.tutorial_layer != null and is_instance_valid(_main.tutorial_layer),
		"tutorial katmanı oluşturuldu")
	check(_main.tutorial_layer.z_index > 0,
		"tutorial katmanı oyunun üstünde (z_index %d)" % _main.tutorial_layer.z_index)
	check(_modal_root() != null, "ilk açılışta tutorial'ın ilk modalı geldi")

	# Not: Android geri tuşu burada DENENMEZ. main._notification, overlay
	# kapalıyken get_tree().quit() çağırır (bkz. orası) — tutorial'ı atlamaz ama
	# testi de bitirir, o yüzden iddia edilemez. Atlanmadığı zaten şuradan
	# görünür: tutorial_seen'i yalnızca son adım, _on_tutorial_skip ve modal
	# dışına tıklama true yapar.

	# --- Adımları tipine göre tek tek geç ---
	var steps: int = _main.TUTORIAL_STEPS.size()
	for i in steps:
		var s: Dictionary = _main.TUTORIAL_STEPS[i]
		check(game.tutorial_seen == false, "adım %d'de tutorial hâlâ bitmemiş" % i)
		if String(s.get("type", "modal")) == "tap":
			await _run_tap_step(i, s)
		else:
			await _run_modal_step(i, s)

	check(game.tutorial_seen == true, "tutorial tamamlandı, kalıcı olarak işaretlendi")
	check(_main._tutorial_step_index == -1, "bitişte spotlight indeksi boşta")
	check(not _main.tutorial_layer.visible, "bitişte spotlight kapandı")

	# --- İkinci açılış: bir daha gelmemeli ---
	_main._maybe_show_tutorial()
	await get_tree().process_frame
	check(_modal_root() == null and not _main.tutorial_layer.visible,
		"ikinci açılışta tutorial tekrar gelmiyor")

	# --- "Skip tutorial" tüm diziyi kapatıyor mu ---
	await _restart_tutorial(game)
	check(game.tutorial_seen == false, "atlama testi: tutorial yeniden başladı")
	# İlk modalı geçip spotlight'lı ilk "tap" adımına gel.
	var first_modal := _modal_button()
	if first_modal != null:
		first_modal.pressed.emit()
		await get_tree().process_frame
	check(_main.tutorial_layer.visible, "atlama testi: spotlight açıldı")
	var skip_b := _skip_button()
	check(skip_b != null, "atlama testi: 'Skip tutorial' butonu var")
	if skip_b != null:
		skip_b.pressed.emit()
		await get_tree().process_frame
		check(game.tutorial_seen == true, "atlama testi: tutorial görülmüş sayıldı")
		check(_main._tutorial_step_index == -1 and not _main.tutorial_layer.visible,
			"atlama testi: spotlight kapandı")

	_finished = true
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol, %d adım)" % [checks, steps])
	else:
		printerr("%d TEST BAŞARISIZ" % failures)
	get_tree().quit(1 if failures > 0 else 0)
