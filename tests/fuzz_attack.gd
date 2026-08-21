extends Node
## Saldırı/fuzz testi: import_save_code() gibi dışa açık, güvenilmeyen girdi
## kabul eden yüzeylere kasıtlı olarak bozuk/kötü niyetli veri besler ve
## rastgele eylem dizileriyle ekonomi değişmezlerini (coins/gems asla negatif,
## NaN/Inf yok, çakışan oda yok vb.) kırmaya çalışır. Amaç var olan hataları
## kanıtlamak değil, _validate_save_dict() ve oyun mantığındaki doğrulama
## boşluklarını sistematik olarak taramak.
##
## Bulgular "BULGU:" öneki ile stderr'e yazılır; script bulgu varsa çıkış
## kodu 1 ile biter (CI'da başarısız sayılabilir).
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/fuzz_attack.tscn

const SEED := 1337

var eco: Dictionary
var quests: Array
var achievements: Array
var GameScript

var findings: Array = []
var cases_run := 0
var rng := RandomNumberGenerator.new()


## Bu test canlı Game autoload'ına bozuk kayıt yükler ve oyunu gerçekten
## oynatır — yol boyunca user://save.json EZİLİR. Oyuncunun/geliştiricinin
## kaydı kaybolmasın diye teste girerken bir yana alınır, çıkarken geri konur.
const SAVE_PATH := "user://save.json"
const BACKUP_PATH := "user://save.json.fuzz.bak"


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
	print("(test öncesi kayıt geri yüklendi)")


func _ready() -> void:
	_stash_save()
	rng.seed = SEED
	GameScript = load("res://src/autoload/game.gd")
	var tmp = GameScript.new()
	eco = tmp.load_json("res://data/economy.json")
	quests = tmp.load_json("res://data/quests.json").get("quests", [])
	achievements = tmp.load_json("res://data/achievements.json").get("achievements", [])
	tmp.free()

	var game := get_node("/root/Game")
	game.tutorial_seen = true

	print("Little Grand Hotel — saldırı/fuzz testi (seed=%d)" % SEED)
	print("=".repeat(64))

	print("\n--- 1) Kötü niyetli kayıt kodu / import_save_code fuzz ---")
	_attack_malicious_saves()

	print("\n--- 2) Render katmanı: en riskli senaryolar main.tscn'de ---")
	await _attack_render(game)

	print("\n--- 3) Rastgele eylem dizileri: ekonomi değişmezleri ---")
	_attack_random_sequences()

	print("\n--- 4) Sınır değer / tekil çağrı saldırıları ---")
	_attack_boundary_calls()

	print("\n" + "=".repeat(64))
	if findings.is_empty():
		print("SONUÇ: %d senaryo çalıştırıldı, hiçbir bulgu yok." % cases_run)
	else:
		print("SONUÇ: %d senaryo, %d BULGU:" % [cases_run, findings.size()])
		for f in findings:
			printerr("  BULGU: ", f)
	print("FUZZ_DONE")
	_restore_save()
	get_tree().quit(1 if not findings.is_empty() else 0)


func _flag(msg: String) -> void:
	findings.append(msg)
	printerr("  !! ", msg)


func _new_instance() -> Object:
	var g = GameScript.new()
	g.eco = eco
	g.quests = quests
	g.achievements = achievements
	g.new_game()
	return g


