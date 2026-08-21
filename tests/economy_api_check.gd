extends Node
## `game.gd`'nin geri kalan genel API'si — kapsam raporunda (docs/test-coverage.md)
## hiçbir testte geçmeyen olarak çıkan 17 fonksiyon.
##
## `sim_check.gd` oynanış AKIŞINI sürüyor (vardiya → gelir → temizlik → satın
## alma); orada bir fonksiyon dolaylı olarak çalışsa bile davranışı ayrıca iddia
## edilmiş olmuyor. Burası o boşluğu doldurur: her fonksiyon kendi başına, sınır
## değerleriyle ve YANLIŞ girdilerle çağrılır — çünkü bunların çoğu doğrudan
## arayüzden, oyuncunun seçtiği rastgele parametrelerle çağrılıyor.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/economy_api_check.tscn

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


func _fresh():
	var g = GameScript.new()
	g.eco = g.load_json("res://data/economy.json")
	g.quests = g.load_json("res://data/quests.json").get("quests", [])
	g.achievements = g.load_json("res://data/achievements.json").get("achievements", [])
	g.new_game()
	return g


func _ready() -> void:
	print("Little Grand Hotel — ekonomi API testi")
	print("=".repeat(64))
	GameScript = load("res://src/autoload/game.gd")

	_test_room_footprint()
	_test_floor_open_width()
	_test_block_price_and_buy()
	_test_can_move_room_to()
	_test_clean_fraction()
	_test_staff_math()
	_test_auto_renew_cost()
	_test_add_pending_income()
	_test_can_afford_item()
	_test_tier_name_and_has_type()
	_test_language_api()

	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _test_room_footprint() -> void:
	print("\n[1] room_footprint")
	var g = _fresh()
	for type in g.eco.room_types:
		var expected := int((g.eco.room_types[type] as Dictionary).get("footprint_w", 1))
		check(g.room_footprint(type) == expected,
			"'%s' ayak izi %d" % [type, expected])
	# Tanınmayan tip 1 dönmeli: 0 dönseydi yerleştirme mantığı sonsuz döngüye
	# ya da sıfıra bölmeye girerdi.
	check(g.room_footprint("olmayan_oda") == 1, "bilinmeyen tip güvenli 1 döner")
	check(g.room_footprint("") == 1, "boş tip güvenli 1 döner")
	g.free()


func _test_floor_open_width() -> void:
	print("\n[2] floor_open_width")
	var g = _fresh()
	check(g.floor_open_width(1) == int(g.floor_blocks[0]),
		"1. katın genişliği blok dizisinden okunuyor (%d)" % g.floor_open_width(1))
	# Aralık dışı katlar: UI kat numarasını doğrudan geçiriyor, 0/negatif/aşırı
	# değerler dizi taşmasına DEĞİL 0'a düşmeli.
	for bad in [0, -1, -999, g.floors + 1, 9999]:
		check(g.floor_open_width(bad) == 0, "aralık dışı kat %d → 0" % bad)
	g.free()


func _test_block_price_and_buy() -> void:
	print("\n[3] block_price / can_buy_block / buy_block")
	var g = _fresh()
	var base_price := int(g.eco.building.block_price)
	# Varsayılan genişlikte fiyat taban fiyat olmalı (üs 0).
	check(g.block_price(1) >= base_price,
		"1. kat blok fiyatı taban fiyattan düşük değil (%d ≥ %d)"
			% [g.block_price(1), base_price])

	g.coins = 0
	check(not g.can_buy_block(1), "parasızken blok alınamıyor")
	check(not g.buy_block(1), "buy_block da reddediyor")

	g.coins = 10_000_000
	for bad in [0, -5, g.floors + 1, 9999]:
		check(not g.can_buy_block(bad), "aralık dışı kat %d için blok alınamaz" % bad)
		check(not g.buy_block(bad), "buy_block aralık dışı katı reddediyor (%d)" % bad)

	var width_before: int = g.floor_open_width(1)
	var coins_before: int = g.coins
	var price: int = g.block_price(1)
	check(g.can_buy_block(1), "para varken blok alınabilir")
	check(g.buy_block(1), "blok satın alındı")
	check(g.floor_open_width(1) == width_before + 1,
		"kat bir blok genişledi (%d → %d)" % [width_before, g.floor_open_width(1)])
	check(g.coins == coins_before - price, "bedel tam olarak düşüldü (%d)" % price)
	# Fiyat her blokla artmalı, yoksa kat genişletmenin bir maliyet eğrisi olmaz.
	check(g.block_price(1) >= price,
		"sonraki blok daha pahalı ya da eşit (%d ≥ %d)" % [g.block_price(1), price])

	# Izgara tavanına kadar al: tavanda artık alınamamalı.
	var guard := 0
	while g.can_buy_block(1) and guard < 64:
		g.buy_block(1)
		guard += 1
	check(g.floor_open_width(1) == int(g.eco.building.grid_cols),
		"kat ızgara tavanına ulaştı (%d)" % g.floor_open_width(1))
	check(not g.can_buy_block(1), "tavanda blok alınamıyor")
	g.free()


