extends Node
## Reklam politikası testi (src/autoload/ads.gd + main.gd'deki tetikleyiciler).
##
## Buradaki iddialar stüdyo genelindeki `pictures/ADS_POLICY.md` kurallarının ve
## AdMob'un "izin verilmeyen geçiş reklamı uygulamaları" sayfasının koda
## dökülmüş hâlidir. Politika ihlalinin bedeli bir hata mesajı değil, hesabın
## askıya alınmasıdır — o yüzden bu kurallar teste bağlanır.
##
## İki katman var:
##   ÇALIŞMA ZAMANI — soğuma sayacının kalıcılığı ve saat oyunlarına dayanıklılığı.
##                    Gerçek reklam SDK'sı yalnızca Android'de var, o yüzden
##                    show_* çağrıları masaüstünde erken döner; test bu yüzden
##                    sayaç mantığını doğrudan sürer.
##   KAYNAK          — "geçiş reklamı açılışta gösterilmiyor" gibi kurallar
##                    yalnızca çağrı grafiğinde görünür; bunlar kaynak metni
##                    üzerinden doğrulanır.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/ads_check.tscn

const STATE_PATH := "user://ads_state.json"
const BACKUP_PATH := "user://ads_state.json.adscheck.bak"
## Google'ın herkese açık test birimleri. Yayına bunlarla çıkmak gerçek gelir
## kaybı, tersi (gerçek birimle test) ise geçersiz trafik demektir.
const GOOGLE_TEST_PUBLISHER := "ca-app-pub-3940256099942544"
const PUBLISHER_ID := "ca-app-pub-9709993577664180"

var failures := 0
var checks := 0
var ads_src := ""
var main_src := ""


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


func _stash() -> void:
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(STATE_PATH),
			ProjectSettings.globalize_path(BACKUP_PATH))


func _restore() -> void:
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH),
			ProjectSettings.globalize_path(STATE_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	elif FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))


func _exit_tree() -> void:
	_restore()


## ads.gd'de bir fonksiyonun gövdesini kaynaktan çeker (kaynak katmanı iddiaları
## için). Bir sonraki üst düzey `func`a kadar okur.
func _body(src: String, fn: String) -> String:
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var rest := src.substr(start)
	var next := rest.find("\nfunc ", 1)
	return rest.substr(0, next) if next > 0 else rest


func _ready() -> void:
	print("Little Grand Hotel — reklam politikası testi")
	print("=".repeat(64))
	_stash()
	ads_src = FileAccess.get_file_as_string("res://src/autoload/ads.gd")
	main_src = FileAccess.get_file_as_string("res://src/main.gd")

	_test_ad_unit_ids()
	_test_cooldown_constants()
	_test_elapsed_since()
	_test_state_persistence()
	_test_state_is_robust()
	_test_cooldown_is_shared()
	_test_no_interstitial_on_app_open()
	_test_interstitial_trigger_points()
	_test_remove_ads_gating()
	_test_rewarded_is_opt_in()
	_test_app_open_staleness()
	_test_consent()

	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


# --- Yapılandırma --------------------------------------------------------

func _test_ad_unit_ids() -> void:
	print("\n[1] Reklam birimi kimlikleri")
	var ids := {
		"ödüllü": Ads._REWARDED_AD_UNIT_ID,
		"geçiş": Ads._INTERSTITIAL_AD_UNIT_ID,
		"App Open": Ads._APP_OPEN_AD_UNIT_ID,
	}
	var seen := {}
	for name in ids:
		var id: String = ids[name]
		check(id != "", "%s birimi tanımlı" % name)
		check(not id.begins_with(GOOGLE_TEST_PUBLISHER),
			"%s birimi Google TEST kimliği DEĞİL" % name)
		check(id.begins_with(PUBLISHER_ID),
			"%s birimi bizim yayıncı kimliğimize ait" % name)
		check(not seen.has(id), "%s birimi başka bir formatla paylaşılmıyor" % name)
		seen[id] = true
	check(seen.size() == 3, "üç format üç AYRI birim kullanıyor")


func _test_cooldown_constants() -> void:
	print("\n[2] Soğuma sabitleri")
	check(Ads._FULL_SCREEN_AD_COOLDOWN_SEC >= 60.0,
		"tam ekran soğuması en az 1 dakika (%.0f sn)" % Ads._FULL_SCREEN_AD_COOLDOWN_SEC)
	check(is_equal_approx(Ads._FULL_SCREEN_AD_COOLDOWN_SEC, 300.0),
		"soğuma politikadaki 5 dakika")
	check(is_equal_approx(Ads._APP_OPEN_MAX_CACHE_SEC, 4.0 * 3600.0),
		"App Open bayatlama süresi AdMob'un 4 saati")
	check(Ads._STATE_PATH != "user://save.json",
		"reklam durumu oyun kaydından AYRI bir dosyada")


# --- Çalışma zamanı: sayaç mantığı ---------------------------------------

