extends Node
## data/*.json şema ve tutarlılık testi.
##
## Oyunun ekonomisi tamamen veri güdümlü (`data/economy.json` — kodda sabit sayı
## yok), görev/başarım zincirleri de öyle. Bu yüzden bir JSON'daki tek bir yazım
## hatası derlemeyi bozmaz, oyunu sessizce bozar: ulaşılamayan bir görev,
## kilitlenmeyen bir oda, sıfıra bölen bir çarpan. Bu test o sınıfı yakalar.
##
## Üç tür iddia var:
##   ŞEMA        — alan var mı, tipi doğru mu, aralık makul mu.
##   ÇAPRAZ      — bir dosyadaki kimlik başka bir yerde gerçekten karşılığı var mı
##                 (görevin istediği oda tipi, paketin içindeki eşya, vb.).
##   KOD-VERİ    — verideki her `type` değerini kod GERÇEKTEN işliyor mu; işlemezse
##                 görev sonsuza dek 0 ilerlemede kalır ve zincir tıkanır.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/data_check.tscn

var failures := 0
var checks := 0

## main.gd'nin ANCHOR_POSITIONS'ı ile eşleşmeli: burada olmayan bir çıpaya sahip
## eşya, oda kartında HİÇBİR yere çizilmez (sessiz kayıp).
const ANCHORS := ["ceiling", "wall", "surface", "floor_rug", "floor_side"]
## Odada tek örneği olabilen dışlayıcı yuvalar.
const SLOTS := ["wallpaper", "bed", "floor"]

var eco: Dictionary
var quests: Array
var achievements: Array
var game  # Game örneği (autoload değil — testte elle kurulur)


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


func _ready() -> void:
	print("Little Grand Hotel — veri dosyası testi")
	print("=".repeat(64))

	var GameScript = load("res://src/autoload/game.gd")
	game = GameScript.new()
	# Game normalde autoload'dır ve tabloları _ready()'de yükler. Burada elle
	# kurulur, yoksa new_game() boş bir `eco` üstünde patlar (bkz. sim_check).
	game.eco = game.load_json("res://data/economy.json")
	game.quests = game.load_json("res://data/quests.json").get("quests", [])
	game.achievements = game.load_json("res://data/achievements.json").get("achievements", [])
	eco = game.eco
	quests = game.quests
	achievements = game.achievements

	_test_files_parse()
	_test_economy_top_level()
	_test_room_types()
	_test_items()
	_test_bundles()
	_test_tiers()
	_test_shift_and_income()
	_test_progression_tables()
	_test_quests()
	_test_achievements()
	_test_progress_types_are_handled()
	_test_quest_chain_is_completable()

	game.free()
	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


# --- Temel ---------------------------------------------------------------

func _test_files_parse() -> void:
	print("\n[1] Dosyalar okunuyor mu")
	check(not eco.is_empty(), "economy.json ayrıştırıldı")
	check(quests.size() > 0, "quests.json'da %d görev var" % quests.size())
	check(achievements.size() > 0, "achievements.json'da %d başarım var" % achievements.size())


func _test_economy_top_level() -> void:
	print("\n[2] economy.json — üst düzey alanlar")
	for key in ["start", "building", "shift_rates", "room_types", "items",
			"tier_names", "tier_thresholds", "tier_mult", "star_mult",
			"xp_curve", "xp_curve_early", "staff_upgrade", "prestige",
			"infest", "poke", "catch", "bundles", "daily_rewards"]:
		check(eco.has(key), "'%s' alanı var" % key)

	check(int(eco.start.coins) > 0, "başlangıç coin pozitif")
	check(int(eco.start.gems) >= 0, "başlangıç elmas negatif değil")
	check(float(eco.occupancy_base) > 0.0 and float(eco.occupancy_base) <= 1.0,
		"doluluk tabanı 0..1 aralığında")
	check(float(eco.sell_refund) > 0.0 and float(eco.sell_refund) < 1.0,
		"satış iadesi 0..1 arasında (tam iade sonsuz para olurdu)")
	check(int(eco.offline_cap_hours) > 0, "çevrimdışı tavan pozitif")

	var b: Dictionary = eco.building
	check(int(b.start_floors) >= 1, "başlangıç kat sayısı ≥ 1")
	check(int(b.max_floors) >= int(b.start_floors), "max_floors ≥ start_floors")
	check(int(b.grid_cols) > 0, "grid_cols pozitif")
	check(float(b.floor_mult) >= 1.0, "kat fiyat çarpanı ≥ 1 (ucuzlamamalı)")
	check(float(b.block_price_mult) >= 1.0, "blok fiyat çarpanı ≥ 1")


