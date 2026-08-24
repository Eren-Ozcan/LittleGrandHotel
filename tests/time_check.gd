extends Node
## Gün ve hafta sınırında değişen her şey.
##
## Bu aritmetiğin bozulduğunu fark etmek zor: takvim ilerledikçe kendini
## düzeltiyormuş gibi görünür. Bayat bir gün indeksine göre sayan bir sınır ya
## oyuncuyu sonsuza kadar kilitler ya da her çağrıda sıfırlanır — ikisi de
## "çalışıyor" gibi durur, ta ki biri gece yarısını geçene kadar oynayana dek.
## reefy'de bu yüzden ödüllü reklam sınırının kendi testi var; buradaki karşılığı
## günlük ödül serisi, dürtme hakkı ve haftalık tema.
##
## Saat SAHTELENMİYOR: karar veren fonksiyonların hepsi "kayıtlı gün indeksi"ni
## bugünkü indeksle karşılaştırıyor, dolayısıyla kayıtlı indeksi bugüne göre
## kaydırmak gerçek bir gün geçişiyle aynı şey.
##
## Çalıştırma:
##   tools\Godot_v4.7-stable_win64_console.exe --headless --path . res://tests/time_check.tscn

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


func _ready() -> void:
	game = get_node("/root/Game")
	_test_daily_reward_day_boundary()
	_test_streak_reset_on_gap()
	_test_poke_cap_day_boundary()
	_test_week_and_day_agree()
	_test_income_boost_window()

	print("=".repeat(64))
	if failures == 0:
		print("TÜM TESTLER GEÇTİ (%d kontrol)" % checks)
	else:
		printerr("%d/%d TEST BAŞARISIZ" % [failures, checks])
	get_tree().quit(1 if failures > 0 else 0)


func _test_daily_reward_day_boundary() -> void:
	print("\n[1] Günlük ödül gün sınırı")
	var today: int = game.daily_day_index()

	game.last_daily_claim_day = today
	check(not game.daily_reward_available(), "bugün alınmışsa tekrar alınamaz")

	game.last_daily_claim_day = today - 1
	check(game.daily_reward_available(), "yeni gün açılınca yeniden alınabilir")

	game.daily_streak = 3
	var before_coins: int = game.coins
	var reward: Dictionary = game.claim_daily_reward()
	check(not reward.is_empty(), "ödül verildi")
	check(game.daily_streak == 4, "art arda gün seriyi bir artırdı (%d)" % game.daily_streak)
	check(game.last_daily_claim_day == today, "son alım günü bugüne yazıldı")
	check(game.coins > before_coins or int(reward.get("gems", 0)) > 0,
		"ödülün karşılığı hesaba geçti")

	# Aynı gün ikinci talep hiçbir şey yapmamalı — yoksa uygulamayı kapatıp
	# açan oyuncu ödülü istediği kadar toplar.
	var coins_after: int = game.coins
	var streak_after: int = game.daily_streak
	check(game.claim_daily_reward().is_empty(), "aynı gün ikinci talep boş döndü")
	check(game.coins == coins_after and game.daily_streak == streak_after,
		"ikinci talep hiçbir şeyi değiştirmedi")


func _test_streak_reset_on_gap() -> void:
	print("\n[2] Seri, gün atlanınca sıfırlanır")
	var today: int = game.daily_day_index()

	game.daily_streak = 6
	game.last_daily_claim_day = today - 1
	check(game.daily_next_streak() == 7, "dünden gelen seri uzuyor (7)")

	game.last_daily_claim_day = today - 2
	check(game.daily_next_streak() == 1, "bir gün atlandıysa seri 1'e döndü")

	game.last_daily_claim_day = today - 30
	check(game.daily_next_streak() == 1, "uzun aradan sonra da seri 1")

	game.last_daily_claim_day = -1
	check(game.daily_next_streak() == 1, "hiç alınmamışsa seri 1")

	# Döngü uzunluğundan büyük seri, tabloyu başa sarmalı (7 günlük tablo).
	var cycle: Array = game.eco.get("daily_rewards", [])
	check(not cycle.is_empty(), "ödül tablosu dolu")
	game.daily_streak = cycle.size()
	game.last_daily_claim_day = today - 1
	game.claim_daily_reward()
	check(game.daily_streak == cycle.size() + 1,
		"seri tablo uzunluğunu aşabiliyor (%d)" % game.daily_streak)


func _test_poke_cap_day_boundary() -> void:
	print("\n[3] Dürtme hakkı gün sınırı")
	var today: int = game.daily_day_index()
	var cap: int = int(game.eco.poke.daily_cap)

	game.poke_day = today
	game.poke_count = cap
	check(game.pokes_left() == 0, "günlük hak dolunca sıfır kaldı")

	game.poke_day = today - 1
	game.poke_count = cap
	check(game.pokes_left() == cap,
		"yeni gün hakkı tazeledi (%d)" % game.pokes_left())

	# İlk dürtme sayacı bugüne taşımalı; aksi halde dünkü sayı bugünü de yer.
	game.poke_guest(1.0)  # rng_override = 1.0 → ödül yok, sayaç yine de artar
	check(game.poke_day == today, "sayaç bugüne taşındı")
	check(game.poke_count == 1, "yeni günün ilk dürtmesi 1 (%d)" % game.poke_count)
	check(game.pokes_left() == cap - 1, "kalan hak bir azaldı")

	game.poke_count = cap
	check(game.poke_guest(1.0) == 0, "hak bitince dürtme çalışmıyor")
	check(game.poke_count == cap, "hak bitince sayaç artmadı")


func _test_week_and_day_agree() -> void:
	print("\n[4] Hafta ve gün indeksi aynı saati okuyor")
	var day: int = game.daily_day_index()
	var week: int = game.current_week_index()
	check(week == int(day / 7.0),
		"hafta indeksi gün indeksinin yedide biri (gün %d, hafta %d)" % [day, week])
	check(game.current_week_index() == week, "arka arkaya iki çağrı aynı haftayı verdi")


func _test_income_boost_window() -> void:
	print("\n[5] Reklam geliri bonusunun penceresi")
	game.time_scale = 1.0
	game.boost_end_unix = 0.0
	check(is_equal_approx(game.income_boost_mult(), 1.0), "bonus yokken çarpan 1.0")

	game.start_income_boost(30.0, 2.0)
	check(is_equal_approx(game.income_boost_mult(), 2.0), "bonus başlayınca çarpan 2.0")
	var first_end: float = game.boost_end_unix
	check(first_end > game.now(), "bitiş zamanı ileride")

	# İkinci reklam süreyi UZATMALI, sıfırdan başlatmamalı.
	game.start_income_boost(30.0, 2.0)
	check(game.boost_end_unix > first_end,
		"ikinci bonus süreyi uzattı (%.0f > %.0f)" % [game.boost_end_unix, first_end])

	# Süre dolunca çarpan kendiliğinden düşmeli — ayrı bir "kapat" çağrısı yok.
	game.boost_end_unix = game.now() - 1.0
	check(is_equal_approx(game.income_boost_mult(), 1.0),
		"süre dolunca çarpan 1.0'a döndü")
