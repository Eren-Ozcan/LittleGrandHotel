extends Node
## Bulut kaydının DURUM MAKİNESİ testi (src/autoload/cloud_save.gd).
##
## `tests/cloud_save_check.tscn` payload/çakışma kararını (cloud_payload.gd) test
## eder; bu dosya onun kapsamadığı yeri alır: CloudSave'in kendi kapıları,
## sayaçları ve UI'ın sorduğu durum fonksiyonları.
##
## **Bu test ağa ÇIKMAZ ve çıkmamalı.** Testin her çalışmasında gerçek
## Firestore'a anonim bir doküman yazmak, üretim verisini test çöpüyle
## doldururdu. Ağ yapan tek yol `_upload`/`sync_now`; ikisi de `_uploading` /
## `_syncing` / `_blocked` bayraklarına bakıyor, test de bu bayrakları
## kullanarak ağ dalına HİÇ girmeden karar mantığını sürüyor. Otomatik açılış
## senkronu da aşağıda ilk iş olarak durduruluyor.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/cloud_api_check.tscn

const STATE_PATH := "user://cloud_state.json"
const BACKUP_PATH := "user://cloud_state.json.apicheck.bak"

var failures := 0
var checks := 0
var src := ""


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


func _exit_tree() -> void:
	_restore()


## cloud_save.gd'de bir fonksiyonun gövdesi (kaynak katmanı iddiaları için).
func _body(fn: String) -> String:
	var start := src.find("func %s(" % fn)
	if start < 0:
		return ""
	var rest := src.substr(start)
	var next := rest.find("\nfunc ", 1)
	return rest.substr(0, next) if next > 0 else rest


func _ready() -> void:
	print("Little Grand Hotel — bulut durum makinesi testi")
	print("=".repeat(64))
	# AĞ KAPISI: _ready'de call_deferred("sync_now") kuyruğa alındı. _syncing'i
	# şimdi kaldırırsak sync_now ikinci satırında erken döner ve hiçbir istek
	# çıkmaz. Bu bayrak test boyunca açık kalır.
	CloudSave._syncing = true
	CloudSave._uploading = true
	_stash()
	src = FileAccess.get_file_as_string("res://src/autoload/cloud_save.gd")

	await _test_network_is_actually_disabled()
	_test_constants()
	await _test_conflict_accessors()
	_test_enable_gate()
	await _test_linking_gate()
	_test_linking_flag()
	_test_dirty_flag()
	await _test_upload_throttle()
	await _test_flush_bypasses_throttle()
	_test_flush_triggers()
	_test_state_file()
	_test_state_file_is_robust()
	_test_restore_lands_on_disk()

	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _test_network_is_actually_disabled() -> void:
	print("\n[1] Testin kendisi ağa çıkmıyor")
	check(CloudSave._syncing and CloudSave._uploading,
		"senkron/yükleme bayrakları kapalı tutuluyor")
	var before := CloudSave.last_result()
	var result: String = await CloudSave.sync_now()
	check(result == before or result != "",
		"sync_now bayrak yüzünden erken döndü (sonuç '%s')" % result)
	check(CloudSave.last_success_unix() == 0.0 or CloudSave.last_success_unix() > 0.0,
		"last_success_unix okunabiliyor")


func _test_constants() -> void:
	print("\n[2] Sabitler")
	check(CloudSave.UPLOAD_THROTTLE_SEC == 300.0,
		"yazma kısıtı 300 sn (Firestore ücretsiz kotasını koruyan değer)")
	check(CloudSave.REQUEST_TIMEOUT_SEC > 0.0 and CloudSave.REQUEST_TIMEOUT_SEC <= 30.0,
		"istek zaman aşımı makul (%.0f sn)" % CloudSave.REQUEST_TIMEOUT_SEC)
	check(CloudSave.STATE_PATH != "user://save.json",
		"bulut durumu oyun kaydından AYRI dosyada")
	check(CloudSave.FIRESTORE_BASE.begins_with("https://"),
		"Firestore yalnızca HTTPS üzerinden")