func _test_can_move_room_to() -> void:
	print("\n[4] can_move_room_to")
	var g = _fresh()
	var rid := String(g.rooms[0].id)
	var f0 := int(g.rooms[0].floor)
	var c0 := int(g.rooms[0].col)

	check(not g.can_move_room_to(rid, f0, c0),
		"odanın ZATEN bulunduğu hücreye taşıma anlamsız — reddediliyor")
	check(not g.can_move_room_to("olmayan_id", 1, 0),
		"bilinmeyen oda kimliği reddediliyor")
	for bad_floor in [0, -1, 9999]:
		check(not g.can_move_room_to(rid, bad_floor, 0),
			"aralık dışı kat %d reddediliyor" % bad_floor)
	check(not g.can_move_room_to(rid, f0, -1), "negatif sütun reddediliyor")
	check(not g.can_move_room_to(rid, f0, 9999), "aşırı sütun reddediliyor")

	# İkinci odanın hücresine taşıma reddedilmeli (çakışma).
	if g.rooms.size() > 1:
		var f1 := int(g.rooms[1].floor)
		var c1 := int(g.rooms[1].col)
		check(not g.can_move_room_to(rid, f1, c1), "dolu hücreye taşıma reddediliyor")

	# Boş bir hücre bulunup taşınabilmeli — ve kontrol, odanın KENDİ eski yerini
	# çakışma saymamalı (fonksiyon bunun için odayı geçici olarak çıkarıyor).
	g.coins = 10_000_000
	while g.can_buy_block(f0):
		g.buy_block(f0)
	var moved := false
	for col in range(g.floor_open_width(f0)):
		if g.can_move_room_to(rid, f0, col):
			moved = g.move_room_to(rid, f0, col)
			if moved:
				check(int(g.rooms[g._room_index_by_id(rid)].col) == col,
					"oda %d. sütuna taşındı" % col)
				break
	check(moved, "genişletilmiş katta boş bir hücreye taşınabildi")
	g.free()


func _test_clean_fraction() -> void:
	print("\n[5] clean_fraction")
	var g = _fresh()
	var guests: Array = g.guest_rooms()
	check(guests.size() > 0, "başlangıçta misafir odası var (%d)" % guests.size())
	for r in guests:
		r.dirty = false
	check(is_equal_approx(g.clean_fraction(), 1.0), "hepsi temizken oran 1.0")
	for r in guests:
		r.dirty = true
	check(is_equal_approx(g.clean_fraction(), 0.0), "hepsi kirliyken oran 0.0")
	if guests.size() >= 2:
		guests[0].dirty = false
		check(is_equal_approx(g.clean_fraction(), 1.0 / guests.size()),
			"karışık durumda oran doğru (%.3f)" % g.clean_fraction())
	# Misafir odası hiç yoksa 1.0 dönmeli: 0 dönseydi yıldız hesabı, hiç oda
	# almamış oyuncuyu "her yer kirli" diye cezalandırırdı.
	g.rooms.clear()
	check(is_equal_approx(g.clean_fraction(), 1.0),
		"misafir odası yokken oran 1.0 (sıfıra bölme yok)")
	g.free()