func _test_elapsed_since() -> void:
	print("\n[3] _elapsed_since — saat oyunlarına dayanıklılık")
	check(Ads._elapsed_since(0.0) == INF,
		"hiç reklam gösterilmemişse (0) süre INF — ilk reklam bloklanmıyor")
	check(Ads._elapsed_since(-5.0) == INF, "negatif damga da INF sayılır")
	var now := Time.get_unix_time_from_system()
	check(Ads._elapsed_since(now + 10000.0) == INF,
		"gelecekteki damga (saat geri alınmış) kalıcı kilide yol açmıyor")
	var elapsed := Ads._elapsed_since(now - 120.0)
	check(elapsed >= 119.0 and elapsed <= 121.0,
		"normal durumda geçen süre doğru (%.1f ≈ 120)" % elapsed)


func _test_state_persistence() -> void:
	print("\n[4] Soğuma sayacı KALICI mı")
	# Politikanın en somut maddesi: sayaç yalnızca oturum içinde tutulursa
	# oyuncu uygulamayı kapatıp açarak her seferinde yeni bir reklam hakkı
	# doğurur ("her açtığımda reklam" şikâyeti).
	if FileAccess.file_exists(STATE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE_PATH))
	Ads._last_full_screen_ad_time = 0.0
	Ads._mark_full_screen_ad_shown()
	check(FileAccess.file_exists(STATE_PATH),
		"reklam gösterimi diske yazıldı (%s)" % STATE_PATH)
	var written := Ads._last_full_screen_ad_time
	check(written > 0.0, "sayaç ilerledi")

	# "Uygulama yeniden açıldı": belleği sıfırla, diskten geri oku.
	Ads._last_full_screen_ad_time = 0.0
	Ads._load_state()
	check(is_equal_approx(Ads._last_full_screen_ad_time, written),
		"yeniden açılışta sayaç diskten aynen geri geldi")
	check(Ads._elapsed_since(Ads._last_full_screen_ad_time) < Ads._FULL_SCREEN_AD_COOLDOWN_SEC,
		"soğuma yeniden açılıştan SONRA da yürürlükte — bedava reklam hakkı doğmuyor")


func _test_state_is_robust() -> void:
	print("\n[5] Bozuk durum dosyası oyunu bozmuyor")
	# Bu dosya oyun ilerlemesi değil; bozulması en fazla bir reklamı kaçırmalı.
	for bad in ["", "{", "null", "[]", "\"metin\"", "{\"last_full_screen_ad\": \"abc\"}",
			"{\"last_full_screen_ad\": -99}", "{}"]:
		var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
		f.store_string(bad)
		f.close()
		Ads._last_full_screen_ad_time = 123.0
		Ads._load_state()
		check(Ads._last_full_screen_ad_time >= 0.0,
			"bozuk içerik (%s) çökmedi, sayaç negatif değil" % bad.substr(0, 24))
	# Geçerli bir negatif değer 0'a kırpılmalı.
	var f2 := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	f2.store_string("{\"last_full_screen_ad\": -1000}")
	f2.close()
	Ads._last_full_screen_ad_time = 5.0
	Ads._load_state()
	check(Ads._last_full_screen_ad_time == 0.0, "negatif damga 0'a kırpıldı")


# --- Kaynak katmanı: çağrı grafiği ---------------------------------------

func _test_cooldown_is_shared() -> void:
	print("\n[6] Tek ortak soğuma sayacı")
	for fn in ["show_interstitial", "show_app_open"]:
		var body := _body(ads_src, fn)
		check(body != "", "%s bulundu" % fn)
		check(body.contains("_elapsed_since(_last_full_screen_ad_time)")
			and body.contains("_FULL_SCREEN_AD_COOLDOWN_SEC"),
			"%s göstermeden ÖNCE ortak soğumayı kontrol ediyor" % fn)
		check(body.contains("_mark_full_screen_ad_shown()"),
			"%s gösterince ortak sayacı ilerletiyor" % fn)
	# Ödüllü reklam sayacı okumaz (oyuncunun kendi isteği) ama ilerletir.
	var rew := _body(ads_src, "show_rewarded")
	check(rew.contains("_mark_full_screen_ad_shown()"),
		"show_rewarded sayacı İLERLETİYOR (ardından zorunlu reklam gelmesin)")
	check(not rew.contains("_FULL_SCREEN_AD_COOLDOWN_SEC"),
		"show_rewarded sayacı OKUMUYOR — opt-in ödül soğumaya takılmıyor")


## AdMob'un en sert kuralı: uygulama açılışında/öne gelişinde geçiş reklamı
## yasak. O senaryonun tek izinli formatı App Open.
func _test_no_interstitial_on_app_open() -> void:
	print("\n[7] Açılış/öne geliş = App Open, asla geçiş reklamı")
	var notif := _body(main_src, "_notification")
	check(notif.contains("NOTIFICATION_APPLICATION_FOCUS_IN"),
		"main.gd öne gelişi dinliyor")
	check(notif.contains("_try_app_open_ad()"),
		"öne gelişte _try_app_open_ad çağrılıyor")
	check(not notif.contains("show_interstitial"),
		"öne geliş yolunda show_interstitial YOK")

	var app_open := _body(main_src, "_try_app_open_ad")
	check(app_open.contains("Ads.show_app_open("),
		"_try_app_open_ad App Open formatını kullanıyor")
	check(not app_open.contains("show_interstitial"),
		"_try_app_open_ad geçiş reklamına DÜŞMÜYOR")
	check(app_open.contains("overlay") or app_open.contains("visible"),
		"_try_app_open_ad açık bir popup varken göstermiyor")


