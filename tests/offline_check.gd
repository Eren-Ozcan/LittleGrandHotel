extends Node
## Uzakta geçen sürenin aritmetiği: 24 saatlik kapak, otomatik yenilemenin
## bankadaki saatleri ve kapağın attığı sürenin ikisiyle örtüşmesi.
##
## Bu üçü tek başına doğru olup birlikte yanlış olabilir ve hata her seferinde
## oyuncunun aleyhine işler: kapak yalnızca GELİRİ sınırlarsa, atılan saatler
## boyunca otomatik yenileme "hayalet" vardiyalar açıp coin harcar — oyuncu üç
## gün sonra döndüğünde kasası boşalmış, geliri tavanda kalmış olur. reefy'de
## aynı sınıf hata (`dirt-grace`) yokluğun yalnızca örtüşen kısmının iptal
## edilmesi kuralıyla çivilenmiş; buradaki karşılığı bu dosya.
##
## `simulate_to()` hedef zaman damgasını dışarıdan aldığı için saat sahtelemeye
## gerek yok: tüm senaryolar gerçek saatten bağımsız, deterministik.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/offline_check.tscn

var failures := 0
var checks := 0
var game: Node


func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  OK   ", label)
	else:
		failures += 1
		printerr("  FAIL ", label)


## Her senaryo aynı yerden başlasın: taze oyun, gerçek zaman ölçeği, bir odalı
## küçük otel ve elle başlatılmış bir vardiya.
func _fresh(hours: int = 1, coins: int = 100000) -> float:
	game.new_game()
	game.time_scale = 1.0
	game.coins = coins
	var t0: float = game.now()
	game.last_sim_unix = t0
	game.start_shift(hours)
	return t0


func _ready() -> void:
	game = get_node("/root/Game")
	_test_cap_limits_income()
	_test_cap_does_not_burn_coins()
	_test_auto_renew_consumes_banked_hours()
	_test_auto_renew_stops_without_coins()
	_test_short_gap_is_not_offline()

	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _test_cap_limits_income() -> void:
	print("\n[1] Kapak geliri sınırlıyor")
	var cap_hours: float = float(game.eco.offline_cap_hours)
	# Gelir kasaya değil BEKLEYEN gelire yazılır (oyuncu "Topla" deyince kasaya
	# geçer) — ölçüm bu yüzden pending_income üzerinden.
	var t0 := _fresh(24)
	game.auto_renew_hours_left = 0.0

	# Kapağın iki katı kadar uzakta kal: kazanç kapak kadar olmalı, iki katı değil.
	game.simulate_to(t0 + cap_hours * 2.0 * 3600.0)
	var earned_long: float = game.pending_income

	var t1 := _fresh(24)
	game.auto_renew_hours_left = 0.0
	game.simulate_to(t1 + cap_hours * 3600.0)
	var earned_cap: float = game.pending_income

	check(earned_long > 0.0, "uzun yokluk gelir üretti (%.0f)" % earned_long)
	check(earned_cap > 0.0, "kapak kadar yoklukta da gelir var (%.0f)" % earned_cap)
	check(earned_long <= earned_cap + 0.01,
		"kapağın ötesi ek gelir VERMEDİ (%.0f <= %.0f)" % [earned_long, earned_cap])


func _test_cap_does_not_burn_coins() -> void:
	print("\n[2] Kapağın attığı süre coin yakmıyor")
	var cap_hours: float = float(game.eco.offline_cap_hours)
	var t0 := _fresh(1)
	# Bol bol bankalı saat: kapak yalnızca geliri sınırlasaydı, atılan saatler
	# boyunca art arda vardiya yenilenir ve hem coin hem banka erirdi.
	game.auto_renew_hours_left = 1000.0
	var renews_before: int = game.auto_renew_count

	game.simulate_to(t0 + cap_hours * 4.0 * 3600.0)
	var renews: int = game.auto_renew_count - renews_before

	# Kapak içinde kaç vardiya sığıyorsa o kadar yenileme olmalı; atılan
	# süredeki "hayalet" yenilemeler sayılmamalı.
	var max_expected := int(cap_hours) + 1
	check(renews > 0, "kapak içinde yenileme oldu (%d)" % renews)
	check(renews <= max_expected,
		"atılan süre için hayalet yenileme YAPILMADI (%d <= %d)" % [renews, max_expected])


func _test_auto_renew_consumes_banked_hours() -> void:
	print("\n[3] Banka yalnızca gerçekten yenilenen vardiyalar kadar eriyor")
	var t0 := _fresh(1)
	game.auto_renew_hours_left = 5.0
	var banked_before: float = game.auto_renew_hours_left
	var renews_before: int = game.auto_renew_count

	game.simulate_to(t0 + 3.0 * 3600.0)
	var renews: int = game.auto_renew_count - renews_before
	var spent: float = banked_before - game.auto_renew_hours_left

	check(renews >= 1, "yokluk boyunca vardiya yenilendi (%d)" % renews)
	check(is_equal_approx(spent, float(renews) * float(game.last_shift_hours)),
		"bankadan tam olarak yenileme kadar saat düştü (%.1f saat / %d yenileme)"
		% [spent, renews])
	check(game.auto_renew_hours_left >= 0.0, "banka eksiye düşmedi")


func _test_auto_renew_stops_without_coins() -> void:
	print("\n[4] Parası bitince yenileme duruyor")
	var t0 := _fresh(1, 0)
	# Vardiya elle başlatıldı ama kasa boş: banka dolu olsa bile yenileme
	# olmamalı, yoksa coin eksiye düşer ya da döngü asılı kalır.
	game.coins = 0
	game.auto_renew_hours_left = 100.0
	var renews_before: int = game.auto_renew_count

	game.simulate_to(t0 + 10.0 * 3600.0)

	check(game.coins >= 0, "coin eksiye düşmedi (%d)" % game.coins)
	check(game.auto_renew_count == renews_before,
		"parasızken hiç yenileme yapılmadı (%d)" % (game.auto_renew_count - renews_before))
	check(is_equal_approx(game.auto_renew_hours_left, 100.0),
		"bankadaki saatler harcanmadı (%.1f)" % game.auto_renew_hours_left)


func _test_short_gap_is_not_offline() -> void:
	print("\n[5] Kısa boşluk 'arka plan' sayılmıyor")
	# Ön planda kare kare ilerleyen küçük boşluklar tam-verim sayılmamalı:
	# sayılsaydı odalar hiç kirlenmez, Temizlik Odası anlamını yitirirdi.
	var t0 := _fresh(24)
	game.auto_renew_hours_left = 0.0
	var threshold: float = game.BACKGROUND_CATCHUP_THRESHOLD_SECONDS
	check(threshold > 0.0, "eşik tanımlı (%.0f sn)" % threshold)

	# Eşiğin altında kalan bir ilerleme: sim ilerlemeli ama kirlenme mekaniği
	# açık kalmalı. Burada ölçülebilir tek şey ilerlemenin gerçekleştiği.
	var before: float = game.last_sim_unix
	game.simulate_to(t0 + threshold * 0.5)
	check(game.last_sim_unix > before, "kısa boşlukta da simülasyon ilerledi")
	check(is_equal_approx(game.last_sim_unix, t0 + threshold * 0.5),
		"simülasyon tam hedefe kadar ilerledi")