## Bir oyun durumunun temel ekonomi değişmezlerini kontrol eder. Her ihlal
## bir bulgu olarak kaydedilir; fonksiyon çökerse (engine seviyesinde runtime
## hatası) bu zaten stderr'de "SCRIPT ERROR" olarak görünür.
func _check_invariants(g, ctx: String) -> void:
	cases_run += 1
	if int(g.coins) < 0:
		_flag("%s: coins negatif (%d)" % [ctx, g.coins])
	if int(g.gems) < 0:
		_flag("%s: gems negatif (%d)" % [ctx, g.gems])
	if int(g.xp) < 0:
		_flag("%s: xp negatif (%d)" % [ctx, g.xp])
	var pi: float = g.pending_income
	if is_nan(pi) or is_inf(pi):
		_flag("%s: pending_income NaN/Inf (%s)" % [ctx, str(pi)])
	elif pi < -0.001:
		_flag("%s: pending_income negatif (%f)" % [ctx, pi])
	var hi: float = g.hourly_income()
	if is_nan(hi) or is_inf(hi):
		_flag("%s: hourly_income() NaN/Inf" % ctx)
	elif hi < 0.0:
		_flag("%s: hourly_income() negatif (%f)" % [ctx, hi])
	var sr: int = g.star_rating()
	if sr < 0 or sr > 6:
		_flag("%s: star_rating() aralık dışı (%d)" % [ctx, sr])
	var seen_cells := {}
	var seen_ids := {}
	for r in g.rooms:
		if typeof(r) != TYPE_DICTIONARY:
			_flag("%s: rooms içinde Dictionary olmayan bir eleman var (%s)" % [ctx, str(r)])
			continue
		var rid := String(r.get("id", ""))
		if not rid.is_empty():
			if seen_ids.has(rid):
				_flag("%s: iki oda aynı id'yi paylaşıyor (%s)" % [ctx, rid])
			seen_ids[rid] = true
		var key := "%s:%s" % [str(r.get("floor")), str(r.get("col"))]
		if seen_cells.has(key):
			_flag("%s: iki oda aynı hücrede çakışıyor (%s)" % [ctx, key])
		seen_cells[key] = true
		var sc: int = g.room_score(r)
		if sc < 0:
			_flag("%s: room_score() negatif (%d, oda %s)" % [ctx, sc, rid])


# --- 1) Kötü niyetli kayıt kodu fuzz ---------------------------------------

func _attack_malicious_saves() -> void:
	var base_g = _new_instance()
	base_g.coins = 50000
	base_g.buy_room("cafe")
	var baseline: Dictionary = JSON.parse_string(Marshalls.base64_to_utf8(base_g.export_save_code()))
	base_g.free()

	for atk in _malicious_variants(baseline):
		var name: String = atk[0]
		var payload: Dictionary = atk[1]
		var g = _new_instance()
		var g_coins_before: int = g.coins
		var text: String
		var ok: bool
		# Bazı mutasyonlar (INF/NAN gibi) geçerli JSON üretemeyebilir; bu
		# durumda stringify/parse'ın kendisi başarısız olur — bu da geçerli
		# bir "reddedildi" sonucudur, script'i çökertmemeli.
		text = JSON.stringify(payload)
		ok = g.import_save_code(Marshalls.utf8_to_base64(text))
		cases_run += 1
		if ok:
			print("  KABUL  %-32s -> yüklendi, değişmezler kontrol ediliyor" % name)
			_check_invariants(g, "import[%s]" % name)
		else:
			print("  RED    %-32s -> reddedildi (beklenen davranış)" % name)
			if g.coins != g_coins_before:
				_flag("import[%s]: reddedilen içe aktarma mevcut durumu bozdu (coins %d -> %d)" \
					% [name, g_coins_before, g.coins])
		g.free()