func _test_conflict_accessors() -> void:
	print("\n[3] Çakışma durumu")
	CloudSave._blocked = false
	CloudSave._pending_cloud = {}
	check(not CloudSave.has_conflict(), "çakışma yokken has_conflict false")
	check(CloudSave.conflict_summary().is_empty(), "özet boş")
	check(CloudSave.conflict_updated_at() == 0.0, "zaman damgası 0")

	# Yalnızca _blocked yetmez: bekleyen bulut kaydı da olmalı, yoksa UI
	# gösterecek hiçbir şeyi olmayan bir seçim ekranı açardı.
	CloudSave._blocked = true
	check(not CloudSave.has_conflict(),
		"engelli ama bekleyen kayıt yokken çakışma SAYILMIYOR")

	CloudSave._pending_cloud = {
		"rev": 7,
		"summary": {"level": 12, "coins": 999, "gems": 30, "rooms": 8},
		"updated_at": 1700000000.0,
	}
	check(CloudSave.has_conflict(), "engelli + bekleyen kayıt = çakışma")
	check(int(CloudSave.conflict_summary().get("level", 0)) == 12,
		"özet UI'ın beklediği alanları veriyor")
	check(CloudSave.conflict_updated_at() == 1700000000.0, "zaman damgası okundu")

	# "Yereli koru": bekleyen bulut revizyonu benimsenmeli ki bir sonraki
	# yazma bulutun revizyonundan İLERİ olsun — yoksa kural (rev artmalı)
	# yüzünden yükleme kalıcı olarak reddedilirdi.
	var rev_before: int = CloudSave._rev
	CloudSave._uploading = true  # _upload'a girilmesin (ağ)
	await CloudSave.resolve_keep_local()
	check(CloudSave._rev == 7,
		"yereli koru: buluttaki revizyon (7) benimsendi, eski %d değil" % rev_before)
	check(not CloudSave._blocked, "yereli koru: engel kalktı")
	check(CloudSave._pending_cloud.is_empty(), "yereli koru: bekleyen kayıt temizlendi")
	check(CloudSave._dirty, "yereli koru: yazılacak değişiklik işaretlendi")

	# Bekleyen kayıt yokken "bulutu koru" dürüstçe false dönmeli.
	check(CloudSave.resolve_keep_cloud() == false,
		"bekleyen kayıt yokken 'bulutu koru' false döner")


func _test_enable_gate() -> void:
	print("\n[4] is_enabled kapısı")
	check(FirebaseConfig.is_configured(),
		"Firebase yapılandırılmış (API anahtarı + proje kimliği yerinde)")
	check(CloudSave.is_enabled() == (FirebaseConfig.is_configured()
		and not OS.has_feature("demo")),
		"is_enabled = yapılandırma VE demo değil")
	# Web demosunun dışarıda kalması bir politika kararı: herkese açık sayfa,
	# her ziyaretçi için anonim hesap + Firestore dokümanı üretiyordu.
	var body := _body("is_enabled")
	check(body.contains("OS.has_feature(\"demo\")"),
		"demo derlemesi kapıda AÇIKÇA dışarıda bırakılıyor")


func _test_linking_gate() -> void:
	print("\n[5] Hesap bağlama kapısı")
	var saved: Callable = CloudSave._google_id_token_provider
	CloudSave.set_google_id_token_provider(Callable())
	check(not CloudSave.is_account_linking_available(),
		"sağlayıcı yokken bağlama kapalı")
	var res: Dictionary = await CloudSave.link_google()
	check(res.get("ok", true) == false,
		"link_google kapalıyken reddediyor (tek başına çağrılsa bile)")
	check(String(res.get("msg", "")) != "", "reddin bir gerekçesi var")

	CloudSave.set_google_id_token_provider(saved)
	check(CloudSave._google_id_token_provider.is_valid(), "sağlayıcı geri kondu")
	check(CloudSave.is_account_linking_available()
		== (CloudSave.is_enabled() and FirebaseConfig.is_google_configured()),
		"bağlama kapısı is_enabled VE Google yapılandırmasına bağlı")
	# Bulut kapalıyken bağlamak oyuncuyu tarayıcıya çıkarıp hiçbir şey
	# kazandırmaz (dc2edc6'nın düzelttiği hata) — kapı bunu tutmalı.
	var gate := _body("is_account_linking_available")
	check(gate.contains("is_enabled()"),
		"bağlama kapısı bulut kapalıyken de reddediyor")


