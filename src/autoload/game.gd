extends Node
## Little Grand Hotel — çekirdek simülasyon v2 (MVP).
## UI'dan bağımsızdır; headless test edilebilir (tests/sim_check.gd).
## Tüm denge değerleri data/economy.json'dan, görevler data/quests.json'dan gelir.

signal state_changed
signal quest_completed(quest: Dictionary)
signal achievement_unlocked(achievement: Dictionary)
signal leveled_up(new_level: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 8
## Göçle yükseltilebilen en eski kayıt sürümü
const MIN_SAVE_VERSION := 2
const ECO_PATH := "res://data/economy.json"
const QUESTS_PATH := "res://data/quests.json"
const ACHIEVEMENTS_PATH := "res://data/achievements.json"
const AUTOSAVE_INTERVAL := 30.0

var eco: Dictionary = {}
var quests: Array = []
var achievements: Array = []

var coins: int = 0
var gems: int = 0
var xp: int = 0
var floors: int = 2
var rooms: Array = []            # {"type":String, "items":Array, "dirty":bool, "clean_left":float}
var shift_end_unix: float = 0.0
var pending_income: float = 0.0
var last_sim_unix: float = 0.0

# Görev ilerlemesi
var quest_index: int = 0
var stat_shifts: int = 0
var stat_collects: int = 0
var stat_collected_total: int = 0
var stat_cleans: int = 0

## Vardiya geçmişi (İstatistik ekranı): {"hours", "cost", "at"} — son 20 kayıt
var shift_history: Array = []

## Açılmış başarım id'leri (kalıcı, tek seferlik ödüller).
var unlocked_achievements: Array = []

## Prestij: devretme sayısı. new_game() ile sıfırlanmaz — kalıcıdır.
var prestige_level: int = 0

## Uygulama açılışında sen-yokken kazanılan gelir (UI popup için; UI okur ve sıfırlar).
var offline_earned: int = 0

## Test hızlandırması: 1.0 = gerçek zaman, 3600.0 = 1 sn : 1 oyun-saati
var time_scale: float = 1.0

## Ayarlar (kayda dahil)
var sound_on: bool = true
var music_on: bool = true

## Otomatik vardiya yenileme: bir vardiya bitince ve coin yetiyorsa, oyuncu
## geri dönmeden aynı süreyle otomatik olarak yeni bir vardiya başlar. Modern
## boşta-bekleme (idle) oyunlarında beklenen "uzaktayken de üretim sürer"
## hissini korur — aksi halde vardiya bitince otel tamamen durur ve oyuncu
## günler sonra geri döndüğünde büyük bir kısmı boşa geçmiş olur. İlk
## vardiyayı elle başlatmak hâlâ gerekir (last_shift_hours == 0 iken devre dışı).
var auto_renew_shift: bool = true
var last_shift_hours: int = 0

## Bu oturumda (son state_changed'den bu yana) otomatik yenilenen vardiya
## sayısı ve harcanan coin — "Hoş geldin" popup'ında şeffaflık için.
var auto_renew_count: int = 0
var auto_renew_spent: int = 0

## Günlük giriş serisi: modern mobil oyunlarda en standart tutundurma
## mekaniği. last_daily_claim_day: en son ödül alınan gün indeksi
## (-1 = hiç alınmadı). Sunucusuz, tamamen cihaz saatinden türer.
var daily_streak: int = 0
var last_daily_claim_day: int = -1

## Uyuyan misafiri dürtme (gizli müfettiş) günlük sayacı — Hotel City'deki
## "poke sleeping guests" mekaniği. Gün değişince sayaç sıfırlanır.
var poke_day: int = -1
var poke_count: int = 0

var _autosave_acc := 0.0
var _rooms_changed_in_sim := false


func _ready() -> void:
	eco = load_json(ECO_PATH)
	quests = load_json(QUESTS_PATH).get("quests", [])
	achievements = load_json(ACHIEVEMENTS_PATH).get("achievements", [])
	if not load_game():
		new_game()


func _process(delta: float) -> void:
	simulate_to(now())
	_autosave_acc += delta
	if _autosave_acc >= AUTOSAVE_INTERVAL:
		_autosave_acc = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if not eco.is_empty():
			save_game()


# --- Kuruluş -----------------------------------------------------------

func now() -> float:
	return Time.get_unix_time_from_system()


## Sunucusuz "haftalık etkinlik" için deterministik hafta indeksi: her yerde
## (ve her cihazda) aynı anda aynı sayıyı üretir, yalnızca takvimden türer.
func current_week_index() -> int:
	return int(now() / (7.0 * 86400.0))


## Günlük giriş serisi için gün indeksi (haftalık temayla aynı yöntem).
func daily_day_index() -> int:
	return int(now() / 86400.0)


func daily_reward_available() -> bool:
	return last_daily_claim_day != daily_day_index()


## Şu an talep edilirse seri kaçıncı güne çıkar (henüz durumu değiştirmez).
## Bir gün atlanırsa seri 1'e sıfırlanır; art arda gelinirse +1 uzar.
func daily_next_streak() -> int:
	var di := daily_day_index()
	if last_daily_claim_day == di - 1:
		return daily_streak + 1
	return 1


## Günlük ödülü talep eder ve verilen ödül dict'ini döner; bugün zaten
## alınmışsa veya ödül tablosu boşsa boş dict döner (yan etkisiz).
func claim_daily_reward() -> Dictionary:
	if not daily_reward_available():
		return {}
	var cycle: Array = eco.get("daily_rewards", [])
	if cycle.is_empty():
		return {}
	daily_streak = daily_next_streak()
	last_daily_claim_day = daily_day_index()
	var reward: Dictionary = cycle[(daily_streak - 1) % cycle.size()]
	coins += int(reward.get("coins", 0))
	gems += int(reward.get("gems", 0))
	state_changed.emit()
	return reward


func load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func new_game() -> void:
	coins = int(eco.start.coins)
	gems = int(eco.start.gems)
	xp = 0
	floors = int(eco.building.start_floors)
	rooms = [make_room("standard"), make_room("standard")]
	shift_end_unix = 0.0
	pending_income = 0.0
	last_sim_unix = now()
	quest_index = 0
	stat_shifts = 0
	stat_collects = 0
	stat_collected_total = 0
	stat_cleans = 0
	shift_history = []
	unlocked_achievements = []
	last_shift_hours = 0
	auto_renew_count = 0
	auto_renew_spent = 0
	daily_streak = 0
	last_daily_claim_day = -1
	poke_day = -1
	poke_count = 0
	offline_earned = 0
	state_changed.emit()


func room_def(type: String) -> Dictionary:
	return eco.room_types.get(type, {})


func make_room(type: String) -> Dictionary:
	var d := room_def(type)
	return {
		"type": type,
		"items": [],
		"dirty": false,
		"clean_left": float(d.get("stay_hours", 0)),
		"dirty_hours": 0.0,
	}


# --- Bina --------------------------------------------------------------

func max_slots() -> int:
	return floors * int(eco.building.slots_per_floor)


func floor_price() -> int:
	return int(float(eco.building.floor_price) * pow(float(eco.building.floor_mult), floors - int(eco.building.start_floors)))


func can_buy_floor() -> bool:
	return floors < int(eco.building.max_floors) and coins >= floor_price()


func buy_floor() -> bool:
	if not can_buy_floor():
		return false
	simulate_to(now())
	coins -= floor_price()
	floors += 1
	_check_progress()
	state_changed.emit()
	return true


# --- Oda puanı, kademe, yıldız (GDD §4.3–4.4) --------------------------

func item_def(item_id: String) -> Dictionary:
	for it in eco.items:
		if it.id == item_id:
			return it
	return {}


func room_score(room: Dictionary) -> int:
	var total := 0
	for item_id in room.items:
		total += int(item_def(item_id).get("sp", 0))
	return total


func room_tier(room: Dictionary) -> int:
	var score := room_score(room)
	var tier := 0
	for i in eco.tier_thresholds.size():
		if score >= int(eco.tier_thresholds[i]):
			tier = i
	return tier


func tier_name(tier: int) -> String:
	return eco.tier_names[tier]


func guest_rooms() -> Array:
	return rooms.filter(func(r): return room_def(r.type).category == "guest")


func has_type(type: String) -> bool:
	for r in rooms:
		if r.type == type:
			return true
	return false


func housekeeping_active() -> bool:
	return has_type("housekeeping")


func facility_diversity() -> int:
	var seen := {}
	for r in rooms:
		if room_def(r.type).category == "facility":
			seen[r.type] = true
	return seen.size()


func clean_fraction() -> float:
	var guests := guest_rooms()
	if guests.is_empty():
		return 1.0
	var clean := 0
	for r in guests:
		if not r.dirty:
			clean += 1
	return float(clean) / guests.size()


func star_rating() -> int:
	# GDD §4.4: ortalama kademe %50 + tesis çeşitliliği %30 + hizmet %20
	var guests := guest_rooms()
	var avg_tier := 0.0
	if not guests.is_empty():
		for r in guests:
			avg_tier += room_tier(r)
		avg_tier /= guests.size()
	var max_tier := float(eco.tier_names.size() - 1)
	var score := 0.5 * (avg_tier / max_tier) \
		+ 0.3 * (minf(facility_diversity(), 5.0) / 5.0) \
		+ 0.2 * clean_fraction()
	return clampi(1 + roundi(score * 4.0), 1, 5)


# --- Gelir ve vardiya (GDD §5.2) ---------------------------------------

## Mevcut durumda anlık saatlik gelir (kirli odalar hariç, otomasyon payı dahil).
func hourly_income() -> float:
	var smult := float(eco.star_mult[str(star_rating())])
	var occ := float(eco.occupancy_base)
	var hk := housekeeping_active()
	var total := 0.0
	for r in rooms:
		var d := room_def(r.type)
		if d.category == "facility":
			total += float(d.base_income)
		elif d.category == "guest":
			if r.dirty and not hk:
				continue
			var rate := float(d.base_income) * float(eco.tier_mult[room_tier(r)])
			if hk:
				rate *= float(d.stay_hours) / (float(d.stay_hours) + float(eco.auto_clean_hours))
			total += rate
	return total * smult * occ * prestige_mult()


func staff_count() -> int:
	return maxi(1, ceili(rooms.size() * float(eco.staff_per_room)))


func shift_cost(hours: int) -> int:
	return staff_count() * hours * int(eco.shift_rates[str(hours)])


func shift_active() -> bool:
	return now() < shift_end_unix


func shift_remaining_game_hours() -> float:
	return maxf(0.0, (shift_end_unix - now()) * time_scale / 3600.0)


func start_shift(hours: int) -> bool:
	if shift_active():
		return false
	var cost := shift_cost(hours)
	if coins < cost:
		return false
	simulate_to(now())
	coins -= cost
	shift_end_unix = now() + hours * 3600.0 / time_scale
	last_shift_hours = hours
	stat_shifts += 1
	shift_history.append({"hours": hours, "cost": cost, "at": now()})
	if shift_history.size() > 20:
		shift_history.pop_front()
	_check_progress()
	state_changed.emit()
	return true


## Vardiyanın kalan kısmını elmasla anında bitirmenin bedeli.
func skip_shift_gem_cost() -> int:
	if not shift_active():
		return 0
	return maxi(1, ceili(shift_remaining_game_hours() / float(eco.gem_skip_hours)))


## Elmas harcayarak vardiyanın kalanını anında işler ve vardiyayı bitirir.
func skip_shift() -> bool:
	if not shift_active():
		return false
	var cost := skip_shift_gem_cost()
	if gems < cost:
		return false
	simulate_to(now())
	gems -= cost
	_advance(shift_remaining_game_hours())
	shift_end_unix = now()
	_check_progress()
	state_changed.emit()
	return true


func simulate_to(to_unix: float) -> void:
	if last_sim_unix <= 0.0:
		last_sim_unix = to_unix
		return
	# Vardiya biterken hâlâ ilerlenecek zaman kaldıysa (uzun süre uzakta
	# kalınmış olabilir) ve otomatik yenileme açıksa, art arda yeni vardiyalar
	# başlatarak boşta geçen süreyi engelle. guard, coin biterse veya yenileme
	# kapalıysa sonsuz döngüye girmeden çıkışı garanti eder.
	var guard := 0
	while true:
		var accrue_end := minf(to_unix, shift_end_unix)
		if accrue_end > last_sim_unix:
			var game_hours := (accrue_end - last_sim_unix) * time_scale / 3600.0
			_advance(game_hours)
			last_sim_unix = accrue_end
		if last_sim_unix >= to_unix or shift_end_unix > to_unix:
			break
		guard += 1
		if guard > 2000 or not _try_auto_renew():
			break
	last_sim_unix = maxf(last_sim_unix, to_unix)
	if _rooms_changed_in_sim:
		_rooms_changed_in_sim = false
		state_changed.emit()


## Bir vardiya süresi dolduğunda (ve hâlâ ilerlenecek zaman varsa) otomatik
## olarak aynı süreyle bir yenisini başlatmayı dener. Yalnızca en az bir kez
## elle vardiya başlatılmışsa (last_shift_hours > 0) devreye girer.
func _try_auto_renew() -> bool:
	if not auto_renew_shift or last_shift_hours <= 0:
		return false
	var cost := shift_cost(last_shift_hours)
	if coins < cost:
		return false
	coins -= cost
	var started_at := shift_end_unix
	shift_end_unix += last_shift_hours * 3600.0 / time_scale
	stat_shifts += 1
	auto_renew_count += 1
	auto_renew_spent += cost
	shift_history.append({"hours": last_shift_hours, "cost": cost, "at": started_at, "auto": true})
	if shift_history.size() > 20:
		shift_history.pop_front()
	_check_progress()
	return true


## Vardiya penceresi içindeki game_hours kadar ilerlet.
func _advance(game_hours: float) -> void:
	var smult := float(eco.star_mult[str(star_rating())]) * prestige_mult()
	var occ := float(eco.occupancy_base)
	var hk := housekeeping_active()
	for r in rooms:
		var d := room_def(r.type)
		if d.category == "facility":
			pending_income += float(d.base_income) * game_hours * smult * occ
		elif d.category == "guest":
			var rate := float(d.base_income) * float(eco.tier_mult[room_tier(r)]) * smult * occ
			if hk:
				# Otomasyon: temizlik molaları duty oranıyla modellenir, oda hiç "kirli" kalmaz.
				var duty := float(d.stay_hours) / (float(d.stay_hours) + float(eco.auto_clean_hours))
				pending_income += rate * game_hours * duty
				if r.dirty:
					r.dirty = false
					r["dirty_hours"] = 0.0
					_rooms_changed_in_sim = true
			else:
				if r.dirty:
					# Kirli bırakılan oda zamanla istilaya döner (Hotel City'deki
					# hamamböceği): eşik aşımında temizlik paralı hale gelir.
					var before_inf := room_infested(r)
					r["dirty_hours"] = float(r.get("dirty_hours", 0.0)) + game_hours
					if room_infested(r) != before_inf:
						_rooms_changed_in_sim = true
					continue
				var earn_h := minf(game_hours, float(r.clean_left))
				pending_income += rate * earn_h
				r.clean_left = float(r.clean_left) - earn_h
				if r.clean_left <= 0.0001:
					r.dirty = true
					# Tek büyük ilerletmede (çevrimdışı) kirlenme anından sonra
					# kalan saatler de kirli geçmiştir — istila birikimine say.
					r["dirty_hours"] = float(r.get("dirty_hours", 0.0)) + (game_hours - earn_h)
					_rooms_changed_in_sim = true


## Kirli oda eşik saatten uzun kirli kaldıysa istilaya dönmüştür:
## temizlik artık bedava değildir (eco.infest.clean_cost).
func room_infested(r: Dictionary) -> bool:
	return bool(r.dirty) and float(r.get("dirty_hours", 0.0)) >= float(eco.infest.after_hours)


func clean_cost(index: int) -> int:
	if index < 0 or index >= rooms.size():
		return 0
	return int(eco.infest.clean_cost) if room_infested(rooms[index]) else 0


func clean_room(index: int) -> bool:
	if index < 0 or index >= rooms.size():
		return false
	var r: Dictionary = rooms[index]
	if not r.dirty:
		return false
	simulate_to(now())
	var cost := clean_cost(index)
	if coins < cost:
		return false
	coins -= cost
	r.dirty = false
	r["dirty_hours"] = 0.0
	r.clean_left = float(room_def(r.type).get("stay_hours", 0))
	stat_cleans += 1
	add_xp(2)
	_check_progress()
	state_changed.emit()
	return true


## Uyuyan misafiri dürtme: günlük tavanlı, şansa bağlı "gizli müfettiş"
## bonusu. rng_override testler için deterministik zar (0..1 arası);
## negatif bırakılırsa gerçek rastgele kullanılır.
func pokes_left() -> int:
	if poke_day != daily_day_index():
		return int(eco.poke.daily_cap)
	return maxi(0, int(eco.poke.daily_cap) - poke_count)


func poke_guest(rng_override: float = -1.0) -> int:
	if pokes_left() <= 0:
		return 0
	if poke_day != daily_day_index():
		poke_day = daily_day_index()
		poke_count = 0
	poke_count += 1
	var roll := rng_override if rng_override >= 0.0 else randf()
	if roll >= float(eco.poke.chance):
		state_changed.emit()
		return 0
	var bonus := int(eco.poke.base) + int(eco.poke.per_star) * star_rating()
	coins += bonus
	add_xp(1)
	_check_progress()
	state_changed.emit()
	return bonus


## Kaçan misafiri yakalama: vardiya sırasında sokakta yürüyüp giden misafire
## dokununca saatlik gelirin bir kesri kadar bonus verir (Hotel City'deki
## "müşteriyi resepsiyona sürükleme"). Hızı UI'daki doğuş aralığı sınırlar.
func catch_guest() -> int:
	if not shift_active():
		return 0
	simulate_to(now())
	var bonus := maxi(5, int(hourly_income() * float(eco.catch.bonus_hourly_frac)))
	coins += bonus
	add_xp(1)
	_check_progress()
	state_changed.emit()
	return bonus


func collect() -> int:
	simulate_to(now())
	var amount := int(pending_income)
	if amount <= 0:
		return 0
	pending_income -= amount
	coins += amount
	stat_collects += 1
	stat_collected_total += amount
	add_xp(maxi(1, int(amount / 10.0)))
	_check_progress()
	state_changed.emit()
	return amount


# --- Satın alma --------------------------------------------------------

## Oda sayısı arttıkça personel maliyeti de artar (staff_per_room). Bu, en
## ucuz (1 saatlik) vardiyayı her zaman karşılayabilmek için tutulması
## gereken coin miktarıdır — harcama bunun altına düşürmemelidir, yoksa
## oyuncu hiç vardiya başlatamayan bir çıkmaza girebilir.
func min_shift_reserve(extra_rooms: int = 0) -> int:
	var staff := maxi(1, ceili((rooms.size() + extra_rooms) * float(eco.staff_per_room)))
	return staff * int(eco.shift_rates["1"])


func can_buy_room(type: String) -> bool:
	var d := room_def(type)
	if d.is_empty():
		return false
	return rooms.size() < max_slots() \
		and level() >= int(d.unlock_level) \
		and coins - int(d.price) >= min_shift_reserve(1)


func buy_room(type: String) -> bool:
	if not can_buy_room(type):
		return false
	simulate_to(now())
	coins -= int(room_def(type).price)
	rooms.append(make_room(type))
	_check_progress()
	state_changed.emit()
	return true


## Eşyanın elmasla mı (premium) yoksa coin'le mi satıldığını söyler.
func item_is_premium(it: Dictionary) -> bool:
	return int(it.get("gem_price", 0)) > 0


## Dekorasyon dürtmesi için: seviye kilidi açık en ucuz coin'li eşyanın
## fiyatı (-1 = alınabilir eşya yok). UI, boş odada bu tutar karşılanıyorsa
## "Dekore et!" rozeti gösterir.
func cheapest_item_price() -> int:
	var best := -1
	for it in eco.items:
		if item_is_premium(it) or level() < int(it.get("unlock_level", 1)):
			continue
		if best < 0 or int(it.price) < best:
			best = int(it.price)
	return best


func can_afford_item(it: Dictionary) -> bool:
	if item_is_premium(it):
		return gems >= int(it.gem_price)
	return coins - int(it.price) >= min_shift_reserve()


## Bir eşyanın belirli bir odada zaten olup olmadığını söyler. Eşyalar odaya
## yalnızca birer kez eklenebilir — aksi halde en ucuz/en erken açılan eşya
## (ör. Masa Lambası/Basit Yatak) tekrar tekrar alınarak kademe eşiği neredeyse
## bedavaya sömürülebilir (tier_thresholds tüm eşyaların birer kez toplanacağı
## varsayımıyla kurulu: 12 eşyanın SP toplamı 645, en üst eşik 550).
func room_has_item(room_index: int, item_id: String) -> bool:
	if room_index < 0 or room_index >= rooms.size():
		return false
	return item_id in rooms[room_index].items


func buy_item(room_index: int, item_id: String) -> bool:
	if room_index < 0 or room_index >= rooms.size():
		return false
	var it := item_def(item_id)
	if it.is_empty() or not can_afford_item(it) or level() < int(it.get("unlock_level", 1)):
		return false
	if room_has_item(room_index, item_id):
		return false
	simulate_to(now())
	if item_is_premium(it):
		gems -= int(it.gem_price)
	else:
		coins -= int(it.price)
	rooms[room_index].items.append(item_id)
	_check_progress()
	state_changed.emit()
	return true


# --- Hazır dekor paketleri (Hotel City "pre-decorated rooms") -----------

func bundle_def(id: String) -> Dictionary:
	for b in eco.get("bundles", []):
		if b.id == id:
			return b
	return {}


## Paket fiyatı: eşyaların toplamı üzerinden indirim (tek tek almaktan ucuz).
func bundle_price(b: Dictionary) -> int:
	var total := 0.0
	for iid in b.get("items", []):
		total += float(item_def(iid).get("price", 0))
	return int(round(total * (1.0 - float(b.get("discount", 0.0)))))


## Paket kilidi: içindeki en yüksek seviyeli eşyanın kilidiyle aynı.
func bundle_unlock_level(b: Dictionary) -> int:
	var lv := 1
	for iid in b.get("items", []):
		lv = maxi(lv, int(item_def(iid).get("unlock_level", 1)))
	return lv


func can_buy_bundle(b: Dictionary) -> bool:
	if b.is_empty():
		return false
	return level() >= bundle_unlock_level(b) \
		and coins - bundle_price(b) >= min_shift_reserve()


func buy_bundle(room_index: int, bundle_id: String) -> bool:
	if room_index < 0 or room_index >= rooms.size():
		return false
	var b := bundle_def(bundle_id)
	if not can_buy_bundle(b):
		return false
	simulate_to(now())
	coins -= bundle_price(b)
	for iid in b.items:
		if not room_has_item(room_index, iid):
			rooms[room_index].items.append(iid)
	_check_progress()
	state_changed.emit()
	return true


# --- Oda taşıma / satma -------------------------------------------------

## Satış iadesi: oda + coin'li eşya bedellerinin sell_refund oranı.
func room_sell_value(index: int) -> int:
	var r: Dictionary = rooms[index]
	var total := float(room_def(r.type).price)
	for iid in r.items:
		total += float(item_def(iid).get("price", 0))
	return int(total * float(eco.sell_refund))


## Premium (elmaslı) eşyaların iadesi elmas olarak yapılır.
func room_sell_gem_value(index: int) -> int:
	var total := 0.0
	for iid in rooms[index].items:
		total += float(item_def(iid).get("gem_price", 0))
	return int(total * float(eco.sell_refund))


func sell_room(index: int) -> bool:
	if index < 0 or index >= rooms.size() or rooms.size() <= 1:
		return false
	simulate_to(now())
	coins += room_sell_value(index)
	gems += room_sell_gem_value(index)
	rooms.remove_at(index)
	state_changed.emit()
	return true


## İki odanın bina içindeki yerini değiştirir (yerleşim düzenleme).
func move_room(a: int, b: int) -> bool:
	if a == b or a < 0 or b < 0 or a >= rooms.size() or b >= rooms.size():
		return false
	var tmp: Dictionary = rooms[a]
	rooms[a] = rooms[b]
	rooms[b] = tmp
	state_changed.emit()
	return true


# --- XP / seviye (GDD §5.3) --------------------------------------------

func xp_for_level(n: int) -> int:
	if n <= 1:
		return 0
	return int(float(eco.xp_curve.base) * pow(n - 1, float(eco.xp_curve.exp)))


func level() -> int:
	var n := 1
	while xp >= xp_for_level(n + 1):
		n += 1
	return n


func add_xp(amount: int) -> void:
	var before := level()
	xp += amount
	var gained := level() - before
	if gained > 0:
		gems += int(eco.levelup_gems) * gained
		leveled_up.emit(level())


# --- Prestij: kalıcı gelir çarpanı karşılığında devretme -----------------

## Her prestij, gelire kalıcı bir çarpan ekler (bileşik değil, toplamsal).
func prestige_mult() -> float:
	return 1.0 + float(eco.prestige.mult_gain) * prestige_level


func can_prestige() -> bool:
	return level() >= int(eco.prestige.min_level)


## Oteli devreder: prestige_level kalıcı olarak artar, ilerlemenin geri
## kalanı (coin, oda, görev, başarım vb.) new_game() ile sıfırlanır.
func do_prestige() -> bool:
	if not can_prestige():
		return false
	prestige_level += 1
	new_game()
	return true


# --- Görevler (GDD §4.7) -----------------------------------------------

func current_quest() -> Dictionary:
	if quest_index >= quests.size():
		return {}
	return quests[quest_index]


func quest_progress(q: Dictionary) -> Array:
	# [mevcut, hedef]
	var target := int(q.get("target", 1))
	match String(q.type):
		"start_shifts":
			return [stat_shifts, target]
		"collects":
			return [stat_collects, target]
		"collect_total":
			return [stat_collected_total, target]
		"cleans":
			return [stat_cleans, target]
		"rooms":
			return [rooms.size(), target]
		"floors":
			return [floors, target]
		"star":
			return [star_rating(), target]
		"own_type":
			return [1 if has_type(String(q.get("room", ""))) else 0, 1]
		"tier":
			var best := 0
			for r in rooms:
				if room_def(r.type).category == "guest":
					best = maxi(best, room_tier(r))
			return [best, target]
		"level":
			return [level(), target]
	return [0, target]


func _quest_done(q: Dictionary) -> bool:
	var p := quest_progress(q)
	return p[0] >= p[1]


func _check_quests() -> void:
	while true:
		var q := current_quest()
		if q.is_empty() or not _quest_done(q):
			break
		coins += int(q.get("reward_coins", 0))
		gems += int(q.get("reward_gems", 0))
		quest_index += 1
		quest_completed.emit(q)


# --- Başarımlar ----------------------------------------------------------

## Görevlerden farklı olarak sırasız: her başarım bağımsız kontrol edilir
## ve hedefine ulaşınca kalıcı olarak (bir kez) ödül verir.
func _check_achievements() -> void:
	for a: Dictionary in achievements:
		var id := String(a.id)
		if unlocked_achievements.has(id):
			continue
		var p := quest_progress(a)
		if p[0] >= p[1]:
			coins += int(a.get("reward_coins", 0))
			gems += int(a.get("reward_gems", 0))
			unlocked_achievements.append(id)
			achievement_unlocked.emit(a)


func _check_progress() -> void:
	_check_quests()
	_check_achievements()


## Kaydı siler ve sıfırdan başlatır (Ayarlar → Kaydı sıfırla). Prestij de dahil
## tüm ilerlemeyi siler — do_prestige()'den farklı olarak çarpanı korumaz.
func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	prestige_level = 0
	new_game()
	save_game()


# --- Kayıt (GDD §10.1–10.2) --------------------------------------------

func _save_dict() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"coins": coins,
		"gems": gems,
		"xp": xp,
		"floors": floors,
		"rooms": rooms,
		"shift_end_unix": shift_end_unix,
		"pending_income": pending_income,
		"last_sim_unix": last_sim_unix,
		"quest_index": quest_index,
		"stat_shifts": stat_shifts,
		"stat_collects": stat_collects,
		"stat_collected_total": stat_collected_total,
		"stat_cleans": stat_cleans,
		"shift_history": shift_history,
		"unlocked_achievements": unlocked_achievements,
		"prestige_level": prestige_level,
		"time_scale": time_scale,
		"sound_on": sound_on,
		"music_on": music_on,
		"auto_renew_shift": auto_renew_shift,
		"last_shift_hours": last_shift_hours,
		"daily_streak": daily_streak,
		"last_daily_claim_day": last_daily_claim_day,
		"poke_day": poke_day,
		"poke_count": poke_count,
	}


