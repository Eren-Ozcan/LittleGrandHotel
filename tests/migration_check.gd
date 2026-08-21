extends Node
## Kayıt göçü testi (game.gd `_migrate_save`).
##
## Bu, projenin geri alınamaz tek kod yolu: bir oyuncunun kaydı yanlış göçerse
## ilerlemesi geri getirilemez. `_migrate_save` v2'den v%d'e kadar on üç adımlık
## bir zincir ve bugüne kadar hiç test edilmemişti.
##
## Ana iddialar:
##   ZİNCİR      — MIN_SAVE_VERSION..SAVE_VERSION-1 arasındaki HER sürüm güncele
##                 çıkıyor, doğrulamayı geçiyor ve gerçekten yüklenebiliyor.
##   KORUMA      — göç yalnızca EKSİK alanı doldurur; var olan bir değeri asla
##                 ezmez ve hiçbir anahtarı düşürmez.
##   v11 YENİDEN — düz oda dizisinin ızgaraya haritalanması: konum, taban eşya
##     YAPILANDIRMA  ayrımı, en iyi yatağın seçilmesi, kimlik/hücre çakışması.
##   ETKİSİZLİK  — güncel bir kaydı göçürmek onu değiştirmez.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/migration_check.tscn

var failures := 0
var checks := 0
var GameScript


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


## Autoload'a dokunmayan taze bir Game örneği (bkz. sim_check.gd).
func _new_game_instance():
	var g = GameScript.new()
	g.eco = g.load_json("res://data/economy.json")
	g.quests = g.load_json("res://data/quests.json").get("quests", [])
	g.achievements = g.load_json("res://data/achievements.json").get("achievements", [])
	return g


## v2 çağındaki kaydın biçimi: odalar DÜZ bir dizi (kat/sütun yok), eşyalar tek
## listede, taban eşya ayrımı yok, ses/başarım/prestij alanları hiç yok.
func _legacy_v2_save() -> Dictionary:
	return {
		"save_version": 2,
		"coins": 12345,
		"gems": 42,
		"xp": 900,
		"floors": 2,
		"quest_index": 3,
		"stat_shifts": 7,
		"stat_collects": 5,
		"stat_collected_total": 50000,
		"stat_cleans": 9,
		"pending_income": 120.5,
		"shift_end_unix": 0.0,
		"last_sim_unix": 0.0,
		"rooms": [
			{"type": "standard", "items": ["lamp_desk", "bed_basic", "rug_wool"],
				"dirty": false, "clean_left": 0.0},
			{"type": "deluxe", "items": ["bed_canopy", "bed_wood", "art_print"],
				"dirty": true, "clean_left": 1.5},
			{"type": "cafe", "items": ["plant_fern"], "dirty": false, "clean_left": 0.0},
		],
	}


func _ready() -> void:
	print("Little Grand Hotel — kayıt göçü testi")
	print("=".repeat(64))
	GameScript = load("res://src/autoload/game.gd")

	_test_version_constants()
	_test_every_version_migrates()
	_test_migration_is_idempotent()
	_test_existing_values_are_not_overwritten()
	_test_no_keys_are_dropped()
	_test_v11_room_restructure()
	_test_v12_tutorial_not_reshown()
	_test_migrated_save_loads()
	_test_out_of_range_versions_rejected()
	_test_empty_and_minimal_saves()

	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _test_version_constants() -> void:
	print("\n[1] Sürüm sabitleri")
	var g = _new_game_instance()
	check(g.SAVE_VERSION > g.MIN_SAVE_VERSION,
		"SAVE_VERSION (%d) > MIN_SAVE_VERSION (%d)" % [g.SAVE_VERSION, g.MIN_SAVE_VERSION])
	check(g.MIN_SAVE_VERSION >= 2, "en eski desteklenen sürüm 2")
	g.free()