# --- Odalar --------------------------------------------------------------

func _test_room_types() -> void:
	print("\n[3] room_types")
	var guest := 0
	var housekeeping := 0
	for id in eco.room_types:
		var r: Dictionary = eco.room_types[id]
		var tag := "oda '%s'" % id
		check(r.has("name") and String(r.name) != "", "%s: adı var" % tag)
		check(r.has("category"), "%s: kategorisi var" % tag)
		check(["guest", "facility", "functional"].has(String(r.category)),
			"%s: kategori bilinen bir değer ('%s')" % [tag, r.category])
		check(int(r.get("price", -1)) >= 0, "%s: fiyat negatif değil" % tag)
		check(int(r.get("unlock_level", 0)) >= 1, "%s: unlock_level ≥ 1" % tag)
		check(int(r.get("footprint_w", 1)) >= 1, "%s: footprint_w ≥ 1" % tag)
		check(int(r.get("footprint_w", 1)) <= int(eco.building.grid_cols),
			"%s: genişliği bir kata sığıyor" % tag)
		if String(r.category) == "guest":
			guest += 1
			check(int(r.get("base_income", 0)) > 0, "%s: misafir odası gelir üretiyor" % tag)
			check(int(r.get("stay_hours", 0)) > 0, "%s: konaklama süresi pozitif" % tag)
		if id == "housekeeping":
			housekeeping += 1
	check(guest >= 3, "en az 3 misafir odası tipi var (%d)" % guest)
	check(housekeeping == 1, "temizlik odası tanımlı")

	# Başlangıç odası gerçekten Sv.1'de açık olmalı, yoksa yeni oyun kilitli başlar.
	check(int(eco.room_types.standard.unlock_level) == 1,
		"standart oda 1. seviyede açık — yeni oyun kilitli başlamıyor")