func save_game(path: String = SAVE_PATH) -> void:
	simulate_to(now())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_save_dict()))


## Eski kayıtları adım adım güncel sürüme taşır. Her case tek bir sürüm
## atlaması yapar; yeni sürüm eklerken buraya yeni bir case eklenir.
func _migrate_save(data: Dictionary) -> Dictionary:
	var v := int(data.get("save_version", 0))
	while v < SAVE_VERSION:
		match v:
			2:
				# v3: vardiya geçmişi + ses ayarları eklendi
				if not data.has("shift_history"):
					data["shift_history"] = []
				if not data.has("sound_on"):
					data["sound_on"] = true
				if not data.has("music_on"):
					data["music_on"] = true
			3:
				# v4: başarımlar eklendi
				if not data.has("unlocked_achievements"):
					data["unlocked_achievements"] = []
			4:
				# v5: prestij eklendi
				if not data.has("prestige_level"):
					data["prestige_level"] = 0
			5:
				# v6: otomatik vardiya yenileme eklendi. last_shift_hours
				# bilerek 0 bırakılır — mevcut oyuncular güncellemeden sonra
				# vardiyayı bir kez daha elle başlatınca zincir devreye girer.
				if not data.has("auto_renew_shift"):
					data["auto_renew_shift"] = true
				if not data.has("last_shift_hours"):
					data["last_shift_hours"] = 0
			6:
				# v7: günlük giriş serisi eklendi.
				if not data.has("daily_streak"):
					data["daily_streak"] = 0
				if not data.has("last_daily_claim_day"):
					data["last_daily_claim_day"] = -1
			7:
				# v8: misafir dürtme sayacı eklendi (istila için oda içi
				# dirty_hours alanı .get varsayılanıyla geriye uyumludur).
				if not data.has("poke_day"):
					data["poke_day"] = -1
				if not data.has("poke_count"):
					data["poke_count"] = 0
		v += 1
		data["save_version"] = v
	return data


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return _load_from_dict(parsed)