## Zincirin HER halkası: v2, v3, … v(SAVE_VERSION-1) → güncel.
func _test_every_version_migrates() -> void:
	print("\n[2] Her sürüm güncele çıkıyor")
	var g = _new_game_instance()
	for v in range(g.MIN_SAVE_VERSION, g.SAVE_VERSION):
		var data := _legacy_v2_save()
		data["save_version"] = v
		var out: Dictionary = g._migrate_save(data.duplicate(true))
		check(int(out.get("save_version", -1)) == g.SAVE_VERSION,
			"v%d → v%d" % [v, g.SAVE_VERSION])
		check(g._validate_save_dict(out),
			"v%d'den göçen kayıt doğrulamayı geçiyor" % v)
	g.free()


func _test_migration_is_idempotent() -> void:
	print("\n[3] Göç etkisiz (idempotent)")
	var g = _new_game_instance()
	var once: Dictionary = g._migrate_save(_legacy_v2_save())
	var twice: Dictionary = g._migrate_save(once.duplicate(true))
	check(JSON.stringify(once) == JSON.stringify(twice),
		"güncel bir kaydı yeniden göçürmek onu DEĞİŞTİRMİYOR")
	# Zaten güncel sürümdeki kayıt hiç dokunulmadan dönmeli.
	var current := {"save_version": g.SAVE_VERSION, "coins": 5}
	var same: Dictionary = g._migrate_save(current.duplicate(true))
	check(int(same.coins) == 5 and int(same.save_version) == g.SAVE_VERSION,
		"güncel kayıt olduğu gibi bırakıldı")
	g.free()


## Göç yalnızca `if not data.has(...)` ile doldurur. Bu kural bozulursa
## oyuncunun ayarları/hakları sessizce sıfırlanır.
func _test_existing_values_are_not_overwritten() -> void:
	print("\n[4] Var olan değerler EZİLMİYOR")
	var g = _new_game_instance()
	var data := _legacy_v2_save()
	# Zincirin her adımının doldurduğu alanları, göç ÖNCESİNDE varsayılandan
	# FARKLI değerlerle dolduruyoruz.
	var preset := {
		"sound_on": false, "music_on": false,
		"unlocked_achievements": ["a01"],
		"prestige_level": 3,
		"auto_renew_shift": false, "last_shift_hours": 8,
		"daily_streak": 5, "last_daily_claim_day": 99,
		"poke_day": 7, "poke_count": 4,
		"staff_tier": 2,
		"boost_end_unix": 111.0, "boost_mult": 2.0,
		"remove_ads": true, "permanent_income_mult": 2.0,
		"tutorial_seen": false,
		"auto_renew_hours_left": 12.0,
		"hotel_name": "Benim Otelim",
		"language": "tr",
		"shift_history": [{"hours": 4}],
	}
	for k in preset:
		data[k] = preset[k]
	var out: Dictionary = g._migrate_save(data)
	for k in preset:
		check(JSON.stringify(out.get(k)) == JSON.stringify(preset[k]),
			"'%s' göçte korundu (%s)" % [k, JSON.stringify(out.get(k))])
	g.free()


func _test_no_keys_are_dropped() -> void:
	print("\n[5] Hiçbir anahtar düşmüyor")
	var g = _new_game_instance()
	var data := _legacy_v2_save()
	# Tanınmayan bir alan bile korunmalı: ileri sürümden geri dönen bir kayıt
	# ya da yeni eklenmiş bir alan sessizce silinmemeli.
	data["bilinmeyen_alan"] = {"x": 1}
	var before := data.keys()
	var out: Dictionary = g._migrate_save(data)
	var missing := []
	for k in before:
		if not out.has(k):
			missing.append(k)
	check(missing.is_empty(), "göç sonrası kayıp anahtar yok (%s)" % str(missing))
	check(out.has("bilinmeyen_alan"), "tanınmayan alan bile korundu")
	g.free()


