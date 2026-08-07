extends Node
## Bulut kaydı — AĞSIZ headless testi.
##
## Bulut kaydının ağa DOKUNMAYAN çekirdeğini (src/cloud/cloud_payload.gd)
## doğrular: çakışma kararı tablosu, entitlement soyma (iki yönlü), buluttan
## gelen verinin yerel doğrulama kapısından geçmesi ve payload boyutu.
## Gerçek Firestore/Auth yolu bilerek KAPSAM DIŞI — bu test ağ olmadan,
## CI'da/masaüstünde her zaman çalışabilmeli.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/cloud_save_check.tscn

var GameScript
var eco: Dictionary
var quests: Array
var achievements: Array

var checks := 0
var failures: Array = []


func _ready() -> void:
	GameScript = load("res://src/autoload/game.gd")
	var tmp = GameScript.new()
	eco = tmp.load_json("res://data/economy.json")
	quests = tmp.load_json("res://data/quests.json").get("quests", [])
	achievements = tmp.load_json("res://data/achievements.json").get("achievements", [])
	tmp.free()

	print("Little Grand Hotel — bulut kaydı (ağsız) testi")
	print("=".repeat(64))

	_test_config_gate()
	_test_decision_table()
	_test_entitlements_not_uploaded()
	_test_entitlements_not_restored()
	_test_malicious_cloud_payload_rejected()
	_test_round_trip_keeps_progress()
	_test_pristine_detection()
	_test_max_payload_fits()
	await _test_conflict_ui_renders()

	print("\n" + "=".repeat(64))
	if failures.is_empty():
		print("SONUÇ: %d kontrol, hepsi geçti." % checks)
	else:
		print("SONUÇ: %d kontrol, %d BAŞARISIZ:" % [checks, failures.size()])
		for f in failures:
			printerr("  BAŞARISIZ: ", f)
	print("CLOUD_SAVE_DONE")
	get_tree().quit(1 if not failures.is_empty() else 0)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  OK    %s" % label)
	else:
		failures.append(label)
		printerr("  FAIL  %s" % label)


func _new_game() -> Object:
	var g = GameScript.new()
	g.eco = eco
	g.quests = quests
	g.achievements = achievements
	g.new_game()
	return g


# --- 1) Yapılandırma kapısı ---------------------------------------------

## Bulut kaydına giden HER yol tek bir kapıdan geçer: FirebaseConfig.is_configured().
## Placeholder'lar dururken kapı kapalı olmalı (Firebase projesi kurulmadan
## yapılan bir sürüm her açılışta boşuna ağa çıkmasın), doldurulduktan sonra da
## gerçekten açılmalı.
##
## Beklenti sabitlerin kendisinden türetiliyor, sabit bir "false" beklenmiyor:
## proje yapılandırıldığında testin kırılmaması için. (Kırıldı da — yapılandırma
## dolduruldu ve bu bölüm hâlâ boş placeholder varsayıyordu.)
func _test_config_gate() -> void:
	print("\n--- 1) Yapılandırma kapısı ---")
	var configured: bool = not FirebaseConfig.API_KEY.begins_with("REPLACE_") \
		and not FirebaseConfig.PROJECT_ID.begins_with("REPLACE_")
	var google_configured: bool = configured \
		and not FirebaseConfig.GOOGLE_WEB_CLIENT_ID.begins_with("REPLACE_")
	print("    (yapılandırma dolu mu: %s)" % configured)
	_check(FirebaseConfig.is_configured() == configured,
		"is_configured() sabitlerle tutarlı")
	_check(FirebaseConfig.is_google_configured() == google_configured,
		"is_google_configured() sabitlerle tutarlı")
	var cs := get_node_or_null("/root/CloudSave")
	_check(cs != null, "CloudSave autoload'ı kayıtlı")
	if cs:
		_check(cs.is_enabled() == configured, "CloudSave.is_enabled() kapıyla aynı")
		_check(not cs.has_conflict(), "açılışta çakışma yok")


# --- 2) Çakışma karar tablosu -------------------------------------------