## Kaydı bulut yerine paylaşılabilir bir metin koduna dönüştürür (Ayarlar →
## Kaydı dışa aktar). Diske yazmadan aynı alan kümesini base64'e sarar.
func export_save_code() -> String:
	simulate_to(now())
	return Marshalls.utf8_to_base64(JSON.stringify(_save_dict()))


## Dışa aktarılan bir kodu geçerli oyun durumuna geri yükler (Ayarlar →
## Kaydı içe aktar). Bozuk/geçersiz kodlarda dokunmadan false döner.
func import_save_code(code: String) -> bool:
	var json_text := Marshalls.base64_to_utf8(code.strip_edges())
	if json_text.is_empty():
		return false
	var parsed = JSON.parse_string(json_text)
	return _load_from_dict(parsed)


func _load_from_dict(parsed) -> bool:
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var v := int(parsed.get("save_version", 0))
	if v < MIN_SAVE_VERSION or v > SAVE_VERSION:
		return false
	parsed = _migrate_save(parsed)
	coins = int(parsed.get("coins", 0))
	gems = int(parsed.get("gems", 0))
	xp = int(parsed.get("xp", 0))
	floors = int(parsed.get("floors", int(eco.building.start_floors)))
	rooms = parsed.get("rooms", [])
	shift_end_unix = float(parsed.get("shift_end_unix", 0.0))
	pending_income = float(parsed.get("pending_income", 0.0))
	last_sim_unix = float(parsed.get("last_sim_unix", now()))
	quest_index = int(parsed.get("quest_index", 0))
	stat_shifts = int(parsed.get("stat_shifts", 0))
	stat_collects = int(parsed.get("stat_collects", 0))
	stat_collected_total = int(parsed.get("stat_collected_total", 0))
	stat_cleans = int(parsed.get("stat_cleans", 0))
	shift_history = parsed.get("shift_history", [])
	unlocked_achievements = parsed.get("unlocked_achievements", [])
	prestige_level = int(parsed.get("prestige_level", 0))
	# Vardiya bitişi gerçek saniye tutulur; ölçek geri yüklenmezse
	# hızlı modda kaydedilen vardiya normal hızda 60/3600 kat kısalır.
	time_scale = float(parsed.get("time_scale", 1.0))
	sound_on = bool(parsed.get("sound_on", true))
	music_on = bool(parsed.get("music_on", true))
	auto_renew_shift = bool(parsed.get("auto_renew_shift", true))
	last_shift_hours = int(parsed.get("last_shift_hours", 0))
	daily_streak = int(parsed.get("daily_streak", 0))
	last_daily_claim_day = int(parsed.get("last_daily_claim_day", -1))
	poke_day = int(parsed.get("poke_day", -1))
	poke_count = int(parsed.get("poke_count", 0))
	# Çevrimdışı kazanç tavanı (GDD §10.2 saat güvenliği)
	var cap_real_seconds := float(eco.offline_cap_hours) * 3600.0 / time_scale
	if now() - last_sim_unix > cap_real_seconds:
		last_sim_unix = now() - cap_real_seconds
	var pending_before := pending_income
	auto_renew_count = 0
	auto_renew_spent = 0
	simulate_to(now())
	offline_earned = int(pending_income - pending_before)
	_check_achievements()  # yeni eklenen başarımlar için geriye dönük kontrol
	state_changed.emit()
	return true