## En riskli adım: düz oda dizisi ızgaraya haritalanıyor.
func _test_v11_room_restructure() -> void:
	print("\n[6] v11 — oda yapısının yeniden kurulması")
	var g = _new_game_instance()
	var data := _legacy_v2_save()
	var out: Dictionary = g._migrate_save(data)
	var rooms: Array = out.rooms
	check(rooms.size() == 3, "üç odanın üçü de göçtü")

	var ids := {}
	var cells := {}
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		check(r.has("floor") and r.has("col") and r.has("w"),
			"oda %d ızgara konumu aldı (kat %s, sütun %s)" % [i, r.floor, r.col])
		check(int(r.w) == 1, "oda %d güvenli 1x1 ayak izi aldı" % i)
		check(r.has("base"), "oda %d taban eşya sözlüğü aldı" % i)
		check(String(r.base.get("wallpaper", "")) != "", "oda %d duvar kâğıdı aldı" % i)
		check(String(r.base.get("floor", "")) != "", "oda %d zemini aldı" % i)
		var rid := String(r.get("id", ""))
		check(rid != "" and not ids.has(rid), "oda %d benzersiz kimlik aldı (%s)" % [i, rid])
		ids[rid] = true
		var cell := "%s:%s" % [r.floor, r.col]
		check(not cells.has(cell), "oda %d benzersiz hücrede (%s)" % [i, cell])
		cells[cell] = true

	# Yatak ayrıştırma: eski liste iki yatak içeriyordu, EN İYİSİ taban yuvaya
	# geçmeli, ikisi de eşya listesinde KALMAMALI.
	var deluxe: Dictionary = rooms[1]
	check(String(deluxe.base.get("bed", "")) == "bed_canopy",
		"iki yataklı odada en iyi yatak seçildi (bed_canopy)")
	check(not deluxe.items.has("bed_canopy") and not deluxe.items.has("bed_wood"),
		"yataklar eşya listesinden çıkarıldı — çift sayılmıyor")
	check(deluxe.items.has("art_print"), "yatak dışı eşya korundu")

	# Misafir odası olmayan (tesis) odaya yatak VERİLMEMELİ.
	var cafe: Dictionary = rooms[2]
	check(not cafe.base.has("bed"), "tesis odasına yatak eklenmedi")
	check(cafe.items.has("plant_fern"), "tesis odasının eşyası korundu")

	# Yataksız misafir odası varsayılan yatağı almalı (oda boş görünmesin).
	var std: Dictionary = rooms[0]
	check(String(std.base.get("bed", "")) == "bed_basic",
		"yatağı olan misafir odası onu taban yuvaya taşıdı")
	check(not std.items.has("bed_basic"), "taban yatak eşya listesinden çıktı")

	# Kat blokları ve sonraki oda kimliği üretilmeli.
	check(out.has("floor_blocks") and (out.floor_blocks as Array).size() == int(out.floors),
		"her kat için blok genişliği üretildi")
	check(int(out.get("next_room_id", -1)) >= rooms.size() - 1,
		"next_room_id kimlik çakışmasına yol açmayacak şekilde ayarlandı")

	# Yataksız bir misafir odası da çökertmemeli.
	var d2 := _legacy_v2_save()
	d2["rooms"] = [{"type": "standard", "items": [], "dirty": false}]
	var out2: Dictionary = g._migrate_save(d2)
	check(String((out2.rooms[0] as Dictionary).base.get("bed", "")) == "bed_basic",
		"eşyasız misafir odası varsayılan yatak aldı")
	g.free()


func _test_v12_tutorial_not_reshown() -> void:
	print("\n[7] v12 — mevcut oyuncuya tutorial tekrar gösterilmiyor")
	var g = _new_game_instance()
	var out: Dictionary = g._migrate_save(_legacy_v2_save())
	check(bool(out.get("tutorial_seen", false)) == true,
		"göçen oyuncu tutorial'ı görmüş sayılıyor")
	check(float(out.get("auto_renew_hours_left", -1.0)) == 0.0,
		"v13: göçen oyuncu 0 otomatik yenileme hakkıyla başlıyor")
	check(String(out.get("language", "yok")) == "",
		"v15: dil boş = cihaz dili (mevcut davranış korunuyor)")
	check(String(out.get("hotel_name", "")) != "", "v14: otel adı dolduruldu")
	g.free()