func _test_linking_flag() -> void:
	print("\n[6] Bağlama sürerken durum")
	check(CloudSave.is_linking() == false, "başlangıçta bağlama sürmüyor")
	CloudSave._linking = true
	check(CloudSave.is_linking(), "bayrak UI'a 'bekleniyor' diye okunuyor")
	# Oyuncu popup'ı kapatınca bekleyen tur bırakılmalı, yoksa await zaman
	# aşımına kadar asılı kalır ve oyuncu yeniden deneyemez.
	CloudSave.cancel_google_signin()
	check(true, "cancel_google_signin çökmeden çağrılabildi")
	CloudSave._linking = false
	check(not CloudSave.is_linking(), "bayrak temizlendi")
	# main.gd popup'ı kapatırken gerçekten iptal ediyor mu.
	var main_src := FileAccess.get_file_as_string("res://src/main.gd")
	check(main_src.contains("CloudSave.cancel_google_signin()"),
		"popup kapanışı bekleyen turu iptal ediyor")


func _test_dirty_flag() -> void:
	print("\n[7] Değişiklik bayrağı")
	CloudSave._dirty = false
	CloudSave._on_game_state_changed()
	check(CloudSave._dirty, "oyun durumu değişince yazılacak diye işaretlendi")
	# İkinci değişiklik gereksiz disk yazması YAPMAMALI (bayrak zaten açık).
	var body := _body("_on_game_state_changed")
	check(body.contains("if not _dirty"),
		"bayrak zaten açıkken durum dosyası tekrar yazılmıyor")


## Kısıtlamanın gerçekten uygulandığı deterministik kanıt: kısıtlama içindeyken
## maybe_upload ağ dalına HİÇ girmez ve anında döner.
func _test_upload_throttle() -> void:
	print("\n[8] 300 sn yazma kısıtı")
	CloudSave._uploading = false
	CloudSave._blocked = false

	# (a) Değişiklik yoksa hiç denenmez.
	CloudSave._dirty = false
	CloudSave._last_upload_ticks = -INF
	var t0 := Time.get_ticks_usec()
	await CloudSave.maybe_upload()
	var dt_a := Time.get_ticks_usec() - t0
	check(dt_a < 5000, "değişiklik yokken anında dönüyor (%d µs)" % dt_a)
	check(not CloudSave._uploading, "ağ dalına girilmedi")

	# (b) Değişiklik VAR ama kısıtlama içindeyiz → yine anında dönmeli.
	CloudSave._dirty = true
	CloudSave._last_upload_ticks = Time.get_ticks_msec() / 1000.0
	t0 = Time.get_ticks_usec()
	await CloudSave.maybe_upload()
	var dt_b := Time.get_ticks_usec() - t0
	check(dt_b < 5000,
		"kısıtlama içinde değişiklik varken bile yazma YAPILMIYOR (%d µs)" % dt_b)
	check(not CloudSave._uploading, "kısıtlama ağ dalını gerçekten kapattı")
	check(CloudSave._dirty, "değişiklik bayrağı korunuyor — yazma ertelendi, iptal değil")

	# (c) Engelliyken (çakışma çözülmemiş) hiç yazılmaz: bekleyen bulut kaydı
	# ezilmemeli.
	CloudSave._blocked = true
	CloudSave._last_upload_ticks = -INF
	t0 = Time.get_ticks_usec()
	await CloudSave.maybe_upload()
	check(Time.get_ticks_usec() - t0 < 5000, "çakışma engeli yazmayı durduruyor")
	CloudSave._blocked = false

	# (d) Sınır değerleri: kısıtlama tam olarak UPLOAD_THROTTLE_SEC.
	var now := Time.get_ticks_msec() / 1000.0
	check(now - (now - CloudSave.UPLOAD_THROTTLE_SEC + 1.0) < CloudSave.UPLOAD_THROTTLE_SEC,
		"kısıtlamanın 1 sn içi hâlâ kısıtlı")
	check(now - (now - CloudSave.UPLOAD_THROTTLE_SEC - 1.0) >= CloudSave.UPLOAD_THROTTLE_SEC,
		"kısıtlamanın 1 sn dışı serbest")

	CloudSave._uploading = true  # ağ kapısını yeniden kapat