func _test_decision_table() -> void:
	print("\n--- 2) Çakışma karar tablosu (saf fonksiyon) ---")
	var cases := [
		# [ad, local_rev, dirty, cloud_exists, cloud_rev, cloud_schema, local_schema, beklenen]
		["bulutta kayıt yok", 0, false, false, 0, 0, 14, CloudPayload.RESULT_UPLOAD],
		["yerel güncel, temiz", 5, false, true, 5, 14, 14, CloudPayload.RESULT_IN_SYNC],
		["yerel güncel, kirli", 5, true, true, 5, 14, 14, CloudPayload.RESULT_UPLOAD],
		["yerel ileride", 9, false, true, 5, 14, 14, CloudPayload.RESULT_IN_SYNC],
		["bulut ileride, temiz", 2, false, true, 7, 14, 14, CloudPayload.RESULT_RESTORE],
		["bulut ileride, kirli", 2, true, true, 7, 14, 14, CloudPayload.RESULT_CONFLICT],
		["bulut şeması yeni", 2, false, true, 7, 99, 14, CloudPayload.RESULT_NEEDS_UPDATE],
		["bulut şeması yeni + kirli", 2, true, true, 7, 99, 14, CloudPayload.RESULT_NEEDS_UPDATE],
	]
	for c in cases:
		var got: String = CloudPayload.decide(c[1], c[2], c[3], c[4], c[5], c[6])
		_check(got == c[7], "%s -> %s (beklenen %s)" % [c[0], got, c[7]])
	# Cihaz saati kararın hiçbir yerine girmiyor: decide() saat parametresi
	# almıyor. Bu, "saati ileri alınmış cihaz kalıcı olarak kazanır" hatasının
	# yapısal olarak imkânsız olduğu anlamına gelir.


# --- 3) Entitlement payload'a YAZILMAZ ----------------------------------

func _test_entitlements_not_uploaded() -> void:
	print("\n--- 3) Entitlement buluta gitmiyor ---")
	var g = _new_game()
	g.remove_ads = true
	g.permanent_income_mult = 2.0
	g.gems = 777
	var payload := CloudPayload.build(g)
	var parsed: Dictionary = JSON.parse_string(payload)
	_check(not parsed.has("remove_ads"), "payload'da remove_ads yok")
	_check(not parsed.has("permanent_income_mult"), "payload'da permanent_income_mult yok")
	# Elmas bilerek KALIR (oyun içi kaynak; soyulursa geri yükleme ilerleme siler).
	_check(int(parsed.get("gems", 0)) == 777, "payload'da gems korunuyor (ilerleme)")
	# Yerel durum payload üretiminden etkilenmemeli.
	_check(g.remove_ads == true and g.permanent_income_mult == 2.0,
		"payload üretimi yerel entitlement'ları bozmuyor")
	g.free()


# --- 4) Entitlement buluttan GERİ YÜKLENMEZ -----------------------------

func _test_entitlements_not_restored() -> void:
	print("\n--- 4) Entitlement buluttan geri yüklenmiyor ---")

	# 4a) Meşru yol: satın almış bir cihaz, entitlement'sız payload'ı indirince
	#     hakkını KAYBETMEMELİ.
	var src = _new_game()
	src.coins = 12345
	src.gems = 42
	var clean_payload := CloudPayload.build(src)
	src.free()

	var buyer = _new_game()
	buyer.remove_ads = true
	buyer.permanent_income_mult = 2.0
	_check(CloudPayload.apply(buyer, clean_payload), "temiz payload uygulandı")
	_check(buyer.remove_ads == true, "geri yükleme sonrası remove_ads korundu")
	_check(buyer.permanent_income_mult == 2.0, "geri yükleme sonrası kazanç çarpanı korundu")
	_check(buyer.coins == 12345, "geri yükleme ilerlemeyi getirdi (coins)")
	buyer.free()

	# 4b) Saldırı yolu: elle düzenlenmiş bir payload entitlement'ı true yapsa
	#     bile bedava hak VERİLMEMELİ (savunma derinliği — tek yönlü filtre yetmez).
	var attacked: Dictionary = JSON.parse_string(clean_payload)
	attacked["remove_ads"] = true
	attacked["permanent_income_mult"] = 5.0
	var victim = _new_game()
	_check(CloudPayload.apply(victim, JSON.stringify(attacked)), "sahte payload uygulandı")
	_check(victim.remove_ads == false, "sahte payload reklamları kaldıramadı")
	_check(victim.permanent_income_mult == 1.0, "sahte payload kazanç çarpanı veremedi")
	victim.free()


# --- 5) Bulut verisi yerel doğrulama kapısından geçiyor -----------------

## Bulut payload'ı, forumdan yapıştırılan bir kayıt kodundan daha güvenilir
## değildir (dokümanı yazan istemci değiştirilmiş olabilir). Bu yüzden aynı
## _validate_save_dict kapısını kullanmalı ve reddedilen bir payload mevcut
## oyun durumunu BOZMAMALI.
func _test_malicious_cloud_payload_rejected() -> void:
	print("\n--- 5) Bozuk bulut payload'ı reddediliyor ---")
	var src = _new_game()
	src.coins = 5000
	var base: Dictionary = JSON.parse_string(CloudPayload.build(src))
	src.free()

	var variants := [
		["JSON değil", "{bu json değil"],
		["dizi (dict değil)", "[1,2,3]"],
		["negatif coin", _mutated(base, "coins", -50)],
		["devasa coin (int64 taşması)", _mutated(base, "coins", 1e30)],
		["coins yerine dict", _mutated(base, "coins", {"a": 1})],
		["rooms dizi değil", _mutated(base, "rooms", {"a": 1})],
		["staff_tier aralık dışı", _mutated(base, "staff_tier", 9999)],
		["save_version gelecekten", _mutated(base, "save_version", 999)],
		["çakışan oda id'leri", _duplicate_room(base)],
	]
	for v in variants:
		var g = _new_game()
		var coins_before: int = g.coins
		var rooms_before: int = g.rooms.size()
		var ok: bool = CloudPayload.apply(g, String(v[1]))
		_check(not ok, "reddedildi: %s" % v[0])
		_check(g.coins == coins_before and g.rooms.size() == rooms_before,
			"reddedilen payload durumu bozmadı: %s" % v[0])
		g.free()


