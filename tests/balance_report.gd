extends SceneTree
## Detaylı denge (balance) analiz raporu — geçici tanı scripti, sim_check.gd'nin
## yerini almaz. Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/balance_report.gd

var GameScript
var eco: Dictionary


func new_g():
	var g = GameScript.new()
	g.eco = eco
	g.quests = []
	g.achievements = []
	g.new_game()
	return g


func _initialize() -> void:
	GameScript = load("res://src/autoload/game.gd")
	var tmp = GameScript.new()
	eco = tmp.load_json("res://data/economy.json")
	tmp.free()

	print("\n=== 1) EŞYA TEKRAR ALIMI SÖMÜRÜSÜ (buy_item duplicate kontrolü) ===")
	_check_duplicate_item_exploit()

	print("\n=== 2) SEVİYEYE GÖRE VARDİYA MARJI (gerçekçi ilerleme, tekrar-eşya YOK) ===")
	_check_margin_by_level()

	print("\n=== 3) ODA TİPİ YATIRIM GERİ DÖNÜŞÜ (ROI, saat) ===")
	_check_room_roi()

	print("\n=== 4) KAT FİYAT EĞRİSİ vs GELİR ===")
	_check_floor_roi()

	print("\n=== 5) EŞYA SP/COIN VERİMLİLİĞİ (azalan getiri var mı?) ===")
	_check_item_efficiency()

	print("\n=== 6) PRESTİJ KARLILIĞI ===")
	_check_prestige_payoff()

	print("\n=== 7) ELMAS EKONOMİSİ (kaynak vs gider) ===")
	_check_gem_economy()

	print("\n=== 8) MOBİL ASKI/OFFLINE KAPAK SENARYOSU (hayalet vardiya yenilemesi) ===")
	_check_offline_cap_ghost_renewals()

	print("\n=== 9) ERKEN TEMİZLİK ODASI KARŞILANABİLİRLİĞİ (Sv.2) ===")
	_check_early_housekeeping_afford()

	print("\n=== 10) İKİ PARÇALI XP EĞRİSİ (kümülatif + seviye-başı artış) ===")
	_check_xp_curve()

	print("\n=== 11) OFFLINE TAM-VERİM (24 saatlik kapak) ===")
	_check_offline_full_efficiency()

	print("\n=== 12) PERSONEL KALİTESİ ETKİSİ (Sv.18 marjı üzerinde) ===")
	_check_staff_upgrade_impact()

	quit()


func _check_duplicate_item_exploit() -> void:
	# Regresyon kontrolü: bu sömürü daha önce bulunup buy_item()/buy_bundle()
	# içine room_has_item() kontrolü eklenerek düzeltildi (bkz. game.gd). Bu
	# test, eşyanın bir odaya yalnızca bir kez eklenebildiğini doğrular —
	# önceden Masa Lambası (sp10/80c) tek başına 55 kez alınarak seviye 1'de
	# 4400 coin'e İkonik kademeye (SP 550) ulaşılabiliyordu.
	var g = new_g()
	g.coins = 1000000
	var room: Dictionary = g.rooms[0]
	var count := 0
	while count < 200 and g.buy_item(0, "lamp_desk"):
		count += 1
	print("  Aynı eşya (Masa Lambası) tekrar tekrar alınmaya çalışıldı: %d adet kabul edildi." % count)
	if count <= 1 and g.room_tier(room) < 4:
		print("  DÜZELTİLDİ: tekrar alım reddediliyor, oda kademesi hâlâ %s (SP %d)." % [
			g.tier_name(g.room_tier(room)), g.room_score(room)])
	else:
		print("  BULGU (SÖMÜRÜ HÂLÂ AÇIK!): İkonik kademeye seviye 1'de yalnızca tek eşya tipiyle")
		print("         ulaşılabiliyor — buy_item()/room_has_item() kontrolünü doğrulayın.")
	g.free()