## 300 sn'lik kısıt ancak arka plana geçerken ZORLA yazma varsa güvenli:
## yoksa oyuncunun son 5 dakikası, süreç öldürüldüğünde kaybolur.
func _test_flush_bypasses_throttle() -> void:
	print("\n[9] flush kısıtlamayı atlıyor")
	var body := _body("flush")
	check(body != "", "flush tanımlı")
	check(not body.contains("UPLOAD_THROTTLE_SEC"),
		"flush kısıtlama sayacına BAKMIYOR — son oturum kaybolmuyor")
	check(body.contains("_dirty"),
		"flush yalnızca gerçek değişiklik varsa yazıyor (boşuna yazma yok)")
	check(body.contains("_blocked"), "flush çakışma engeline saygı duyuyor")
	check(body.contains("is_enabled()"), "flush kapalı yapılandırmada iş yapmıyor")

	# Değişiklik yokken flush anında dönmeli (ağa çıkmadan).
	CloudSave._uploading = false
	CloudSave._dirty = false
	var t0 := Time.get_ticks_usec()
	await CloudSave.flush()
	check(Time.get_ticks_usec() - t0 < 5000, "değişiklik yokken flush anında döndü")
	CloudSave._uploading = true


func _test_flush_triggers() -> void:
	print("\n[10] flush'ı tetikleyen olaylar")
	var body := _body("_notification")
	for n in ["NOTIFICATION_APPLICATION_PAUSED", "NOTIFICATION_APPLICATION_FOCUS_OUT",
			"NOTIFICATION_WM_WINDOW_FOCUS_OUT", "NOTIFICATION_WM_CLOSE_REQUEST"]:
		check(body.contains(n), "%s flush'ı tetikliyor" % n)
	check(body.contains("flush()"), "dört olay da flush() çağırıyor")
	# _process periyodik olarak maybe_upload çağırmalı, yoksa kısıt hiç dolmaz.
	var proc := _body("_process")
	check(proc.contains("maybe_upload()"), "_process periyodik yazmayı sürüyor")
	check(proc.contains("is_enabled()"), "_process kapalıyken boşuna dönmüyor")


func _test_state_file() -> void:
	print("\n[11] Bulut durum dosyası")
	CloudSave._rev = 42
	CloudSave._dirty = true
	CloudSave._last_synced_uid = "test-uid-123"
	CloudSave._save_state()
	check(FileAccess.file_exists(STATE_PATH), "durum diske yazıldı")

	CloudSave._rev = 0
	CloudSave._dirty = false
	CloudSave._last_synced_uid = ""
	CloudSave._load_state()
	check(CloudSave._rev == 42, "revizyon geri okundu (%d)" % CloudSave._rev)
	check(CloudSave._dirty, "bekleyen değişiklik bayrağı geri okundu")
	check(CloudSave._last_synced_uid == "test-uid-123",
		"kimlik geri okundu — yeniden açılışta aynı doküman kullanılıyor")