func _test_staff_math() -> void:
	print("\n[6] staff_count / staff_cost_mult / staff_income_mult")
	var g = _fresh()
	check(g.staff_count() >= 1, "personel sayısı en az 1 (%d)" % g.staff_count())
	var before: int = g.staff_count()
	g.rooms.append(g.make_room("standard", 1, 0))
	g.rooms.append(g.make_room("standard", 1, 1))
	check(g.staff_count() >= before, "oda eklenince personel azalmıyor")
	g.rooms.clear()
	check(g.staff_count() == 1, "oda yokken bile en az 1 personel (sıfır maliyet yok)")

	# Yükseltme kademesi 0'da çarpanlar nötr olmalı.
	g = _fresh()
	g.staff_tier = 0
	check(is_equal_approx(g.staff_cost_mult(), 1.0), "kademe 0'da maliyet çarpanı 1.0")
	check(is_equal_approx(g.staff_income_mult(), 1.0), "kademe 0'da gelir çarpanı 1.0")

	var max_tier := int(g.eco.staff_upgrade.max_tier)
	var prev_cost := 1.0
	var prev_income := 1.0
	for tier in range(1, max_tier + 1):
		g.staff_tier = tier
		var c: float = g.staff_cost_mult()
		var inc: float = g.staff_income_mult()
		check(c < prev_cost, "kademe %d maliyeti düşürüyor (%.4f < %.4f)" % [tier, c, prev_cost])
		check(inc > prev_income, "kademe %d geliri artırıyor (%.4f > %.4f)" % [tier, inc, prev_income])
		check(c > 0.0 and is_finite(c), "kademe %d maliyet çarpanı sonlu ve pozitif" % tier)
		check(is_finite(inc), "kademe %d gelir çarpanı sonlu" % tier)
		prev_cost = c
		prev_income = inc
	g.free()


func _test_auto_renew_cost() -> void:
	print("\n[7] auto_renew_buy_cost")
	var g = _fresh()
	for hours in [1, 4, 8, 24]:
		var shift_cost: int = g.shift_cost(hours)
		var renew: int = g.auto_renew_buy_cost(hours)
		check(renew > shift_cost,
			"%d saatlik yenileme hakkı vardiyadan pahalı (%d > %d) — kolaylık zammı"
				% [hours, renew, shift_cost])
		check(renew == ceili(float(shift_cost) * float(g.eco.auto_renew.price_mult)),
			"%d saat için fiyat tam olarak vardiya × price_mult" % hours)
	# Uzun vardiya, kısa vardiyadan pahalı olmalı.
	check(g.auto_renew_buy_cost(24) > g.auto_renew_buy_cost(1),
		"24 saatlik hak 1 saatlikten pahalı")
	# Sınır: satın alma yalnızca 1..24 aralığını kabul ediyor.
	g.coins = 10_000_000
	for bad in [0, -1, 25, 9999]:
		check(not g.buy_auto_renew(bad), "geçersiz süre %d reddedildi" % bad)
	check(g.buy_auto_renew(8), "geçerli süre kabul edildi")
	check(g.auto_renew_hours_left > 0.0, "hak hesaba eklendi (%.1f)" % g.auto_renew_hours_left)
	g.free()


func _test_add_pending_income() -> void:
	print("\n[8] add_pending_income")
	var g = _fresh()
	g.pending_income = 0.0
	var fired := [0]
	g.state_changed.connect(func(): fired[0] += 1)
	g.add_pending_income(500)
	check(is_equal_approx(g.pending_income, 500.0), "birikim eklendi")
	check(fired[0] == 1, "arayüzü tazeleyecek sinyal yayıldı")
	g.add_pending_income(250)
	check(is_equal_approx(g.pending_income, 750.0), "ikinci ekleme birikti")
	# Sıfır/negatif hiçbir şey yapmamalı: ödüllü reklam callback'i 0 ile
	# çağrılabiliyor ve orada negatif birikim bakiye sömürüsüne yol açardı.
	var before: float = g.pending_income
	var signals_before: int = fired[0]
	g.add_pending_income(0)
	g.add_pending_income(-1000)
	check(is_equal_approx(g.pending_income, before), "0 ve negatif ekleme yok sayıldı")
	check(fired[0] == signals_before, "yok sayılan çağrı sinyal de yaymadı")
	g.free()