func _milestone_setup(level: int, coins: int, rooms_wanted: Array, target_tier: int) -> Object:
	var g = new_g()
	g.coins = coins
	g.add_xp(g.xp_for_level(level) - g.xp)
	for t in rooms_wanted:
		if g.room_def(t).is_empty():
			continue
		while not g.has_type(t) and g.can_buy_room(t):
			g.buy_room(t)
	# Misafir odalarını hedef kademeye kadar en verimli eşyayla (en yüksek
	# unlock seviyesi geçerli eşya) doldur — GERÇEKÇİ oyuncu davranışı,
	# tekrar-eşya sömürüsü kullanılmıyor.
	var affordable_items := []
	for it in eco.items:
		# Yalnızca dekor-eklenti eşyalar (anchor'lı) — taban eşyaları
		# (duvar kağıdı/zemin/yatak, "slot"lı) artık items[] değil
		# upgrade_base() üzerinden değişir, gerçek buy_item() akışıyla eşleşir.
		if it.has("anchor") and not g.item_is_premium(it) and level >= int(it.get("unlock_level", 1)):
			affordable_items.append(it)
	affordable_items.sort_custom(func(a, b): return int(a.sp) > int(b.sp))
	for r in g.rooms:
		if g.room_def(r.type).category != "guest":
			continue
		for it in affordable_items:
			if g.room_tier(r) >= target_tier:
				break
			if it.id in r.items:
				continue
			if g.coins - int(it.price) >= g.min_shift_reserve():
				g.coins -= int(it.price)
				r.items.append(it.id)
	return g


func _check_margin_by_level() -> void:
	# Her kilometre taşında o seviyeye kadar açılan tüm oda tiplerinden birer
	# tane + ortalama "Şık" kademe (tier 2) hedefiyle gerçekçi bir kurulum.
	var levels := [1, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28]
	var room_types: Array = eco.room_types.keys()
	for lv in levels:
		var unlocked := []
		for t in room_types:
			if int(eco.room_types[t].unlock_level) <= lv:
				unlocked.append(t)
		var g = _milestone_setup(lv, 5000000, unlocked, 2)
		var star: int = g.star_rating()
		for hours in [1, 4, 8, 24]:
			var cost: float = g.shift_cost(hours)
			var income: float = g.hourly_income() * hours
			if income <= 0.0:
				print("  Sv.%2d  %2ds vardiya: GELİR SIFIR (oda yok/hepsi kirli?) — marj hesaplanamıyor" % [lv, hours])
				continue
			var margin := cost / income
			var flag := "" if (margin > 0.05 and margin < 0.35) else "  <-- BANT DIŞI"
			print("  Sv.%2d  yıldız %d  %2ds vardiya: maliyet %6d  gelir %8.0f  marj %%%5.1f%s" % [
				lv, star, hours, int(cost), income, margin * 100.0, flag])
		g.free()


func _check_room_roi() -> void:
	var g = new_g()
	g.coins = 5000000
	g.add_xp(g.xp_for_level(28) - g.xp)
	while g.floors < int(eco.building.max_floors):
		g.buy_floor()
	for t in eco.room_types.keys():
		var d: Dictionary = eco.room_types[t]
		if String(d.category) == "functional":
			continue
		var price := float(d.price)
		var base := float(d.base_income)
		if base <= 0.0:
			continue
		# Kaba ROI: tier_mult/star_mult/occupancy etkisi olmadan yalnızca
		# taban gelir ile fiyat/saat oranı (facility ve tier-0 guest için
		# karşılaştırılabilir taban metrik).
		var hours_to_payback := price / base
		print("  %-14s fiyat %7d  taban gelir/s %5d  ->  taban geri ödeme %7.1f saat (%.1f gün)" % [
			String(d.name), int(price), int(base), hours_to_payback, hours_to_payback / 24.0])
	g.free()


func _check_floor_roi() -> void:
	var g = new_g()
	var slots := int(GameScript.DEFAULT_FLOOR_OPEN_WIDTH)
	for i in range(int(eco.building.max_floors) - int(eco.building.start_floors)):
		var price: int = g.floor_price()
		# Yeni katın 4 yuvası ortalama bir "standart oda" ile dolarsa ek saatlik gelir:
		var extra_income := slots * float(eco.room_types.standard.base_income) * float(eco.tier_mult[0])
		var payback := price / extra_income
		print("  %d. kat: fiyat %8d  (+%d yuva standart oda ile ~+%.0f coin/s)  ->  geri ödeme ~%.0f saat" % [
			g.floors + 1, price, slots, extra_income, payback])
		g.floors += 1
	g.free()


func _check_item_efficiency() -> void:
	print("  id                 sp    fiyat   sp/coin")
	for it in eco.items:
		if int(it.get("gem_price", 0)) > 0 or int(it.get("price", 0)) == 0:
			continue  # ücretsiz taban varsayılanları (wallpaper/floor/bed_basic) hariç
		var ratio := float(it.sp) / float(it.price)
		print("  %-16s %5d  %6d   %.4f" % [String(it.id), int(it.sp), int(it.price), ratio])
	print("  (Beklenen: seviye arttıkça sp/coin oranı azalmalı — aksi halde erken eşyalar")
	print("   her zaman daha 'verimli' kalır ve geç eşyaların satın alınmasının tek sebebi")
	print("   -eğer tekrar alım engellenmiş olsaydı- üst kademe eşiğine ulaşmak olurdu.)")


