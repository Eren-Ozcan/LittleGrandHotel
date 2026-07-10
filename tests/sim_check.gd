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
	check(not g.eco.is_empty(), "economy.json yüklendi")
	check(g.quests.size() >= 15, "quests.json yüklendi")
	g.new_game()

	# 1) Başlangıç durumu
	check(g.coins == 3000 and g.gems == 25, "başlangıç bakiyesi (3000c / 25e)")
	check(g.rooms.size() == 2 and g.floors == 2, "başlangıç: 2 oda, 2 kat")
	check(g.star_rating() == 2, "başlangıç yıldızı 2")
	check(g.max_slots() == 8, "başlangıç yuva kapasitesi 8")

	# 2) Vardiya marjı (ideal koşullar): maliyet gelirin %5–35'i arasında
	for hours in [1, 4, 8, 24]:
		var cost: float = g.shift_cost(hours)
		var income: float = g.hourly_income() * hours
		var margin := cost / income
		print("       vardiya %2d saat: maliyet %5d · ideal gelir %7.0f · marj %%%4.1f" % [hours, int(cost), income, margin * 100.0])
		check(margin > 0.05 and margin < 0.35, "vardiya %d saat marjı bantta" % hours)

	# 3) Temizlik döngüsü: standart oda 3 oyun-saatinde kirlenir, gelir durur
	g.time_scale = 3600.0
	check(g.start_shift(8), "8 saatlik vardiya başladı")
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
	check(g.xp_for_level(2) == 100, "XP eğrisi: seviye 2 = 100")
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

	# 8c) Premium eşya elmasla alınır
	var it_prem: Dictionary = g.item_def("statue_gold")
	check(g.item_is_premium(it_prem), "Altın Heykel premium eşya")
	g.gems = maxi(g.gems, int(it_prem.gem_price))
	gems_b = g.gems
	var coins_b: int = g.coins
	check(g.buy_item(1, "statue_gold"), "premium eşya alındı")
	check(g.gems == gems_b - int(it_prem.gem_price), "premium bedeli elmastan düşüldü")
	check(g.coins == coins_b, "premium alım coin harcamadı")

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
	check(g2.load_game(save_path), "kayıt dosyası yüklendi")
	check(g2.coins == g.coins and g2.xp == g.xp and g2.rooms.size() == g.rooms.size(), "gidiş-dönüş verisi eşleşti")
	check(g2.quest_index == g.quest_index and g2.floors == g.floors, "görev/kat durumu korundu")
	check(g2.room_score(g2.rooms[0]) == 155, "oda eşyaları kayıtta korundu")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	g.free()
	g2.free()
	print("TÜM TESTLER GEÇTİ" if failures == 0 else "%d test BAŞARISIZ" % failures)
	quit(1 if failures > 0 else 0)