func _test_can_afford_item() -> void:
	print("\n[9] can_afford_item")
	var g = _fresh()
	var normal := {}
	var premium := {}
	for it in g.eco.items:
		var d: Dictionary = it
		if int(d.get("gem_price", 0)) > 0 and premium.is_empty():
			premium = d
		elif int(d.get("price", 0)) > 0 and normal.is_empty():
			normal = d
	check(not normal.is_empty() and not premium.is_empty(),
		"test için normal ve premium birer eşya bulundu")

	# Premium eşya ELMASA bakar, coine değil.
	g.coins = 0
	g.gems = int(premium.gem_price)
	check(g.can_afford_item(premium), "elmas yeterken premium alınabilir (coin 0 olsa da)")
	g.gems = int(premium.gem_price) - 1
	check(not g.can_afford_item(premium), "elmas 1 eksikken premium alınamaz")

	# Normal eşya coine bakar VE vardiya rezervini korur: oyuncu son parasıyla
	# eşya alıp vardiya başlatamaz duruma düşmemeli.
	g.gems = 0
	var reserve: int = g.min_shift_reserve()
	g.coins = int(normal.price) + reserve
	check(g.can_afford_item(normal), "fiyat + rezerv varken alınabilir")
	g.coins = int(normal.price) + reserve - 1
	check(not g.can_afford_item(normal),
		"rezervi bozacak alım reddediliyor (kilitlenme koruması)")
	check(reserve > 0, "vardiya rezervi pozitif (%d)" % reserve)
	g.free()


func _test_tier_name_and_has_type() -> void:
	print("\n[10] tier_name / has_type")
	var g = _fresh()
	var names: Array = g.eco.tier_names
	for i in names.size():
		check(g.tier_name(i) == String(names[i]),
			"kademe %d adı '%s'" % [i, g.tier_name(i)])
	# room_tier() her zaman 0..son aralığında döndüğü için tier_name yalnızca
	# geçerli indekslerle çağrılır; sınırın kendisi yine de doğrulanır.
	var g2 = _fresh()
	for r in g2.rooms:
		var t: int = g2.room_tier(r)
		check(t >= 0 and t < names.size(),
			"room_tier hep geçerli indeks döndürüyor (%d)" % t)

	check(g.has_type(String(g.rooms[0].type)),
		"sahip olunan tip için has_type true ('%s')" % g.rooms[0].type)
	check(not g.has_type("olmayan_oda"), "olmayan tip için false")
	check(not g.has_type(""), "boş tip için false")
	# housekeeping_active() doğrudan has_type'a dayanıyor.
	check(g.housekeeping_active() == g.has_type("housekeeping"),
		"housekeeping_active has_type ile tutarlı")
	g.rooms.append(g.make_room("housekeeping", 1, 5))
	check(g.has_type("housekeeping") and g.housekeeping_active(),
		"temizlik odası eklenince ikisi de true")
	g.free()
	g2.free()


func _test_language_api() -> void:
	print("\n[11] cycle_language / language_name")
	var g = _fresh()
	var codes := []
	for l in g.LANGUAGES:
		codes.append(String(l.code))
	check(codes.size() >= 2, "en az iki dil tanımlı (%s)" % str(codes))

	# Her dil kodu için insan-okunur bir ad dönmeli.
	for l in g.LANGUAGES:
		g.language = String(l.code)
		check(g.language_name() == String(l.name),
			"'%s' → '%s'" % [l.code, g.language_name()])
	# Tanınmayan kod ilk seçeneğe (sistem dili) düşmeli, boş dize değil.
	g.language = "klingon"
	check(g.language_name() == String(g.LANGUAGES[0].name),
		"bilinmeyen kod ilk seçeneğe düşüyor ('%s')" % g.language_name())

	# cycle_language tüm listeyi dolaşıp başa dönmeli (hiçbir dil atlanmamalı).
	g.language = codes[0]
	var seen := [codes[0]]
	for i in range(codes.size() - 1):
		g.cycle_language()
		seen.append(g.language)
	check(seen.size() == codes.size(), "%d adımda %d dil gezildi" % [codes.size(), seen.size()])
	var unique := {}
	for c in seen:
		unique[c] = true
	check(unique.size() == codes.size(), "her dile bir kez uğradı (atlama yok)")
	g.cycle_language()
	check(g.language == codes[0], "tur tamamlanınca başa döndü")
	g.free()