func _malicious_variants(baseline: Dictionary) -> Array:
	var variants: Array = []

	# --- oda konumu / boyutu: _validate_save_dict sayı TİPİNİ kontrol eder
	# ama DEĞER aralığını kontrol etmez (bkz. game.gd:1449-1452) ---
	variants.append(["floor_negatif", _mut(baseline, func(d):
		d.rooms[0].floor = -1)])
	variants.append(["floor_devasa", _mut(baseline, func(d):
		d.rooms[0].floor = 999999)])
	variants.append(["col_negatif", _mut(baseline, func(d):
		d.rooms[0].col = -999)])
	variants.append(["col_devasa", _mut(baseline, func(d):
		d.rooms[0].col = 999999)])
	variants.append(["w_negatif", _mut(baseline, func(d):
		d.rooms[0].w = -5)])
	variants.append(["w_devasa", _mut(baseline, func(d):
		d.rooms[0].w = 999999)])
	variants.append(["w_sifir", _mut(baseline, func(d):
		d.rooms[0].w = 0)])
	# --- oda `base` alanı: room_score() onu doğrudan Dictionary'ye atıyor.
	# Yanlış tip, _load_from_dict'in SONUNDAKİ başarım kontrolünde çalışma
	# zamanı hatası veriyordu — yani oyun durumu çoktan değiştikten SONRA.
	# 2026-08-21'de _validate_save_dict'e tip kapısı eklendi; bu varyantlar o
	# kapının açık kalmasını sağlar. ---
	variants.append(["base_dize", _mut(baseline, func(d):
		d.rooms[0].base = "hepsi")])
	variants.append(["base_dizi", _mut(baseline, func(d):
		d.rooms[0].base = ["wallpaper_default"])])
	variants.append(["base_sayi", _mut(baseline, func(d):
		d.rooms[0].base = 7)])
	variants.append(["base_null", _mut(baseline, func(d):
		d.rooms[0].base = null)])
	# aynı hücreye iki oda yerleştirilmiş kayıt (elle bozulmuş kod senaryosu)
	variants.append(["cakisan_odalar", _mut(baseline, func(d):
		d.rooms[1].floor = d.rooms[0].floor
		d.rooms[1].col = d.rooms[0].col)])

	# --- base/id/dirty alanları: tip kontrolü yok ---
	variants.append(["base_yanlis_tip", _mut(baseline, func(d):
		d.rooms[0].base = "not-a-dict")])
	variants.append(["base_eksik", _mut(baseline, func(d):
		d.rooms[0].erase("base"))])
	variants.append(["id_yanlis_tip", _mut(baseline, func(d):
		d.rooms[0].id = 12345)])
	variants.append(["id_tekrar", _mut(baseline, func(d):
		d.rooms[1].id = d.rooms[0].id)])
	variants.append(["dirty_hours_yanlis_tip", _mut(baseline, func(d):
		d.rooms[0].dirty_hours = "bir_milyon")])
	variants.append(["clean_left_yanlis_tip", _mut(baseline, func(d):
		d.rooms[0].clean_left = {"x": 1})])
	variants.append(["dirty_yanlis_tip", _mut(baseline, func(d):
		d.rooms[0].dirty = "evet")])

	# --- oda tipi ---
	variants.append(["type_bilinmeyen", _mut(baseline, func(d):
		d.rooms[0].type = "bu_tip_hicbir_yerde_yok")])
	variants.append(["type_bos", _mut(baseline, func(d):
		d.rooms[0].type = "")])
	variants.append(["items_icinde_sayi", _mut(baseline, func(d):
		d.rooms[0].items = [1, 2, 3])])
	variants.append(["items_icinde_bilinmeyen", _mut(baseline, func(d):
		d.rooms[0].items = ["bu_esya_yok", "bu_esya_yok"])])

	# --- para/kaynak: negatif değerler tip olarak geçerli (int/float),
	# değer olarak asla oluşmaması gereken durumlar ---
	variants.append(["coins_negatif", _mut(baseline, func(d):
		d.coins = -999999)])
	variants.append(["gems_negatif", _mut(baseline, func(d):
		d.gems = -500)])
	variants.append(["xp_negatif", _mut(baseline, func(d):
		d.xp = -100)])
	variants.append(["coins_devasa", _mut(baseline, func(d):
		d.coins = 9223372036854775807)])

	# --- yapısal: kat/blok listesi, boş oda dizisi ---
	variants.append(["floor_blocks_negatif", _mut(baseline, func(d):
		d.floor_blocks = [-1, -1])])
	variants.append(["floor_blocks_bos", _mut(baseline, func(d):
		d.floor_blocks = [])])
	variants.append(["floors_sifir", _mut(baseline, func(d):
		d.floors = 0)])
	variants.append(["floors_negatif", _mut(baseline, func(d):
		d.floors = -3)])
	variants.append(["rooms_bos_dizi", _mut(baseline, func(d):
		d.rooms = [])])

	# --- ilerleme sayaçları: negatif/aralık dışı indeksler ---
	variants.append(["quest_index_negatif", _mut(baseline, func(d):
		d.quest_index = -1000)])
	variants.append(["quest_index_devasa", _mut(baseline, func(d):
		d.quest_index = 999999)])
	variants.append(["prestige_negatif", _mut(baseline, func(d):
		d.prestige_level = -5)])
	variants.append(["staff_tier_devasa", _mut(baseline, func(d):
		d.staff_tier = 999999)])
	variants.append(["next_room_id_yanlis_tip", _mut(baseline, func(d):
		d.next_room_id = "abc")])

	# --- tip karışıklığı: sayısal alanlara dizi/sözlük ---
	variants.append(["shift_end_unix_yanlis_tip", _mut(baseline, func(d):
		d.shift_end_unix = {"x": 1})])
	variants.append(["pending_income_yanlis_tip", _mut(baseline, func(d):
		d.pending_income = [1, 2, 3])])

	# --- sürüm sınırları ---
	variants.append(["save_version_gelecek", _mut(baseline, func(d):
		d.save_version = 99999)])
	variants.append(["save_version_negatif", _mut(baseline, func(d):
		d.save_version = -1)])

	return variants


