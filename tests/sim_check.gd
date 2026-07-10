extends SceneTree
## Headless ekonomi/kayıt doğrulaması.
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/sim_check.gd

var failures := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


func _initialize() -> void:
	print("Little Grand Hotel — simülasyon testi")
	var GameScript := load("res://src/autoload/game.gd")
	var g = GameScript.new()
	g.eco = g.load_json("res://data/economy.json")
	check(not g.eco.is_empty(), "economy.json yüklendi")
	g.new_game()

	# 1) Başlangıç durumu
	check(g.coins == 3000 and g.gems == 25, "başlangıç bakiyesi (3000c / 25e)")
	check(g.rooms.size() == 2, "başlangıç: 2 standart oda")
	check(g.star_rating() == 2, "başlangıç yıldızı 2")
	check(g.level() == 1, "başlangıç seviyesi 1")

	# 2) Vardiya marjı: maliyet, beklenen gelirin %5–35'i arasında kalmalı (hedef %15–25)
	for hours in [1, 4, 8, 24]:
		var cost: float = g.shift_cost(hours)
		var income: float = g.hourly_income() * hours
		var margin := cost / income
		print("       vardiya %2d saat: maliyet %5d · gelir %7.0f · marj %%%4.1f" % [hours, int(cost), income, margin * 100.0])
		check(margin > 0.05 and margin < 0.35, "vardiya %d saat marjı bantta" % hours)

	# 3) Kademe eşikleri ve çarpanları tekdüze artmalı
	var monotonic := true
	for i in range(1, g.eco.tier_thresholds.size()):
		if int(g.eco.tier_thresholds[i]) <= int(g.eco.tier_thresholds[i - 1]):
			monotonic = false
		if float(g.eco.tier_mult[i]) <= float(g.eco.tier_mult[i - 1]):
			monotonic = false
	check(monotonic, "kademe eşik/çarpanları tekdüze artıyor")

	# 4) Dekorasyon kademeyi ve geliri yükseltir
	var income_before: float = g.hourly_income()
	g.rooms[0]["items"] = ["bed_wood", "wardrobe_oak", "rug_wool", "chair_arm"]  # SP 155
	check(g.room_score(g.rooms[0]) == 155, "SP toplamı 155")
	check(g.room_tier(g.rooms[0]) == 2, "SP 155 → Şık (kademe 2)")
	check(g.hourly_income() > income_before, "dekorasyon saatlik geliri artırdı")

	# 5) Hızlandırılmış vardiya: 2 oyun-saatlik birikim doğru mu?
	g.time_scale = 3600.0  # 1 gerçek sn = 1 oyun saati
	var coins_before: int = g.coins
	check(g.start_shift(4), "vardiya başlatıldı")
	check(g.coins == coins_before - g.shift_cost(4), "vardiya maliyeti düşüldü")
	g.last_sim_unix -= 2.0  # 2 gerçek saniye geçmiş gibi
	g.simulate_to(g.now())
	var expected: float = g.hourly_income() * 2.0
	check(absf(g.pending_income - expected) < expected * 0.01, "2 oyun-saati gelir birikimi doğru")

	# 6) Vardiya penceresi dışında birikim olmaz
	var pending_frozen: float = g.pending_income
	g.shift_end_unix = g.now() - 10.0  # vardiya çoktan bitmiş
	g.last_sim_unix = g.now() - 5.0    # ...ve bitişten sonra zaman geçmiş
	g.simulate_to(g.now())
	check(absf(g.pending_income - pending_frozen) < 0.001, "vardiya bitince birikim duruyor")

	# 7) Toplama: coin artar, birikim sıfırlanır, XP gelir
	coins_before = g.coins
	var xp_before: int = g.xp
	var got: int = g.collect()
	check(got > 0 and g.coins == coins_before + got, "toplama coin'e işlendi")
	check(int(g.pending_income) == 0, "birikim sıfırlandı")
	check(g.xp > xp_before, "toplama XP verdi")

	# 8) XP eğrisi ve seviye atlama ödülü
	check(g.xp_for_level(2) == 100, "XP eğrisi: seviye 2 = 100")
	check(g.xp_for_level(10) > g.xp_for_level(9), "XP eğrisi tekdüze artıyor")
	var gems_before: int = g.gems
	g.add_xp(g.xp_for_level(5))
	check(g.level() >= 5 and g.gems > gems_before, "seviye atlama elmas verdi")

	# 9) Kayıt/yükleme gidiş-dönüşü
	var save_path := "user://test_save.json"
	g.save_game(save_path)
	var g2 = GameScript.new()
	g2.eco = g.eco
	check(g2.load_game(save_path), "kayıt dosyası yüklendi")
	check(g2.coins == g.coins and g2.xp == g.xp and g2.rooms.size() == g.rooms.size(), "gidiş-dönüş verisi eşleşti")
	check(g2.room_score(g2.rooms[0]) == 155, "oda eşyaları kayıtta korundu")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	g.free()
	g2.free()
	print("TÜM TESTLER GEÇTİ" if failures == 0 else "%d test BAŞARISIZ" % failures)
	quit(1 if failures > 0 else 0)
