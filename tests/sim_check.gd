extends SceneTree
## Headless ekonomi/kayıt doğrulaması (simülasyon v2).
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
	print("Little Grand Hotel — simülasyon testi v2")
	var GameScript := load("res://src/autoload/game.gd")
	var g = GameScript.new()
	g.eco = g.load_json("res://data/economy.json")
	g.quests = g.load_json("res://data/quests.json").get("quests", [])
	g.achievements = g.load_json("res://data/achievements.json").get("achievements", [])
	check(not g.eco.is_empty(), "economy.json yüklendi")
	check(g.quests.size() >= 15, "quests.json yüklendi")
	check(g.achievements.size() >= 10, "achievements.json yüklendi")
	g.new_game()

	# 1) Başlangıç durumu
	check(g.coins == 3000 and g.gems == 25, "başlangıç bakiyesi (3000c / 25e)")
	check(g.rooms.size() == 2 and g.floors == 2, "başlangıç: 2 oda, 2 kat")
	check(g.star_rating() == 2, "başlangıç yıldızı 2")
	check(g.max_slots() == 8, "başlangıç yuva kapasitesi 8")
	check(g.cheapest_item_price() == 80, "dürtme eşiği: en ucuz eşya 80 (Masa Lambası)")

	# 2) Vardiya marjı (ideal koşullar): maliyet gelirin %5–35'i arasında.
	# Saatlik oran tüm sürelerde bilerek eşit (bkz. shift_rates): otomatik
	# yenileme varken süreye göre farklı oranlar, oyuncuyu her zaman tek bir
	# "en ucuz" süreye kilitleyen anlamsız bir seçime dönüşürdü (level design
	# incelemesinde bulunan bir "tuzak seçenek" sorunu).
	var rates: Dictionary = g.eco.shift_rates
	for hours in [4, 8, 24]:
		check(int(rates[str(hours)]) == int(rates["1"]), "vardiya oranı %d saat için 1 saatle eşit (tuzak seçenek yok)" % hours)
	for hours in [1, 4, 8, 24]:
		var cost: float = g.shift_cost(hours)
		var income: float = g.hourly_income() * hours
		var margin := cost / income
		print("       vardiya %2d saat: maliyet %5d · ideal gelir %7.0f · marj %%%4.1f" % [hours, int(cost), income, margin * 100.0])
		check(margin > 0.05 and margin < 0.35, "vardiya %d saat marjı bantta" % hours)

	# 3) Temizlik döngüsü: standart oda 3 oyun-saatinde kirlenir, gelir durur
	g.time_scale = 3600.0
	check(g.start_shift(8), "8 saatlik vardiya başladı")
	check(g.shift_history.size() == 1 and int(g.shift_history[0].hours) == 8, "vardiya geçmişe yazıldı")
	g.last_sim_unix -= 4.0  # 4 oyun-saati geçmiş gibi
	g.simulate_to(g.now())
	check(g.rooms[0].dirty and g.rooms[1].dirty, "odalar 3 saat sonra kirlendi")
	var stuck: float = g.pending_income
	g.last_sim_unix -= 2.0
	g.simulate_to(g.now())
	check(absf(g.pending_income - stuck) < 0.001, "kirli oda gelir üretmiyor")

	# 4) Temizleme geliri geri açar
	check(g.clean_room(0), "oda temizlendi")
	check(not g.rooms[0].dirty, "oda temiz işaretlendi")
	g.last_sim_unix -= 1.0
	g.simulate_to(g.now())
	check(g.pending_income > stuck, "temiz oda yeniden kazandırıyor")

	# 5) Temizlik Odası otomasyonu (önce seviye kilidini aç)
	check(not g.can_buy_room("housekeeping"), "seviye kilidi çalışıyor (Sv.1'de Temizlik Odası kapalı)")
	g.coins = 100000
	g.add_xp(g.xp_for_level(10) - g.xp)  # seviye 10'a çıkar
	check(g.level() == 10, "seviye 10'a yükseltildi")
	check(g.buy_room("housekeeping"), "Temizlik Odası alındı")
	g.clean_room(1)
	g.last_sim_unix -= 10.0  # uzun süre geçse de...
	g.simulate_to(g.now())
	check(not g.rooms[0].dirty and not g.rooms[1].dirty, "otomasyon: odalar kirli kalmıyor")

	# 6) Tesis geliri ve yıldıza katkısı
	var div_before: int = g.facility_diversity()
	var inc_before: float = g.hourly_income()
	check(g.buy_room("cafe"), "Kafe alındı")
	check(g.facility_diversity() == div_before + 1, "tesis çeşitliliği arttı")
	check(g.hourly_income() > inc_before, "tesis saatlik geliri artırdı")

	# 7) Dekorasyon → kademe → yıldız
	g.rooms[0]["items"] = ["bed_wood", "wardrobe_oak", "rug_wool", "chair_arm"]  # SP 155
	check(g.room_score(g.rooms[0]) == 155, "SP toplamı 155")
	check(g.room_tier(g.rooms[0]) == 2, "SP 155 → Şık (kademe 2)")
	var star_now: int = g.star_rating()
	check(star_now >= 3, "dekorasyon + tesis → yıldız 3+ (şu an %d)" % star_now)

	# 8) Toplama, XP, seviye (görev ödülleri de coin ekleyebilir → >= kontrolü)
	var coins_before: int = g.coins
	var got: int = g.collect()
	check(got > 0 and g.coins >= coins_before + got, "toplama coin'e işlendi")
	check(int(g.pending_income) == 0, "birikim sıfırlandı")
	check(g.xp_for_level(2) == 55, "XP eğrisi (erken/hızlı parça): seviye 2 = 55")
	check(g.xp_for_level(12) - g.xp_for_level(11) == int(g._xp_late_raw(12)) - int(g._xp_late_raw(11)),
		"XP eğrisi: seam sonrası artış eski dik eğriyle birebir aynı")
	var gems_before: int = g.gems
	g.add_xp(g.xp_for_level(g.level() + 1) - g.xp + 1)  # tam bir seviye atlat
	check(g.gems > gems_before, "seviye atlama elmas verdi")

	# 8b) Elmasla vardiya bitirme
	if g.shift_active():
		g.shift_end_unix = g.now()
	check(not g.skip_shift(), "vardiya yokken elmasla bitirme reddedilir")
	check(g.start_shift(24), "24 saatlik vardiya başladı (elmas testi)")
	var skip_cost: int = g.skip_shift_gem_cost()
	check(skip_cost >= 1 and skip_cost <= 12, "elmas bedeli makul (şu an %d)" % skip_cost)
	g.gems = maxi(g.gems, skip_cost)
	var gems_b: int = g.gems
	var pend_b: float = g.pending_income
	check(g.skip_shift(), "vardiya elmasla bitirildi")
	check(g.gems == gems_b - skip_cost, "elmas bedeli düşüldü")
	check(not g.shift_active(), "vardiya kapandı")
	check(g.pending_income > pend_b, "kalan saatlerin geliri işlendi")
	# Vardiya tam da şimdi bittiği için sıradaki simulate_to() çağrıları
	# (ör. buy_item içindeki) otomatik yenilemeyi anlık olarak tetikleyebilir
	# ve sonraki denetimlerin zamanlamaya bağlı hale gelmesine yol açabilir.
	# Otomatik yenileme kendi bölümünde (20) ayrıca test ediliyor; burada
	# kapatarak geri kalan denetimleri ondan izole ediyoruz.
	g.auto_renew_shift = false

	# 8c) Premium eşya elmasla alınır
	var it_prem: Dictionary = g.item_def("statue_gold")
	check(g.item_is_premium(it_prem), "Altın Heykel premium eşya")
	g.gems = maxi(g.gems, int(it_prem.gem_price))
	gems_b = g.gems
	var coins_b: int = g.coins
	check(g.buy_item(1, "statue_gold"), "premium eşya alındı")
	check(g.gems == gems_b - int(it_prem.gem_price), "premium bedeli elmastan düşüldü")
	check(g.coins == coins_b, "premium alım coin harcamadı")

	# 8d) Aynı eşya bir odaya yalnızca bir kez eklenebilir (denge incelemesinde
	# bulunan sömürü: tekrar alım engeli yoksa en ucuz eşya defalarca alınarak
	# kademe eşiği (tier_thresholds) neredeyse bedavaya aşılabiliyordu).
	check(g.room_has_item(1, "statue_gold"), "room_has_item alınan eşyayı görüyor")
	check(g.buy_item(1, "lamp_desk"), "farklı eşya normalde alınabiliyor")
	var score_before: int = g.room_score(g.rooms[1])
	check(not g.buy_item(1, "lamp_desk"), "aynı eşya ikinci kez reddedilir")
	check(g.room_score(g.rooms[1]) == score_before, "tekrar reddi puanı şişirmedi")
	check(not g.buy_item(1, "statue_gold"), "sahip olunan premium eşya de tekrar alınamaz")

	# 9) Yuva/kat sınırları
	var big_price: int = g.floor_price()
	check(big_price == 15000, "3. kat fiyatı 15000")
	check(g.buy_floor(), "3. kat alındı")
	check(g.floor_price() == int(15000 * 2.2), "4. kat fiyatı ×2,2")
	check(g.max_slots() == 12, "yuva kapasitesi 12'ye çıktı")

	# 10) Görev zinciri ilerliyor
	check(g.quest_index >= 2, "görevler tamamlanıyor (vardiya + toplama; şu an %d)" % g.quest_index)
	var q: Dictionary = g.current_quest()
	check(not q.is_empty(), "aktif görev var")
	var p: Array = g.quest_progress(q)
	check(p.size() == 2 and p[1] > 0, "görev ilerlemesi okunuyor")

	# 11) Kayıt/yükleme gidiş-dönüşü + görev durumu
	var save_path := "user://test_save.json"
	g.save_game(save_path)
	var g2 = GameScript.new()
	g2.eco = g.eco
	g2.quests = g.quests
	g2.achievements = g.achievements
	check(g2.load_game(save_path), "kayıt dosyası yüklendi")
	check(g2.coins == g.coins and g2.xp == g.xp and g2.rooms.size() == g.rooms.size(), "gidiş-dönüş verisi eşleşti")
	check(g2.quest_index == g.quest_index and g2.floors == g.floors, "görev/kat durumu korundu")
	check(g2.room_score(g2.rooms[0]) == 155, "oda eşyaları kayıtta korundu")
	check(g2.shift_history.size() == g.shift_history.size(), "vardiya geçmişi kayıtta korundu")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	# 12) Oda taşıma / satma
	var idx_cafe := -1
	for i in g.rooms.size():
		if g.rooms[i].type == "cafe":
			idx_cafe = i
	check(idx_cafe > 0, "kafe bulundu")
	var t_a: String = g.rooms[0].type
	check(g.move_room(0, idx_cafe), "odalar yer değişti")
	check(g.rooms[idx_cafe].type == t_a and g.rooms[0].type == "cafe", "taşıma dizilimi doğru")
	check(not g.move_room(0, 0), "aynı odaya taşıma reddedilir")
	g.move_room(0, idx_cafe)  # geri al
	var sv: int = g.room_sell_value(idx_cafe)
	check(sv == int(3000 * 0.5), "kafe iade bedeli %%50 (şu an %d)" % sv)
	var idx_statue := -1
	for i in g.rooms.size():
		if g.rooms[i].items.has("statue_gold"):
			idx_statue = i
	check(idx_statue >= 0 and g.room_sell_gem_value(idx_statue) == 7, "premium eşya iadesi elmasla (%50)")
	var coins_s: int = g.coins
	var rooms_s: int = g.rooms.size()
	check(g.sell_room(idx_cafe), "kafe satıldı")
	check(g.rooms.size() == rooms_s - 1 and g.coins >= coins_s + sv, "iade coin'e işlendi")
	var g3 = GameScript.new()
	g3.eco = g.eco
	g3.quests = g.quests
	g3.achievements = g.achievements
	g3.new_game()
	check(g3.sell_room(0), "yedek oda satılabilir")
	check(not g3.sell_room(0), "son oda satılamaz")
	g3.free()

	# 13) Kayıt sürüm göçü: v2 kaydı v3'e taşınır, bilinmeyen sürüm reddedilir
	var g4 = GameScript.new()
	g4.eco = g.eco
	g4.quests = g.quests
	g4.achievements = g.achievements
	var v2_path := "user://test_v2.json"
	var old_save := {
		"save_version": 2,
		"coins": 1234, "gems": 7, "xp": 50, "floors": 2,
		"rooms": [g4.make_room("standard")],
		"shift_end_unix": 0.0, "pending_income": 0.0,
		"last_sim_unix": Time.get_unix_time_from_system(),
		"quest_index": 1, "stat_shifts": 1, "stat_collects": 0,
		"stat_collected_total": 0, "stat_cleans": 0, "time_scale": 1.0,
	}
	var fw := FileAccess.open(v2_path, FileAccess.WRITE)
	fw.store_string(JSON.stringify(old_save))
	fw = null
	check(g4.load_game(v2_path), "v2 kaydı göçle yüklendi")
	check(g4.coins == 1234 and g4.shift_history.is_empty() and g4.sound_on and g4.music_on,
		"göç varsayılanları doğru (geçmiş boş, sesler açık)")
	g4.save_game(v2_path)
	var reparsed = JSON.parse_string(FileAccess.get_file_as_string(v2_path))
	check(int(reparsed.save_version) == int(g4.SAVE_VERSION), "göçen kayıt güncel sürümle yazıldı")
	check(bool(reparsed.auto_renew_shift) == true and int(reparsed.last_shift_hours) == 0,
		"göç otomatik yenileme alanlarını varsayılanla ekledi")
	check(reparsed.unlocked_achievements is Array, "göç unlocked_achievements alanını ekledi")
	check(int(reparsed.prestige_level) == 0, "göç prestige_level alanını 0 ile ekledi")
	check(int(reparsed.daily_streak) == 0 and int(reparsed.last_daily_claim_day) == -1,
		"göç günlük seri alanlarını varsayılanla ekledi")
	old_save["save_version"] = 99
	fw = FileAccess.open(v2_path, FileAccess.WRITE)
	fw.store_string(JSON.stringify(old_save))
	fw = null
	check(not g4.load_game(v2_path), "bilinmeyen gelecek sürüm reddedilir")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(v2_path))
	g4.free()

	# 14) Geç oyun turu: yeni tesisler, 5 yıldız, 24 saat vardiya marjı
	var g5 = GameScript.new()
	g5.eco = g.eco
	g5.quests = g.quests
	g5.achievements = g.achievements
	g5.new_game()
	g5.coins = 1500000
	g5.add_xp(g5.xp_for_level(28) - g5.xp)
	check(g5.level() >= 28, "seviye 28'e yükseltildi")
	while g5.floors < int(g5.eco.building.max_floors):
		check(g5.buy_floor(), "kat alındı (%d. kat)" % g5.floors)
	check(g5.max_slots() == 24, "6 katta 24 yuva")
	check(g5.buy_room("restaurant"), "Restoran alındı")
	check(g5.buy_room("roof_garden"), "Çatı Bahçesi alındı")
	for t in ["cafe", "gym", "pool", "housekeeping"]:
		g5.buy_room(t)
	check(g5.facility_diversity() == 5, "tesis çeşitliliği 5 (tavan)")
	while g5.can_buy_room("suite"):
		g5.buy_room("suite")
	check(g5.rooms.size() == 24, "tüm yuvalar dolu")
	for r in g5.rooms:
		if g5.room_def(r.type).category == "guest" and r.type == "suite":
			r["items"] = ["bed_canopy", "bed_canopy", "chandelier", "chandelier", "sofa_velvet"]  # SP 630
			check(g5.room_tier(r) == 4, "süit İkonik kademede")
			break
	for r in g5.rooms:
		if r.type == "suite":
			r["items"] = ["bed_canopy", "bed_canopy", "chandelier", "chandelier", "sofa_velvet"]
	check(g5.star_rating() == 5, "geç oyun oteli 5 yıldız (şu an %d)" % g5.star_rating())
	var lg_cost: float = g5.shift_cost(24)
	var lg_income: float = g5.hourly_income() * 24.0
	var lg_margin := lg_cost / lg_income
	print("       geç oyun: 24 saat maliyet %d · gelir %.0f · marj %%%.1f" % [int(lg_cost), lg_income, lg_margin * 100.0])
	check(lg_margin > 0.01 and lg_margin < 0.35, "geç oyun vardiya marjı makul bantta")
	check(g5.floor_price() >= 350000 or g5.floors == int(g5.eco.building.max_floors), "kat fiyat eğrisi tavana ulaştı")
	g5.free()

	# 15) Başarımlar: hedefe ulaşınca kalıcı, tek seferlik ödül veriyor
	check(g.unlocked_achievements.has("a01"), "ilk temizlik başarımı otomatik açıldı")
	var g6 = GameScript.new()
	g6.eco = g.eco
	g6.quests = g.quests
	g6.achievements = g.achievements
	g6.new_game()
	g6.stat_cleans = 50
	var coins_before6: int = g6.coins
	g6._check_achievements()
	check(g6.unlocked_achievements.has("a02"), "50 temizlik başarımı açıldı")
	check(g6.coins > coins_before6, "başarım ödülü coin'e eklendi")
	var coins_after_first: int = g6.coins
	g6._check_achievements()
	check(g6.coins == coins_after_first, "başarım tekrar ödül vermiyor (tek seferlik)")
	g6.free()

	# 16) Prestij: eşik altında reddedilir, devirde kalıcı çarpan ekler ve ilerlemeyi sıfırlar
	var g7 = GameScript.new()
	g7.eco = g.eco
	g7.quests = g.quests
	g7.achievements = g.achievements
	g7.new_game()
	check(g7.prestige_mult() == 1.0, "başlangıç prestij çarpanı ×1.0")
	check(not g7.can_prestige(), "seviye 1'de devretme kilitli")
	check(not g7.do_prestige(), "eşik altı devretme reddedilir")
	g7.add_xp(g7.xp_for_level(20) - g7.xp)
	check(g7.level() >= 20, "seviye 20'ye ulaşıldı")
	check(g7.can_prestige(), "seviye 20'de devretme açık")
	g7.coins = 50000
	g7.buy_room("cafe")
	check(g7.do_prestige(), "oteli devretme başarılı")
	check(g7.prestige_level == 1, "devir sayısı arttı")
	check(absf(g7.prestige_mult() - 1.2) < 0.001, "devir sonrası çarpan ×1.2")
	check(g7.coins == int(g7.eco.start.coins) and g7.rooms.size() == 2, "devir sonrası ilerleme sıfırlandı")
	var mult_after_prestige: float = g7.prestige_mult()
	check(mult_after_prestige > 1.0, "devir çarpanı kalıcı")
	# reset_game() gerçek user://save.json dosyasına yazdığı için burada
	# doğrudan çağrılmaz; aynı sıfırlama mantığı (prestige_level = 0 + new_game())
	# diske dokunmadan doğrulanır.
	g7.prestige_level = 0
	g7.new_game()
	check(g7.prestige_level == 0 and absf(g7.prestige_mult() - 1.0) < 0.001, "tam sıfırlama mantığı prestiji de sıfırlar")
	g7.free()

	# 17) Haftalık tema indeksi: deterministik ve kararlı
	var week_a: int = g.current_week_index()
	var week_b: int = g.current_week_index()
	check(week_a == week_b and week_a >= 0, "hafta indeksi deterministik ve negatif değil")

	# 18) Kayıt dışa/içe aktarma: bulut yerine paylaşılabilir kod
	var code: String = g.export_save_code()
	check(not code.is_empty(), "dışa aktarma kodu üretildi")
	var g8 = GameScript.new()
	g8.eco = g.eco
	g8.quests = g.quests
	g8.achievements = g.achievements
	g8.new_game()
	check(g8.import_save_code(code), "kod içe aktarıldı")
	check(g8.coins == g.coins and g8.prestige_level == g.prestige_level, "içe aktarılan veri eşleşti")
	check(g8.unlocked_achievements.size() == g.unlocked_achievements.size(), "içe aktarılan başarımlar eşleşti")
	check(not g8.import_save_code("bu-gecerli-bir-kod-degil"), "bozuk kod reddedilir")
	check(not g8.import_save_code(""), "boş kod reddedilir")
	g8.free()

	# 19) Ekonomi güvenlik ağı: açgözlü harcama oyuncuyu vardiya başlatamaz
	# duruma düşürmemeli (level design incelemesinde bulunan gerçek bir çıkmaz).
	var g9 = GameScript.new()
	g9.eco = g.eco
	g9.quests = g.quests
	g9.achievements = g.achievements
	g9.new_game()
	g9.coins = 200000
	g9.add_xp(g9.xp_for_level(20) - g9.xp)  # çoğu oda tipini aç
	var g9_room_types: Array = g9.eco.room_types.keys()
	var stuck_check := true
	for _round_i in 60:
		var any_bought := false
		if g9.can_buy_floor():
			g9.buy_floor()
		for t in g9_room_types:
			if g9.can_buy_room(t):
				g9.buy_room(t)
				any_bought = true
		if g9.coins < g9.min_shift_reserve():
			stuck_check = false
		if not any_bought:
			break
	check(stuck_check, "art arda oda/kat alımı asla rezervin altına düşmedi")
	check(g9.coins >= g9.min_shift_reserve(), "alım turu sonunda hâlâ rezerv kadar coin var")
	check(g9.start_shift(1), "açgözlü alım turu sonrasında 1 saatlik vardiya hâlâ başlatılabiliyor")
	g9.free()

	# 20) Otomatik vardiya yenileme: vardiya "gerçekten" bitmiş (shift_end_unix
	# şimdiden önce) ve uzun süre simüle edilmemiş gibi kurulur — tıpkı
	# uygulamanın kapalıyken saatlerce beklediği gerçek senaryo gibi.
	var g10 = GameScript.new()
	g10.eco = g.eco
	g10.quests = g.quests
	g10.achievements = g.achievements
	g10.new_game()
	g10.time_scale = 3600.0
	g10.coins = 100000
	check(g10.start_shift(1), "1 saatlik vardiya başladı (yenileme testi)")
	var shifts_before: int = g10.stat_shifts
	var real_now10: float = g10.now()
	g10.last_sim_unix = real_now10 - 6.5
	g10.shift_end_unix = real_now10 - 5.5
	g10.simulate_to(g10.now())
	check(g10.stat_shifts >= shifts_before + 5, "vardiya birden fazla kez otomatik yenilendi (şu an %d)" % g10.stat_shifts)
	check(g10.shift_active(), "yenileme sonrası vardiya hâlâ aktif")
	check(g10.auto_renew_count >= 5, "yenileme sayacı doğru izleniyor (şu an %d)" % g10.auto_renew_count)
	check(g10.auto_renew_spent == g10.auto_renew_count * g10.shift_cost(1), "yenileme harcaması doğru toplanıyor")
	check(g10.pending_income > 0.0, "kesintisiz üretimden gelir birikti")
	g10.free()

	var g11 = GameScript.new()
	g11.eco = g.eco
	g11.quests = g.quests
	g11.achievements = g.achievements
	g11.new_game()
	g11.time_scale = 3600.0
	g11.coins = 100000
	g11.auto_renew_shift = false
	check(g11.start_shift(1), "1 saatlik vardiya başladı (kapalı yenileme testi)")
	var real_now11: float = g11.now()
	g11.last_sim_unix = real_now11 - 6.5
	g11.shift_end_unix = real_now11 - 5.5
	g11.simulate_to(g11.now())
	check(not g11.shift_active(), "yenileme kapalıyken vardiya bitik kalır")
	check(g11.auto_renew_count == 0, "yenileme kapalıyken hiç tetiklenmez")
	g11.free()

	var g12 = GameScript.new()
	g12.eco = g.eco
	g12.quests = g.quests
	g12.achievements = g.achievements
	g12.new_game()
	g12.time_scale = 3600.0
	check(g12.start_shift(1), "1 saatlik vardiya başladı (coin tükenme testi)")
	g12.coins = g12.shift_cost(1) * 2  # yalnızca 2 yenilemelik coin bırak
	var real_now12: float = g12.now()
	g12.last_sim_unix = real_now12 - 20.5
	g12.shift_end_unix = real_now12 - 19.5
	g12.simulate_to(g12.now())
	check(g12.coins == 0, "coin tam olarak tükendi, negatife düşmedi")
	check(g12.auto_renew_count == 2, "coin tükenince yenileme kendiliğinden durdu (şu an %d)" % g12.auto_renew_count)
	check(not g12.shift_active(), "coin bitince vardiya nihayetinde durur")
	g12.free()

	# 21) Günlük giriş serisi: ardışık gün uzatır, atlanan gün sıfırlar,
	# aynı gün ikinci kez ödül vermez.
	var g13 = GameScript.new()
	g13.eco = g.eco
	g13.quests = g.quests
	g13.achievements = g.achievements
	g13.new_game()
	var cycle: Array = g13.eco.daily_rewards
	check(cycle.size() == 7, "7 günlük ödül döngüsü tanımlı")
	check(g13.daily_reward_available(), "yeni oyunda günlük ödül alınabilir")
	var r1: Dictionary = g13.claim_daily_reward()
	check(not r1.is_empty() and g13.daily_streak == 1, "ilk gün ödülü alındı, seri 1")
	check(int(r1.coins) == int(cycle[0].coins), "ilk gün ödülü döngünün ilk girdisiyle eşleşir")
	check(not g13.daily_reward_available(), "aynı gün tekrar alınamaz")
	check(g13.claim_daily_reward().is_empty(), "aynı gün ikinci talep boş döner")
	var di: int = g13.daily_day_index()
	g13.last_daily_claim_day = di - 1  # dün alınmış gibi
	check(g13.daily_next_streak() == 2, "ardışık gün seriyi 1 uzatır")
	g13.claim_daily_reward()
	check(g13.daily_streak == 2, "ikinci gün ödülü alındı, seri 2")
	g13.last_daily_claim_day = di - 5  # 5 gün atlanmış gibi
	check(g13.daily_next_streak() == 1, "gün atlanınca seri sıfırlanır")
	g13.claim_daily_reward()
	check(g13.daily_streak == 1, "atlama sonrası seri gerçekten 1'e döndü")
	g13.free()

	# 22) İstila: kirli kalan oda eşikten sonra istilaya döner, temizlik paralı olur
	var g14 = GameScript.new()
	g14.eco = g.eco
	g14.quests = g.quests
	g14.achievements = g.achievements
	g14.new_game()
	g14.time_scale = 3600.0
	# Coin delta kontrollerini görev/başarım ödülleri ve otomatik vardiya
	# yenilemesi bozmasın diye üçü de bu testte devre dışı.
	g14.quest_index = g14.quests.size()
	g14.achievements = []
	g14.auto_renew_shift = false
	check(g14.start_shift(24), "istila testi: 24 saatlik vardiya başladı")
	g14.last_sim_unix -= 12.0  # 12 oyun-saati geçmiş gibi: 3'te kirlenir, 9 saat kirli kalır
	g14.simulate_to(g14.now())
	check(g14.rooms[0].dirty, "oda kirlendi")
	check(float(g14.rooms[0].dirty_hours) >= 6.0, "kirli saat birikti (şu an %.1f)" % float(g14.rooms[0].dirty_hours))
	check(g14.room_infested(g14.rooms[0]), "oda istilaya döndü")
	check(g14.clean_cost(0) == 150, "istila temizliği 150 coin")
	var coins_inf: int = g14.coins
	g14.coins = 0
	check(not g14.clean_room(0), "coin yoksa istila temizlenemez")
	g14.coins = coins_inf + 1000
	check(g14.clean_room(0), "istila paralı temizlendi")
	check(g14.coins == coins_inf + 1000 - 150, "temizlik bedeli düşüldü")
	check(not g14.room_infested(g14.rooms[0]) and float(g14.rooms[0].dirty_hours) == 0.0, "istila sıfırlandı")
	check(g14.clean_cost(1) == 0 or g14.rooms[1].dirty, "temiz/kirli normal oda için temizlik bedava")

	# 23) Misafir dürtme: tavan, şans, yıldıza göre bonus
	var cap: int = int(g14.eco.poke.daily_cap)
	check(g14.pokes_left() == cap, "dürtme hakkı gün başında tam (%d)" % cap)
	var poke_coins: int = g14.coins
	var win: int = g14.poke_guest(0.0)  # kesin kazanç
	var expect_bonus: int = int(g14.eco.poke.base) + int(g14.eco.poke.per_star) * g14.star_rating()
	check(win == expect_bonus, "müfettiş bonusu yıldıza göre (%d)" % expect_bonus)
	check(g14.coins == poke_coins + expect_bonus, "bonus coin'e işlendi")
	check(g14.poke_guest(0.99) == 0, "şanssız dürtme bonus vermez")
	check(g14.pokes_left() == cap - 2, "iki dürtme hakkı düştü")
	g14.poke_count = cap
	check(g14.pokes_left() == 0 and g14.poke_guest(0.0) == 0, "günlük tavan aşılamaz")

	# 24) Kaçan misafiri yakalama: yalnızca vardiyada, saatlik gelirin kesri
	var catch_coins: int = g14.coins
	var got_catch: int = g14.catch_guest()
	var expect_catch: int = maxi(5, int(g14.hourly_income() * float(g14.eco.catch.bonus_hourly_frac)))
	check(got_catch == expect_catch and g14.coins == catch_coins + got_catch, "yakalama bonusu doğru (%d)" % got_catch)
	# Oyun mantığı kendi tarafında da aralığı uyguluyor (UI'nin ~25 sn'lik doğuş
	# zamanlayıcısına güvenmek yerine) — art arda çağrılırsa ikincisi reddedilir.
	check(g14.catch_guest() == 0, "hemen art arda yakalama reddedilir (kendi aralık kontrolü)")
	g14.last_catch_unix -= float(g14.eco.catch.interval_real_seconds) + 1.0
	check(g14.catch_guest() > 0, "aralık geçince yakalama tekrar çalışır")
	g14.shift_end_unix = g14.now()  # vardiyayı bitir
	check(g14.catch_guest() == 0, "vardiya yokken yakalama bonus vermez")

	# 25) Hazır dekor paketleri: indirim, kilit, eşyaların yerleşmesi
	var bnd: Dictionary = g14.bundle_def("cozy_set")
	check(not bnd.is_empty(), "Konfor Paketi tanımlı")
	var raw_total := 0.0
	for iid in bnd.items:
		raw_total += float(g14.item_def(iid).price)
	check(g14.bundle_price(bnd) == int(round(raw_total * 0.9)), "paket fiyatı %%10 indirimli")
	check(g14.bundle_unlock_level(bnd) == 5, "paket kilidi en yüksek eşyaya göre (Sv.5)")
	var royal: Dictionary = g14.bundle_def("royal_set")
	check(not g14.can_buy_bundle(royal), "seviye yetmeyince paket kilitli")
	g14.add_xp(g14.xp_for_level(6) - g14.xp)
	g14.coins = 10000
	var items_before: int = g14.rooms[0].items.size()
	var bundle_cost: int = g14.bundle_price(bnd)
	check(g14.buy_bundle(0, "cozy_set"), "Konfor Paketi satın alındı")
	check(g14.rooms[0].items.size() == items_before + 4, "4 eşya odaya yerleşti")
	check(g14.coins == 10000 - bundle_cost, "paket bedeli düşüldü")
	# Aynı paket ikinci kez alınırsa (veya içindeki eşyalarla çakışırsa) odaya
	# mükerrer eşya eklenmez — buy_item ile aynı tekil-eşya kuralı geçerli.
	var items_after_first: int = g14.rooms[0].items.size()
	check(g14.buy_bundle(0, "cozy_set"), "aynı paket ikinci kez de satın alınabiliyor (ücret düşüyor)")
	check(g14.rooms[0].items.size() == items_after_first, "ikinci alımda mükerrer eşya eklenmedi")
	check(g14.eco.room_types.cafe.capacity == 4, "tesis kapasitesi tanımlı (kafe 4)")
	g14.free()

	# 26) Mobil arka plan/askı senaryosu: uygulama kapatılmadan (load_game()
	# tekrar tetiklenmeden) günlerce arka planda askıya alınıp geri dönülürse
	# de 24 saatlik çevrimdışı kazanç tavanı işlemeli. Bu tavan artık yalnızca
	# load_game()'de değil simulate_to() içinde uygulanıyor (bkz. game.gd) —
	# aksi halde iOS/Android'de uygulama arka planda askıya alınıp (öldürülmeden)
	# günler sonra öne getirildiğinde _process() askıdayken hiç çalışmadığından
	# ve load_game() tekrar tetiklenmediğinden kapak devre dışı kalırdı.
	# Ayrıca kapak yalnızca last_sim_unix'i ileri atlarsa (shift_end_unix'i
	# değil), auto-renew döngüsü atılan sürenin tamamını (gerçek gelir
	# üretmeden) tek tek "hayalet" vardiya yenilemesiyle coin harcayarak
	# yürümek zorunda kalırdı — bu yüzden shift_end_unix de eşit miktarda
	# kaydırılıyor.
	var g15 = GameScript.new()
	g15.eco = g.eco
	g15.quests = g.quests
	g15.achievements = g.achievements
	g15.new_game()
	g15.coins = 1000000
	g15.time_scale = 3600.0
	check(g15.start_shift(1), "mobil senaryo: 1 saatlik vardiya başladı")
	var real_now15: float = g15.now()
	g15.last_sim_unix = real_now15 - 240.0
	g15.shift_end_unix = real_now15 - 239.0
	g15.auto_renew_count = 0
	var coins_before15: int = g15.coins
	g15.simulate_to(g15.now())
	var renews15: int = g15.auto_renew_count
	var cap_h: int = int(g15.eco.offline_cap_hours)
	check(renews15 > 0 and renews15 <= cap_h + 2,
		"askıdan dönüşte 240 saatlik boşluk yerine ~%d saatlik kapak uygulandı (şu an %d yenileme)" % [cap_h, renews15])
	check(coins_before15 - g15.coins == renews15 * g15.shift_cost(1),
		"yalnızca gerçekleşen yenilemeler kadar coin harcandı (hayalet yenileme yok)")
	check(g15.now() - g15.last_sim_unix < 2.0, "simulate_to sonunda güncel zamana yetişildi")
	g15.free()

	# 27) Arka plan tam-verim: Temizlik Odası yokken büyük bir arka plan (offline)
	# boşluğunda oda hiç kirlenmemeli — ve aynı süreyi otomasyonsuz (ön plan,
	# full_efficiency=false) ilerleten bir referanstan kesinlikle daha fazla
	# üretmeli, çünkü kirlenip duran oda gelir üretmeyi durdurur.
	var g16 = GameScript.new()
	g16.eco = g.eco; g16.quests = g.quests; g16.achievements = g.achievements
	g16.new_game(); g16.coins = 1000000; g16.time_scale = 1.0
	check(g16.start_shift(24), "arka plan testi: 24 saatlik vardiya başladı")
	g16.last_sim_unix = g16.now() - 20.0 * 3600.0
	g16.simulate_to(g16.now())
	var all_clean16 := true
	for r16 in g16.rooms:
		if bool(r16.dirty) or float(r16.get("dirty_hours", 0.0)) > 0.0:
			all_clean16 = false
	check(all_clean16, "arka planda (full_efficiency) oda hiç kirlenmedi")
	check(g16.pending_income > 0.0, "arka planda gelir birikti")
	var g16b = GameScript.new()
	g16b.eco = g.eco; g16b.quests = g.quests; g16b.achievements = g.achievements
	g16b.new_game(); g16b.coins = 1000000
	g16b._advance(20.0, false)
	check(g16.pending_income > g16b.pending_income,
		"arka plan tam-verim, kirlenip duran ön-plan senaryosundan kesinlikle daha fazla üretti")
	g16.free(); g16b.free()

	# 28) 24 saatlik offline kapak: kapak ötesindeki süre birikime katkı vermemeli
	# — 30 saatlik boşluk, 24 saatlik bir referansla aynı geliri üretmeli.
	var g17 = GameScript.new()
	g17.eco = g.eco; g17.quests = g.quests; g17.achievements = g.achievements
	g17.new_game(); g17.coins = 1000000; g17.time_scale = 1.0
	check(g17.start_shift(24), "kapak testi: 24 saatlik vardiya başladı")
	check(int(g17.eco.offline_cap_hours) == 24, "offline_cap_hours 24 olarak ayarlı")
	g17.last_sim_unix = g17.now() - 30.0 * 3600.0
	g17.simulate_to(g17.now())
	var g17b = GameScript.new()
	g17b.eco = g.eco; g17b.quests = g.quests; g17b.achievements = g.achievements
	g17b.new_game(); g17b.coins = 1000000; g17b.time_scale = 1.0
	check(g17b.start_shift(24), "kapak testi (referans): 24 saatlik vardiya başladı")
	g17b.last_sim_unix = g17b.now() - 24.0 * 3600.0
	g17b.simulate_to(g17b.now())
	check(absf(g17.pending_income - g17b.pending_income) < 5.0,
		"30 saatlik boşluk, 24 saatlik referansla aynı geliri biriktirdi (kapak ötesi atıldı)")
	check(g17.now() - g17.last_sim_unix < 2.0, "simulate_to sonunda güncel zamana yetişildi")
	g17.free(); g17b.free()

	g.free()
	g2.free()
	print("TÜM TESTLER GEÇTİ" if failures == 0 else "%d test BAŞARISIZ" % failures)
	quit(1 if failures > 0 else 0)