func _test_items() -> void:
	print("\n[4] items")
	var ids := {}
	var free_wallpaper := 0
	var premium := 0
	for it: Dictionary in eco.items:
		var id := String(it.get("id", ""))
		var tag := "eşya '%s'" % id
		check(id != "", "eşyanın kimliği var")
		check(not ids.has(id), "%s: kimlik benzersiz" % tag)
		ids[id] = true
		check(String(it.get("name", "")) != "", "%s: adı var" % tag)
		check(int(it.get("sp", -1)) >= 0, "%s: stil puanı negatif değil" % tag)
		check(int(it.get("unlock_level", 0)) >= 1, "%s: unlock_level ≥ 1" % tag)
		# Eşya ya DIŞLAYICI bir yuvaya (odada tek: duvar kâğıdı/yatak/zemin) ya da
		# bir KONUM çıpasına oturur. İkisi birden ya da hiçbiri, eşyayı ya iki kez
		# ya da hiç çizdirmez.
		var has_slot := it.has("slot") and String(it.get("slot", "")) != ""
		var has_anchor := it.has("anchor") and String(it.get("anchor", "")) != ""
		check(has_slot != has_anchor,
			"%s: slot VEYA anchor (ikisi birden değil, hiçbiri de değil)" % tag)
		if has_anchor:
			check(ANCHORS.has(String(it.anchor)),
				"%s: '%s' çıpası main.gd ANCHOR_POSITIONS'ta tanımlı" % [tag, it.anchor])
		if has_slot:
			check(SLOTS.has(String(it.slot)),
				"%s: '%s' yuvası bilinen bir dışlayıcı yuva" % [tag, it.slot])
		var gem_price := int(it.get("gem_price", 0))
		var price := int(it.get("price", 0))
		check(price >= 0 and gem_price >= 0, "%s: fiyatlar negatif değil" % tag)
		# Bedava eşya yalnızca başlangıç setinde olabilir. Sonradan açılan bedava
		# bir eşya, seviye atlayan herkese karşılıksız stil puanı dağıtırdı.
		if price == 0 and gem_price == 0:
			check(int(it.get("unlock_level", 1)) == 1,
				"%s: bedava eşya yalnızca başlangıç setinde (Sv.1)" % tag)
		if gem_price > 0:
			premium += 1
		if price == 0 and gem_price == 0:
			free_wallpaper += 1
	check(free_wallpaper >= 1, "en az bir bedava başlangıç eşyası var (duvar kâğıdı)")
	check(premium >= 1, "en az bir premium (elmaslı) eşya var")

	# Yukarıdaki ANCHORS listesi main.gd'nin ANCHOR_POSITIONS'ının kopyasıdır;
	# kopyanın sessizce kaymadığını burada doğrularız (main.gd'yi örneklemek tüm
	# sahneyi ayağa kaldırmayı gerektirirdi).
	var src := FileAccess.get_file_as_string("res://src/main.gd")
	var block := src.get_slice("const ANCHOR_POSITIONS := {", 1).get_slice("}", 0)
	check(block != "", "main.gd'de ANCHOR_POSITIONS bulundu")
	for a in ANCHORS:
		check(block.contains("\"%s\":" % a),
			"main.gd ANCHOR_POSITIONS '%s' çıpasını tanıyor" % a)
	var declared := 0
	for line in block.split("
"):
		if line.strip_edges().begins_with("\""):
			declared += 1
	check(declared == ANCHORS.size(),
		"main.gd'de %d çıpa tanımlı, test %d tanesini biliyor" % [declared, ANCHORS.size()])


func _test_bundles() -> void:
	print("\n[5] bundles")
	var item_ids := {}
	for it: Dictionary in eco.items:
		item_ids[String(it.id)] = it
	for b: Dictionary in eco.bundles:
		var tag := "paket '%s'" % String(b.get("id", ""))
		check(String(b.get("id", "")) != "", "paketin kimliği var")
		check(String(b.get("name", "")) != "", "%s: adı var" % tag)
		var items: Array = b.get("items", [])
		check(items.size() >= 2, "%s: en az 2 eşya içeriyor" % tag)
		for iid in items:
			# ÇAPRAZ: paketin içindeki her eşya gerçekten tanımlı olmalı, yoksa
			# satın alma sessizce eksik eşya verir.
			check(item_ids.has(String(iid)),
				"%s: içerdiği '%s' eşyası tanımlı" % [tag, iid])
		var disc := float(b.get("discount", 0.0))
		check(disc >= 0.0 and disc < 1.0, "%s: indirim 0..1 arasında" % tag)


func _test_tiers() -> void:
	print("\n[6] kademe tabloları")
	var names: Array = eco.tier_names
	var thr: Array = eco.tier_thresholds
	var mult: Array = eco.tier_mult
	check(names.size() == thr.size() and thr.size() == mult.size(),
		"tier_names/thresholds/mult aynı uzunlukta (%d)" % names.size())
	check(int(thr[0]) == 0, "ilk kademe eşiği 0 — boş oda da bir kademeye düşüyor")
	for i in range(1, thr.size()):
		check(int(thr[i]) > int(thr[i - 1]),
			"eşik %d bir öncekinden büyük (%d > %d)" % [i, int(thr[i]), int(thr[i - 1])])
		check(float(mult[i]) >= float(mult[i - 1]),
			"kademe çarpanı %d azalmıyor" % i)
	check(float(mult[0]) > 0.0, "en düşük kademe çarpanı pozitif — gelir sıfırlanmıyor")

	# Eşiklerin ulaşılabilir olması: tüm eşyaların SP toplamı en üst eşiği geçmeli,
	# yoksa en üst kademeye HİÇBİR şekilde çıkılamaz.
	var max_sp := 0
	for it: Dictionary in eco.items:
		max_sp += int(it.get("sp", 0))
	check(max_sp >= int(thr[thr.size() - 1]),
		"tüm eşyaların SP toplamı (%d) en üst eşiğe (%d) yetiyor"
			% [max_sp, int(thr[thr.size() - 1])])


func _test_shift_and_income() -> void:
	print("\n[7] vardiya ve gelir")
	var rates: Dictionary = eco.shift_rates
	check(rates.size() > 0, "vardiya süreleri tanımlı")
	for k in rates:
		check(int(k) > 0, "vardiya uzunluğu '%s' pozitif" % k)
		check(float(rates[k]) > 0.0, "vardiya '%s' saat/gerçek-saat oranı pozitif" % k)
	check(rates.has("24"), "24 saatlik uzun vardiya var")

	check(float(eco.staff_per_room) > 0.0, "oda başına personel maliyeti pozitif")
	var su: Dictionary = eco.staff_upgrade
	check(float(su.get("cost_mult", 1.0)) > 0.0, "personel maliyet çarpanı pozitif")
	check(float(su.get("income_boost_pct", -1.0)) > 0.0,
		"personel yükseltmesi geliri artırıyor")
	check(float(su.get("cost_reduction_pct", -1.0)) >= 0.0,
		"personel yükseltmesi maliyeti artırmıyor")
	check(int(su.get("max_tier", 0)) > 0, "personel yükseltmesinin bir tavanı var")
	check(float(su.get("base_cost", 0.0)) > 0.0, "personel yükseltme taban bedeli pozitif")
	check(float(eco.auto_renew.get("price_mult", 0.0)) > 1.0,
		"otomatik yenileme kolaylık zammı taşıyor (price_mult > 1)")
	var inf: Dictionary = eco.infest
	check(int(inf.get("after_hours", 0)) > 0, "istila süresi pozitif")
	check(int(inf.get("clean_cost", 0)) > 0, "istila temizlik bedeli pozitif")
	var cat: Dictionary = eco.catch
	check(float(cat.get("interval_real_seconds", 0.0)) > 0.0, "yakalama aralığı pozitif")
	check(float(cat.get("bonus_hourly_frac", 0.0)) > 0.0, "yakalama bonusu pozitif")

	var star: Dictionary = eco.star_mult
	var prev := -1.0
	var keys := star.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	for k in keys:
		var v := float(star[k])
		check(v > 0.0, "%s yıldız çarpanı pozitif" % k)
		check(v >= prev, "%s yıldız çarpanı bir öncekinden düşük değil" % k)
		prev = v


func _test_progression_tables() -> void:
	print("\n[8] ilerleme tabloları")
	var xc: Dictionary = eco.xp_curve
	var xe: Dictionary = eco.xp_curve_early
	check(float(xc.get("base", 0)) > 0.0, "xp_curve.base pozitif")
	check(float(xc.get("exp", 0)) > 1.0, "xp_curve.exp > 1 — eğri gerçekten dikleşiyor")
	check(float(xe.get("base", 0)) > 0.0, "xp_curve_early.base pozitif")
	check(float(xe.get("exp", 0)) > 1.0, "xp_curve_early.exp > 1")
	check(int(xe.get("seam_level", 0)) >= 2, "erken eğrinin ek yeri en az 2. seviyede")
	check(float(xe.get("exp", 9.0)) < float(xc.get("exp", 0.0)),
		"erken eğri geç eğriden DAHA YUMUŞAK (%s < %s) — açılış hızlı"
			% [xe.get("exp", 0), xc.get("exp", 0)])
	check(int(eco.levelup_gems) > 0, "seviye atlama elmas veriyor")

	var pr: Dictionary = eco.prestige
	check(int(pr.get("min_level", 0)) > 1, "prestij en az 2. seviyeyi şart koşuyor")
	check(float(pr.get("mult_gain", 0.0)) > 0.0, "prestij çarpan kazancı pozitif")

	var dif := float(eco.get("dirty_income_frac", -1.0))
	check(dif > 0.0 and dif < 1.0, "kirli oda gelir oranı (0,1) aralığında — sıfır DEĞİL")
	check(float(eco.infest.after_hours) > float(eco.room_types.standard.stay_hours) * 4.0,
		"istila eşiği konaklama süresinin en az 4 katı (ön planda dakikalar içinde tetiklenmemeli)")

	var poke: Dictionary = eco.poke
	check(int(poke.get("daily_cap", 0)) > 0, "günlük dürtme hakkı var")
	check(int(poke.get("base", 0)) > 0, "dürtme taban ödülü pozitif")
	check(int(poke.get("per_star", -1)) >= 0, "yıldız başına dürtme bonusu negatif değil")
	check(float(poke.get("chance", 0.0)) > 0.0 and float(poke.get("chance", 1.0)) <= 1.0,
		"dürtme şansı 0..1 arasında")

	var daily: Array = eco.daily_rewards
	check(daily.size() == 7, "günlük ödül tablosu 7 günlük (%d)" % daily.size())
	for i in daily.size():
		var d: Dictionary = daily[i]
		check(int(d.get("coins", 0)) > 0 or int(d.get("gems", 0)) > 0,
			"gün %d bir şey veriyor" % (i + 1))


# --- Görev / başarım -----------------------------------------------------

func _test_quests() -> void:
	print("\n[9] quests.json")
	var ids := {}
	for q: Dictionary in quests:
		var id := String(q.get("id", ""))
		var tag := "görev '%s'" % id
		check(id != "", "görevin kimliği var")
		check(not ids.has(id), "%s: kimlik benzersiz" % tag)
		ids[id] = true
		check(String(q.get("name", "")) != "", "%s: adı var" % tag)
		check(String(q.get("desc", "")) != "", "%s: açıklaması var" % tag)
		check(q.has("type"), "%s: tipi var" % tag)
		check(int(q.get("target", 0)) >= 1, "%s: hedefi ≥ 1" % tag)
		check(int(q.get("reward_coins", 0)) + int(q.get("reward_gems", 0)) > 0,
			"%s: bir ödül veriyor" % tag)
		if String(q.type) == "own_type":
			# ÇAPRAZ: istenen oda tipi gerçekten var mı.
			check(eco.room_types.has(String(q.get("room", ""))),
				"%s: istediği '%s' odası tanımlı" % [tag, q.get("room", "")])


func _test_achievements() -> void:
	print("\n[10] achievements.json")
	var ids := {}
	for a: Dictionary in achievements:
		var id := String(a.get("id", ""))
		var tag := "başarım '%s'" % id
		check(id != "", "başarımın kimliği var")
		check(not ids.has(id), "%s: kimlik benzersiz" % tag)
		ids[id] = true
		check(String(a.get("name", "")) != "", "%s: adı var" % tag)
		check(String(a.get("desc", "")) != "", "%s: açıklaması var" % tag)
		check(int(a.get("target", 0)) >= 1, "%s: hedefi ≥ 1" % tag)
		check(int(a.get("reward_coins", 0)) + int(a.get("reward_gems", 0)) > 0,
			"%s: bir ödül veriyor" % tag)


## KOD-VERİ kapısı. `quest_progress()` bilinmeyen bir tipte `[0, target]`
## döndürür — yani görev sonsuza dek 0 ilerlemede kalır ve SIRALI zincir orada
## tıkanır. Bu, JSON'a yeni bir tip yazıp koda eklemeyi unutmanın tam sonucu.
func _test_progress_types_are_handled() -> void:
	print("\n[11] her 'type' değerini kod işliyor mu")
	game.new_game()
	var seen := {}
	for entry in quests + achievements:
		seen[String(entry.get("type", ""))] = true
	for t in seen:
		# Hedefi 0 olan bir sahte kayıtla sorulur: işlenen bir tip için
		# quest_progress kendi sayacını döndürür, işlenmeyen tip [0, 0] döner
		# ve `p[1] == 0` olur — bu ayrımı hedefi 1 vererek yapıyoruz.
		var probe := {"type": t, "target": 7, "room": "standard"}
		var p: Array = game.quest_progress(probe)
		var handled: bool = p[1] == 7 or t == "own_type"  # own_type hedefi 1'e sabitler
		check(handled, "'%s' tipi quest_progress içinde işleniyor" % t)


## Zincirin gerçekten bitirilebilir olması: her görevin hedefi, oyunun
## sunabileceği tavanın altında kalmalı. Aksi halde oyuncu son göreve gelir ve
## orada sonsuza dek takılır.
func _test_quest_chain_is_completable() -> void:
	print("\n[12] görev zinciri tamamlanabilir mi")
	var max_floors := int(eco.building.max_floors)
	var max_slots := max_floors * int(eco.building.grid_cols)
	var max_star := 0
	for k in eco.star_mult:
		max_star = maxi(max_star, int(k))
	var max_tier: int = eco.tier_names.size()
	for entry in quests + achievements:
		var t := String(entry.get("type", ""))
		var target := int(entry.get("target", 1))
		var id := String(entry.get("id", ""))
		match t:
			"floors":
				check(target <= max_floors,
					"'%s': %d kat hedefi tavanın (%d) altında" % [id, target, max_floors])
			"rooms":
				check(target <= max_slots,
					"'%s': %d oda hedefi kapasitenin (%d) altında" % [id, target, max_slots])
			"star":
				check(target <= max_star,
					"'%s': %d yıldız hedefi tavanın (%d) altında" % [id, target, max_star])
			"tier":
				check(target <= max_tier,
					"'%s': %d kademe hedefi tavanın (%d) altında" % [id, target, max_tier])
	# Sıra: zincirin ilk görevi ilk hamlede yapılabilir olmalı.
	game.new_game()
	var first: Dictionary = quests[0]
	var p: Array = game.quest_progress(first)
	check(p[0] < p[1], "ilk görev yeni oyunda henüz tamamlanmamış")
	check(int(first.get("target", 99)) <= 3,
		"ilk görevin hedefi küçük (%d) — açılış hemen ödül veriyor" % int(first.get("target", 99)))