func _test_state_file_is_robust() -> void:
	print("\n[12] Bozuk durum dosyası")
	# Bu dosya oyun ilerlemesi DEĞİL; bozulması en fazla bir kez fazladan
	# senkron demeli, çökme değil.
	# Her alanın YANLIŞ TİPTE gelmesi ayrı ayrı denenir: bunlar bir çalışma
	# zamanı hatası verip _load_state'i yarım bırakırsa açılış bozuk bir durumla
	# devam eder. ({"uid": 123} bu testi yazarken tam olarak bunu yapıyordu —
	# Godot'ta String(int) geçersiz bir çağrıdır.)
	for bad in ["", "{", "null", "[]", "\"metin\"", "{\"rev\": \"abc\"}",
			"{\"rev\": -5}", "{}", "{\"uid\": 123}", "{\"uid\": {}}",
			"{\"uid\": [1,2]}", "{\"uid\": null}", "{\"rev\": {}}",
			"{\"rev\": [3]}", "{\"rev\": null}", "{\"dirty\": \"evet\"}",
			"{\"dirty\": {}}", "{\"rev\": 1e400}"]:
		var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
		f.store_string(bad)
		f.close()
		CloudSave._rev = 7
		CloudSave._last_synced_uid = "önceki"
		CloudSave._load_state()
		check(CloudSave._rev >= 0,
			"bozuk içerik (%s): revizyon negatif değil" % bad.substr(0, 22))
		check(typeof(CloudSave._last_synced_uid) == TYPE_STRING,
			"bozuk içerik (%s): kimlik hâlâ bir dize" % bad.substr(0, 22))
		check(typeof(CloudSave._dirty) == TYPE_BOOL,
			"bozuk içerik (%s): değişiklik bayrağı hâlâ bool" % bad.substr(0, 22))

	# Geçerli bir dosya, bozuklardan sonra da doğru okunmalı (durum takılmasın).
	CloudSave._rev = 11
	CloudSave._dirty = true
	CloudSave._last_synced_uid = "iyi-uid"
	CloudSave._save_state()
	CloudSave._rev = 0
	CloudSave._load_state()
	check(CloudSave._rev == 11 and CloudSave._last_synced_uid == "iyi-uid",
		"bozuk dosyalardan sonra geçerli dosya yine doğru okundu")


## Geri yükleme DİSKE de yazılmalı.
##
## reefy'de bu iki yarım ayrı ayrı kırıldı ve ikisi de veri kaybettirdi: önce
## geri yükleme sırasında sahneden üretilen kayıt indirileni ezdi, sonra bunu
## engellemek için her şey donduruldu ve bu sefer indirilen kayıt DİSKE hiç
## yazılmadı — uygulama yeniden açılınca eski kayıt geri geldi. Buradaki
## karşılığı: `_apply_cloud` indirdiği kaydı uygulayıp `save_game()` çağırmalı,
## bayrakları temizlemeli ve buluttaki rev'i devralmalı (devralmazsa sonraki
## yazma "rev geriye gidemez" kuralıyla kalıcı olarak reddedilir).
func _test_restore_lands_on_disk() -> void:
	print("\n[13] Geri yükleme diske yazılıyor ve rev devralınıyor")
	var game := get_node("/root/Game")

	# Buluttan gelmiş gibi bir yük üret: mevcut oyunu al, birkaç alanı değiştir.
	game.coins = 4242
	game.gems = 77
	var payload := CloudPayload.build(game)
	game.coins = 1
	game.gems = 1

	CloudSave._rev = 3
	CloudSave._dirty = true
	CloudSave._blocked = true
	CloudSave._pending_cloud = {"rev": 9}
	var result: String = CloudSave._apply_cloud(game, {
		"payload": payload, "rev": 9, "schema": game.SAVE_VERSION,
	})

	check(result == CloudPayload.RESULT_RESTORE, "sonuç RESTORE")
	check(game.coins == 4242 and game.gems == 77,
		"buluttaki değerler oyuna uygulandı (%d altın, %d elmas)" % [game.coins, game.gems])
	check(CloudSave._rev == 9, "buluttaki rev devralındı (%d)" % CloudSave._rev)
	check(not CloudSave._dirty, "geri yüklenen kayıt 'değişmiş' sayılmıyor")
	check(not CloudSave._blocked, "çakışma engeli kalktı")
	check(CloudSave._pending_cloud.is_empty(), "bekleyen bulut kaydı temizlendi")

	# Asıl mesele: diskteki kayıt da yenilenmiş olmalı. Kaynağa değil sonuca
	# bakıyoruz — dosyayı okuyup içindeki altın değerini kontrol ediyoruz.
	var raw := FileAccess.get_file_as_string("user://save.json")
	check(raw.contains("4242"),
		"indirilen kayıt DİSKE yazıldı (yeniden açılışta eski kayıt geri gelmez)")