func _mut(baseline: Dictionary, fn: Callable) -> Dictionary:
	var d: Dictionary = baseline.duplicate(true)
	d.rooms = baseline.rooms.duplicate(true)
	fn.call(d)
	return d


# --- 2) Render katmanı: en riskli senaryoları gerçek sahnede dene ----------

func _attack_render(game) -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	game.coins += 200000
	game.start_shift(8)
	game.shift_end_unix = game.now() + 999999.0
	main._finish_loading_screen()
	await get_tree().process_frame

	var risky_names := ["floor_negatif", "floor_devasa", "col_negatif", "col_devasa",
		"w_negatif", "w_devasa", "w_sifir", "cakisan_odalar", "rooms_bos_dizi",
		"base_yanlis_tip", "base_eksik", "floor_blocks_negatif", "floor_blocks_bos"]
	var baseline: Dictionary = JSON.parse_string(Marshalls.base64_to_utf8(game.export_save_code()))
	for atk in _malicious_variants(baseline):
		var name: String = atk[0]
		if not risky_names.has(name):
			continue
		var payload: Dictionary = atk[1]
		var ok: bool = game.import_save_code(Marshalls.utf8_to_base64(JSON.stringify(payload)))
		cases_run += 1
		if not ok:
			print("  RED    %-24s -> render denemesi gerekmedi (reddedildi)" % name)
			continue
		print("  KABUL  %-24s -> _rebuild_hotel() deneniyor..." % name)
		main._rebuild_hotel()
		await get_tree().process_frame
		print("           node sayısı: %d (çökme yok)" % get_tree().get_node_count())

	# render denemeleri bittikten sonra oyunu tekrar sağlıklı bir duruma
	# döndür ki sonraki bölümler kirlenmiş singleton üstünde çalışmasın
	game.new_game()
	main.queue_free()
	await get_tree().process_frame


# --- 3) Rastgele eylem dizileri: ekonomi değişmezlerini kırmaya çalış ------

func _attack_random_sequences() -> void:
	var actions := [
		"start_shift_random", "skip_shift", "buy_room_random", "sell_room_random",
		"buy_item_random", "move_room_random", "clean_room_random", "buy_floor",
		"poke_guest_random", "catch_guest", "collect", "buy_bundle_random",
		"buy_staff_upgrade", "do_prestige", "claim_daily_reward",
	]
	for run_i in 8:
		var g = _new_instance()
		g.coins = 500000
		g.gems = 500
		g.time_scale = 3600.0
		for step_i in 200:
			var a: String = actions[rng.randi() % actions.size()]
			_apply_random_action(g, a)
			g.simulate_to(g.now() - rng.randf_range(-5.0, 20.0))
		_check_invariants(g, "random_sequence[run=%d]" % run_i)
		g.free()
	print("  8 çalıştırma x 200 rastgele eylem tamamlandı.")