func _mutated(base: Dictionary, key: String, value) -> String:
	var d := base.duplicate(true)
	d[key] = value
	return JSON.stringify(d)


func _duplicate_room(base: Dictionary) -> String:
	var d := base.duplicate(true)
	var rooms: Array = d.get("rooms", [])
	if rooms.size() >= 2:
		rooms[1]["id"] = rooms[0]["id"]
	return JSON.stringify(d)


# --- 6) Gidiş-dönüş ilerlemeyi koruyor ----------------------------------

func _test_round_trip_keeps_progress() -> void:
	print("\n--- 6) Gidiş-dönüş ---")
	var src = _new_game()
	src.coins = 250000
	src.gems = 310
	src.xp = 4200
	src.buy_floor()
	src.buy_room("cafe")
	src.buy_room("deluxe")
	src.stat_shifts = 17
	src.prestige_level = 3
	src.hotel_name = "Bulut Oteli"
	var payload := CloudPayload.build(src)
	var want := {
		"coins": src.coins, "gems": src.gems, "xp": src.xp, "level": src.level(),
		"rooms": src.rooms.size(), "floors": src.floors,
		"prestige": src.prestige_level, "name": src.hotel_name,
	}
	var summary := CloudPayload.summary(src)
	src.free()

	var dst = _new_game()
	_check(CloudPayload.apply(dst, payload), "payload uygulandı")
	_check(dst.coins == want.coins, "coins korundu (%d)" % dst.coins)
	_check(dst.gems == want.gems, "gems korundu (%d)" % dst.gems)
	_check(dst.xp == want.xp, "xp korundu (%d)" % dst.xp)
	_check(dst.level() == want.level, "seviye korundu (%d)" % dst.level())
	_check(dst.rooms.size() == want.rooms, "oda sayısı korundu (%d)" % dst.rooms.size())
	_check(dst.floors == want.floors, "kat sayısı korundu (%d)" % dst.floors)
	_check(dst.prestige_level == want.prestige, "prestij korundu (%d)" % dst.prestige_level)
	_check(dst.hotel_name == want.name, "otel adı korundu (%s)" % dst.hotel_name)
	# Çakışma ekranı payload'ı açmadan bu özeti gösterir.
	_check(int(summary.level) == want.level and int(summary.coins) == want.coins \
		and int(summary.gems) == want.gems and int(summary.rooms) == want.rooms,
		"özet (level/coins/gems/rooms) kayıtla tutarlı: %s" % str(summary))
	dst.free()


# --- 7) Taze kurulum hızlı yolu -----------------------------------------

func _test_pristine_detection() -> void:
	print("\n--- 7) El değmemiş kayıt tespiti ---")
	var fresh = _new_game()
	_check(CloudPayload.is_pristine(fresh), "yepyeni kayıt el değmemiş sayılıyor")
	fresh.coins = 100000
	_check(fresh.buy_room("standard"), "1. seviyede standart oda alınabildi")
	_check(not CloudPayload.is_pristine(fresh), "oda alınınca artık el değmemiş değil")
	fresh.free()

	var played = _new_game()
	played.stat_shifts = 1
	_check(not CloudPayload.is_pristine(played), "vardiya başlatılmış kayıt el değmemiş değil")
	played.free()


# --- 8) Payload doküman tavanına sığıyor --------------------------------