func _check_prestige_payoff() -> void:
	var g = new_g()
	g.coins = 5000000
	g.add_xp(g.xp_for_level(20) - g.xp)
	for t in ["deluxe", "cafe", "gym", "housekeeping"]:
		g.buy_room(t)
	var pre_income: float = g.hourly_income()
	print("  Prestij ÖNCESİ (seviye 20, çarpan x%.2f): saatlik gelir %.0f" % [g.prestige_mult(), pre_income])
	check_prestige_result(g)


func check_prestige_result(g) -> void:
	var ok: bool = g.do_prestige()
	print("  do_prestige() sonucu: %s  (yeni çarpan x%.2f, coin sıfırlandı mı: %s)" % [
		ok, g.prestige_mult(), g.coins == int(eco.start.coins)])
	print("  BULGU: prestij sonrası oyuncu 3000 coin + 2 standart odayla sıfırdan başlıyor,")
	print("         yalnızca kalıcı +%%%d gelir çarpanı korunuyor. Seviye 20'ye tekrar ulaşmak" % int(eco.prestige.mult_gain * 100))
	print("         için gereken oyun-süresi (grinding) ile kazanılan %%%d'lik kalıcı bonusun" % int(eco.prestige.mult_gain * 100))
	print("         karşılaştırması: ilk 0->20 ilerlemenin ne kadar sürdüğü otomatik ölçülmüyor,")
	print("         bu ölçüm elle/log ile yapılmalı (aşağıdaki not).")
	g.free()


func _check_gem_economy() -> void:
	var g = new_g()
	print("  Elmas KAYNAKLARI:")
	print("    - başlangıç: %d" % int(eco.start.gems))
	print("    - seviye atlama: %d/seviye (levelup_gems)" % int(eco.levelup_gems))
	print("    - günlük ödül döngüsü (7 gün): %s" % [_daily_gem_list()])
	print("  Elmas GİDERLERİ:")
	print("    - vardiya atlama: %d saat = 1 elmas (gem_skip_hours)" % int(eco.gem_skip_hours))
	print("    - premium eşyalar: %s" % _premium_item_list())
	var total_daily_gems := 0
	for d in eco.daily_rewards:
		total_daily_gems += int(d.get("gems", 0))
	print("    -> 7 günlük döngü toplam elmas: %d (döngü başına)" % total_daily_gems)
	var lv20_gems: int = int(eco.levelup_gems) * 20
	print("    -> seviye 1->20 arası seviye atlama elması: %d" % lv20_gems)
	var cheapest_premium := 999
	for it in eco.items:
		if int(it.get("gem_price", 0)) > 0:
			cheapest_premium = mini(cheapest_premium, int(it.gem_price))
	print("    -> en ucuz premium eşya %d elmas; seviye 20'ye kadar biriken elmasla (%d + seviye atlama)" % [
		cheapest_premium, int(eco.start.gems)])
	print("       rahatça karşılanabiliyor mu: %s" % (int(eco.start.gems) + lv20_gems >= cheapest_premium))
	g.free()


func _check_offline_cap_ghost_renewals() -> void:
	# Regresyon: uygulama kapatılmadan (mobilde askıya alınıp) 24 saatlik
	# kapağı çok aşan bir süre sonra öne dönülürse, simulate_to() eskiden
	# yalnızca last_sim_unix'i ileri atlıyordu; shift_end_unix eski kalınca
	# auto-renew döngüsü atılan sürenin tamamını (gelir üretmeden) tek tek
	# "hayalet" yenilemeyle coin harcayarak yürümek zorunda kalıyordu.
	# Düzeltme: shift_end_unix de eşit miktarda kaydırılıyor (bkz. game.gd).
	var g = new_g()
	g.coins = 1000000
	g.time_scale = 3600.0
	g.start_shift(1)
	var real_now: float = g.now()
	g.last_sim_unix = real_now - 240.0  # 240 "saat" (10 gün) önce
	g.shift_end_unix = real_now - 239.0
	g.auto_renew_count = 0
	var coins_before: int = g.coins
	g.simulate_to(g.now())
	var cap_h: int = int(eco.offline_cap_hours)
	print("  240 saatlik (10 günlük) boşluk sonrası: %d yenileme yapıldı (beklenen ~%d, kapak: %d saat)" % [
		g.auto_renew_count, cap_h, cap_h])
	print("  harcanan coin: %d (yenileme başına %d) -> hayalet (gelirsiz) yenileme: %s" % [
		coins_before - g.coins, g.shift_cost(1),
		"YOK" if coins_before - g.coins == g.auto_renew_count * g.shift_cost(1) else "VAR (bkz. yukarıdaki sayı tutarsızlığı)"])
	if g.auto_renew_count > cap_h + 5:
		print("  BULGU: kapak etkisiz görünüyor, yenileme sayısı beklenenden çok yüksek.")
	g.free()