func _apply_random_action(g, action: String) -> void:
	match action:
		"start_shift_random":
			g.start_shift([1, 4, 8, 24, 0, -1, 999][rng.randi() % 7])
		"skip_shift":
			g.skip_shift()
		"buy_room_random":
			var types: Array = eco.room_types.keys()
			g.buy_room(types[rng.randi() % types.size()])
		"sell_room_random":
			if g.rooms.size() > 0:
				g.sell_room(rng.randi() % (g.rooms.size() + 2) - 1)  # bazen aralık dışı
		"buy_item_random":
			if g.rooms.size() > 0:
				var item_ids: Array = []
				for it in eco.items:
					item_ids.append(String(it.id))
				g.buy_item(rng.randi() % (g.rooms.size() + 2) - 1, item_ids[rng.randi() % item_ids.size()])
		"move_room_random":
			if g.rooms.size() > 0:
				var r: Dictionary = g.rooms[rng.randi() % g.rooms.size()]
				g.move_room_to(String(r.id), rng.randi_range(-5, g.floors + 5), rng.randi_range(-5, 15))
		"clean_room_random":
			if g.rooms.size() > 0:
				g.clean_room(rng.randi() % (g.rooms.size() + 2) - 1)
		"buy_floor":
			g.buy_floor()
		"poke_guest_random":
			g.poke_guest(rng.randf())
		"catch_guest":
			g.catch_guest()
		"collect":
			g.collect()
		"buy_bundle_random":
			if g.rooms.size() > 0:
				var bundle_ids: Array = []
				for b in eco.get("bundles", []):
					bundle_ids.append(String(b.id))
				if not bundle_ids.is_empty():
					g.buy_bundle(rng.randi() % g.rooms.size(), bundle_ids[rng.randi() % bundle_ids.size()])
		"buy_staff_upgrade":
			g.buy_staff_upgrade()
		"do_prestige":
			g.do_prestige()
		"claim_daily_reward":
			g.claim_daily_reward()


# --- 4) Sınır değer / tekil çağrı saldırıları -------------------------------

func _attack_boundary_calls() -> void:
	var g = _new_instance()
	g.coins = 100000
	var calls := [
		["buy_item(-1, '')", func(): return g.buy_item(-1, "")],
		["buy_item(9999, 'bed_basic')", func(): return g.buy_item(9999, "bed_basic")],
		["clean_room(-1)", func(): return g.clean_room(-1)],
		["clean_room(9999)", func(): return g.clean_room(9999)],
		["sell_room(-1)", func(): return g.sell_room(-1)],
		["sell_room(9999)", func(): return g.sell_room(9999)],
		["room_sell_value(-1)", func(): return g.room_sell_value(-1)],
		["room_sell_gem_value(9999)", func(): return g.room_sell_gem_value(9999)],
		["move_room_to('yok', 0, 0)", func(): return g.move_room_to("yok", 0, 0)],
		["can_place_room('', -1, -1)", func(): return g.can_place_room("", -1, -1)],
		["place_room('standard', -999, -999)", func(): return g.place_room("standard", -999, -999)],
		["buy_room('')", func(): return g.buy_room("")],
		["buy_room('bilinmeyen')", func(): return g.buy_room("bilinmeyen")],
		["start_shift(-5)", func(): return g.start_shift(-5)],
		["start_shift(0)", func(): return g.start_shift(0)],
		["upgrade_base(-1, 'wallpaper_default')", func(): return g.upgrade_base(-1, "wallpaper_default")],
		["staff_upgrade_cost(-5)", func(): return g.staff_upgrade_cost(-5)],
		["buy_bundle(-1, 'yok')", func(): return g.buy_bundle(-1, "yok")],
		["import_save_code('')", func(): return g.import_save_code("")],
		["import_save_code(garbage-base64)", func(): return g.import_save_code("!!!not-base64!!!")],
		["room_score({})", func(): return g.room_score({})],
		["room_tier({})", func(): return g.room_tier({})],
		["item_def('yok')", func(): return g.item_def("yok")],
		["bundle_def('yok')", func(): return g.bundle_def("yok")],
	]
	for c in calls:
		var label: String = c[0]
		var fn: Callable = c[1]
		cases_run += 1
		var result = fn.call()
		print("  %-42s -> %s" % [label, str(result)])
	_check_invariants(g, "boundary_calls")
	g.free()