## Göçün ürettiği kayıt yalnızca "doğrulamayı geçmekle" kalmamalı, GERÇEKTEN
## yüklenmeli ve değerler oyuna doğru şekilde oturmalı.
func _test_migrated_save_loads() -> void:
	print("\n[8] Göçen kayıt gerçekten yükleniyor")
	var g = _new_game_instance()
	g.new_game()
	var out: Dictionary = g._migrate_save(_legacy_v2_save())
	var ok: bool = g._load_from_dict(out)
	check(ok, "_load_from_dict göçen kaydı kabul etti")
	# Yükleme geriye dönük başarım kontrolü de yapar (bkz. _check_progress):
	# göçen oyuncu, o güne kadar hak ettiği başarımların ödülünü yüklenirken
	# alır. Bu yüzden coin AZALMAMALI ama artabilir.
	check(g.coins >= 12345, "coin taşındı ve azalmadı (%d ≥ 12345)" % g.coins)
	check(g.unlocked_achievements.size() > 0,
		"geriye dönük başarımlar açıldı (%d) — coin farkı buradan geliyor"
			% g.unlocked_achievements.size())
	check(g.gems == 42, "elmas taşındı (%d)" % g.gems)
	check(g.rooms.size() == 3, "odalar taşındı (%d)" % g.rooms.size())
	check(g.quest_index == 3, "görev ilerlemesi taşındı")
	check(g.stat_cleans == 9, "istatistikler taşındı")
	check(g.level() >= 1, "seviye hesaplanabiliyor (%d)" % g.level())
	# Yüklendikten sonra yeniden kaydetmek güncel sürümü yazmalı.
	var redo: Dictionary = g._save_dict()
	check(int(redo.save_version) == g.SAVE_VERSION,
		"yeniden kaydetme güncel sürümü yazıyor")
	check(g._validate_save_dict(redo), "yeniden kaydedilen kayıt geçerli")
	g.free()


func _test_out_of_range_versions_rejected() -> void:
	print("\n[9] Aralık dışı sürümler reddediliyor")
	var g = _new_game_instance()
	g.new_game()
	var coins_before: int = g.coins
	for bad_v in [0, 1, g.SAVE_VERSION + 1, 9999, -3]:
		var data := _legacy_v2_save()
		data["save_version"] = bad_v
		var ok: bool = g._load_from_dict(data)
		check(not ok, "sürüm %d reddedildi" % bad_v)
	check(g.coins == coins_before,
		"reddedilen kayıtlar mevcut oyun durumunu BOZMADI (atomiklik)")
	g.free()


func _test_empty_and_minimal_saves() -> void:
	print("\n[10] Boş / asgari kayıtlar")
	var g = _new_game_instance()
	# Hiç alanı olmayan bir v2 kaydı: göç çökmemeli, doğrulamayı geçmeli.
	var bare := {"save_version": 2}
	var out: Dictionary = g._migrate_save(bare)
	check(int(out.save_version) == g.SAVE_VERSION, "alansız v2 kaydı göçtü")
	check(g._validate_save_dict(out), "alansız göç sonucu geçerli")
	check((out.get("rooms", []) as Array).is_empty(), "odasız kayıt odasız kaldı")
	check(out.has("floor_blocks"), "kat blokları yine de üretildi")

	# Odaların yerinde beklenmedik tipler olması göçü çökertmemeli; sonuç
	# doğrulamada elenir (ki asıl kapı orası).
	var weird := {"save_version": 10, "rooms": [], "floors": 2}
	var out2: Dictionary = g._migrate_save(weird)
	check(int(out2.save_version) == g.SAVE_VERSION, "v10'dan boş oda dizisi göçtü")
	check(g._validate_save_dict(out2), "sonuç geçerli")
	g.free()