## Payload tavanı aşarsa yükleme SESSİZCE atlanır (bkz. cloud_save.gd) — yani
## en çok ilerlemiş oyuncu bulut kaydını hiç kullanamaz. Gerçekçi bir üst sınır
## (tüm katlar, tüm bloklar dolu, her oda dekorlu) burada ölçülür.
func _test_max_payload_fits() -> void:
	print("\n--- 8) En büyük kayıtta payload boyutu ---")
	var g = _new_game()
	g.coins = 1_000_000_000
	g.gems = 1_000_000
	var max_floors: int = int(eco.building.max_floors)
	while g.floors < max_floors:
		g.floors += 1
		g.floor_blocks.append(int(eco.building.grid_cols))
	for i in g.floor_blocks.size():
		g.floor_blocks[i] = int(eco.building.grid_cols)
	g.rooms = []
	var decor: Array = []
	for it in eco.items:
		if it.has("anchor"):
			decor.append(String(it.id))
	for floor_i in range(1, g.floors + 1):
		for col in int(eco.building.grid_cols):
			var r: Dictionary = g.make_room("standard", floor_i, col)
			r["items"] = decor.duplicate()
			g.rooms.append(r)
	for i in 20:
		g.shift_history.append({"hours": 8, "cost": 1234, "at": g.now()})
	for a in achievements:
		g.unlocked_achievements.append(String(a.id))

	var payload := CloudPayload.build(g)
	print("    %d oda, %d kat -> payload %d bayt (tavan %d)" \
		% [g.rooms.size(), g.floors, payload.length(), CloudPayload.MAX_PAYLOAD_BYTES])
	_check(payload.length() < CloudPayload.MAX_PAYLOAD_BYTES,
		"en büyük kayıt doküman tavanına sığıyor")
	# Ve o dev payload hâlâ geri yüklenebilmeli.
	var dst = _new_game()
	_check(CloudPayload.apply(dst, payload), "en büyük kayıt geri yüklenebiliyor")
	_check(dst.rooms.size() == g.rooms.size(), "geri yüklemede oda sayısı aynı")
	dst.free()
	g.free()


# --- 9) Çakışma seçici gerçekten çiziliyor ------------------------------

## Ağ yolu test edilemiyor, ama çakışma UI'ı edilebilir: CloudSave'e sahte bir
## "bekleyen bulut kaydı" yerleştirip modalı main.tscn üstünde ÇİZDİRİYORUZ ve
## "Buluttakini kullan" kararını gerçekten uyguluyoruz. Böylece seçicinin iki
## tarafı da özet gösterebiliyor mu ve karar uygulanıyor mu görülür.
##
## Bu bölüm CANLI Game autoload'ını değiştirir ve user://save.json'a yazar —
## geliştiricinin kaydı kaybolmasın diye teste girerken bir yana alınır
## (fuzz_attack.gd ile aynı desen).
const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.cloudtest.bak"


func _test_conflict_ui_renders() -> void:
	print("\n--- 9) Çakışma seçici (main.tscn üstünde) ---")
	_stash_save()

	var game := get_node("/root/Game")
	var cs := get_node("/root/CloudSave")
	game.tutorial_seen = true

	# Buluttaki "diğer cihaz" kaydını üret.
	var other = _new_game()
	other.coins = 987654
	other.gems = 123
	other.xp = 9000
	other.hotel_name = "Diğer Cihaz Oteli"
	var cloud_payload := CloudPayload.build(other)
	var cloud_summary := CloudPayload.summary(other)
	other.free()

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	main._finish_loading_screen()
	await get_tree().process_frame

	# Yapılandırma yokken bölüm "yakında" dalını çizmeli — çökmemeli.
	var probe := VBoxContainer.new()
	add_child(probe)
	main._build_cloud_section(probe)
	_check(probe.get_child_count() > 0, "yapılandırma yokken Hesap bölümü çiziliyor")
	probe.queue_free()

	_check(main._fmt_relative(Time.get_unix_time_from_system() - 120.0) == "2 dakika önce",
		"göreli zaman metni doğru")
	_check(main._cloud_result_toast(CloudPayload.RESULT_RESTORE) != "",
		"senkron sonucu için kullanıcı metni var")

	# Sahte çakışma: normalde sync_now() doldurur, burada doğrudan yerleştirilir.
	cs._blocked = true
	cs._pending_cloud = {
		"rev": 7, "payload": cloud_payload, "summary": cloud_summary,
		"updated_at": Time.get_unix_time_from_system() - 3600.0,
	}
	_check(cs.has_conflict(), "çakışma durumu kuruldu")

	main._show_cloud_conflict_modal()
	await get_tree().process_frame
	_check(main._cloud_conflict_open, "çakışma seçici açıldı")
	print("           node sayısı: %d (çökme yok)" % get_tree().get_node_count())

	# Kararı uygula: buluttaki kazansın.
	var ok: bool = cs.resolve_keep_cloud()
	await get_tree().process_frame
	_check(ok, "\"Buluttakini kullan\" kararı uygulandı")
	_check(game.coins == 987654, "bulut kaydı oyuna yüklendi (coins %d)" % game.coins)
	_check(game.hotel_name == "Diğer Cihaz Oteli", "bulut kaydı oyuna yüklendi (otel adı)")
	_check(not cs.has_conflict(), "karar sonrası çakışma temizlendi")

	main.queue_free()
	await get_tree().process_frame
	_restore_save()


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