func _daily_gem_list() -> String:
	var parts := []
	for d in eco.daily_rewards:
		parts.append(str(int(d.get("gems", 0))))
	return "+".join(parts)


func _premium_item_list() -> String:
	var parts := []
	for it in eco.items:
		if int(it.get("gem_price", 0)) > 0:
			parts.append("%s(%d elmas, Sv.%d)" % [it.id, int(it.gem_price), int(it.get("unlock_level", 1))])
	return ", ".join(parts)


func _check_early_housekeeping_afford() -> void:
	# Temizlik Odası artık Sv.2/1500 coin — q07 görevinin ("Görünmez El") ilk
	# oturumun içinde tamamlanabilir olduğunu doğrula: gerçekçi bir seviye-2
	# oyuncu (birkaç erken eşya almış) hâlâ karşılayabiliyor mu?
	var g = _milestone_setup(2, int(eco.start.coins), [], 0)
	var hk_price: int = int(eco.room_types.housekeeping.price)
	var hk_level: int = int(eco.room_types.housekeeping.unlock_level)
	var reserve: int = g.min_shift_reserve()
	print("  Sv.2 oyuncu: coin %d, Temizlik Odası fiyatı %d (Sv.%d'de açılıyor), min vardiya rezervi %d" % [
		g.coins, hk_price, hk_level, reserve])
	print("  can_buy_room('housekeeping'): %s" % g.can_buy_room("housekeeping"))
	if not g.can_buy_room("housekeeping"):
		print("  BULGU: Sv.2 oyuncu gerçekçi harcamadan sonra Temizlik Odası'nı karşılayamıyor.")
	g.free()


func _check_xp_curve() -> void:
	var g = new_g()
	print("  sv  kümülatif-xp  seviye-başı-artış")
	var prev := 0
	for lv in range(1, 31):
		var cum: int = g.xp_for_level(lv)
		var delta: int = cum - prev
		var mark := "  <-- seam (Sv.%d)" % int(eco.xp_curve_early.seam_level) if lv == int(eco.xp_curve_early.seam_level) else ""
		print("  %2d  %10d  %8d%s" % [lv, cum, delta, mark])
		prev = cum
	g.free()


func _check_offline_full_efficiency() -> void:
	# Arka planda (full_efficiency) 20 saatlik ve 30 saatlik (24 saatlik kapağı
	# aşan) senaryoları karşılaştır — kapak sonrası fazlanın birikime katkı
	# vermediğini ve arka planda odanın hiç kirlenmediğini göster.
	var g20 = new_g()
	g20.coins = 1000000
	g20.time_scale = 1.0
	g20.start_shift(24)
	g20.last_sim_unix = g20.now() - 20.0 * 3600.0
	g20.simulate_to(g20.now())
	print("  20 saatlik arka plan boşluğu: birikim %.0f, oda kirli mi: %s" % [
		g20.pending_income, g20.rooms[0].dirty])
	g20.free()

	var g30 = new_g()
	g30.coins = 1000000
	g30.time_scale = 1.0
	g30.start_shift(24)
	g30.last_sim_unix = g30.now() - 30.0 * 3600.0
	g30.simulate_to(g30.now())
	print("  30 saatlik arka plan boşluğu (24 saatlik kapak): birikim %.0f, oda kirli mi: %s" % [
		g30.pending_income, g30.rooms[0].dirty])
	g30.free()


func _check_staff_upgrade_impact() -> void:
	var levels := [8, 18, 28]
	var room_types: Array = eco.room_types.keys()
	for lv in levels:
		var unlocked := []
		for t in room_types:
			if int(eco.room_types[t].unlock_level) <= lv:
				unlocked.append(t)
		var g = _milestone_setup(lv, 5000000, unlocked, 2)
		print("  --- Seviye %d ---" % lv)
		var max_tier: int = int(eco.staff_upgrade.max_tier)
		for tier in range(0, max_tier + 1):
			g.staff_tier = tier
			var cost: float = g.shift_cost(1)
			var income: float = g.hourly_income()
			var margin := cost / income if income > 0.0 else 0.0
			print("    kademe %d: vardiya maliyeti %6d  saatlik gelir %8.0f  marj %%%5.1f" % [
				tier, int(cost), income, margin * 100.0])
		g.free()