func _test_interstitial_trigger_points() -> void:
	print("\n[8] Geçiş reklamı yalnızca doğal molalarda")
	var brk := _body(main_src, "_try_break_interstitial")
	check(brk.contains("Ads.show_interstitial("), "_try_break_interstitial tanımlı")
	check(brk.contains("overlay") and brk.contains("return"),
		"popup açıkken geçiş reklamı gösterilmiyor (oyuncu bir eylemin ortasında)")
	# Çağrı yerlerinin tamamı sayılır: beklenmedik bir yerden çağrılırsa fark edilsin.
	var call_sites := 0
	for line in main_src.split("\n"):
		if line.contains("Ads.show_interstitial("):
			call_sites += 1
	check(call_sites <= 2,
		"show_interstitial main.gd'de en fazla 2 yerden çağrılıyor (%d)" % call_sites)


func _test_remove_ads_gating() -> void:
	print("\n[9] remove_ads satın alımı")
	for line in main_src.split("\n"):
		if line.contains("Ads.show_interstitial(") or line.contains("Ads.show_app_open("):
			check(line.contains("not Game.remove_ads"),
				"zorunlu reklam çağrısı remove_ads ile kapatılıyor: %s" % line.strip_edges())
	# Ads bu kararı KENDİ vermez — çağıran taraf verir (show_if sözleşmesi).
	# Yalnızca KOD satırlarına bakılır: aynı ifade dosyanın doküman yorumunda da
	# geçiyor ve orada geçmesi doğru.
	var code_refs := 0
	for line in ads_src.split("
"):
		var t := line.strip_edges()
		if t.begins_with("#"):
			continue
		if t.contains("Game.remove_ads"):
			code_refs += 1
	check(code_refs == 0,
		"ads.gd KODU oyun durumuna bakmıyor — karar çağırana ait (show_if)")


func _test_rewarded_is_opt_in() -> void:
	print("\n[10] Ödüllü reklam opt-in kalıyor")
	# remove_ads ödüllü reklamı KAPATMAMALI: oyuncu isteyerek izleyip ödül alır.
	var rewarded_lines := 0
	for line in main_src.split("\n"):
		if line.contains("Ads.show_rewarded("):
			rewarded_lines += 1
			check(not line.contains("remove_ads"),
				"ödüllü reklam remove_ads'e bağlanmamış: %s" % line.strip_edges())
	check(rewarded_lines >= 1, "en az bir ödüllü reklam noktası var (%d)" % rewarded_lines)
	# Masaüstünde SDK yok: ödül anında verilmeli, yoksa test/geliştirme tıkanır.
	var got := [false]
	Ads.show_rewarded(func(): got[0] = true)
	check(got[0], "SDK yokken show_rewarded ödülü anında veriyor")


func _test_app_open_staleness() -> void:
	print("\n[11] Bayat App Open reklamı gösterilmiyor")
	var body := _body(ads_src, "show_app_open")
	check(body.contains("_APP_OPEN_MAX_CACHE_SEC"),
		"show_app_open bayatlama süresini kontrol ediyor")
	check(body.contains("_release_app_open_ad"),
		"bayat reklam atılıyor")
	# Bayat dalında gösterim OLMAMALI: atıp `return` etmeli.
	var stale := body.get_slice("_APP_OPEN_MAX_CACHE_SEC", 1)
	var before_show := stale.get_slice("_app_open_ad.show()", 0)
	check(before_show.contains("return"),
		"bayat dalı göstermeden dönüyor (return, show değil)")


func _test_consent() -> void:
	print("\n[12] Rıza (UMP) akışı")
	check(ads_src.contains("UserMessagingPlatform"), "UMP rıza akışı kurulu")
	var init := _body(ads_src, "_request_consent_then_init")
	check(init.contains("consent_info.update"), "rıza bilgisi güncelleniyor")
	check(ads_src.contains("func consent_options_available"),
		"gizlilik seçenekleri sorgulanabiliyor")
	check(main_src.contains("Ads.show_privacy_options_form()"),
		"Ayarlar'dan gizlilik formu açılabiliyor (GDPR şartı)")
	# Rıza alınmadan reklam yüklenmemeli: init rızanın ARDINDAN çağrılıyor.
	var ready_body := _body(ads_src, "_ready")
	check(ready_body.contains("_request_consent_then_init()")
		and not ready_body.contains("_init_ads()"),
		"_ready doğrudan _init_ads çağırmıyor — önce rıza")
